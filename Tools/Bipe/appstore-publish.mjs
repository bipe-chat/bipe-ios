#!/usr/bin/env node
// Sends the App Store listing and the screenshot panels to App Store Connect, with the API (no web
// UI). bipe-chat/bipe#456. Text comes from bipe-shared/product/appstore.md (the iOS block), parsed by
// bipe-shared/tools/lib/appstore.mjs; panels come from appstore/screenshots/<device>/<locale>/, made
// by the bipe-web store image builder. Review details are Tools/Bipe/review-details.mjs, not this tool.
//
// Usage: node Tools/Bipe/appstore-publish.mjs <metadata|screenshots|all> [--dry-run] [--app-id <id>]
//          [--device iphone69] [--screenshots <dir>] [--shared <bipe-shared dir>]
//   --dry-run  reads App Store Connect and prints every change; sends nothing.
// A second run with the same input changes nothing. Key "Bipe CI": see asc.mjs.
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { APP_ID, asc, ascAll, sleep } from "./asc.mjs";
import { device } from "../../appstore/devices.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const args = process.argv.slice(2);
const opt = (flag, fallback) => (args.includes(flag) ? args[args.indexOf(flag) + 1] : fallback);
const what = args[0];
if (!["metadata", "screenshots", "all"].includes(what)) throw new Error("usage: appstore-publish.mjs <metadata|screenshots|all> [--dry-run]");
const dryRun = args.includes("--dry-run");
const appId = opt("--app-id", APP_ID);
const dev = device(opt("--device", "iphone69"));
const shotsRoot = resolve(root, opt("--screenshots", "appstore/screenshots"));
const shared = resolve(root, opt("--shared", "../bipe-shared"));

const { parseAppstore, checkAppstore, LOCALES } = await import(pathToFileURL(join(shared, "tools/lib/appstore.mjs")).href);
const listing = parseAppstore(readFileSync(join(shared, "product/appstore.md"), "utf8"));
const problems = checkAppstore(listing, JSON.parse(readFileSync(join(shared, "product/product.json"), "utf8")));
if (problems.length) throw new Error(`appstore.md fails its check:\n${problems.join("\n")}`);
const ios = listing.platforms.ios;
const version = /^BIPE_VERSION=(.+)$/m.exec(readFileSync(join(root, "Tools/Bipe/version.env"), "utf8"))[1];

const change = async (label, method, path, body) => {
  console.log(`${dryRun ? "would" : "do"}: ${label}`);
  return dryRun ? null : asc(method, path, body);
};
const differs = (current, wanted) => Object.keys(wanted).filter((k) => (current?.[k] ?? "") !== (wanted[k] ?? ""));

// --- The version in preparation ------------------------------------------------------------------

const versions = await ascAll(`/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&fields[appStoreVersions]=versionString,appStoreState,copyright`);
const released = versions.some((v) => v.attributes.appStoreState === "READY_FOR_SALE");
let target = versions.find((v) => !["READY_FOR_SALE", "REMOVED_FROM_SALE", "REPLACED_WITH_NEW_VERSION"].includes(v.attributes.appStoreState));
if (!target) {
  const made = await change(`create App Store version ${version}`, "POST", "/v1/appStoreVersions", {
    data: { type: "appStoreVersions", attributes: { platform: "IOS", versionString: version }, relationships: { app: { data: { type: "apps", id: appId } } } },
  });
  target = made?.data;
}
if (!target) {
  console.log("dry run: no version in preparation yet, so the version texts and screenshots below are not compared");
} else {
  console.log(`version ${target.attributes.versionString} (${target.attributes.appStoreState ?? "new"})`);
  // A version made in the web UI is named "1.0". It must match the build (version.env, ADR 0088).
  if (target.attributes.versionString !== version) {
    await change(`rename version ${target.attributes.versionString} to ${version}`, "PATCH", `/v1/appStoreVersions/${target.id}`, {
      data: { type: "appStoreVersions", id: target.id, attributes: { versionString: version } },
    });
  }
}

