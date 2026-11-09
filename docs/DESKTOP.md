# Desktop host and release guide

The same Flutter app and four-tab layout now target macOS and Windows. The laptop owns the SQLite ledger for every trip. Android guests continue to use existing Discord invitations and encrypted requests; see [Discord setup](discord-sharing.md). No new HTTP backend, always-on service or automatic startup task is installed.

Open the desktop app and configure Discord in Sharing. Create a separate invitation per guest/trip. Keep the app open and connected while collecting submissions. On open/resume and every 30 seconds while foreground, it processes up to three pages of requests. The top status strip shows indeterminate network activity, then completed/total requests for each fetched page. This counts messages examined, including unrelated messages, rather than pretending to know the entire remaining inbox. Further pages continue on the next tick. Errors preserve queues/cursor; retry from Sharing to see the error. Closing/suspending the app stops future sync; guests' queued expenses wait until the host returns. Discord requires internet; personal tracking stays offline.

## Storage and migration from a phone

Ledger files use `path_provider`'s application support directory with a `ledger/` child: Application Support on macOS, application data on Windows. They are outside the `.app` or installation directory. Keep the bundle ID, Windows company/product metadata and data paths stable across versions. Replacing binaries does not replace the ledger. Tokens remain in the existing secure-storage plugin: macOS Keychain (single-app legacy Keychain, no shared group/provisioning requirement) and Windows protected credential storage. User backups continue through the native file picker/save/share interfaces.

Use a manual JSON export on the phone, transfer it, then preview and restore it on the laptop. Restore replaces the destination ledger. Export a safety backup first. Reconfigure Discord and recreate invitations on the new host: relay credentials and sessions are not portable ledger backup data. Retire invitations on the old host before switching; do not run two hosts against the same Discord channel/cursor. Databases on separate devices do not automatically mirror one another.

Desktop files may be included in Time Machine, Windows backup or a user-configured sync folder. AppData is not encryption. Use OS account protection/full-disk encryption and keep exported JSON private. The standalone macOS build disables App Sandbox because this native Sparkle integration expects a non-sandboxed app; mobile file-protection and backup settings are unchanged. This distribution is outside the Mac App Store.

## Build and package

Use an official stable Flutter SDK and resolve the lockfile on each native host. Run `flutter analyze` and focused tests from AGENTS.md before building.

macOS requires full Xcode, its command-line tools, and CocoaPods for plugins requiring Pods:

```sh
flutter pub get
flutter build macos --release
python3 tool/package_desktop.py macos
```

Outputs: `release/expense-tracker-<version>-macos.dmg` (drag the app to Applications) and `-macos-update.zip` (Sparkle update payload). The app currently retains the generated stable desktop identity `com.example.expenseTracker`; choose a permanent identity before the first distributed build if desired, then retain it. Sign the app with your Developer ID, enable hardened runtime with appropriate Flutter entitlements, notarize/staple, then package. For public distribution also sign/notarize/staple the DMG. Local unsigned validation builds can trigger Gatekeeper and are not signed releases.

Windows requires Visual Studio's Desktop development with C++ workload, Windows SDK, CMake and Inno Setup 6:

```powershell
flutter pub get
flutter build windows --release
python tool/package_desktop.py windows --iscc "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
```

Outputs: `release/expense-tracker-<version>-windows-x64.zip` and `-windows-x64-setup.exe`. The ZIP contains the EXE, DLLs and data together. Extract the whole ZIP before running. The installer uses a stable AppId and per-user `{localappdata}\Programs\ExpenseTracker` directory, closes the running app for upgrades and leaves ledger data intact. Prefer the installer for native updates; portable users can manually replace the entire extracted binary folder after closing the app. Install the Visual C++ x64 runtime on machines that lack it. Authenticode-sign the installer before generating its updater signature. Windows SmartScreen may flag unsigned or unfamiliar applications.

`.github/workflows/desktop-build.yml` provides a manually triggered native build matrix and downloadable validation artifacts. These builds have no release signing credentials and do not publish releases or enable desktop update feeds.

## Prompted desktop updates

