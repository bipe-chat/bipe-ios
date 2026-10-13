# Bipe fork notes

This repo is Bipe's iOS app: a fork of Element X iOS (AGPL-3.0). Upstream conventions in `AGENTS.md` still apply. This file adds the fork rules.

## Rules

- **All Bipe code lives in `Components/BipeKit`** (local Swift package, linked into the ElementX target). Element X sources get small hooks only. Keep the upstream diff small so rebases stay cheap.
- **Never hand-edit `Components/BipeKit/Sources/BipeKit/Generated/`.** It comes from `../proseio-shared` (`node tools/gen.mjs`). Change registries and strings there.
- Bipe UI strings come from `BipeStrings` (generated), not `Untranslated.strings` and not Localazy.
- Platform logic (badge verification, normalisation, scam detection) must pass `../proseio-shared/test-vectors/`. Android mirrors the same vectors.
- Build settings, identifiers and entitlements: `app.yml`, `project.yml`, `target.yml`, then `xcodegen`. Never edit `ElementX.xcodeproj` directly.
- The `Enterprise/` submodule (private Element repo) is not used. `Package.swift` skips it when absent.

## Upstream

- `upstream` = element-hq/element-x-ios (push disabled). `origin` = bipe-chat/proseio-ios. Local `main` tracks `origin/main`.
- Rebase: `git fetch upstream && git rebase upstream/develop`.
- git-lfs is not installed on the dev Mac. The LFS filter is overridden in this clone's local config; LFS files (snapshots, dev media) are pointers. Snapshot tests need git-lfs.

## Build (green gate)

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Shared test vectors (ADR 0031 rule 4): `Components/BipeKit/Tests/BipeKitTests/SharedVectorTests.swift` reads `../proseio-shared/test-vectors` directly. Run it after any registry, vector or BipeKit logic change:

```bash
cd Components/BipeKit && swift test
```

Device builds (signed, automatic provisioning with the Centaur Labs team):

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'platform=iOS,name=MZ Air' -allowProvisioningUpdates build
```

### Ad-hoc build signed as CENTAUR LABS OU

Development builds carry the developer's personal certificate (Apple always issues development certificates to a person, even in a company team). For a build signed **"Apple Distribution: CENTAUR LABS OU"**, archive and export ad hoc:

```bash
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release -destination 'generic/platform=iOS' -archivePath build/Bipe.xcarchive -allowProvisioningUpdates
```

```bash
xcodebuild -exportArchive -archivePath build/Bipe.xcarchive -exportOptionsPlist Tools/Bipe/ExportAdHoc.plist -exportPath build/adhoc -allowProvisioningUpdates
```

```bash
xcrun devicectl device install app --device <UDID> build/adhoc/ElementX.ipa
```

Devices must be registered in the Centaur Labs team (automatic signing does this for connected devices).

## Signing

- **Dev builds use the Centaur Labs team (`992N457T8D`)** with bundle ID `chat.bipe.app.dev` and app group `group.chat.bipe.dev` (ADR 0061). Approved by MZ on 11 October 2026.
- **The production ID `chat.bipe.app` (app group `group.chat.bipe`) stays unregistered** until the Bipe organisation account exists. App IDs belong to the team that registers them; never register the production ID under Centaur.
- **By hand (MZ), after the rename to Bipe names:**
  - Developer portal: register App IDs `chat.bipe.app.dev`, `chat.bipe.app.dev.nse`, `chat.bipe.app.dev.shareextension` and app group `group.chat.bipe.dev` (production: the same without `.dev`, group `group.chat.bipe`). Register the push key for them.
  - Developer portal: create the manual App Store profiles "Bipe App Store", "Bipe NSE App Store", "Bipe Share App Store" (names in `Tools/Bipe/ExportAppStore.plist`) and install them in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. Delete the old "Proseio ..." profiles.
  - App Store Connect: create the new app record "Bipe" for `chat.bipe.app.dev`. Rename the API key "Proseio CI" to "Bipe CI".
  - Mac: `mv ~/.config/proseio ~/.config/bipe`. Keychain: rename item `proseio-asc-api-key` to `bipe-asc-api-key`.
- Switching to production: change `DEVELOPMENT_TEAM`, `BASE_BUNDLE_IDENTIFIER` and `APP_GROUP_IDENTIFIER` in `app.yml`, then `xcodegen`.

## Rebrand status

Done: display name and production app name ("Bipe", ADR 0054; the code name stays Bipe), dev bundle ID and app group, Element's team ID replaced.

- **OAuth login:** redirect is the private-use scheme `<bundle id>:/oauth/callback` (RFC 8252); client URI, logo, terms and privacy URLs are on `https://bipe.chat/...` (client URI `https://bipe.chat/apps/ios`) because MAS requires them on the client URI host and requires the scheme to be the reverse of that host. Pages do not exist yet. **Verified 11 October 2026:** sign-in to matrix.org works end to end on a device (MAS dynamic registration accepted the client).
- **Accent colour:** açaí `acai.1100` (`#80307B` light, `#D993D2` dark; high contrast `#5D1D59` / `#ECC0E7`) in `accent-color.colorset`. See proseio/docs/design/identity.md.
- **App icon:** the web mark (`proseio-web/public/brand/app-icon.svg`, white seal-tail bubble on `acai.1100`, tight corner top left so it reads as a "b") rendered full-bleed at 1024 px; iOS applies the corner mask. iOS and web share one icon. Final designer artwork replaces both at once.

