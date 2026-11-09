# Android app updates

The Android app checks the public GitHub latest-release API after successful ledger startup and when returning to the foreground after at least five minutes. A newer ARM64 build prompts with **Update now** and **Later**. Checks are skipped on other platforms and during ledger recovery. An available update stays pending while you are away from Home and is offered when you return. Choosing Later defers that version for the current app session.

Metadata and initial APK requests use fresh query URLs and no-cache headers to avoid stale GitHub redirects or cached failures. Signed redirect URLs are preserved unchanged. Temporary check failures are retried once, and simultaneous checks share one request. Offline failures never block the ledger. In Settings, the update button next to Current version provides an explicit check, shows whether you are up to date, and offers Retry on failure. No GitHub account or phone setup is required.

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


## Desktop extension

macOS and Windows now have opt-in native updater integration. Their signed appcasts and payloads are separate from Android's `update.json`. See [Desktop setup and releases](DESKTOP.md) for native build, signing, DMG/Windows bundle packaging and update-feed configuration. The publisher now requires artifacts for all three release platforms; this page's earlier APK-only instructions describe the Android part of that workflow.