// --- Metadata ------------------------------------------------------------------------------------

if (what !== "screenshots") {
  // App info: name, subtitle, privacy URL per locale, and the categories.
  const infos = await ascAll(`/v1/apps/${appId}/appInfos`);
  const info = infos.find((i) => !["READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_INFO"].includes(i.attributes.appStoreState ?? i.attributes.state)) ?? infos[0];
  const infoLocs = await ascAll(`/v1/appInfos/${info.id}/appInfoLocalizations`);
  for (const locale of LOCALES) {
    const f = ios.locales[locale];
    const wanted = { name: f.name, subtitle: f.subtitle, privacyPolicyUrl: ios.shared.privacy_url };
    const cur = infoLocs.find((l) => l.attributes.locale === locale);
    if (!cur) {
      await change(`app info ${locale}: create`, "POST", "/v1/appInfoLocalizations", {
        data: { type: "appInfoLocalizations", attributes: { locale, ...wanted }, relationships: { appInfo: { data: { type: "appInfos", id: info.id } } } },
      });
    } else if (differs(cur.attributes, wanted).length) {
      await change(`app info ${locale}: ${differs(cur.attributes, wanted).join(", ")}`, "PATCH", `/v1/appInfoLocalizations/${cur.id}`, {
        data: { type: "appInfoLocalizations", id: cur.id, attributes: wanted },
      });
    } else console.log(`same: app info ${locale}`);
  }
  const cats = await asc("GET", `/v1/appInfos/${info.id}?include=primaryCategory,secondaryCategory`);
  const primary = cats.data.relationships.primaryCategory?.data?.id ?? null;
  const secondary = cats.data.relationships.secondaryCategory?.data?.id ?? null;
  const wantPrimary = ios.shared.primary_category, wantSecondary = ios.shared.secondary_category || null;
  if (primary !== wantPrimary || secondary !== wantSecondary) {
    await change(`categories: ${wantPrimary}, ${wantSecondary ?? "none"}`, "PATCH", `/v1/appInfos/${info.id}`, {
      data: { type: "appInfos", id: info.id, relationships: {
        primaryCategory: { data: { type: "appCategories", id: wantPrimary } },
        secondaryCategory: { data: wantSecondary ? { type: "appCategories", id: wantSecondary } : null },
      } },
    });
  } else console.log("same: categories");

  // Version texts per locale. Apple rejects whatsNew before the first release.
  if (target) {
    if ((target.attributes.copyright ?? "") !== ios.shared.copyright) {
      await change("version copyright", "PATCH", `/v1/appStoreVersions/${target.id}`, {
        data: { type: "appStoreVersions", id: target.id, attributes: { copyright: ios.shared.copyright } },
      });
    }
    const verLocs = await ascAll(`/v1/appStoreVersions/${target.id}/appStoreVersionLocalizations`);
    for (const locale of LOCALES) {
      const f = ios.locales[locale];
      const wanted = {
        description: f.description, keywords: f.keywords, promotionalText: f.promotional_text,
        supportUrl: ios.shared.support_url, marketingUrl: ios.shared.marketing_url,
        ...(released ? { whatsNew: f.release_notes } : {}),
      };
      const cur = verLocs.find((l) => l.attributes.locale === locale);
      if (!cur) {
        await change(`version texts ${locale}: create`, "POST", "/v1/appStoreVersionLocalizations", {
          data: { type: "appStoreVersionLocalizations", attributes: { locale, ...wanted }, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: target.id } } } },
        });
      } else if (differs(cur.attributes, wanted).length) {
        await change(`version texts ${locale}: ${differs(cur.attributes, wanted).join(", ")}`, "PATCH", `/v1/appStoreVersionLocalizations/${cur.id}`, {
          data: { type: "appStoreVersionLocalizations", id: cur.id, attributes: wanted },
        });
      } else console.log(`same: version texts ${locale}`);
    }
  }
}

