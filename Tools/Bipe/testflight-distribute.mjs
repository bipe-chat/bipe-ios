#!/usr/bin/env node
// Gives an uploaded build to the external TestFlight testers, with the App Store Connect API (no web UI).
// Waits until App Store Connect has processed the build, adds it to the external group and submits it
// for beta review. A build of an already approved version goes to the testers at once.
// Usage: node Tools/Bipe/testflight-distribute.mjs <build number>   (testflight.sh runs it after the upload)
// Key "Bipe CI" (App Manager): ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH as in testflight.sh.
import { APP_ID, asc, sleep } from "./asc.mjs";

const GROUP = "Amigos"; // the external group with the public link

const build = process.argv[2];
if (!/^\d+$/.test(build ?? "")) throw new Error("usage: testflight-distribute.mjs <build number>");

let found;
for (let attempt = 0; attempt < 60; attempt++) {
  const { data } = await asc("GET", `/v1/builds?filter[app]=${APP_ID}&filter[version]=${build}&fields[builds]=processingState`);
  found = data[0];
  const state = found?.attributes.processingState;
  if (state === "VALID") break;
  if (state === "FAILED" || state === "INVALID") throw new Error(`build ${build}: processing ${state}`);
  console.log(`build ${build}: ${state ?? "not listed yet"}, waiting`);
  await sleep(60_000);
}
if (found?.attributes.processingState !== "VALID") throw new Error(`build ${build}: not processed after an hour`);

const groups = await asc("GET", `/v1/apps/${APP_ID}/betaGroups?fields[betaGroups]=name,isInternalGroup`);
const group = groups.data.find((g) => g.attributes.name === GROUP && !g.attributes.isInternalGroup);
if (!group) throw new Error(`no external group "${GROUP}"`);
await asc("POST", `/v1/betaGroups/${group.id}/relationships/builds`, { data: [{ type: "builds", id: found.id }] });

const review = await asc("GET", `/v1/builds/${found.id}/betaAppReviewSubmission`).catch(() => null);
if (!review?.data) {
  await asc("POST", "/v1/betaAppReviewSubmissions", {
    data: { type: "betaAppReviewSubmissions", relationships: { build: { data: { type: "builds", id: found.id } } } },
  });
}
const detail = await asc("GET", `/v1/builds/${found.id}/buildBetaDetail`);
console.log(`build ${build}: in "${GROUP}", external state ${detail.data.attributes.externalBuildState}`);
