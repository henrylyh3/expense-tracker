# Android app updates

The Android app checks the public GitHub latest-release API once after successful ledger startup on each cold app launch. A newer ARM64 build prompts with **Update now** and **Later**. Checks are skipped on other platforms, during ledger recovery, and if the user has navigated away from Home while the request was running. Offline, invalid or rate-limited responses do not block the app or show repeated errors. Choosing Later defers until the next cold launch.

Update now downloads the APK with progress and cancellation. The app accepts only HTTPS GitHub release endpoints and their known asset hosts. It bounds metadata and APK size, cross-checks the manifest against the GitHub asset digest/size, and verifies the downloaded checksum. Android also checks the actual package ID, strictly newer version code, existing signing certificate and ARM64 libraries before the installer can open. Installation is always initiated by the user; it is not a silent background update.

Android may require **Allow from this source** for Expense Tracker. Return to the app after enabling it; the verified update then opens in Android's package installer. Confirm Update. If installation was cancelled, the prompt can reopen the installer. Failed or cancelled downloads are removed, and downloaded APKs are stored only in the app's temporary cache. Reset/import of ledger data is not part of updating.

## Publishing each release

Follow AGENTS.md: bump pubspec and app_info, analyze/test, build and verify a signed ARM64 APK using the existing private key, then copy it to release/. The ARM64 split adds 2000 to the pubspec build number; the updater compares actual Android version codes.

1. Run `python tool/publish_release.py --prepare` after copying the APK. This creates `release/update-<version>.json` containing its size, checksum, package, ABI and build/version.
2. Write actual release notes at `docs/releases/v<version>.md`.
3. Commit source, notes, APK and manifest together, push origin/main and verify the remote commit.
4. Run `python tool/publish_release.py --notes-file docs/releases/v<version>.md`.
5. Confirm the public latest-release API points at that version and both assets match their checksums.

The publisher uses the existing Git Credential Manager credential only on the developer's machine. It creates a draft, uploads the APK and update.json, checks GitHub's uploaded digests, then publishes the completed release as latest. Interrupted drafts can be retried; published versions cannot be overwritten by this tool. The current repository is public, so phones do not need a GitHub account or token. The APK contains no publishing credential or signing key.

The first version containing this feature must be installed manually. iOS needs a separate Apple signing/distribution route such as TestFlight or registered-device Ad Hoc distribution; this updater installs Android APKs only.