Entitlements removed from the fork (they block provisioning outside Element's team):
- `com.apple.developer.usernotifications.filtering` (NSE). Apple grants it on request only. Without it the NSE cannot silently drop notifications. Request it for Bipe later.
- Element Classic app group and keychain group in the app entitlements (`group.im.vector`, owned by Element's team).

Element leftovers cleaned up (11 October 2026):
- **Associated domains:** only `applinks:bipe.chat`. Link parsers also accept `proseio.com.br` links, which redirect to `bipe.chat`. Element domains, `applinks:matrix.to` and `webcredentials:*.element.io` are gone. matrix.to links inside messages still open in the app: that is URL parsing (`AppRoutes.swift`), not universal links.
- **Background tasks:** `BGTaskSchedulerPermittedIdentifiers` are `$(BASE_BUNDLE_IDENTIFIER).background.refresh` and `.background.search-backfill`. `AppSettings` derives the same IDs from `InfoPlistReader.main.baseBundleIdentifier`.
- **Help links:** `encryptionURL`, `deviceVerificationURL`, `chatBackupDetailsURL`, `identityPinningViolationDetailsURL` and `historySharingDetailsURL` are `nil` in `AppSettings`, so their "Learn more" links are hidden (`AttributedString.bipeReplaceLink` in BipeKit). Set a URL when Bipe has a help page. Terms, privacy and copyright already point at `proseio.com.br`.
- **Matrix IDs:** the identity-reset warning in member details and the soft-logout notice show the handle when the resolver knows it.
- **Permission prompts:** `InfoPlist.strings` in `en.lproj` and `pt-BR.lproj` say "Bipe", not "Element X" (the `.strings` override `$(APP_DISPLAY_NAME)` in `Info.plist`). pt-BR typos fixed ("áudio", "Para tirar") and the background-location prompt translated. The other locales are already excluded from the app target in `ElementX/SupportingFiles/target.yml`, so their Element X text does not ship.
- **401 retry:** `BipeAPIClient.withTokenRetry` re-reads the access token once on HTTP 401. The handle resolver and the "Nome de usuário" screen use it.

Left on purpose: `elementWebHosts` and `accountProvisioningHost` (link parsing only), `elementProAppStoreURL` (only shown when a server requires Element Pro), Element Call and SDK URLs, `io.element.elementx.*` dispatch queue and notification IDs (internal, not user-visible).

Not done (needs the domain, Apple team or brand):
- Help pages on `bipe.chat` for the hidden "Learn more" links
- Element Classic migration settings in `app.yml`
- Final app icon artwork, onboarding copy

## Voice messages (proseio/docs/audio.md, ADR 0023)

- **Transcript:** `VoiceTranscriber` and `VoiceTranscriptDraft` in BipeKit. On-device Apple Speech only; no model, no transcript. The draft starts in `TimelineInteractionHandler` when a recording stops, rides in `ComposerMode.previewVoiceMessage(transcript:)`, and goes out as the event caption through `sendVoiceMessage(caption:)` on the recorder, controller and proxy.
- **Display and scam check:** `BipeVoiceTranscriptView` under `VoiceMessageRoomTimelineView`; `RoomTimelineItemFactory.bipeAddingScamWarning(to: AudioRoomTimelineItemContent…)`.
- **Pause and resume recording:** `AudioRecorder.pauseRecording()` / `resumeRecording()` pause the engine and keep the file open. Resume sends `.didResumeRecording`, not `.didStartRecording`, so the waveform survives. `BipeRecordingPauseButton` in the composer.
- Sourcery is not installed on the dev Mac. The mock changes for these protocols were made by hand in `GeneratedMocks.swift` in Sourcery's pattern. A Sourcery run must give the same result.

## Stickers (ADR 0029, 0033, issue #101)

- **Picker:** composer "+" menu → `ComposerAttachmentType.sticker` → `TimelineViewModelAction.displayStickerPicker` → `presentStickerPicker` in `RoomFlowCoordinator` (a sheet, no state machine state). Screen: `BipeStickerPickerScreen`.
- **Packs:** MSC2545 (`im.ponies.*`). `StickerPackClient` in BipeKit reads them over HTTP: the SDK cannot read custom room state under sliding sync, and it cannot observe custom account data. Order: the user's pack, this room's packs, then enabled packs from other rooms.
- **Send:** `JoinedRoomProxy.sendRaw(eventType: "m.sticker", …)`. The SDK has no typed sticker send. `sendRaw` skips the send queue: no local echo, no retry. In a thread the content carries an `m.thread` relation.
- **Import:** "Importar do WhatsApp" in the picker opens the file importer for a WhatsApp chat export ZIP, WebP or PNG. `ZipReader` (BipeKit, Compression framework, no dependency) reads the `.webp` entries. `StickerImporter` checks magic bytes, size (1 MB) and sides (1024 px), derives the shortcode from SHA-256 (`st_…`), uploads over HTTP and adds the images to `im.ponies.user_emotes`. Same file twice: skipped.
- **Animated WebP:** `LoadableImage` loads `image/webp` as data, like GIF. More than one frame plays in `BipeAnimatedImage` (ImageIO `CGAnimateImageDataWithBlock`); Kingfisher animates GIF only.
- **Make from a photo:** the picker's "+" menu → PhotosPicker → `StickerMaker` (BipeKit) cuts out the subject with Vision (`VNGenerateForegroundInstanceMaskRequest`), or crops a centred square when there is no subject, fits it on a transparent 512 × 512 canvas and encodes PNG. On the device, nothing leaves it before the upload.
- **Save a received sticker:** timeline menu action `.saveSticker` → `TimelineInteractionHandler.saveSticker` downloads the image and adds it. `BipeStickerSaver` is the one place that adds stickers to the pack (import, photo, save).

## Groups MVP (proseio/docs/groups.md, ADR 0026)

- **Quiet by default (#97):** `BipeQuietGroups` runs once per account from `AppCoordinator.runPostSessionSetupTasks`. It sets the group default to mentions and keywords and adds the override push rule `chat.bipe.poll_start` (`*.poll.start`) so new polls notify. It does nothing until `canPushEncryptedEventsToDevice()` is true: mentions in encrypted rooms need Synapse `msc4028_push_encrypted_events`, or mentions-only silences the group. Turn that server flag on only after Apple grants the NSE filtering entitlement (see Rebrand status), or the NSE cannot drop the other pushes. Android ships the same feature (#97, #98).
- **"O que você perdeu" (#98):** `BipeMissedSummary` (rules) and `BipeMissedSummaryView` sit above the read marker in `RoomTimelineItemView`. Shown in groups on the live timeline when at least 20 loaded messages follow the marker. Lines: mentions of you or @room, replies to you, open polls you have not voted in. Pins are not in it yet.

## Tab bar (bipe ADR 0053)

- **Tabs:** Conversas, Grupos, Você, plus search (`UserSessionFlowCoordinator.HomeTab`). The Spaces tab is not created; `SpacesTabFlowCoordinator` stays in the tree for rebases.
- **Conversas and Grupos** are two `ChatsTabFlowCoordinator`s with a `BipeRoomListScope`. `clientProxy.roomSummaryProvider` lists Conversas (SDK category `people`, plus every invite); `bipeGroupsRoomSummaryProvider` lists Grupos (category `group`, joined). `NotificationSettingsEditScreenViewModel` reads `staticRoomSummaryProvider`, because the main provider no longer lists all rooms.
- **Routing:** `.room`, `.event`, `.roomDetails` and `.thread` open in the tab that lists the room (`bipeRoomTab(for:)`). Other room routes stay in the current tab.
- **Badges:** each tab sums `unreadNotificationsCount` of its own rooms. The app icon badge stays the total.
- **Você** is `SettingsFlowCoordinator(isInTab: true)` in a stack in the tab: no close button, title "Você". `.settings` and `.chatBackupSettings` routes select the tab. On a Mac with secondary windows, settings still open in a window.
- **Self-chat:** `BipeSelfChat`. Account data `chat.bipe.self_chat` = `{"room_id": "..."}` (same on Android). Created on first tap as a private encrypted room named "Anotações". The room lists hide it by a cached ID in `UserDefaults`; it opens in Conversas.
- **Search:** the search tab needs iOS 26 (`globalSearchEnabled`, on by default). On iOS 18 to 25 search stays inline in the room list.

## Design tokens

- Compound tokens come from the Bipe fork **proseio/compound-design-tokens** (local clone `~/Dev/Proseio/proseio-tokens`, notes in its `PROSEIO.md`). The repo keeps the upstream name on purpose: SwiftPM names a mirrored package after the mirror's repo, and `compound-ios` and `element-call-ios` both expect `compound-design-tokens`.
- `Tools/XcodeGen/mirrors.json` maps Element's URL to the fork for every package. `postGenCommand.sh` copies it into the workspace on each `xcodegen`.
- `compound-ios/Package.swift` pins the fork's version tag (`exact:`). Bump it when the fork gets a new tag.
- `ORGANIZATIONNAME` in `project.yml` (file headers)
- **Telemetry off (done 11 Oct 2026):** `Components/Secrets/Secrets.swift` sets Sentry, PostHog and rageshake to `nil`. That also disables Element Call analytics, which only switch on when app analytics exist. If `Secrets.swift` is ever regenerated from `Secrets.pkl`, keep these `nil`. Later: remove the Sentry and PostHog packages from `project.yml` to cut build size.
- **Server (done 11 Oct 2026):** default account provider `bipe.net.br` (base `https://matrix.bipe.net.br`), picker hidden (`allowOtherAccountProviders = false`), push gateway `https://push.bipe.net.br` (Sygnal, issue #61; never matrix.org).
- **TestFlight signing (11 Oct 2026):** xcodebuild cannot use the account signed in to the Xcode GUI, so it cannot regenerate profiles. `testflight.sh` signs in with the App Store Connect API key "Bipe CI" (`M2VUX56QAJ`, App Manager, `~/.config/bipe/`). App Manager keys cannot use cloud signing, so export uses manual App Store profiles made in the developer portal with the local "Apple Distribution: CENTAUR LABS OU" certificate (expires 20 Mar 2027): "Bipe App Store", "Bipe NSE App Store", "Bipe Share App Store" (`Tools/Bipe/ExportAppStore.plist`). **After any capability change on an App ID, regenerate its profile in the portal and install it in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.**
- **TestFlight:** `Tools/Bipe/testflight.sh` archives Release with a UTC timestamp build number and uploads with `Tools/Bipe/ExportAppStore.plist`. Plan: `docs/testflight-plan.md`.

## Troubleshooting

- **Login stuck on "loading" after choosing a server:** check the app log for `TimedOut` on `/.well-known/matrix/client`. On 11 October 2026 the cause was the phone's Tailscale routing, not the app. Logs: `xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer --domain-identifier group.chat.bipe.dev --source Library/Logs/chat.bipe.app.dev/<file> --destination <local file>`.

## Differences from Android (ADR 0031)

Each line is a deliberate difference with its reason. A difference not listed here is a bug. Android's list: `../proseio-android/PROSEIO.md`.

| Area | iOS | Android | Reason |
|---|---|---|---|
| Dev bundle ID | `chat.bipe.app.dev` | `chat.bipe.app.debug` | Element's build-type suffix on each platform |
| OAuth redirect | `<bundle id>:/oauth/callback` | `<application id>:/` | Element's default per platform; both are reverse-domain private-use schemes |
| Push | APNs through Sygnal | FCM through Sygnal; UnifiedPush optional | OS push channel (#90) |
| Sign-up attestation | App Attest | None yet | Play Integrity not built on Android (#92) |
| Invite code input | Paste button | Pasted text collapses to the code in the field | Platform idiom |
| Unencrypted room option | Still offered | Removed | Not done on iOS (#78). **Gap** |
| Sticker from a photo | Subject cut-out (Vision) | Centred square crop | Cut-out needs ML Kit, not decided |
| Sticker import | Chat export ZIP or files | Chat export ZIP or files; picker opens in WhatsApp's stickers folder | iOS apps cannot read WhatsApp's files |
| Signed-device isolation | User preference, default on | Fixed on | Undecided (#102) |
| Language fallback | pt-BR for other device languages | en | Undecided (#102) |
| Handle lookup | Start chat only | Every user search | Undecided (#102) |
| Quiet groups "done" marker | A flag on the device (once per device) | The poll rule in the account's push rules (once per account) | Android has no per-session store in libraries/bipe; same result for the user |
| Search | Search tab (iOS 26+), inline before iOS 26 | Search in the top bar | Platform idiom (ADR 0053) |
