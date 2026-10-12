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

- `upstream` = element-hq/element-x-ios (push disabled). `origin` = proseio/proseio-ios. Local `main` tracks `origin/main`.
- Rebase: `git fetch upstream && git rebase upstream/develop`.
- git-lfs is not installed on the dev Mac. The LFS filter is overridden in this clone's local config; LFS files (snapshots, dev media) are pointers. Snapshot tests need git-lfs.

## Build (green gate)

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Shared test vectors (ADR 0031 rule 4): `Components/ProseioKit/Tests/ProseioKitTests/SharedVectorTests.swift` reads `../proseio-shared/test-vectors` directly. Run it after any registry, vector or ProseioKit logic change:

```bash
cd Components/ProseioKit && swift test
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
- **Accent colour:** açaí `acai.1100` (`#80307B` light, `#D993D2` dark; high contrast `#5D1D59` / `#ECC0E7`) in `accent-color.colorset`. See proseio/docs/design/identity.md.
- **App icon:** the web mark (`proseio-web/public/brand/app-icon.svg`, white seal-tail bubble on `acai.1100`) rendered full-bleed at 1024 px; iOS applies the corner mask. iOS and web share one icon. Final designer artwork replaces both at once.

Entitlements removed from the fork (they block provisioning outside Element's team):
- `com.apple.developer.usernotifications.filtering` (NSE). Apple grants it on request only. Without it the NSE cannot silently drop notifications. Request it for Proseio later.
- Element Classic app group and keychain group in the app entitlements (`group.im.vector`, owned by Element's team).

Element leftovers cleaned up (11 October 2026):
- **Associated domains:** only `applinks:proseio.com.br`. Element domains, `applinks:matrix.to` and `webcredentials:*.element.io` are gone. matrix.to links inside messages still open in the app: that is URL parsing (`AppRoutes.swift`), not universal links.
- **Background tasks:** `BGTaskSchedulerPermittedIdentifiers` are `$(BASE_BUNDLE_IDENTIFIER).background.refresh` and `.background.search-backfill`. `AppSettings` derives the same IDs from `InfoPlistReader.main.baseBundleIdentifier`.
- **Help links:** `encryptionURL`, `deviceVerificationURL`, `chatBackupDetailsURL`, `identityPinningViolationDetailsURL` and `historySharingDetailsURL` are `nil` in `AppSettings`, so their "Learn more" links are hidden (`AttributedString.proseioReplaceLink` in ProseioKit). Set a URL when Proseio has a help page. Terms, privacy and copyright already point at `proseio.com.br`.
- **Matrix IDs:** the identity-reset warning in member details and the soft-logout notice show the handle when the resolver knows it.
- **Permission prompts:** `InfoPlist.strings` in `en.lproj` and `pt-BR.lproj` say "Proseio", not "Element X" (the `.strings` override `$(APP_DISPLAY_NAME)` in `Info.plist`). pt-BR typos fixed ("áudio", "Para tirar") and the background-location prompt translated. The other locales are already excluded from the app target in `ElementX/SupportingFiles/target.yml`, so their Element X text does not ship.
- **401 retry:** `ProseioAPIClient.withTokenRetry` re-reads the access token once on HTTP 401. The handle resolver and the "Nome de usuário" screen use it.

Left on purpose: `elementWebHosts` and `accountProvisioningHost` (link parsing only), `elementProAppStoreURL` (only shown when a server requires Element Pro), Element Call and SDK URLs, `io.element.elementx.*` dispatch queue and notification IDs (internal, not user-visible).

Not done (needs the domain, Apple team or brand):
- Help pages on `proseio.com.br` for the hidden "Learn more" links
- Element Classic migration settings in `app.yml`
- Final app icon artwork, onboarding copy

## Voice messages (proseio/docs/audio.md, ADR 0023)

- **Transcript:** `VoiceTranscriber` and `VoiceTranscriptDraft` in ProseioKit. On-device Apple Speech only; no model, no transcript. The draft starts in `TimelineInteractionHandler` when a recording stops, rides in `ComposerMode.previewVoiceMessage(transcript:)`, and goes out as the event caption through `sendVoiceMessage(caption:)` on the recorder, controller and proxy.
- **Display and scam check:** `ProseioVoiceTranscriptView` under `VoiceMessageRoomTimelineView`; `RoomTimelineItemFactory.proseioAddingScamWarning(to: AudioRoomTimelineItemContent…)`.
- **Pause and resume recording:** `AudioRecorder.pauseRecording()` / `resumeRecording()` pause the engine and keep the file open. Resume sends `.didResumeRecording`, not `.didStartRecording`, so the waveform survives. `ProseioRecordingPauseButton` in the composer.
- Sourcery is not installed on the dev Mac. The mock changes for these protocols were made by hand in `GeneratedMocks.swift` in Sourcery's pattern. A Sourcery run must give the same result.

## Stickers (ADR 0029, 0033, issue #101)

- **Picker:** composer "+" menu → `ComposerAttachmentType.sticker` → `TimelineViewModelAction.displayStickerPicker` → `presentStickerPicker` in `RoomFlowCoordinator` (a sheet, no state machine state). Screen: `ProseioStickerPickerScreen`.
- **Packs:** MSC2545 (`im.ponies.*`). `StickerPackClient` in ProseioKit reads them over HTTP: the SDK cannot read custom room state under sliding sync, and it cannot observe custom account data. Order: the user's pack, this room's packs, then enabled packs from other rooms.
- **Send:** `JoinedRoomProxy.sendRaw(eventType: "m.sticker", …)`. The SDK has no typed sticker send. `sendRaw` skips the send queue: no local echo, no retry. In a thread the content carries an `m.thread` relation.
- Not built yet: making a sticker from a photo, saving a received sticker, pack import.

## Design tokens

- Compound tokens come from the Proseio fork **proseio/compound-design-tokens** (local clone `~/Dev/Proseio/proseio-tokens`, notes in its `PROSEIO.md`). The repo keeps the upstream name on purpose: SwiftPM names a mirrored package after the mirror's repo, and `compound-ios` and `element-call-ios` both expect `compound-design-tokens`.
- `Tools/XcodeGen/mirrors.json` maps Element's URL to the fork for every package. `postGenCommand.sh` copies it into the workspace on each `xcodegen`.
- `compound-ios/Package.swift` pins the fork's version tag (`exact:`). Bump it when the fork gets a new tag.
- `ORGANIZATIONNAME` in `project.yml` (file headers)
- **Telemetry off (done 11 Oct 2026):** `Components/Secrets/Secrets.swift` sets Sentry, PostHog and rageshake to `nil`. That also disables Element Call analytics, which only switch on when app analytics exist. If `Secrets.swift` is ever regenerated from `Secrets.pkl`, keep these `nil`. Later: remove the Sentry and PostHog packages from `project.yml` to cut build size.
- **Server (done 11 Oct 2026):** default account provider `proseio.com.br` (base `https://matrix.proseio.com.br`), picker hidden (`allowOtherAccountProviders = false`), push gateway `https://push.proseio.com.br` (Sygnal, issue #61; never matrix.org).
- **TestFlight signing (11 Oct 2026):** xcodebuild cannot use the account signed in to the Xcode GUI, so it cannot regenerate profiles. `testflight.sh` signs in with the App Store Connect API key "Proseio CI" (`M2VUX56QAJ`, App Manager, `~/.config/proseio/`). App Manager keys cannot use cloud signing, so export uses manual App Store profiles made in the developer portal with the local "Apple Distribution: CENTAUR LABS OU" certificate (expires 20 Mar 2027): "Proseio App Store", "Proseio NSE App Store", "Proseio Share App Store" (`Tools/Proseio/ExportAppStore.plist`). **After any capability change on an App ID, regenerate its profile in the portal and install it in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.**
- **TestFlight:** `Tools/Proseio/testflight.sh` archives Release with a UTC timestamp build number and uploads with `Tools/Proseio/ExportAppStore.plist`. Plan: `docs/testflight-plan.md`.

## Troubleshooting

- **Login stuck on "loading" after choosing a server:** check the app log for `TimedOut` on `/.well-known/matrix/client`. On 11 October 2026 the cause was the phone's Tailscale routing, not the app. Logs: `xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer --domain-identifier group.br.com.proseio.dev --source Library/Logs/br.com.proseio.app.dev/<file> --destination <local file>`.

## Differences from Android (ADR 0031)

Each line is a deliberate difference with its reason. A difference not listed here is a bug. Android's list: `../proseio-android/PROSEIO.md`.

| Area | iOS | Android | Reason |
|---|---|---|---|
| Dev bundle ID | `br.com.proseio.app.dev` | `br.com.proseio.app.debug` | Element's build-type suffix on each platform |
| OAuth redirect | `<bundle id>:/oauth/callback` | `<application id>:/` | Element's default per platform; both are reverse-domain private-use schemes |
| Push | APNs through Sygnal | FCM through Sygnal; UnifiedPush optional | OS push channel (#90) |
| Sign-up attestation | App Attest | None yet | Play Integrity not built on Android (#92) |
| Invite code input | Paste button | Pasted text collapses to the code in the field | Platform idiom |
| Unencrypted room option | Still offered | Removed | Not done on iOS (#78). **Gap** |
| Signed-device isolation | User preference, default on | Fixed on | Undecided (#102) |
| Language fallback | pt-BR for other device languages | en | Undecided (#102) |
| Handle lookup | Start chat only | Every user search | Undecided (#102) |
