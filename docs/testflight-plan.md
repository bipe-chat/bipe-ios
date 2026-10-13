# TestFlight plan (11 October 2026)

Goal: friends install Bipe on iPhone and use `bipe.net.br` during the 11-day dev-server window.

## Distribution model

- **Team:** Centaur Labs OU (`992N457T8D`) until Bipe has its own Apple organisation account.
- **Bundle ID:** `chat.bipe.app.dev` (already registered under Centaur). The production ID `chat.bipe.app` stays unregistered.
- **App Store Connect record name: "Bipe Chat"** (MZ, 12 Oct 2026; was "Bipe"; Apple refused "Bipe" because another account uses it). The name under the icon is "Bipe" (`APP_DISPLAY_NAME`). The record sits under Centaur for now; it moves to Bipe's own account later through Apple's app transfer.
- **Testers:** friends are **external testers** through a **public TestFlight link**. External testing needs Beta App Review for the first build of each version. Internal testing (no review) is only for App Store Connect users of the Centaur team.

## Blockers before the first upload

| # | Item | Owner | Why |
|---|---|---|---|
| 1 | Create the App Store Connect app record "Bipe" for `chat.bipe.app.dev`, primary language pt-BR | MZ (Centaur account) | Creating records and accepting agreements is the account holder's step |
| 2 | Beta App Information: description, feedback email, privacy policy URL, test-account sign-in details for the reviewer | MZ + me (text drafted by me) | Required for external testing review |
| 3 | **Privacy policy page** at `https://bipe.chat/privacidade` (the app already links there) | Me (page), MZ (approve copy) | Reviewers and testers need a reachable policy |
| 4 | **Reviewer account:** a demo account on `bipe.net.br` with credentials given to Apple | Me (issue a token; account created by MZ) | Sign-up is invite-only; review fails without a way in |
| 5 | Export compliance answer for end-to-end encryption | MZ (legal call) | The app uses standard encryption (Matrix Olm/Megolm); Element declares `ITSAppUsesNonExemptEncryption = false`. Confirm the same answer applies to Bipe |
| 6 | Build number increments on every upload (`CURRENT_PROJECT_VERSION`) | Me | App Store Connect rejects duplicate builds |

## Strongly recommended before friends join

| Item | Owner | Effect if skipped |
|---|---|---|
| **Push notifications:** APNs key (.p8) from the Centaur account → Sygnal on the server | MZ (create key), me (deploy) | Friends only see messages while the app is open |
| Disable telemetry placeholders (Sentry, PostHog) → `nil` | Me | Consent prompt for analytics that go nowhere |
| Replace Element links in onboarding and settings that still point to element.io | Me | Confusing branding |
| Default server `bipe.net.br` and hide the server picker in this build | Me | Friends land on matrix.org by default |

## Upload pipeline

1. Archive Release with the Centaur team (as in BIPE.md, ad-hoc section).
2. Export with an App Store Connect export options plist (`method: app-store-connect`, `destination: upload`), `-allowProvisioningUpdates`. Xcode uploads with the signed-in Apple account on this Mac.
3. Wait for processing in App Store Connect, add the build to the external group, submit for Beta App Review.
4. After approval, share the public link.

## Alternative that works today

The server is standard Matrix. Until TestFlight is live, friends can use:

- **Element Web:** `https://chat.bipe.net.br` (any browser)
- **Element X** (App Store / Play Store): choose `bipe.net.br` as the account provider

Trade-off: the official Element X apps send push notifications through Element's push gateway, so Element sees push metadata (not message content). Acceptable for a friends test, not for production.

## Sign-up for friends

Invite-only. A registration token for 10 sign-ups, valid 12 days, is in MZ's Keychain (`proseio-friends-token`). Share it with friends directly; never post it publicly.

## Status of my part of #60 (11 October 2026)

- Done: default server `bipe.net.br`, server picker hidden, push gateway pointed at our own host, telemetry off, upload script `Tools/Bipe/testflight.sh`.
- Published 11 Oct 2026: `https://bipe.chat/privacidade` and `/termos` (pt-BR, English under `/en/`), contact contact@envisioning.com. Legal review still advisable before public launch.
- Reviewer access: a single-use registration token (60 days) is in MZ's Keychain as `proseio-review-token`. In the Beta App Review notes: "Choose Create account, then use this registration token: <token>". The reviewer creates their own account.

## App Store Connect record (11 October 2026)

- Created by me in the browser: "Bipe", Apple ID `6821694616`, iOS, primary language Portuguese (Brazil), bundle `chat.bipe.app.dev`, SKU `proseio-dev` (App Store Connect SKU, cannot change), Full Access.
- Test Information saved: description (below), feedback email, marketing URL `https://bipe.chat`, privacy URL `/privacidade`, review notes without the token.
- Beta App Review contact: MZ (saved 11 Oct 2026).
- Still empty: the token at the end of the review notes. MZ pastes it.
- Export compliance: no non-exempt encryption (MZ, 11 Oct 2026). `ITSAppUsesNonExemptEncryption = false` in `target.yml` answers it per build.
- First upload: build `202610111832`, 11 Oct 2026.

## Beta App Information (as saved)

- **Beta App Description (pt-BR):** Bipe é um aplicativo de mensagens brasileiro, com servidores no Brasil e conversas privadas criptografadas de ponta a ponta. Nesta fase de testes, o acesso é só por convite.
- **What to Test:** criar conta com o código de convite, enviar mensagens e fotos, criar um grupo, fazer uma chamada de voz.
- **Feedback email:** contact@envisioning.com

## Status (11 October 2026, evening)

- Groups: internal "Equipe" (needed first: App Store Connect hides External Testing until an internal group exists) and external "Amigos".
- Build `202610112038` (open sign-up, no invite code) submitted for Beta App Review in Amigos. Sign-in not required: the reviewer creates an account.
- Public link: https://testflight.apple.com/join/KUnUX9Mz, open to anyone, limit 100. It works after Apple approves the build.
- Review notes: no code, create two accounts to test chat. Old MAS reviewer token and the API reviewer invite are revoked.

## Status (11 October 2026, night)

- Build `202610112038` (no invite field) was removed from review: the server requires invite codes again.
- Build `202610120012` (invite codes, App Attest, handles, Pedidos, scam warnings, trust card) submitted for Beta App Review in Amigos. Review notes give a 2-use invite code (Keychain `proseio-review-invite`).
- Uploads sign in with the App Store Connect API key and manual App Store profiles (see BIPE.md).

## Status (13 October 2026)

- Build `202610121820` (version 26.10.1, bundle `br.com.proseio.app.dev`, uploaded 12 Oct 2026) is approved by Beta App Review. It is in Amigos (external, public link on) and Equipe (internal). No testers, feedback or crashes yet.
- The App Store Connect record "Bipe Chat" (`6821694616`) has bundle ID `br.com.proseio.app.dev`, not `chat.bipe.app.dev`. App Store Connect cannot change the bundle ID of a record after a build is uploaded.
- Since `cde6178ba` (12 Oct 2026) the app builds as `chat.bipe.app.dev`, and bipe-infra (App Attest, Sygnal, AASA) accepts only `chat.bipe.app.dev`. Builds from main need a new App Store Connect record for `chat.bipe.app.dev`.
