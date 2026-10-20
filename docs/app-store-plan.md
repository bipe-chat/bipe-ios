# App Store plan (18 October 2026)

Tracker: bipe-chat/bipe#419.

Goal: Bipe on the public App Store. TestFlight works already (see `testflight-plan.md`): record "Bipe Chat" (`6822454419`, bundle `chat.bipe.app.dev`, Centaur Labs OU `992N457T8D`).

## Decision 1: which developer account

The account that owns the App Store record is the seller on the store page.

| Option | Effect |
|---|---|
| **Launch on Centaur Labs OU, transfer later** | Launch does not wait for a Bipe account. Store page shows "Centaur Labs OU" (Estonia) as seller until the transfer. This works against "data stays in Brazil". Transfer costs listed below. |
| **Bipe organisation account first** | Needs the Bipe company (bipe-chat/bipe#1, CNPJ), then D-U-N-S (bipe-chat/bipe#2), then the USD 99 enrollment. No transfer later. Launch waits for all three. |

### App transfer: what Apple allows

Source: [Overview of app transfer](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer/).

- Account Holder of each account starts and accepts the transfer.
- The app keeps its bundle ID, reviews and ratings. It stays on sale. Users keep getting updates.
- The App ID moves to the new account.
- Before the transfer: remove all TestFlight builds and testers and clear Test Information in every localization.

### App transfer: costs for Bipe

The Team ID changes. These parts depend on it:

- **Keychain.** `KEYCHAIN_ACCESS_GROUP_IDENTIFIER` starts with `$(DEVELOPMENT_TEAM)`. The first update from the new team cannot read the old keychain items. Apple says users must log in again. For device-first accounts (ADR 0057, ADR 0059) this is the largest cost:
  - The Matrix session token is in the keychain, so every user is signed out once.
  - `BipeCredentialStore` keeps the hidden password and the recovery token in the same access group. The new team cannot read either, and the iCloud Keychain copy of the token is in the same group.
  - So the silent sign-in and the token-and-PIN recovery both fail after the update. A user without a recovery email (or a linked Apple or Google account, bipe-chat/bipe#305) cannot get back into the account.
  - Encrypted history comes back only with key backup or recovery.
  - Before a transfer, a build from the old team must move every user to a factor that does not depend on the Team ID. That build is not designed yet.
- **App group.** After the transfer Centaur deletes it and the new team registers the same ID.
- **Push.** New team makes an APNs key. Sygnal gets the new key.
- **App Attest and universal links.** Both use `TeamID.bundleID`. bipe-infra must accept the new Team ID. AASA lists both during the switch.

## Decision 2: bundle ID before the first App Store build

The bundle ID is permanent after the first upload, and the App ID moves with a transfer. So the production IDs (ADR 0061) do not technically need the Bipe account.

Conflict: BIPE.md says "never register the production ID under Centaur". This option needs MZ to drop that rule. Steps if MZ drops it:

- Register `chat.bipe.app` (+ `.nse`, `.shareextension`) and `group.chat.bipe` on Centaur.
- Create a new App Store Connect record for `chat.bipe.app`.
- Change `BASE_BUNDLE_IDENTIFIER` and `APP_GROUP_IDENTIFIER` in `app.yml`, run `xcodegen`. bipe-infra (App Attest, Sygnal, AASA) accepts the new bundle ID.

If the app launches as `chat.bipe.app.dev`, the public app keeps that ID permanently.

## What the App Store needs beyond TestFlight

### Store listing

- Screenshots: 6.9" iPhone. `TARGETED_DEVICE_FAMILY` is not set, so the app is iPhone and iPad, and 13" iPad screenshots are required too. Alternative: set iPhone only.
- Subtitle, description, keywords, promotional text (pt-BR first). Copy goes through the humanizer skill.
- Support URL, marketing URL (`https://bipe.chat`), privacy URL (`https://bipe.chat/privacidade`, live).
- Category Social Networking, free, copyright line.

### Compliance forms

- **App Privacy labels.** Must match `ElementX/SupportingFiles/PrivacyInfo.xcprivacy` (handle, contacts if uploaded, device IDs for App Attest, crash data if any).
- **Age rating questionnaire** (2025 version). Chat with user-generated content gives 13+ or 16+.
- **Countries.** Brazil only or worldwide. EU distribution needs a DSA trader declaration (public address and phone). Exclude China: Apple refuses CallKit VoIP there.
- **Export compliance:** done (`ITSAppUsesNonExemptEncryption = false`).

### App Review rules for chat apps

- **1.2 user-generated content:** report content, block users, terms the user accepts, action on reports within 24 hours. Element has report and ignore. Missing: a moderation channel on the server and terms accepted at sign-up.
- **5.1.1(v) account deletion in the app:** Element deactivation exists. The Bipe flow is bipe-chat/bipe#363.
- **Reviewer access:** demo account `app-review@bipe.chat` in the review details (Keychain `bipe-review-demo`), set with `Tools/Bipe/review-details.mjs`, plus an invite code in the notes for a second account (Keychain `bipe-review-invite`).
- **4.3 copycat risk:** a reviewer can flag a fork of Element X. Name the Bipe features (handles, Pedidos, trust card) in the review notes.

### Legal

- The code is AGPL-3.0 (Element) or Element commercial licence (`LICENSE`, `LICENSE-COMMERCIAL`). The FSF says the App Store terms conflict with the GPL family (VLC precedent). Published source does not fix that conflict. Get a legal opinion, or a commercial licence or written permission from Element. Tracked in bipe-chat/bipe#16.
- Privacy policy and terms still need legal review (`testflight-plan.md`).

### Build

- Bump the version in bipe-shared (`node tools/bump-build.mjs --version YY.MM.N`), then `Tools/Bipe/testflight.sh`. The same upload goes to the App Store version page.
- Confirm production APNs in Sygnal (TestFlight already uses production APNs).

## Owners

| Item | Owner |
|---|---|
| Decision 1 (account) | MZ |
| Company, D-U-N-S and enrollment, if Bipe account (#1, #2) | MZ |
| Decision 2 (production IDs under Centaur, against the BIPE.md rule) | MZ |
| Legal call on AGPL distribution (#16) | MZ |
| Agreements, DSA trader info, Submit in App Store Connect | MZ |
| Production IDs, new record, bipe-infra, `app.yml` | Agent |
| Migration build before any transfer (keychain) | Agent, after MZ picks Centaur |
| Listing copy, privacy labels, age-rating answers (drafts) | Agent |
| iPhone only or iPad screenshots | MZ decides, agent does |
