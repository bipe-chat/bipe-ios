#!/usr/bin/env node
// Sets the App Review demo account and review notes in App Store Connect, with the API (no web UI).
// It writes both the Beta App Review details (TestFlight) and the App Store review details of the
// newest App Store version that is not live. Run it again after the demo password or the invite changes.
// Usage: node Tools/Bipe/review-details.mjs
// Secrets come from the login Keychain and never go into the repo or the output:
//   bipe-review-demo   (account = demo email): password of the demo account (MAS email + password login)
//   bipe-review-invite (account = bipe): invite code for a second account
// Key "Bipe CI" (App Manager): ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH as in testflight.sh.
import { execFileSync } from "node:child_process";
import { APP_ID, asc } from "./asc.mjs";

const DEMO_EMAIL = "app-review@bipe.chat";
const CONTACT = { contactFirstName: "Michell", contactLastName: "Zappa", contactEmail: "mz@envisioning.com", contactPhone: "+31611118869" };

const keychain = (service, account) =>
  execFileSync("security", ["find-generic-password", "-s", service, "-a", account, "-w"], { encoding: "utf8" }).trim();
const password = keychain("bipe-review-demo", DEMO_EMAIL);
const invite = keychain("bipe-review-invite", "bipe");

// English: App Review reads English. The UI labels are pt-BR, with the English text in brackets.
const notes = `Sign in with the demo account:
1. On the first screen, tap "Já tenho conta" (I already have an account).
2. Tap "Entrar com e-mail e senha" (Sign in with email and password).
3. A sign-in page opens. Enter the email and password from the demo account fields.
4. Accept the terms when the app asks. If the app offers to set an 8-digit PIN, you can skip it.

To test chat between two accounts, create a second account on another device: tap "Tenho um convite" (I have an invite), enter a name, an 8-digit PIN twice and this invite code: ${invite}
The second device must be a real iPhone (sign-up uses App Attest). From the demo account you can also open the "Você" (You) tab > Ajuda (Help) > "Falar com o suporte" (Talk to support) to chat with the Bipe team.

Bipe features: @handles instead of phone numbers, Pedidos (message requests from people you do not know), the trust card on each contact and scam warnings in chats. Servers and data are in Brazil.`;

const demo = { demoAccountRequired: true, demoAccountName: DEMO_EMAIL, demoAccountPassword: password, notes };

await asc("PATCH", `/v1/betaAppReviewDetails/${APP_ID}`, {
  data: { type: "betaAppReviewDetails", id: APP_ID, attributes: { ...CONTACT, ...demo } },
});
console.log("beta review details: set");

const versions = await asc("GET", `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&fields[appStoreVersions]=versionString,appStoreState`);
const version = versions.data.find((v) => v.attributes.appStoreState !== "READY_FOR_SALE");
if (!version) {
  console.log("app store review details: no App Store version in preparation, skipped");
} else {
  const current = await asc("GET", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(() => null);
  const attributes = { ...CONTACT, ...demo };
  if (current?.data) {
    await asc("PATCH", `/v1/appStoreReviewDetails/${current.data.id}`, { data: { type: "appStoreReviewDetails", id: current.data.id, attributes } });
  } else {
    await asc("POST", "/v1/appStoreReviewDetails", {
      data: { type: "appStoreReviewDetails", attributes, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } } },
    });
  }
  console.log(`app store review details: set on version ${version.attributes.versionString}`);
}
