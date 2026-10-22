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

- **First run (bipe#415):** the start screen variant, the sign-up steps, the "Já tenho conta" rows and the later prompts come from bipe-shared `registries/onboarding.json` (generated `BipeOnboarding.swift`), the same source as Android. Start: `BipeOnboardingStart.variant(invitePending:inviteRequired:)` picks one filled button ("Tenho um convite", "Entrar com o convite" after an invite link, or "Criar conta" when `GET /v1/signup/config` says open) and "Já tenho conta". An invite link no longer jumps into sign-up: it rebuilds the start screen, which shows "@ana te chamou para o Bipe." from the invite preview. Notifications: no Element onboarding step; `TimelineViewModel.bipeAskForNotificationsIfNeeded` asks once after the first sent message. The @: `BipeHandlePromptRow` on Conversas while `GET /v1/me/handle` has none (`AppSettings.bipeHasDismissedHandlePrompt`).
- **Sign-up:** `BipeSignupScreen` steps: invite code (skipped with a link; "Não tem convite?" opens the waitlist sheet, `POST /v1/waitlist`), name and terms, 8-digit PIN twice, then the fallback (add an email or "Agora não"). No @ and no email on the first form. App Attest. `POST /v1/signup` without `password`. The API returns the hidden password and a recovery token once. The PIN is checked with `BipePIN.problem(for:)` (BipeKit, cases in `test-vectors/pins.json`).
- **Keychain:** `BipeCredentialStore` (BipeKit). The hidden password is `AfterFirstUnlockThisDeviceOnly` and never syncs. The recovery token is `kSecAttrSynchronizable` (iCloud Keychain). A pending email recovery (its claim secret) stays on the device. Nothing is shown or logged. ADR 0059 overrides ADR 0057 here: the password does not sync. Each account has its own password and token item, keyed by Matrix ID in `kSecAttrAccount` (ADR 0086, bipe#265): a second account never replaces the first. Calls without a Matrix ID read the newest item. The pending sign-up and the pending email recovery stay one per device: they have no Matrix ID until they end.
- **Password login without a browser:** `BipeAccountSignIn` calls `AuthenticationService.configure(for:flow:)` and then `login(username:password:…)` with the Matrix ID. That is the SDK's `Client.login`, a plain `m.login.password` to `/_matrix/client/v3/login`. MAS answers it through its compatibility layer (`passwords.enabled: true`). The SDK does not force OAuth for this call; OAuth support only changes what Element's own login screens offer. Element's guard stays: a login that returns a refresh token is signed out again.
- **Lost sign-up answer (ADR 0094):** `BipeCredentialStore.pendingSignup(pin:)` stores a `signup_key` and the PIN (`ThisDeviceOnly`) before the first `POST /v1/signup`. Every try sends the key, so a retry returns the same account. `BipeSignupScreenViewModel` retries up to 4 times on network, `internal` and `signup_in_progress`, with a new App Attest attestation each time. The pending sign-up goes after sign-in and the app lock PIN are done.
- **App start without a session** (`AuthenticationFlowCoordinator.resumeBipeAccount`): a pending email recovery opens the wait screen; else a pending sign-up without a stored password finishes through `POST /v1/signup/resume`; else the password on this device signs in silently (and a pending sign-up gives the app lock its PIN); else a synced token opens the PIN prompt (`POST /v1/recovery/token`, new password and token).
- **Sign-out** deletes the signed-in account's password on this device (`AppCoordinator.bipeDeleteStoredPassword`, user sign-out and forced sign-out; without a session, every password). The token stays, so the next sign-in needs the PIN. An auth error from the server keeps the password.
- **Recovery screen** (`BipeRecoveryScreen`, start screen button "Já tenho conta"): rows in registry order: token and PIN; old phone (hidden until bipe#203); recovery email (`POST /v1/recovery/email`); "Entrar com e-mail e senha" for beta accounts and the App Review demo account (MAS OAuth; no "beta" in the label, guideline 2.2). Link `https://bipe.chat/recuperar/#<token>` → `AppRoute.bipeRecoveryLink` → PIN, or a new PIN after "Esqueci minha senha" → `POST /v1/recovery/email/confirm` → wait screen that polls `/claim` every minute.
- **App lock:** off by default (ADR 0137). The "Bloquear o app" switch in Sua conta turns it on: `AppLockSetupFlowCoordinator(.bipeTurnOn)` creates the PIN and offers biometrics. Switching it off needs the device owner check (`verifyDeviceOwner`); a phone with no passcode goes through Element's PIN check and "Remove PIN". Sign-up, sign-in, recovery and a PIN change never turn the lock on. The app lock PIN is the device PIN (ADR 0086, bipe#266). While the lock is on and the phone holds one account, it follows the account PIN (`BipeDevicePIN.followsAccountPIN`, `AppLockServiceProtocol.bipeUseAccountPIN`). Biometric unlock keeps its setting. With two or more accounts, a set device PIN stays and the PIN footer in Sua conta says so (`bipe_account_pin_footer_device`). A new app lock PIN has 8 digits and passes the shared rule. An older 4-digit app lock PIN still unlocks (`pinCodeLength` follows the stored PIN).
- **Settings → "Trocar senha":** `BipeAccountScreen`. Device owner check (Face ID or passcode), then `PUT /v1/me/pin`. Blocked PIN state from `GET /v1/me/account`. Beta accounts: "Crie sua senha" sets the PIN, then `POST /v1/me/device-first` and stores the returned credentials. Recovery email: add, change, remove.
- **Old devices:** `BipeRecoveryAlerts` reads `GET /v1/me/account` after sign-in and on every foreground. A waiting recovery shows `bipe_recovery_alert_*` with "Cancelar, não fui eu" (`POST /v1/me/recoveries/{id}/cancel`). A completed token recovery shows once. The device's own token recovery, and recoveries that existed before this device's first check, do not alert.
- **Terms re-accept (ADR 0113, bipe#366):** `BipeRecoveryAlerts` shows `BipeTermsReacceptScreen` when a successful `GET /v1/me/account` has a `terms_version` other than `BipeRegistries.legalVersion` (none counts as other). Read errors show nothing: the server is the authority. Full-screen cover from `UserSessionFlowCoordinator.presentBipeTermsReacceptScreen`; no close, no swipe, no sign-out. Waits for onboarding. Recovery alerts wait until accepted (an alert cannot show over the cover); acceptance runs the check again. Checkbox row: `BipeTermsCheckbox`, shared with sign-up.
- **Password saving:** `webcredentials:bipe.chat` in the associated domains; the AASA lists both app IDs (bipe-infra).
- Not built: guardian and CPF recovery (no API yet), QR sign-in checks from bipe#152.

## Link a computer (ADR 0116, ADR 0118, bipe#391)

- **Entry point:** Settings > Aparelhos > Aparelhos conectados (`BipeLinkedDevicesScreen`) is the root of `LinkNewDeviceFlowCoordinator`. It lists the other devices (`GET /_matrix/client/v3/devices`) with last use and "Desconectar", and has the only "Conectar um computador" button. Only the desktop direction: the phone scans the code that `chat.bipe.net.br` shows. `LinkNewDeviceScreen` (both directions) is not used. `linkNewDeviceEnabled` (key `bipeLinkNewDeviceEnabled`, default on) shows the button.
- **Support check:** `ClientProxy.isLoginWithQRCodeSupported` is the Bipe check, not the FFI one (the FFI is true only for an OAuth session): `/versions` advertises `org.matrix.msc4108` and `BipeCredentialStore` holds this account's hidden password.
- **Approval:** at `waitingForAuthorisation` the QR screen shows `BipeWebApprovalScreen` (state `.bipeWebApproval`) in place of the system browser: full-access warning with the cooldown (`BipeRegistries.webLinkCooldownSeconds`), `LAContext` check, then the hidden password is read. `WKWebView` with `WKWebsiteDataStore.nonPersistent()`, MAS issuer host only (from `auth_metadata`). The MAS login form is filled once in the `.defaultClient` script world and never shown; a second login form is an error. The consent page shows the place from `GET /v1/web-link/place` (DB-IP attribution). `confirm()` when the page leaves the consent page or the user closes it; `cancel()` before the consent page. `POST /v1/web-link/finish` when the flow ends.
- **Sign-out of a linked device:** the MAS account page with `action=org.matrix.session_end&device_id=…` in the same private web view (Synapse with MAS refuses `DELETE /devices`).
- **Trap:** the Synapse rendezvous session lives 60 s from the QR code. Scan, warning, cooldown, biometric check and the MAS page must fit in it.
- Unverified (19 Oct 2026): the whole flow on a phone, the MAS consent page markup (IP in the page text, a `form` on `/device/<id>`), the MAS `session_end` page.

## Several accounts (ADR 0086, bipe#267)

- **Switcher on the Você tab (ADR 0135, bipe#446):** `BipeAccountSwitcher` (`Application/Navigation`), owned by `UserSessionFlowCoordinator` and hung on the Você `TabDetails.bipeAccountSwitcher`. A tap opens Você. A double tap switches to the next account (`switchToNextAccount`); with one account it is a tap. A long press opens the account menu. The menu is one `UIMenu` (`makeMenu`): every account (`BipeAccountMenuItem`) with a check on the current one, no title. "Nova conta" (`bipe_account_add`) shows only while the phone has one account and `BipeAccountCap.canAdd` allows one more; with two or more it is the Sua conta row `account.add`. Android does the same. Each row has the account's avatar, drawn into an image because menus render only images (`BipeAccountMenuItem.withAvatar`): a rounded square for a company (ADR 0132, from `BipeAccountLabels.isCompany`), else a circle. The other accounts' sessions are closed, so the open session reads their public profile (`clientProxy.profile(for:)`) and loads their photo from the same server; initials show until it loads. The Você tab icon is the current account's avatar in the same shape (`BipeAccountSwitcher.currentAvatar`, `TabDetails.bipeIcon`); the person icon shows until the profile loads. **Other-account dot:** a small red dot on the lower right of the Você icon while another account on the phone has a notification in Notification Center, and on that account's row in the menu. The other sessions are closed, so delivered notifications (their `receiverID`) are the signal: read on start and on each foreground, plus `.bipeOtherAccountNotification` from `NotificationManager.willPresent` for a push that shows while the app is open. The dot goes when that account reads the room (its notifications are removed) or the user clears them. `NotificationManager` removes only the current account's notifications, so a room shared by two accounts keeps the other's. The long-press preview is an empty one-point line on the item's top edge: a snapshot caught the iOS 26 glass lens mid-press and floated a lifted copy of the item, and an empty view the size of the item left the menu a finger above the tab bar. Account names come from `BipeAccountLabels` (BipeKit), because another account's session may not be live; the list comes from the session keychain (`BipeSignedInAccounts`), because `sessionsPublisher` lists live sessions only.
- **Gestures:** SwiftUI `Tab` has no gesture API. `NavigationTabCoordinatorView.configureBipeAccountGestures` puts `BipeAccountGestures` (a `UIContextMenuInteraction` and a double-tap recognizer that does not delay the first tap) on the `UITabBar` from the `introspect(.tabView…)` hook. **Trap:** UIKit has no public frame for a tab item. `BipeAccountGestures.tabBarItemFrame` walks up from the touched view to the row of same-class siblings with one view per tab and takes the Você index. A new tab bar layout in an iOS release can break it: then the menu and the double tap do nothing, and a tap still opens Você. iPad rail: `BipeAccountGestureOverlay` covers the Você button and takes the tap too. No haptic is added: the system menu plays its own (ADR 0134), and a switch played none before.
- **Chat list avatar** (`HomeScreen.settingsButton`): a tap opens Você. No long press, no switch.
- **Switch** (`AppCoordinator.bipeSwitchAccount`): pause the current session, `UserSessionManager.activate(userID:)` (restores the session when it is not live, moves it first), then rebuild the session UI. The state stays `signedIn`.
- **"Nova conta" window** (`BipeNewAccountScreen`, bipe#445, #446): a sheet from `UserSessionFlowCoordinator.presentBipeNewAccountScreen`. Two entry points: the Você tab menu (one account only) and the Sua conta row `account.add` (section "Contas neste celular"). Three rows: "Conta pessoal" (disabled at the cap with `bipe_account_cap_reached`), "Conta da empresa" (only with `BipeAppAttest.isSupported` and when the account on screen is not a company), and "Entrar numa conta que já existe" (always enabled). The choice (`BipeNewAccountChoice`) goes up to `AppCoordinator.bipeStartAddingAccount` after the sheet closes.
- **Invite for the new account (#445):** on open, the window reads the quota of the account on screen (`BipeInviteCreator.quota`, creates nothing). Invites left: the footer says `bipe_account_new_invite_note`. None left: the two sign-up rows are disabled and the footer is `BipeInviteQuota.noneLeft`. The first tap on a sign-up row calls `BipeInviteCreator.createIfAvailable` once per window, so a closed window spends no invite. The code goes to `AuthenticationFlowCoordinator(bipeOpensSignup: true, bipeInviteCode:)` as `pendingInviteCode`, and `BipeSignupScreenViewModel` starts at the name step. A network error keeps the rows enabled: the sign-up opens on its invite step. A first sign-up on an empty phone is unchanged.
- **Add account** (`bipeStartAddingAccount`): `AuthenticationFlowCoordinator(isAddingAccount: true)` shows the flow as a sheet over the session, without the silent sign-in. A sign-up choice opens straight on the sign-up; "Entrar numa conta que já existe" opens the start screen (sign-in, QR code, recovery). A swipe down cancels. A sign-in adds the session and opens it (`isNewLogin: true`). The recovery screen offers only tokens of accounts not on the phone (`BipeCredentialStore.recoveryToken(excluding:)`).
- **Cap:** `BipeAccountCap` (BipeKit): the last `max_accounts` from `GET /v1/me/account` (read in `BipeRecoveryAlerts`), else `BipeRegistries.maxPersonalAccounts` (2). Company accounts do not count (#269): `BipeAccountCap.canAdd(signedInUserIDs:)` counts personal accounts only. The window and `bipeStartAddingAccount` both use it. A sign-in to an existing account is not capped on the phone.
- **Sign-out:** another account on the phone opens (`signedOut => restoringSession`). A sign-out after a forgotten device PIN removes every account from the phone (`userSessionManager.reset()`), so the PIN cannot be skipped to reach the other account.
- Element's upstream multi-account UI (developer toggle, Add account row, announcement) is removed (bipe#434). The Você tab is the only switcher (ADR 0135).
- Not done: the account avatar in the composer, the account name in notifications, a check that the NSE reads the right session per push (unverified), the ADR 0120 rounded square for a verified company (needs #252). Upstream develop has 28 newer commits with multi-account work ("Keep every signed-in account live", "Notify every signed-in account"); a rebase onto it can replace parts of this.

## Company account, owner case (ADR 0087, bipe#269)

- **Conta da empresa:** a row of the "Nova conta" window (bipe#445), shown only when `BipeAppAttest.isSupported` and the account on screen is not a company (ADR 0043). The old Sua conta row `account.createCompany` and its `flag:companyAccount` are gone. The row opens the add-account sheet straight on the sign-up screen in company mode (`AuthenticationFlowCoordinator(bipeAccountType: .company, bipeOpensSignup: true)`), with the invite from the account on screen: the name field is "Nome da empresa" (footer `bipe_account_new_company_body`), and `POST /v1/signup` sends `account_type: company` with the App Attest attestation.
- **Account type** on the phone: `BipeAccountLabels.rememberCompany` at sign-up and from `account_type` in `GET /v1/me/account` (`BipeRecoveryAlerts`). A company account does not count in the cap (`BipeAccountCap.canAdd(signedInUserIDs:)`).
- **Avatar shape (ADR 0132, bipe#397):** a company account is a rounded square everywhere `LoadableAvatarImage` draws a user (its `contentID` is the Matrix ID), verified or not. `BipeCompanySeals.isCompany` reads `GET /v1/accounts/{userId}/type` (public, cached a day; known companies kept in UserDefaults). Unknown type or a failed fetch: circle. Android is a circle until #397 reaches it.
- **Trust card:** a company account gets the company ladder (Conta, Perfil, CNPJ, Empresa verificada, Site; bipe/docs/trust-levels.md). `SettingsScreenViewModel` takes the type from `account_type` in `GET /v1/me/account` (the local label until it loads) and the step states from `GET /v1/me/business`. Not-done steps show "Em breve" until the claim UI (bipe#249). Android does the same.
- **Identity on screen:** the chat list title is the company's name (`HomeScreen.title`); the composer placeholder is "Respondendo como <empresa>" (`ComposerToolbarViewState.bipeReplyingAs`).
- Not done: the CNPJ steps in the app (the claim UI is bipe#249 and #115; the API has them), the seal and the distinct colour in the top bar (#252, ADR 0120), the company's own recovery key and fallback prompts, a second seat verified from the owner's phone (Element's device verification may cover it; unverified).

## Contacts and invites (growth loop step 2)

- **One settings row**, "Contatos e convites", opens `BipeContactsScreen`. Invites have no settings row of their own.
- **Contacts screen:** the invite buttons on top (`BipeInviteButtonsSection`, shared with `BipeInvitesScreen`), then people who joined with the user's invite (`GET /v1/me/invites`, status `used`), then address-book matches, then a "Convites ainda não usados" row with the count that opens `BipeInvitesScreen`. The counts reload on each appear, so they are current after a return from the invites screen.
- **Start chat "Convidar pessoas":** creates a personal invite and opens the share sheet (`BipeInviteCreator.createIfAvailable`). Element shared a matrix.to profile link, which is a dead end for an invite-only sign-up.
- `BipeInviteCreator` (BipeKit) is the one place that creates an invite and stores its link. `BipeInviteQuota` writes the quota text.
- **Invite names** ("Para quem é?") live on the server: `PUT /v1/me/invites/{id}`, returned as `name` in `GET /v1/me/invites`. Builds before 19 Oct 2026 kept them only in UserDefaults, and pruned them whenever one list reply missed an ID, so most were lost. `BipeInvitesScreenViewModel.uploadLocalNames` uploads what is left once, then removes the local copy. Links stay on the device (the server keeps only a hash).
- **Invite note (ADR 0136, bipe#458):** every place that makes a personal invite (invites screen, contacts screen, start chat "Convidar pessoas") first shows `bipeInviteNoteAlert`: "Primeira mensagem", pre-filled with `bipe_invite_note_default`, editable; empty means no note. The share text never carries the note. `BipeInviteCreator.create(note:)` stores it in `BipeInviteStore` (keychain service `chat.bipe.invites.notes`, per account, `ThisDeviceOnly`). The server never receives it. Nova conta invites (#445) have no note.
- **Sending the note:** `BipeInviteNoteSender` (in `BipeInviteJoinNotifier.swift`) runs after the join toast at session start, and after `BipeInvitePairs.autoAccept` joins a pair chat. For each used invite with a note, it sends the note into the joined DM with `joinedUserId` (`directRoomForUserID`, or the room just auto-accepted when its heroes hold that user). It never creates a DM: the invitee's app does. No DM yet: the note waits. The note leaves the store before the send and comes back on a send error, so it goes at most once.
- **Invitee side:** while the inviter hint shows and the loaded timeline has no message from the inviter, `BipeInviterHint` adds `bipe_inviter_knows_you_joined` ("%1$s já sabe que você chegou.") above "Mandar um oi" (`RoomScreenViewModel.updateBipeInviterKnows`).

## Handle change lines (ADR 0066, bipe#166)

- **Remove the handle:** "Remover nome de usuário" on `BipeHandleScreen`, also during the cooldown. A confirmation alert (`bipe_handle_remove_body`), then `DELETE /v1/me/handle`. Same flow on Android.

- `BipeHandleChangeStore` (BipeKit): one per session, made in `AppCoordinator.setupUserSession`, cached in `Caches/bipe-handle-changes-<user>.json`. `POST /v1/handle-changes` in chunks of 100. People without a cached change go without `since`; the others share the oldest of their latest cached times.
- Fetch: on room open, for the joined members (`TimelineController`); after the room list loads, for the cached people plus every joined room's heroes (`AppCoordinator.refreshBipeHandleChangesAfterSync`).
- Display: `TimelineController.bipeInsertingHandleChanges` adds a local `StateRoomTimelineItem` (virtual ID) at `at` in the room's main timeline. Rules in `BipeHandleChangePlacement`: current members only, inside the loaded range (after the end only on the live timeline), not before a join seen in the loaded items. Text: `bipe_handle_set`, `bipe_handle_changed`, `bipe_handle_removed` with the member's display name in the room.

## Groups MVP (bipe/docs/groups.md, ADR 0026)

- **Quiet by default (#97):** `BipeQuietGroups` runs once per account from `AppCoordinator.runPostSessionSetupTasks`. It sets the group default to mentions and keywords and adds the override push rule `chat.bipe.poll_start` (`*.poll.start`) so new polls notify. It does nothing until `canPushEncryptedEventsToDevice()` is true: mentions in encrypted rooms need Synapse `msc4028_push_encrypted_events`, or mentions-only silences the group. Turn that server flag on only after Apple grants the NSE filtering entitlement (see Rebrand status), or the NSE cannot drop the other pushes. Android ships the same feature (#97, #98).
- **"O que você perdeu" (#98):** `BipeMissedSummary` (rules) and `BipeMissedSummaryView` sit above the read marker in `RoomTimelineItemView`. Shown in groups on the live timeline when at least 20 loaded messages follow the marker. Lines: mentions of you or @room, replies to you, open polls you have not voted in. Pins are not in it yet.

## gov.br verification (trust step 5, bipe#544)

- **Gate:** `AppSettings.bipeGovbrEnabled` (developer options, "gov.br verification"), off by default until the legal review of the gov.br signer terms (bipe#17). Off: step 5 shows "Em breve".
- **Flow:** the step 5 row in `BipeTrustProfileSection` opens `BipeGovbrScreen` (a sheet from `SettingsScreen`). `BipeGovbrFlow` (BipeKit) calls `POST /v1/verifications/govbr`, saves `bipe-verificacao.pdf` in the app's Documents folder and opens the gov.br App Store page (no documented URL scheme; the page shows "Abrir" when the app is installed). "Já assinei" picks the signed PDF and sends it to `PUT .../document`. A rejection shows its reason and "Tentar de novo" (a new challenge).
- **Done state:** `SettingsScreenViewModel` reads the account's own badge (`GET /v1/badges`) and takes `lvl` without the signature check, only for the card. Seals always go through `BadgeVerifier`.
- Not done: Bipe in the share sheet for the signed PDF (`CFBundleDocumentTypes`), Files showing the Documents folder (`UIFileSharingEnabled`).

## "Conferir no Bipe" (bipe ADR 0091, bipe#294)

- **Share target:** the existing share extension. `ShareExtensionViewController.bipePixCheck(for:)` reads shared text, or the QR codes in shared images (`PixCheck.qrPayloads`, Core Image). When it finds a Pix code or key it shows `BipePixCheckView` (`ElementX/Sources/ShareExtension`, compiled into the app too for the store screenshots) in the extension and does not open the app. "Enviar para uma conversa" continues to Element's share flow. No account and no network needed.
- **Logic:** `PixCheck` in BipeKit (BR Code TLV, CRC-16, key types, keys in the text, the rule 9 warning without `pixCode` and `pixKey`). Cases: `bipe-shared/test-vectors/pix-check.json`.

## Tab bar (bipe ADR 0053)

- **Tabs:** Conversas, Grupos, Você, plus search (`UserSessionFlowCoordinator.HomeTab`). Conversas shows the b mark (`bipe-tab-chats`, outline; `-fill` when selected; template SVGs from `bipe-web/public/brand/mark.svg`) through `TabDetails.bipeImages`, not an SF Symbol. The Spaces tab is not created; `SpacesTabFlowCoordinator` stays in the tree for rebases.
- **Conversas and Grupos** are two `ChatsTabFlowCoordinator`s with a `BipeRoomListScope`. `clientProxy.roomSummaryProvider` lists Conversas (SDK category `people`, DM invites included); `bipeGroupsRoomSummaryProvider` lists Grupos (category `group`, joined or invited). Group invites show in Grupos, as on Android. `NotificationSettingsEditScreenViewModel` reads `staticRoomSummaryProvider`, because the main provider no longer lists all rooms.
- **Routing:** `.room`, `.event`, `.roomDetails` and `.thread` open in the tab that lists the room (`bipeRoomTab(for:)`). Other room routes stay in the current tab.
- **Badges:** each tab sums `unreadNotificationsCount` of its own rooms. A group invite not in `seenInvites` adds 1 to Grupos (`updateBipeTabBadges`). The app icon badge stays the total. Você shows no ways-back warning (mz, 21 Oct 2026): the warning is only on the Sua conta row, so the only mark on Você is the other-account dot.
- **Trap: the room count is not the tab's.** `RoomSummaryProviderState.loaded(totalNumberOfRooms:)` comes from the SDK and counts every room in the account, whatever the tab's filter. Never read it as "this tab has rooms". On 15 Oct 2026 Grupos showed skeletons forever for an account with chats and no groups: the home screen waited for rooms that the filter never published. `HomeScreenViewModel.scheduleBipeEmptyTabFallback` now shows the empty state after one second.
- **No spaces in the create-group screen:** `StartChatFlowCoordinator` passes `spaceSelectionMode: .none`, so the space picker and the "space members" access types do not show. Spaces come back only as Comunidade inside Grupos (ADR 0084).
- **Você** is `SettingsFlowCoordinator(isInTab: true)` in a stack in the tab: no close button, title "Você". `.settings` and `.chatBackupSettings` routes select the tab. On a Mac with secondary windows, settings still open in a window.
- **Support DM (ADR 0114):** Ajuda → "Falar com o suporte" (`help.support`) → `UserSessionFlowCoordinator.openSupportChat`: `POST /v1/me/support`, join the invite, open the room.
- **Self-chat:** `BipeSelfChat`. Account data `chat.bipe.self_chat` = `{"room_id": "..."}` (same on Android). Created on first tap as a private encrypted room named "Anotações". The room lists hide it by a cached ID in `UserDefaults`; it opens in Conversas. A cache change posts `BipeSelfChat.cachedRoomIDDidChange` and the room lists filter again. **Trap:** the new room reaches the Grupos list before `createRoom` returns, and an empty room sends no later update, so without the post it stays in Grupos as an empty "Anotações" group.
- **Archive:** the Matrix `m.lowpriority` tag (`JoinedRoomProxy.flagAsLowPriority`, `RoomSummary.isLowPriority`). The home tab providers always hide low priority rooms (`RoomSummaryProvider.hidesLowPriority`); the static provider does not, so search and pickers still find them. Swipe left on a row (`bipeSwipeAction`, a custom pan because the list is a `LazyVStack`, not a `List`) or the context menu archives. `BipeArchivedRow` ("Arquivadas", count from `staticRoomSummaryProvider`) opens the `.lowPriority` filter. The row's own tag (`HomeScreenRoom.isLowPriority`) picks "Arquivar" or "Desarquivar", so an archived chat found by search unarchives too. The chip is hidden (`BipeRoomListScope.hiddenFilters`). Android: bipe#435.
- **App lock screen:** `BipeAppLockPlaceholderScreen` replaces Element's logo placeholder in `AppLockFlowCoordinator.showPlaceholder`: logo, "Bipe bloqueado", and the Face ID or Touch ID icon when biometric unlock is on. The app switcher shows it too.
- **Trap: a short resign never hides the main window.** On `willResignActive` (system UI, Control Center) the placeholder covers the main window from the alternate window (`windowLevel` `.normal + 1`, `WindowManager.bipeCoverMain`); only a lock (background, unlock prompts) hides the main window. On 19 Oct 2026 the app resigned for under a second on the first message after a new sign-up, and the hidden-then-shown main window stayed black until the app went to the background. The cause of that resign is unknown.
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
- **Icons are SF Symbols (20 Oct 2026):** `CompoundIcon` looks up each Compound key path in `compound-ios/.../Icons/BipeSystemSymbols.swift` and draws that SF Symbol. Call sites keep `CompoundIcon(\.x)` and `Label(_:icon:)`. An icon with no entry draws the Compound image (`spinner`, `keyOffSolid` today). A new Compound icon in the code needs an entry there.
- **No telemetry (bipe#55, 14 Oct 2026):** the Sentry and PostHog packages are gone from `project.yml`. `DisabledAnalyticsClient` replaces the PostHog client, `Signposter` records nothing, the Rust SDK gets `sentryConfig: nil`, Element Call gets no PostHog or Sentry values, and CI no longer uploads dSYMs. `AppSettings.analyticsConfiguration` is `nil`, so the analytics prompt and setting never show. Rageshake points at the Bipe API (`Secrets.swift`, bipe#367): "Avisar sobre um problema" in Ajuda e sobre sends the report with the access token, logs off by default; the sign-in screens do not offer it. On a rebase, drop any Sentry or PostHog code that upstream adds.
- **Trimmed packages (15 Oct 2026):** GZIP, LoremSwiftum and KZFileWatchers are gone from `project.yml`. `BugReportService` writes logs uncompressed. The `EventTimelineItem` mock uses a fixed sentence. `UITestsSignalling` has its own polling `FileWatcher`. AnalyticsEvents stays: 109 call sites use its types, and removing it would rewrite upstream code. On a rebase, keep these three out.
- **Location maps (bipe ADR 0131, 19 Oct 2026):** `AppSettings.bundledMapTilerConfiguration` points at `https://maps.bipe.net.br/styles` (tileserver-gl in bipe-infra `k8s/bipe/maps.yaml`), styles `light` and `dark`, empty key. Never set a MapTiler key or URL: every tile and static map request carries the shared location. `Secrets.mapLibreAPIKey` is not used.
- **Server (done 11 Oct 2026):** default account provider `bipe.net.br` (base `https://matrix.bipe.net.br`), picker hidden (`allowOtherAccountProviders = false`), push gateway `https://push.bipe.net.br` (Sygnal, issue #61; never matrix.org).
- **TestFlight signing (11 Oct 2026):** xcodebuild cannot use the account signed in to the Xcode GUI, so it cannot regenerate profiles. `testflight.sh` signs in with the App Store Connect API key "Bipe CI" (`M2VUX56QAJ`, App Manager, `~/.config/bipe/`). App Manager keys cannot use cloud signing, so export uses manual App Store profiles made in the developer portal with the local "Apple Distribution: CENTAUR LABS OU" certificate (expires 20 Mar 2027): "Bipe App Store", "Bipe NSE App Store", "Bipe Share App Store" (`Tools/Bipe/ExportAppStore.plist`). **After any capability change on an App ID, regenerate its profile in the portal and install it in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.**
- **TestFlight:** `Tools/Bipe/testflight.sh` archives Release, uploads with `Tools/Bipe/ExportAppStore.plist`, then runs `Tools/Bipe/testflight-distribute.mjs`: it waits until App Store Connect has processed the build, adds it to the external group "Amigos" and submits it for beta review, with the "Bipe CI" key. Agents do all App Store Connect work through the API; MZ does nothing in the web UI. Plan: `docs/testflight-plan.md`.
- **App Review demo account:** `Tools/Bipe/review-details.mjs` writes the demo account and review notes to the Beta App Review details and to the App Store version in preparation. Account `app-review@bipe.chat` (email and password in MAS, no PIN, signs in through "Entrar com e-mail e senha"); password in the login Keychain `bipe-review-demo`, invite for a second account in `bipe-review-invite`. Run it again after either changes.
- **App Store:** plan and open decisions in `docs/app-store-plan.md` (bipe-chat/bipe#419).
- **Version and build number (ADR 0088):** one build number for iOS and Android, set in `bipe-shared/product/version.json`. Before each upload: `node tools/bump-build.mjs` in bipe-shared (`--version YY.MM.N` for a new version), then commit and push bipe-shared, this repo and bipe-android. `Tools/Bipe/version.env` (read by `testflight.sh`) and `Tools/Bipe/Version.xcconfig` (the project config file for Debug and Release, `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`) are generated. Do not set either value in `project.yml`: it overrides the xcconfig, and the bipe-shared drift check fails when it differs.

## Store screenshots (bipe#454)

- One command captures the raw App Store screenshots on the installed `iPhone 17 Pro Max` simulator, in pt-BR with the status bar at 9:41:

```bash
./appstore/capture.sh iphone69
```

- Output: `appstore/raw/<device>/<appearance>/<slug>.png` (git-ignored), one per panel slug in `bipe-shared/product/appstore.md`. `appstore/capture.sh iphone69 dark` gives the dark set; `ipad13` waits for the iPhone-only decision (bipe#419 step 4). The bipe-web image builder (bipe#455) makes the store panels from these files.
- Sizes and simulators: `appstore/devices.mjs`. The script fails when a capture has another size, and when the simulator is missing (it never downloads one).
- Screens: `BipeStoreScreens` (`ElementX/Sources/UITests`, DEBUG only), one `UITestsScreenIdentifier.bipeStore*` case per slug, built from the existing Bipe views on mock proxies. People come from `BipeCast` (generated from `bipe-shared/product/cast.json`); photos from `../bipe-web/src/cast/photos`, passed to the app in `BIPE_CAST_PHOTOS`. `AppSettings.bipeDisableAPIForScreenshots` and `BipeCompanySeals.storeFixture` (both DEBUG only) keep the real API out.
- Test: `UITests/Sources/StoreScreenshotTests.swift`, one test per slug. It attaches the screen as `<slug>` and does not compare snapshots.
- Each test also attaches the screen's elements (label, identifier, type, frame in points) as `<slug>.elements`; `capture.sh` writes `<slug>.elements.json` next to the PNG. The bipe-web builder places the panel callouts on them (`scripts/lib/callouts.mjs`): no app code gets store-only identifiers.
- CI captures: `.github/workflows/store-captures.yml` runs `capture.sh iphone69 light` on the `xcode-27` runner, on `workflow_dispatch` and on PRs that touch the store screens. Its artifact holds the pt-BR set: commit it under `appstore/raw/iphone69/light/pt-BR/`. Agents use this instead of a local simulator run.

## App Store listing upload (bipe#456)

- `node Tools/Bipe/appstore-publish.mjs <metadata|screenshots|all> --dry-run` reads App Store Connect and prints every change; without `--dry-run` it sends them. Text: the iOS block of `bipe-shared/product/appstore.md` (it stops when `check-appstore` fails). Panels: `appstore/screenshots/<device>/<locale>/` from the bipe-web image builder (`--screenshots <dir>` for another folder). A second run changes nothing: it compares texts and screenshot MD5s first.
- It renames a version in preparation to `BIPE_VERSION` (the web UI makes "1.0"), leaves out `whatsNew` until a version is live, and sets the categories. App Review details stay in `Tools/Bipe/review-details.mjs`.
- All three tools share `Tools/Bipe/asc.mjs` (JWT and requests, `APP_ID`). The 6.9" set is the API type `APP_IPHONE_67` (`ascScreenshotType` in `appstore/devices.mjs`).
- The record is still "Bipe Chat" `6822454419` (`chat.bipe.app.dev`). Run it for real only after bipe#419 decides the account and bundle ID.

## Troubleshooting

- **Login stuck on "loading" after choosing a server:** check the app log for `TimedOut` on `/.well-known/matrix/client`. On 11 October 2026 the cause was the phone's Tailscale routing, not the app. Logs: `xcrun devicectl device copy from --device <UDID> --domain-type appGroupDataContainer --domain-identifier group.chat.bipe.dev --source Library/Logs/chat.bipe.app.dev/<file> --destination <local file>`.

## DMs are DMs (16 Oct 2026)

- One DM test: the SDK isDm decides on every screen (bipe#524).
- A DM never turns into a group. DM details: no topic (`hasTopicSection`), no polls history, no "Convidar" to the DM. "Convidar para um grupo" opens `BipeInviteToGroupSheet` with your joined groups from `staticRoomSummaryProvider` (not DMs, spaces, replaced rooms or the self-chat) and invites the other person to the one you pick. The group's invite permission is checked at pick time.
- The composer "+" menu has no poll in a DM (`ComposerToolbarViewState.isDM`).
- A DM has no room leave in the UI. "Apagar conversa" (`bipe_dm_delete_action`) replaces it in the room list menu and in DM details. Groups keep "Sair do grupo".
- One exception: the report screen (`ReportRoomScreen`) keeps its leave switch ("Sair da conversa") in a DM. With it on, the report leaves the room, so the other person sees that you left. Report and leave is the safety path, so it stays.
- No room setup lines in a DM timeline or room list preview: `RoomStateEventStringBuilder` (with `isDM`) drops invites and accepted invites, `RoomTimelineItemFactory` drops joins and "encryption enabled" (upstream already dropped the create event and your own join). The invite-pair auto-accept made "Você aceitou o convite" the DM's preview on the inviter's phone. A join in the preview says "entrou na conversa" (`bipe_dm_joined`), as on Android. A leave says "saiu da conversa" (`bipe_dm_left`). DM details are titled "Informações da conversa". The room list menu, leave toast and spinner, mute errors and the media empty states say "conversa" in a DM.
- A DM shows no 'sala' in any string (bipe#507); a new DM-reachable string gets a `bipe_dm_*` variant.
- A DM shows no topic anywhere (bipe#527). Topic events are not in the DM timeline (`RoomTimelineItemFactory`) and are not the room list last message (`RoomStateEventStringBuilder` gives no line for `.roomTopic` with `isDM`). A DM invite (`JoinRoomScreen`) shows no topic.
- A group says "descrição" for its topic, never "tópico": in Bipe "tópico" is a thread (`linguagem.md`). The topic lines, the details section and the create field use `bipe_group_*` strings (bipe#527).
- A group has no 'sala' in any string (bipe#508); new strings use 'grupo' or 'comunidade'.
- **Apagar conversa (bipe#464):** you stay in the room. Bipe writes a marker to the global account data `chat.bipe.cleared_chats`: `{"rooms": {"<room_id>": {"ts": <ms>}}}`. `ts` is the `origin_server_ts` of the room's latest event (`RoomSummary.bipeLatestEventTimestamp`), else the current time. The write reads the event from the server over HTTP (`StickerPackClient.accountData`; the SDK's copy waits for the next sync and can miss another device's marker), merges the entry and writes it back. It keeps the other keys and entries, and a marker never moves back. A failed read writes nothing and shows the clear error (bipe#479). `ClearedChats` (BipeKit) holds the rules; `test-vectors/cleared-chats.json` holds the cases. Android uses the same event.
- The room lists, the archive, the tab badges and search leave out a DM when its latest event is at or before the marker. A newer event shows it again in its place by time. The timeline and search drop every event at or before the marker. Back pagination stops at the marker, and the timeline has no "start of conversation" header (`BipeClearedTimeline` in `TimelineController`). Every timeline goes through `TimelineController`, so the media gallery, pinned list and threads drop the same events. The pinned banner reads the pinned timeline directly and uses `BipeClearedChatsStore.keptEvents`. The pinned count in DM details still counts every pinned event ID, as on Android. The other person sees no change. Nothing is deleted on the server.
- The share and forward pickers (`RoomSelectionScreen`, `MessageForwardingScreen` and its suggestions) leave out a hidden DM too. Share sheet suggestions: every `INSendMessageIntent` donation (app and NSE) has `groupIdentifier` = room ID, and a clear deletes that group. Donations made before bipe#479 have no group and stay until iOS drops them.
- `BipeClearedChatsStore` holds the markers of one account and caches them in `UserDefaults`. The SDK cannot observe custom account data, so the store reads the event again on each room list update (at most every 2 s), on foreground and after its own write. A read never removes a known marker. Another device follows at its next room list update or foreground.
- A new chat with the same person finds the joined DM (`get_dm_rooms`) and opens it, empty after the marker. A DM that you left before this change stays left. Bipe does not migrate it.
- The SDK has no API to delete the media cache of one room, so a clear keeps the cached media files.
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
| Criar conta da empresa | Company option in Nova conta on a phone with App Attest | Company option in Nova conta hidden | A company account needs an attested device (ADR 0043, ADR 0087); Play Integrity not built on Android (#92) **Gap** |
| Synced recovery token | iCloud Keychain | Block Store (gplay); none in the F-Droid build | Platform credential store (ADR 0059). F-Droid has no Google Play services |
| App lock | Off by default; switch in Sua conta. Element's lock screen, biometrics optional | Off by default; switch in Sua conta. Element's lock screen, biometrics optional | Element X lock screen per platform |
| Check before a PIN change | Biometrics or the phone's passcode | Biometrics or the phone's screen lock; else the app lock PIN | `LAContext` on iOS, `BiometricPrompt` with `DEVICE_CREDENTIAL` on Android |
| Invite code input | Paste button | Pasted text collapses to the code in the field | Platform idiom |
| Voice transcript | Any iPhone with an on-device model for the language | Android 13 and later with an installed on-device model; older phones send without a transcript | Android gives a recogniser an audio stream only from Android 13. Quality on low-end phones is not measured (#81) |
| Sticker from a photo | Subject cut-out (Vision) | Centred square crop | Cut-out needs ML Kit, not decided (#101) **Undecided** |
| Sticker import | Chat export ZIP or files | Chat export ZIP or files; picker opens in WhatsApp's stickers folder | iOS apps cannot read WhatsApp's files |
| Signed-device isolation | User preference, default on | Fixed on | Undecided (#102) **Undecided** |
| Language fallback | pt-BR for other device languages | Bipe strings pt-BR, Element strings en | Undecided (#102) **Undecided** |
| Handle lookup | Start chat only | Every user search | Undecided (#102) **Undecided** |
| Search | Search tab (iOS 26+), inline before iOS 26 | Search button in the top bar of Conversas and Grupos | Platform idiom (ADR 0053) |
| Quiet groups "done" marker | A flag on the device (once per device) | The poll rule in the account's push rules (once per account) | Android has no per-session store in libraries/bipe; same result for the user |
| Conferir no Bipe: close | Back to the app that shared | Back to Bipe | The iOS check runs in the share extension; Android shows it in the app (ADR 0091) |
| Message actions | Native context menu on long press: reaction row, actions, the message as preview | Element's bottom sheet | Platform idiom |
| Terms screen and a recovery alert due together | Terms screen first, the alert right after Continue | Recovery alert first, then the terms screen | On iOS a root alert cannot show over the full-screen terms cover; on Android the terms screen is an overlay that waits for the alert |
| Settings: Idioma | Row that opens the iPhone Ajustes | No row | iOS sets the app language in system settings; Android follows the system language |
| Warning haptic | Notification warning pattern | One long-press pulse | Android has no warning haptic constant (ADR 0134) |

<!-- /parity:differences -->
