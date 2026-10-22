// App Store Connect API client for the Bipe tools (testflight-distribute, review-details,
// appstore-publish). One JWT signer and one request function, so no tool keeps its own copy.
// Key "Bipe CI" (App Manager): ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH as in testflight.sh.
import { createPrivateKey, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";

export const APP_ID = "6822454419"; // "Bipe Chat", chat.bipe.app.dev (bipe-chat/bipe#419 may change it)

const keyId = process.env.ASC_KEY_ID || "M2VUX56QAJ";
const issuer = process.env.ASC_ISSUER_ID || "3cfd203a-f83c-4f1b-8895-2f31c9c02a26";
let key;

const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");

function token() {
  key ??= createPrivateKey(readFileSync(process.env.ASC_KEY_PATH || `${homedir()}/.config/bipe/AuthKey_${keyId}.p8`));
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({ alg: "ES256", kid: keyId, typ: "JWT" })}.${b64({ iss: issuer, iat: now, exp: now + 900, aud: "appstoreconnect-v1" })}`;
  return `${unsigned}.${sign("sha256", Buffer.from(unsigned), { key, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
}

/**
 * One API request. An error names only the API's error details, never the response body: some
 * bodies echo secrets (the review demo password).
 */
export async function asc(method, path, body) {
  const res = await fetch(path.startsWith("https://") ? path : `https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
    body: body && JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    let detail = "";
    try { detail = JSON.parse(text).errors?.map((e) => e.detail ?? e.title).join("; ") ?? ""; } catch {}
    throw new Error(`${method} ${path.split("?")[0]}: HTTP ${res.status} ${detail}`);
  }
  return text ? JSON.parse(text) : null;
}

/** Every page of a list request. */
export async function ascAll(path) {
  const out = [];
  for (let next = path; next; ) {
    const page = await asc("GET", next);
    out.push(...page.data);
    next = page.links?.next;
  }
  return out;
}

export const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
