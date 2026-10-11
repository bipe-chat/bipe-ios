# Proseio fork notes

This repo is Proseio's iOS app: a fork of Element X iOS (AGPL-3.0). Upstream conventions in `AGENTS.md` still apply. This file adds the fork rules.

## Rules

- **All Proseio code lives in `Components/ProseioKit`** (local Swift package, linked into the ElementX target). Element X sources get small hooks only. Keep the upstream diff small so rebases stay cheap.
- **Never hand-edit `Components/ProseioKit/Sources/ProseioKit/Generated/`.** It comes from `../proseio-shared` (`node tools/gen.mjs`). Change registries and strings there.
- Proseio UI strings come from `ProseioStrings` (generated), not `Untranslated.strings` and not Localazy.
- Platform logic (badge verification, normalisation, scam detection) must pass `../proseio-shared/test-vectors/`. Android mirrors the same vectors.
- Build settings, identifiers and entitlements: `app.yml`, `project.yml`, `target.yml`, then `xcodegen`. Never edit `ElementX.xcodeproj` directly.
- The `Enterprise/` submodule (private Element repo) is not used. `Package.swift` skips it when absent.

## Upstream

- `upstream` = element-hq/element-x-ios (push disabled). `origin` = michellzappa/proseio-ios. Local `main` tracks `origin/main`.
- Rebase: `git fetch upstream && git rebase upstream/develop`.
- git-lfs is not installed on the dev Mac. The LFS filter is overridden in this clone's local config; LFS files (snapshots, dev media) are pointers. Snapshot tests need git-lfs.

## Build (green gate)

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Device builds (signed, automatic provisioning with the Centaur Labs team):

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'platform=iOS,name=MZ Air' -allowProvisioningUpdates build
```

### Ad-hoc build signed as CENTAUR LABS OU

Development builds carry the developer's personal certificate (Apple always issues development certificates to a person, even in a company team). For a build signed **"Apple Distribution: CENTAUR LABS OU"**, archive and export ad hoc:

```bash
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release -destination 'generic/platform=iOS' -archivePath build/Proseio.xcarchive -allowProvisioningUpdates
```

```bash
xcodebuild -exportArchive -archivePath build/Proseio.xcarchive -exportOptionsPlist Tools/Proseio/ExportAdHoc.plist -exportPath build/adhoc -allowProvisioningUpdates
```

```bash
xcrun devicectl device install app --device <UDID> build/adhoc/ElementX.ipa
```

Devices must be registered in the Centaur Labs team (automatic signing does this for connected devices).

## Signing

- **Dev builds use the Centaur Labs team (`992N457T8D`)** with bundle ID `br.com.proseio.app.dev` and app group `group.br.com.proseio.dev`. Approved by MZ on 11 October 2026.
- **The production ID `br.com.proseio.app` stays unregistered** until the Proseio organisation account exists. App IDs belong to the team that registers them; never register the production ID under Centaur.
- Switching to production: change `DEVELOPMENT_TEAM`, `BASE_BUNDLE_IDENTIFIER` and `APP_GROUP_IDENTIFIER` in `app.yml`, then `xcodegen`.

## Rebrand status

Done: display name, production app name, dev bundle ID and app group, Element's team ID replaced.

- **OAuth login:** redirect is the private-use scheme `<bundle id>:/oauth/callback` (RFC 8252); client URI, logo, terms and privacy URLs moved to `https://proseio.com.br/...` because MAS requires them on the client URI host and requires the scheme to be the reverse of that host. Pages do not exist yet. **Verified 11 October 2026:** sign-in to matrix.org works end to end on a device (MAS dynamic registration accepted the client).
- **Accent colour:** açaí (`#7C2C78` light, `#DA96D4` dark, `#692465` / `#E6AFE0` high contrast) in `accent-color.colorset`. See proseio/docs/design/identity.md.
- **App icon: PLACEHOLDER** drawn in code (white bubble on açaí). Replace with designer artwork.

