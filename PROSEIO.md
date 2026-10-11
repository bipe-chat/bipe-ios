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

## Signing

- **Dev builds use the Centaur Labs team (`992N457T8D`)** with bundle ID `br.com.proseio.app.dev` and app group `group.br.com.proseio.dev`. Approved by MZ on 11 October 2026.
- **The production ID `br.com.proseio.app` stays unregistered** until the Proseio organisation account exists. App IDs belong to the team that registers them; never register the production ID under Centaur.
- Switching to production: change `DEVELOPMENT_TEAM`, `BASE_BUNDLE_IDENTIFIER` and `APP_GROUP_IDENTIFIER` in `app.yml`, then `xcodegen`.

## Rebrand status

Done: display name, production app name, dev bundle ID and app group, Element's team ID replaced.

- **OAuth login:** redirect is the private-use scheme `<bundle id>:/oauth/callback` (RFC 8252); client URI, logo, terms and privacy URLs moved to `https://proseio.com.br/...` because MAS requires them on the client URI host and requires the scheme to be the reverse of that host. Pages do not exist yet.
- **Accent colour:** açaí (`#7C2C78` light, `#DA96D4` dark, `#692465` / `#E6AFE0` high contrast) in `accent-color.colorset`. See proseio/docs/design/identity.md.
- **App icon: PLACEHOLDER** drawn in code (white bubble on açaí). Replace with designer artwork.

Entitlements removed from the fork (they block provisioning outside Element's team):
- `com.apple.developer.usernotifications.filtering` (NSE). Apple grants it on request only. Without it the NSE cannot silently drop notifications. Request it for Proseio later.
- Element Classic app group and keychain group in the app entitlements (`group.im.vector`, owned by Element's team).

Not done (needs the domain, Apple team or brand):
- Associated domains (`applinks:element.io` and others) and `webcredentials` in `ElementX/SupportingFiles/target.yml`
- `BGTaskSchedulerPermittedIdentifiers` (`io.element.elementx.*`)
- Element Classic migration settings in `app.yml`
- Homeserver defaults, OIDC configuration and feature flags in app settings
- Final app icon artwork, onboarding copy

## Design tokens

- Compound tokens come from the Proseio fork **michellzappa/compound-design-tokens** (local clone `~/Dev/proseio-tokens`, notes in its `PROSEIO.md`). The repo keeps the upstream name on purpose: SwiftPM names a mirrored package after the mirror's repo, and `compound-ios` and `element-call-ios` both expect `compound-design-tokens`.
- `Tools/XcodeGen/mirrors.json` maps Element's URL to the fork for every package. `postGenCommand.sh` copies it into the workspace on each `xcodegen`.
- `compound-ios/Package.swift` pins the fork's version tag (`exact:`). Bump it when the fork gets a new tag.
- `ORGANIZATIONNAME` in `project.yml` (file headers)
- **Telemetry: Sentry (crash reports) and PostHog (analytics), both US services.** Current `Components/Secrets/Secrets.swift` holds `localhost` placeholders, so no data reaches Element's services. Before real users: set the four values to `nil` (disables SDK init and the consent prompt) or point them at Proseio-hosted instances in Brazil. Later: remove the Sentry and PostHog packages from `project.yml` to cut build size.
