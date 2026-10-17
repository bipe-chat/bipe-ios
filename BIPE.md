# Bipe fork notes

This repo is Bipe's iOS app: a fork of Element X iOS (AGPL-3.0). Upstream conventions in `AGENTS.md` still apply. This file adds the fork rules.

## Rules

- **All Bipe code lives in `Components/BipeKit`** (local Swift package, linked into the ElementX target). Element X sources get small hooks only. Keep the upstream diff small so rebases stay cheap.
- **Never hand-edit `Components/BipeKit/Sources/BipeKit/Generated/`.** It comes from `../bipe-shared` (`node tools/gen.mjs`). Change registries and strings there.
- Bipe UI strings come from `BipeStrings` (generated), not `Untranslated.strings` and not Localazy.
- Platform logic (badge verification, normalisation, scam detection) must pass `../bipe-shared/test-vectors/`. Android mirrors the same vectors.
- Build settings, identifiers and entitlements: `app.yml`, `project.yml`, `target.yml`, then `xcodegen`. Never edit `ElementX.xcodeproj` directly.
- The `Enterprise/` submodule (private Element repo) is not used. `Package.swift` skips it when absent.

## Upstream

- `upstream` = element-hq/element-x-ios (push disabled). `origin` = bipe-chat/bipe-ios. Local `main` tracks `origin/main`.
- Rebase: `git fetch upstream && git rebase upstream/develop`.
- git-lfs is not installed on the dev Mac. The LFS filter is overridden in this clone's local config; LFS files (snapshots, dev media) are pointers. Snapshot tests need git-lfs.

## Build (green gate)

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Shared test vectors (ADR 0031 rule 4): `Components/BipeKit/Tests/BipeKitTests/SharedVectorTests.swift` reads `../bipe-shared/test-vectors` directly. Run it after any registry, vector or BipeKit logic change:

```bash
cd Components/BipeKit && swift test
```

Device builds (signed, automatic provisioning with the Centaur Labs team). Always Release on a phone, never Debug: a Debug build on MZ Air broke typing (15 Oct 2026).

```bash
xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Release -destination 'platform=iOS,name=MZ Air' -allowProvisioningUpdates -derivedDataPath build/device build
```

```bash
xcrun devicectl device install app --device <UDID> build/device/Build/Products/Release-iphoneos/ElementX.app
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
- **Rename to Bipe names, done 13 October 2026:** App IDs `chat.bipe.app.dev` (+ `.nse`, `.shareextension`) and app group `group.chat.bipe.dev` registered; profiles "Bipe App Store", "Bipe NSE App Store", "Bipe Share App Store" installed; App Store Connect record "Bipe Chat" (`6822454419`, SKU `bipe-dev`) for `chat.bipe.app.dev`; the old record (`6821694616`, `br.com.proseio.app.dev`) renamed "Bipe Chat Legacy"; `~/.config/proseio` moved to `~/.config/bipe`.
- **Still by hand (MZ):** delete the old "Proseio ..." profiles in the portal; rename the API key "Proseio CI" to "Bipe CI". Production IDs (without `.dev`, group `group.chat.bipe`) wait for the Bipe organisation account.
- Switching to production: change `DEVELOPMENT_TEAM`, `BASE_BUNDLE_IDENTIFIER` and `APP_GROUP_IDENTIFIER` in `app.yml`, then `xcodegen`.

## Rebrand status

Done: display name and production app name ("Bipe", ADR 0054; the code name stays Bipe), dev bundle ID and app group, Element's team ID replaced.

- **OAuth login:** redirect is the private-use scheme `<bundle id>:/oauth/callback` (RFC 8252); client URI, logo, terms and privacy URLs are on `https://bipe.chat/...` (client URI `https://bipe.chat/apps/ios`) because MAS requires them on the client URI host and requires the scheme to be the reverse of that host. Pages do not exist yet. **Verified 11 October 2026:** sign-in to matrix.org works end to end on a device (MAS dynamic registration accepted the client).
- **Accent colour:** açaí `acai.1100` (`#80307B` light, `#D993D2` dark; high contrast `#5D1D59` / `#ECC0E7`) in `accent-color.colorset`. See bipe/docs/design/identity.md.
- **Welcome screen:** `BipeWelcomeView` and `BipeWelcomeBackground` (`Screens/Authentication/StartScreen/View`) replace Element's logo, welcome text and launch artwork on the start screen. Copy: `bipe_onboarding_*` in bipe-shared. Android: `BipeWelcomeView` in libraries/bipe.
- **App icon:** the web mark (`bipe-web/public/brand/app-icon.svg`, white seal-tail bubble on `acai.1100`, tight corner top left so it reads as a "b") rendered full-bleed at 1024 px; iOS applies the corner mask. iOS and web share one icon. Final designer artwork replaces both at once.