Entitlements removed from the fork (they block provisioning outside Element's team):
- `com.apple.developer.usernotifications.filtering` (NSE). Apple grants it on request only. Without it the NSE cannot silently drop notifications. Request it for Proseio later.
- Element Classic app group and keychain group in the app entitlements (`group.im.vector`, owned by Element's team).

Element leftovers cleaned up (11 October 2026):
- **Associated domains:** only `applinks:proseio.com.br`. Element domains, `applinks:matrix.to` and `webcredentials:*.element.io` are gone. matrix.to links inside messages still open in the app: that is URL parsing (`AppRoutes.swift`), not universal links.
- **Background tasks:** `BGTaskSchedulerPermittedIdentifiers` are `$(BASE_BUNDLE_IDENTIFIER).background.refresh` and `.background.search-backfill`. `AppSettings` derives the same IDs from `InfoPlistReader.main.baseBundleIdentifier`.
- **Help links:** `encryptionURL`, `deviceVerificationURL`, `chatBackupDetailsURL`, `identityPinningViolationDetailsURL` and `historySharingDetailsURL` are `nil` in `AppSettings`, so their "Learn more" links are hidden (`AttributedString.proseioReplaceLink` in ProseioKit). Set a URL when Proseio has a help page. Terms, privacy and copyright already point at `proseio.com.br`.
- **Matrix IDs:** the identity-reset warning in member details and the soft-logout notice show the handle when the resolver knows it.
- **401 retry:** `ProseioAPIClient.withTokenRetry` re-reads the access token once on HTTP 401. The handle resolver and the "Nome de usuário" screen use it.

Left on purpose: `elementWebHosts` and `accountProvisioningHost` (link parsing only), `elementProAppStoreURL` (only shown when a server requires Element Pro), Element Call and SDK URLs, `io.element.elementx.*` dispatch queue and notification IDs (internal, not user-visible).

Not done (needs the domain, Apple team or brand):
- Help pages on `proseio.com.br` for the hidden "Learn more" links
- Element Classic migration settings in `app.yml`
- Final app icon artwork, onboarding copy

## Design tokens

- Compound tokens come from the Proseio fork **michellzappa/compound-design-tokens** (local clone `~/Dev/Proseio/proseio-tokens`, notes in its `PROSEIO.md`). The repo keeps the upstream name on purpose: SwiftPM names a mirrored package after the mirror's repo, and `compound-ios` and `element-call-ios` both expect `compound-design-tokens`.
- `Tools/XcodeGen/mirrors.json` maps Element's URL to the fork for every package. `postGenCommand.sh` copies it into the workspace on each `xcodegen`.
- `compound-ios/Package.swift` pins the fork's version tag (`exact:`). Bump it when the fork gets a new tag.
- `ORGANIZATIONNAME` in `project.yml` (file headers)
- **Telemetry off (done 11 Oct 2026):** `Components/Secrets/Secrets.swift` sets Sentry, PostHog and rageshake to `nil`. That also disables Element Call analytics, which only switch on when app analytics exist. If `Secrets.swift` is ever regenerated from `Secrets.pkl`, keep these `nil`. Later: remove the Sentry and PostHog packages from `project.yml` to cut build size.
- **Server (done 11 Oct 2026):** default account provider `proseio.com.br` (base `https://matrix.proseio.com.br`), picker hidden (`allowOtherAccountProviders = false`), push gateway `https://push.proseio.com.br` (Sygnal, issue #61; never matrix.org).
- **TestFlight:** `Tools/Proseio/testflight.sh` archives Release with a UTC timestamp build number and uploads with `Tools/Proseio/ExportAppStore.plist`. Plan: `docs/testflight-plan.md`.

## Troubleshooting

- **Login stuck on "loading" after choosing a server:** check the app log for `TimedOut` on `/.well-known/matrix/client`. On 11 October 2026 the cause was the phone's Tailscale routing, not the app. Logs: `xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer --domain-identifier group.br.com.proseio.dev --source Library/Logs/br.com.proseio.app.dev/<file> --destination <local file>`.