// --- Screenshots ---------------------------------------------------------------------------------

if (what !== "metadata" && target) {
  const md5 = (buf) => createHash("md5").update(buf).digest("hex");
  const verLocs = await ascAll(`/v1/appStoreVersions/${target.id}/appStoreVersionLocalizations`);
  for (const locale of LOCALES) {
    const dir = join(shotsRoot, dev.key, locale);
    if (!existsSync(dir)) { console.log(`skip: no panels for ${locale} in ${dir} (App Store Connect uses the primary language's set)`); continue; }
    const files = readdirSync(dir).filter((f) => f.endsWith(".png")).sort();
    if (files.length < 1 || files.length > 10) throw new Error(`${dir}: ${files.length} panels; App Store Connect takes 1 to 10`);
    const local = files.map((f) => { const buf = readFileSync(join(dir, f)); return { name: f, buf, sum: md5(buf) }; });
    const loc = verLocs.find((l) => l.attributes.locale === locale);
    if (!loc) { console.log(`skip: ${locale} has no version localization yet (run metadata first)`); continue; }

    // filter[screenshotDisplayType] is not reliable: read every set and pick locally.
    const sets = await ascAll(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`);
    let set = sets.find((s) => s.attributes.screenshotDisplayType === dev.ascScreenshotType);
    const current = set ? await ascAll(`/v1/appScreenshotSets/${set.id}/appScreenshots`) : [];
    if (current.map((s) => s.attributes.sourceFileChecksum).join() === local.map((l) => l.sum).join()) {
      console.log(`same: ${locale} ${dev.label} panels (${local.length})`);
      continue;
    }
    if (!set) {
      set = (await change(`${locale}: create ${dev.ascScreenshotType} set`, "POST", "/v1/appScreenshotSets", {
        data: { type: "appScreenshotSets", attributes: { screenshotDisplayType: dev.ascScreenshotType }, relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc.id } } } },
      }))?.data;
    }
    for (const s of current) await change(`${locale}: delete old panel ${s.attributes.fileName}`, "DELETE", `/v1/appScreenshots/${s.id}`);
    const ids = [];
    for (const l of local) {
      const made = await change(`${locale}: upload ${l.name}`, "POST", "/v1/appScreenshots", {
        data: { type: "appScreenshots", attributes: { fileName: l.name, fileSize: l.buf.length }, relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set?.id ?? "dry-run" } } } },
      });
      if (!made) continue;
      for (const op of made.data.attributes.uploadOperations) {
        const res = await fetch(op.url, {
          method: op.method,
          headers: Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value])),
          body: l.buf.subarray(op.offset, op.offset + op.length),
        });
        if (!res.ok) throw new Error(`${l.name}: upload part at ${op.offset} failed, HTTP ${res.status}`);
      }
      // The checksum is a plain MD5 hex string; an object gets HTTP 409.
      await asc("PATCH", `/v1/appScreenshots/${made.data.id}`, { data: { type: "appScreenshots", id: made.data.id, attributes: { uploaded: true, sourceFileChecksum: l.sum } } });
      ids.push(made.data.id);
    }
    if (dryRun) continue;
    for (const id of ids) {
      for (let i = 0; ; i++) {
        const state = (await asc("GET", `/v1/appScreenshots/${id}`)).data.attributes.assetDeliveryState?.state;
        if (state === "COMPLETE") break;
        if (state === "FAILED" || i > 40) throw new Error(`panel ${id}: processing ${state ?? "unknown"}`);
        await sleep(5000);
      }
    }
    await asc("PATCH", `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, { data: ids.map((id) => ({ type: "appScreenshots", id })) });
    console.log(`done: ${locale} ${dev.label} panels (${ids.length})`);
  }
}