Entitlements removed from the fork (they block provisioning outside Element's team):
- `com.apple.developer.usernotifications.filtering` (NSE). Apple grants it on request only. Without it the NSE cannot silently drop notifications. Request it for Bipe later.
- Element Classic app group and keychain group in the app entitlements (`group.im.vector`, owned by Element's team).

Element leftovers cleaned up (11 October 2026):
- **Associated domains:** `applinks:bipe.chat` and `webcredentials:bipe.chat` (since bipe#153). Link parsers also accept `proseio.com.br` links, which redirect to `bipe.chat`. Element domains, `applinks:matrix.to` and `webcredentials:*.element.io` are gone. matrix.to links inside messages still open in the app: that is URL parsing (`AppRoutes.swift`), not universal links.
- **Background tasks:** `BGTaskSchedulerPermittedIdentifiers` are `$(BASE_BUNDLE_IDENTIFIER).background.refresh` and `.background.search-backfill`. `AppSettings` derives the same IDs from `InfoPlistReader.main.baseBundleIdentifier`.
- **Help links:** `encryptionURL`, `deviceVerificationURL`, `chatBackupDetailsURL`, `identityPinningViolationDetailsURL` and `historySharingDetailsURL` are `nil` in `AppSettings`, so their "Learn more" links are hidden (`AttributedString.bipeReplaceLink` in BipeKit). Set a URL when Bipe has a help page. Terms, privacy and copyright point at `bipe.chat`.
- **Matrix IDs:** the identity-reset warning in member details and the soft-logout notice show the handle when the resolver knows it.
- **Permission prompts:** `InfoPlist.strings` in `en.lproj` and `pt-BR.lproj` say "Bipe", not "Element X" (the `.strings` override `$(APP_DISPLAY_NAME)` in `Info.plist`). pt-BR typos fixed ("áudio", "Para tirar") and the background-location prompt translated. The other locales are already excluded from the app target in `ElementX/SupportingFiles/target.yml`, so their Element X text does not ship.
- **401 retry:** `BipeAPIClient.withTokenRetry` re-reads the access token once on HTTP 401. The handle resolver and the "Nome de usuário" screen use it.

Left on purpose: `elementWebHosts` and `accountProvisioningHost` (link parsing only), `elementProAppStoreURL` (only shown when a server requires Element Pro), Element Call and SDK URLs, `io.element.elementx.*` dispatch queue and notification IDs (internal, not user-visible).

Not done (needs the domain, Apple team or brand):
- Help pages on `bipe.chat` for the hidden "Learn more" links
- Element Classic migration settings in `app.yml`
- Final app icon artwork

## Voice messages (bipe/docs/audio.md, ADR 0023)

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

## Device-first accounts (ADR 0057, ADR 0059, bipe#153)

- **Sign-up:** `BipeSignupScreen`: name, optional handle, 8-digit PIN twice, optional recovery email, invite code, App Attest. `POST /v1/signup` without `password`. The API returns the hidden password and a recovery token once. The PIN is checked with `BipePIN.problem(for:)` (BipeKit, cases in `test-vectors/pins.json`).
- **Keychain:** `BipeCredentialStore` (BipeKit). The hidden password is `AfterFirstUnlockThisDeviceOnly` and never syncs. The recovery token is `kSecAttrSynchronizable` (iCloud Keychain). A pending email recovery (its claim secret) stays on the device. Nothing is shown or logged. ADR 0059 overrides ADR 0057 here: the password does not sync.
- **Password login without a browser:** `BipeAccountSignIn` calls `AuthenticationService.configure(for:flow:)` and then `login(username:password:…)` with the Matrix ID. That is the SDK's `Client.login`, a plain `m.login.password` to `/_matrix/client/v3/login`. MAS answers it through its compatibility layer (`passwords.enabled: true`). The SDK does not force OAuth for this call; OAuth support only changes what Element's own login screens offer. Element's guard stays: a login that returns a refresh token is signed out again.
- **Lost sign-up answer (ADR 0094):** `BipeCredentialStore.pendingSignup(pin:)` stores a `signup_key` and the PIN (`ThisDeviceOnly`) before the first `POST /v1/signup`. Every try sends the key, so a retry returns the same account. `BipeSignupScreenViewModel` retries up to 4 times on network, `internal` and `signup_in_progress`, with a new App Attest attestation each time. The pending sign-up goes after sign-in and the app lock PIN are done.
- **App start without a session** (`AuthenticationFlowCoordinator.resumeBipeAccount`): a pending email recovery opens the wait screen; else a pending sign-up without a stored password finishes through `POST /v1/signup/resume`; else the password on this device signs in silently (and a pending sign-up gives the app lock its PIN); else a synced token opens the PIN prompt (`POST /v1/recovery/token`, new password and token).
- **Sign-out** deletes the password on this device (`AppCoordinator`, user sign-out and forced sign-out). The token stays, so the next sign-in needs the PIN. An auth error from the server keeps the password.
- **Recovery screen** (`BipeRecoveryScreen`, start screen button "Voltar pra sua conta"): token and PIN; old phone (QR, the old phone shows the code); recovery email (`POST /v1/recovery/email`); "Entrar manualmente" for beta accounts (MAS OAuth). Link `https://bipe.chat/recuperar/#<token>` → `AppRoute.bipeRecoveryLink` → PIN, or a new PIN after "Esqueci minha senha" → `POST /v1/recovery/email/confirm` → wait screen that polls `/claim` every minute.
- **App lock:** the account PIN is the app lock PIN (`AppLockServiceProtocol.bipeUseAccountPIN`), with biometric unlock on when the device has it. A new app lock PIN has 8 digits and passes the shared rule. An older 4-digit app lock PIN still unlocks (`pinCodeLength` follows the stored PIN).
- **Settings → "Trocar senha":** `BipeAccountScreen`. Device owner check (Face ID or passcode), then `PUT /v1/me/pin`. Blocked PIN state from `GET /v1/me/account`. Beta accounts: "Crie sua senha" sets the PIN, then `POST /v1/me/device-first` and stores the returned credentials. Recovery email: add, change, remove.
- **Old devices:** `BipeRecoveryAlerts` reads `GET /v1/me/account` after sign-in and on every foreground. A waiting recovery shows `bipe_recovery_alert_*` with "Cancelar, não fui eu" (`POST /v1/me/recoveries/{id}/cancel`). A completed token recovery shows once. The device's own token recovery, and recoveries that existed before this device's first check, do not alert.
- **Password saving:** `webcredentials:bipe.chat` in the associated domains; the AASA lists both app IDs (bipe-infra).
- Not built: guardian and CPF recovery (no API yet), QR sign-in checks from bipe#152, the fallback prompt after sign-up (the optional email on the form is the only fallback).

## Contacts and invites (growth loop step 2)

- **One settings row**, "Contatos e convites", opens `BipeContactsScreen`. Invites have no settings row of their own.
- **Contacts screen:** the invite buttons on top (`BipeInviteButtonsSection`, shared with `BipeInvitesScreen`), then people who joined with the user's invite (`GET /v1/me/invites`, status `used`), then address-book matches, then a "Convites ainda não usados" row with the count that opens `BipeInvitesScreen`. The counts reload on each appear, so they are current after a return from the invites screen.
- **Start chat "Convidar pessoas":** creates a personal invite and opens the share sheet (`BipeInviteCreator.createIfAvailable`). Element shared a matrix.to profile link, which is a dead end for an invite-only sign-up.
- `BipeInviteCreator` (BipeKit) is the one place that creates an invite and stores its link. `BipeInviteQuota` writes the quota text.

## Handle change lines (ADR 0066, bipe#166)

- **Remove the handle:** "Remover nome de usuário" on `BipeHandleScreen`, also during the cooldown. A confirmation alert (`bipe_handle_remove_body`), then `DELETE /v1/me/handle`. Same flow on Android.

- `BipeHandleChangeStore` (BipeKit): one per session, made in `AppCoordinator.setupUserSession`, cached in `Caches/bipe-handle-changes-<user>.json`. `POST /v1/handle-changes` in chunks of 100. People without a cached change go without `since`; the others share the oldest of their latest cached times.
- Fetch: on room open, for the joined members (`TimelineController`); after the room list loads, for the cached people plus every joined room's heroes (`AppCoordinator.refreshBipeHandleChangesAfterSync`).
- Display: `TimelineController.bipeInsertingHandleChanges` adds a local `StateRoomTimelineItem` (virtual ID) at `at` in the room's main timeline. Rules in `BipeHandleChangePlacement`: current members only, inside the loaded range (after the end only on the live timeline), not before a join seen in the loaded items. Text: `bipe_handle_set`, `bipe_handle_changed`, `bipe_handle_removed` with the member's display name in the room.

## Groups MVP (bipe/docs/groups.md, ADR 0026)

- **Quiet by default (#97):** `BipeQuietGroups` runs once per account from `AppCoordinator.runPostSessionSetupTasks`. It sets the group default to mentions and keywords and adds the override push rule `chat.bipe.poll_start` (`*.poll.start`) so new polls notify. It does nothing until `canPushEncryptedEventsToDevice()` is true: mentions in encrypted rooms need Synapse `msc4028_push_encrypted_events`, or mentions-only silences the group. Turn that server flag on only after Apple grants the NSE filtering entitlement (see Rebrand status), or the NSE cannot drop the other pushes. Android ships the same feature (#97, #98).
- **"O que você perdeu" (#98):** `BipeMissedSummary` (rules) and `BipeMissedSummaryView` sit above the read marker in `RoomTimelineItemView`. Shown in groups on the live timeline when at least 20 loaded messages follow the marker. Lines: mentions of you or @room, replies to you, open polls you have not voted in. Pins are not in it yet.

## "Conferir no Bipe" (bipe ADR 0091, bipe#294)

- **Share target:** the existing share extension. `ShareExtensionViewController.bipePixCheck(for:)` reads shared text, or the QR codes in shared images (`PixCheck.qrPayloads`, Core Image). When it finds a Pix code or key it shows `BipePixCheckView` in the extension and does not open the app. "Enviar para uma conversa" continues to Element's share flow. No account and no network needed.
- **Logic:** `PixCheck` in BipeKit (BR Code TLV, CRC-16, key types, keys in the text, the rule 9 warning without `pixCode` and `pixKey`). Cases: `bipe-shared/test-vectors/pix-check.json`.

## Tab bar (bipe ADR 0053)

- **Tabs:** Conversas, Grupos, Você, plus search (`UserSessionFlowCoordinator.HomeTab`). The Spaces tab is not created; `SpacesTabFlowCoordinator` stays in the tree for rebases.
- **Conversas and Grupos** are two `ChatsTabFlowCoordinator`s with a `BipeRoomListScope`. `clientProxy.roomSummaryProvider` lists Conversas (SDK category `people`, DM invites included); `bipeGroupsRoomSummaryProvider` lists Grupos (category `group`, joined or invited). Group invites show in Grupos, as on Android. `NotificationSettingsEditScreenViewModel` reads `staticRoomSummaryProvider`, because the main provider no longer lists all rooms.
- **Routing:** `.room`, `.event`, `.roomDetails` and `.thread` open in the tab that lists the room (`bipeRoomTab(for:)`). Other room routes stay in the current tab.
- **Badges:** each tab sums `unreadNotificationsCount` of its own rooms. A group invite not in `seenInvites` adds 1 to Grupos (`updateBipeTabBadges`). The app icon badge stays the total.
- **Trap: the room count is not the tab's.** `RoomSummaryProviderState.loaded(totalNumberOfRooms:)` comes from the SDK and counts every room in the account, whatever the tab's filter. Never read it as "this tab has rooms". On 15 Oct 2026 Grupos showed skeletons forever for an account with chats and no groups: the home screen waited for rooms that the filter never published. `HomeScreenViewModel.scheduleBipeEmptyTabFallback` now shows the empty state after one second.
- **No spaces in the create-group screen:** `StartChatFlowCoordinator` passes `spaceSelectionMode: .none`, so the space picker and the "space members" access types do not show. Spaces come back only as Comunidade inside Grupos (ADR 0084).
- **Você** is `SettingsFlowCoordinator(isInTab: true)` in a stack in the tab: no close button, title "Você". `.settings` and `.chatBackupSettings` routes select the tab. On a Mac with secondary windows, settings still open in a window.
- **Self-chat:** `BipeSelfChat`. Account data `chat.bipe.self_chat` = `{"room_id": "..."}` (same on Android). Created on first tap as a private encrypted room named "Anotações". The room lists hide it by a cached ID in `UserDefaults`; it opens in Conversas.
- **Search:** the search tab needs iOS 26 (`globalSearchEnabled`, on by default). On iOS 18 to 25 search stays inline in the room list.

## Threads and galleries on by default, no Labs (15 Oct 2026)

- **No Labs entry in settings.** The row is gone from `SettingsScreen`; `LabsScreen` stays in the tree for rebases. "Ask to join" (knocking) stays off.
- Not in Labs any more. `threadsEnabled` and `galleryEnabled` use new keys (`threadsEnabledV2`, `galleryEnabledV2`, default on), so an old Labs opt-out does not stick.
- The event cache is built differently with threads on. `AppCoordinator.rebuildEventCacheForThreadsIfNeeded` clears it once after the first session restore, through the same `.clearCache` path the Labs toggle used. The marker is the old Labs key `threadsEnabled` (`isEventCacheBuiltWithThreads`). Fresh installs and new logins set it without a clear.
- Android does the same (`AppMigration` in bipe-android).

## Design tokens

- Compound tokens come from the Bipe fork **bipe-chat/compound-design-tokens** (local clone `~/Dev/Bipe/bipe-tokens`, notes in its `BIPE.md`). The repo keeps the upstream name on purpose: SwiftPM names a mirrored package after the mirror's repo, and `compound-ios` and `element-call-ios` both expect `compound-design-tokens`.
- `Tools/XcodeGen/mirrors.json` maps Element's URL to the fork for every package. `postGenCommand.sh` copies it into the workspace on each `xcodegen`.
- `compound-ios/Package.swift` pins the fork's version tag (`exact:`). Bump it when the fork gets a new tag.
- `ORGANIZATIONNAME` in `project.yml` (file headers)
- **No telemetry (bipe#55, 14 Oct 2026):** the Sentry and PostHog packages are gone from `project.yml`. `DisabledAnalyticsClient` replaces the PostHog client, `Signposter` records nothing, the Rust SDK gets `sentryConfig: nil`, Element Call gets no PostHog or Sentry values, and CI no longer uploads dSYMs. `AppSettings.analyticsConfiguration` is `nil`, so the analytics prompt and setting never show. Rageshake stays `nil` in `Secrets.swift`. On a rebase, drop any Sentry or PostHog code that upstream adds.
- **Trimmed packages (15 Oct 2026):** GZIP, LoremSwiftum and KZFileWatchers are gone from `project.yml`. `BugReportService` writes logs uncompressed (bug reports are off). The `EventTimelineItem` mock uses a fixed sentence. `UITestsSignalling` has its own polling `FileWatcher`. AnalyticsEvents stays: 109 call sites use its types, and removing it would rewrite upstream code. On a rebase, keep these three out.
- **Server (done 11 Oct 2026):** default account provider `bipe.net.br` (base `https://matrix.bipe.net.br`), picker hidden (`allowOtherAccountProviders = false`), push gateway `https://push.bipe.net.br` (Sygnal, issue #61; never matrix.org).
- **TestFlight signing (11 Oct 2026):** xcodebuild cannot use the account signed in to the Xcode GUI, so it cannot regenerate profiles. `testflight.sh` signs in with the App Store Connect API key "Bipe CI" (`M2VUX56QAJ`, App Manager, `~/.config/bipe/`). App Manager keys cannot use cloud signing, so export uses manual App Store profiles made in the developer portal with the local "Apple Distribution: CENTAUR LABS OU" certificate (expires 20 Mar 2027): "Bipe App Store", "Bipe NSE App Store", "Bipe Share App Store" (`Tools/Bipe/ExportAppStore.plist`). **After any capability change on an App ID, regenerate its profile in the portal and install it in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.**
- **TestFlight:** `Tools/Bipe/testflight.sh` archives Release and uploads with `Tools/Bipe/ExportAppStore.plist`. Plan: `docs/testflight-plan.md`.
- **Version and build number (ADR 0088):** one build number for iOS and Android, set in `bipe-shared/product/version.json`. Before each upload: `node tools/bump-build.mjs` in bipe-shared (`--version YY.MM.N` for a new version), then commit and push bipe-shared, this repo and bipe-android. `Tools/Bipe/version.env` is generated; `testflight.sh` passes its values to `xcodebuild`. `MARKETING_VERSION` in `project.yml` must match (the bipe-shared drift check fails otherwise); after you change it, run `xcodegen`. Until then, local builds show the old version in `ElementX.xcodeproj`.

## Troubleshooting

- **Login stuck on "loading" after choosing a server:** check the app log for `TimedOut` on `/.well-known/matrix/client`. On 11 October 2026 the cause was the phone's Tailscale routing, not the app. Logs: `xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer --domain-identifier group.chat.bipe.dev --source Library/Logs/chat.bipe.app.dev/<file> --destination <local file>`.

## DMs are DMs (16 Oct 2026)

- A DM never turns into a group. DM details: no topic (`hasTopicSection`), no polls history, no "Convidar" to the DM. "Convidar para um grupo" opens `BipeInviteToGroupSheet` with your joined groups from `staticRoomSummaryProvider` (not DMs, spaces, replaced rooms or the self-chat) and invites the other person to the one you pick. The group's invite permission is checked at pick time.
- The composer "+" menu has no poll in a DM (`ComposerToolbarViewState.isDM`).
- Leave in a DM says "Sair da conversa" with `bipe_dm_leave_body`.
- No room setup lines in a DM timeline: `RoomTimelineItemFactory` drops invites, joins and "encryption enabled" (upstream already dropped the create event and your own join). A leave says "saiu da conversa" (`bipe_dm_left`). DM details are titled "Informações da conversa". The room list menu, leave toast and spinner, mute errors and the media empty states say "conversa" in a DM.
- Leaving a DM is final for that room. The SDK finds a DM only among joined rooms (`get_dm_rooms`), so if you start a chat again, Bipe creates a new room. The other person keeps the old room: they see "Você está sozinho nesta conversa" and can invite you back to it.
- Android does the same (`BipeInviteToGroup` in libraries/bipe).

## Message menu (16 Oct 2026)

- Long press on a message opens the native iOS context menu, not Element's sheet. `TimelineItemContextMenu`: reaction palette (emoji drawn into images, palettes only render images), actions, secondary actions. `TimelineItemContextMenuPreview`: the sheet's header (`TimelineItemMenuHeader`) above the bubble.
- The sheet (`TimelineItemMenu`) stays for the VoiceOver action. `longPressWithFeedback` on the bubble is gone.
- On a rebase, keep the context menu unconditional (upstream shows it only on a Mac).

## Differences from Android (ADR 0031)

Each line is a difference with its reason. A difference not listed here is a bug. The table is generated from `bipe-shared/product/parity.json` (ADR 0092): change it there, then run `node tools/parity.mjs --write` in bipe-shared. Android's list: `../bipe-android/BIPE.md`.

<!-- parity:differences (generated from bipe-shared/product/parity.json by tools/parity.mjs --write; do not edit) -->

| Area | iOS | Android | Reason |
|---|---|---|---|
| Dev app ID | `chat.bipe.app.dev` | `chat.bipe.app.debug` | Element's build-type suffix on each platform |
| OAuth redirect | `<bundle id>:/oauth/callback` | `<application id>:/` | Element's default per platform; both are reverse-domain private-use schemes |
| Push | APNs through Sygnal | FCM through Sygnal; UnifiedPush optional | OS push channel (#89, #90, #91) |
| Sign-up attestation | App Attest | None yet | Play Integrity not built on Android (#92) **Gap** |
| Synced recovery token | iCloud Keychain | Block Store (gplay); none in the F-Droid build | Platform credential store (ADR 0059). F-Droid has no Google Play services |
| App lock | Element's lock screen, the account PIN, biometrics on | Element's lock screen, 8-digit account PIN, biometric option | Element X lock screen per platform |
| Check before a PIN change | Biometrics or the phone's passcode | Biometrics or the phone's screen lock; else the app lock PIN | `LAContext` on iOS, `BiometricPrompt` with `DEVICE_CREDENTIAL` on Android |
| Invite code input | Paste button | Pasted text collapses to the code in the field | Platform idiom |
| Voice messages | Sender-side transcription, pause and resume | Shows the transcript and checks it for scams; no sender-side transcription | On-device recognition on low-end Android unmeasured (#80, #81) **Gap** |
| Where invites live | Contatos e convites: invite buttons, people who joined with your invite, and unused invites in the contacts screen | Convidar pessoas in settings | Android has no contacts screen yet (#162) **Gap** |
| Help links | Hidden | Still point to element.io | Not done on Android (#205) **Gap** |
| Sticker from a photo | Subject cut-out (Vision) | Centred square crop | Cut-out needs ML Kit, not decided (#101) **Undecided** |
| Sticker import | Chat export ZIP or files | Chat export ZIP or files; picker opens in WhatsApp's stickers folder | iOS apps cannot read WhatsApp's files |
| Signed-device isolation | User preference, default on | Fixed on | Undecided (#102) **Undecided** |
| Language fallback | pt-BR for other device languages | Bipe strings pt-BR, Element strings en | Undecided (#102) **Undecided** |
| Handle lookup | Start chat only | Every user search | Undecided (#102) **Undecided** |
| Search | Search tab (iOS 26+), inline before iOS 26 | Search button in the top bar of Conversas and Grupos | Platform idiom (ADR 0053) |
| Quiet groups "done" marker | A flag on the device (once per device) | The poll rule in the account's push rules (once per account) | Android has no per-session store in libraries/bipe; same result for the user |
| Conferir no Bipe: close | Back to the app that shared | Back to Bipe | The iOS check runs in the share extension; Android shows it in the app (ADR 0091) |
| Message actions | Native context menu on long press: reaction row, actions, the message as preview | Element's bottom sheet | Platform idiom |

<!-- /parity:differences -->