Desktop uses `auto_updater` (Sparkle / WinSparkle). It checks on app open/resume using the existing five-minute throttle, with explicit checking from Settings. Native dialogs handle download progress, consent and installation/restart. It does not silently replace a running app. Offline checks never prevent access to the ledger. Android keeps its existing verified APK updater.

Desktop updating is **disabled by default until signing is configured**. Complete this on the native release hosts:

1. Run `dart run auto_updater:generate_keys` on each OS. Back up private signing keys outside git. macOS keeps its EdDSA private key in Keychain; Windows generates `dsa_priv.pem` and `dsa_pub.pem`. These are updater keys, separate from Developer ID/Authenticode certificates.
2. macOS: create ignored `macos/Runner/Configs/Signing.xcconfig` with `SPARKLE_PUBLIC_ED_KEY = <public key>`. The release Info.plist embeds it as `SUPublicEDKey`. Windows: place the generated **public** `dsa_pub.pem` at the repository root; CMake embeds it as the `DSAPub` resource. Retain these public keys across updates.
3. Build with the appropriate platform feed and explicit signing opt-in, for example:

```sh
flutter build macos --release \
  --dart-define=DESKTOP_UPDATE_SIGNING_CONFIGURED=true \
  --dart-define=DESKTOP_UPDATE_FEED_URL=https://github.com/henrylyh3/expense-tracker/releases/latest/download/appcast-macos.xml
```

Use `flutter build windows` and `appcast-windows.xml` on Windows. Never set the signing flag without embedding the real public key. Both constants are build configuration, not private credentials.

4. Sign/notarize/package the final binaries. Run `dart run auto_updater:sign_update <payload>` on the corresponding host. macOS signs the `-macos-update.zip`, Windows signs the final `-windows-x64-setup.exe`. Do not modify a payload after signing.
5. Generate each feed using the signature value from that command:

```sh
python3 tool/desktop_appcast.py macos --signature '<edSignature value>'
python tool/desktop_appcast.py windows --signature '<dsaSignature value>'
```

The script writes versioned appcast files, matching payload URLs, sizes and native versions. It validates signature encoding/length; native updater signature verification is the cryptographic check. Keep both appcasts with the release. Test a signed older install upgrading to the new build on actual macOS and Windows before enabling publication. Verify retained ledger, credentials, skipped/offline updates and tampered-payload rejection.

## Publish the complete release

Collect the signed ARM64 APK, DMG, macOS update ZIP, Windows ZIP and setup EXE under `release/`. Prepare both appcasts when updates are enabled. Then:

```sh
python tool/publish_release.py --prepare
# Commit/push artifacts, generated manifest/checksums and release notes.
python tool/publish_release.py --notes-file docs/releases/v<version>.md
```

Add `--desktop-updates` to both publisher commands when signed native updates are enabled; this also requires both appcasts. The publisher requires every platform binary, generates/checks `SHA256SUMS`, preserves Android's `update.json` contract, uploads appcasts when supplied and verifies every GitHub upload digest before publishing. A missing platform keeps publication blocked. It never overwrites a published version. See [AGENTS.md](../AGENTS.md) for the release contract.

## Verification status for 0.4.7

Both native desktop build jobs passed on GitHub-hosted macOS and Windows using stable Flutter 3.47.9. Their DMG, macOS update ZIP, Windows bundle ZIP and installer are available as validation artifacts in [build run 42628890725](https://github.com/henrylyh3/expense-tracker/actions/runs/42628890725). The downloaded DMG passed `hdiutil verify`; the app identity/version and Windows x64 executable/native bundle contents were checked.

Local analysis is clean. 75 distinct focused Flutter checks (including updater platform selection and startup recovery) and 7 Python release-integrity checks passed. The existing automatic verification workflow also runs its configured suite on pushes; its first run exposed a recovery test regression caused by using the UI platform for updater selection. Update support now follows the real OS, with explicit platform injection in Android updater tests.

These are validation builds, without configured desktop update feeds, Developer ID notarization or Windows Authenticode release signing. Real-device installation, upgrades, picker/Keychain and Discord guest testing remain pending. A complete GitHub Release is blocked by the missing original Android keystore/`android/key.properties` and desktop release-signing setup. Do not replace the Android signing key: existing installations must retain their update path. The public latest release remains v0.4.6.
