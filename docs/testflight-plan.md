# TestFlight plan (11 October 2026)

Goal: friends install Proseio on iPhone and use `proseio.com.br` during the 11-day dev-server window.

## Distribution model

- **Team:** Centaur Labs OU (`992N457T8D`) until Proseio has its own Apple organisation account.
- **Bundle ID:** `br.com.proseio.app.dev` (already registered under Centaur). The production ID `br.com.proseio.app` stays unregistered.
- **App Store Connect record name: "Proseio Beta"**, not "Proseio". App names are unique on the App Store; keep "Proseio" free for the production app under Proseio's own account.
- **Testers:** friends are **external testers** through a **public TestFlight link**. External testing needs Beta App Review for the first build of each version. Internal testing (no review) is only for App Store Connect users of the Centaur team.

## Blockers before the first upload

| # | Item | Owner | Why |
|---|---|---|---|
| 1 | Create the App Store Connect app record "Proseio Beta" for `br.com.proseio.app.dev`, primary language pt-BR | MZ (Centaur account) | Creating records and accepting agreements is the account holder's step |
| 2 | Beta App Information: description, feedback email, privacy policy URL, test-account sign-in details for the reviewer | MZ + me (text drafted by me) | Required for external testing review |
| 3 | **Privacy policy page** at `https://proseio.com.br/privacidade` (the app already links there) | Me (page), MZ (approve copy) | Reviewers and testers need a reachable policy |
| 4 | **Reviewer account:** a demo account on `proseio.com.br` with credentials given to Apple | Me (issue a token; account created by MZ) | Sign-up is invite-only; review fails without a way in |
| 5 | Export compliance answer for end-to-end encryption | MZ (legal call) | The app uses standard encryption (Matrix Olm/Megolm); Element declares `ITSAppUsesNonExemptEncryption = false`. Confirm the same answer applies to Proseio |
| 6 | Build number increments on every upload (`CURRENT_PROJECT_VERSION`) | Me | App Store Connect rejects duplicate builds |

## Strongly recommended before friends join

| Item | Owner | Effect if skipped |
|---|---|---|
| **Push notifications:** APNs key (.p8) from the Centaur account → Sygnal on the server | MZ (create key), me (deploy) | Friends only see messages while the app is open |
| Disable telemetry placeholders (Sentry, PostHog) → `nil` | Me | Consent prompt for analytics that go nowhere |
| Replace Element links in onboarding and settings that still point to element.io | Me | Confusing branding |
| Default server `proseio.com.br` and hide the server picker in this build | Me | Friends land on matrix.org by default |

## Upload pipeline

1. Archive Release with the Centaur team (as in PROSEIO.md, ad-hoc section).
2. Export with an App Store Connect export options plist (`method: app-store-connect`, `destination: upload`), `-allowProvisioningUpdates`. Xcode uploads with the signed-in Apple account on this Mac.
3. Wait for processing in App Store Connect, add the build to the external group, submit for Beta App Review.
4. After approval, share the public link.

## Alternative that works today

The server is standard Matrix. Until TestFlight is live, friends can use:

- **Element Web:** `https://chat.proseio.com.br` (any browser)
- **Element X** (App Store / Play Store): choose `proseio.com.br` as the account provider

Trade-off: the official Element X apps send push notifications through Element's push gateway, so Element sees push metadata (not message content). Acceptable for a friends test, not for production.

## Sign-up for friends

Invite-only. A registration token for 10 sign-ups, valid 12 days, is in MZ's Keychain (`proseio-friends-token`). Share it with friends directly; never post it publicly.

## Status of my part of #60 (11 October 2026)

- Done: default server `proseio.com.br`, server picker hidden, push gateway pointed at our own host, telemetry off, upload script `Tools/Proseio/testflight.sh`.
- Drafted, not published: `/privacidade` and `/termos` pages (proseio-infra `compose/site/`). Waiting for MZ: contact email, copy approval (humanizer pass), legal review.
- Reviewer access: a single-use registration token (60 days) is in MZ's Keychain as `proseio-review-token`. In the Beta App Review notes: "Choose Create account, then use this registration token: <token>". The reviewer creates their own account.

## Draft Beta App Information (DRAFT, humanizer pass pending)

- **Beta App Description (pt-BR):** Proseio é um aplicativo de mensagens brasileiro, com servidores no Brasil e conversas privadas criptografadas de ponta a ponta. Nesta fase de testes, o acesso é só por convite.
- **What to Test:** criar conta com o código de convite, enviar mensagens e fotos, criar um grupo, fazer uma chamada de voz.
- **Feedback email:** to be set by MZ.
