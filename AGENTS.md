# Testing policy

- Run only tests for the new or changed feature and tests for directly linked behavior that the change can affect.
- Add focused test cases when needed. Keep tests modular so related checks can run independently.
- Do not run the full test suite unless the user explicitly asks. Leave unrelated tests untouched.
- Run `flutter analyze` for code changes. Complete selected tests before starting native builds.
- Documentation-only changes do not require tests, a version bump, or new release artifacts.

# Product constraints

- Reuse the existing layout on Android, iOS, macOS and Windows.
- The desktop app owns its local SQLite ledger. Existing Discord invitations allow Android guests to submit expenses; do not introduce another backend or LAN server for this workflow.
- Sync only while the app is open/foreground, with visible progress. No background service or startup daemon.
- Desktop ledger files belong in OS application data, outside the installed app. Keep existing protected credential storage.

# Release workflow

For each completed app change:

1. Increase version/build in `pubspec.yaml` and match `lib/core/app_info.dart`. Preserve Android package ID/keystore, macOS bundle ID, Windows installer AppId, application-data paths and updater signing keys so updates retain existing data.
2. Run `flutter analyze` and focused tests before building. Use an official stable Flutter SDK for release verification. Do not run the full suite unless requested.
3. Build **all three release platforms** on appropriate hosts:
   - Android: `flutter build apk --release --target-platform android-arm64 --split-per-abi`. Verify release signature, package ID, increasing version code and architecture. Copy to `release/expense-tracker-<version>-arm64-release.apk`.
   - macOS on macOS with full Xcode: `flutter build macos --release`, then `python3 tool/package_desktop.py macos`. Deliver `release/expense-tracker-<version>-macos.dmg` and the companion `-macos-update.zip` for Sparkle. Sign/notarize before packaging public releases; verify the resulting app and DMG.
   - Windows on Windows with Visual Studio C++ tooling: `flutter build windows --release`, then `python tool/package_desktop.py windows` with Inno Setup on PATH (or `--iscc <path>`). Deliver the **complete** `release/expense-tracker-<version>-windows-x64.zip` bundle and companion `-windows-x64-setup.exe` for WinSparkle. Never ship the EXE alone. Verify the installer and installed app.
4. Configure signed desktop updates as described in `docs/DESKTOP.md`. Embed public keys, sign the final macOS update ZIP and Windows setup EXE, and create platform appcasts. Never publish unsigned update feeds or fabricate signatures. Build with the platform HTTPS feed and signing opt-in only when public keys are embedded. Updates must prompt before installation/restart.
5. Run `python tool/publish_release.py --prepare` after collecting all artifacts; add `--desktop-updates` when signed native updates are enabled (also when publishing). It creates Android's manifest and SHA256SUMS for every platform and requires all platform files. Write `docs/releases/v<version>.md`. Preserve earlier releases. Keep signing keys, Android `key.properties`, credentials and private certificates out of git/artifacts/logs.
6. Commit changes, artifacts, manifests and release notes together. Push and verify the remote branch. Report paths, commit, focused test results and native verification.
7. Run `python tool/publish_release.py --notes-file docs/releases/v<version>.md` to publish all platform files and configured appcasts to GitHub Releases. Verify the latest release, download names and checksums. Never overwrite a published version or embed GitHub credentials.
8. If any native toolchain, signing identity or required artifact is unavailable, finish source changes and available checks, then report the exact blocker. Do not publish a partial release as complete or claim a build/device test succeeded. Native build automation is available in `.github/workflows/desktop-build.yml`; artifacts from that workflow still require release signing/validation.
