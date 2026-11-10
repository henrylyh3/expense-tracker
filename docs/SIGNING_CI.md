# Signed builds from GitHub Actions

Every push to `release` or `release/**` automatically builds Android, Windows and macOS and collects the complete release files when all three succeed. For example, commits pushed to `release/0.4.9` or `release/android/fix` trigger the workflow. The branch must contain this workflow file. Pushes to `main`, unrelated branches and tags do not trigger this signed workflow.

Manual runs remain available through **Actions → Build release files with signed updates → Run workflow** on `main` or a release branch. Select `android`, `windows`, `macos` or `all`; Android is the manual default. Enable `check_only` for a configuration-only check, or disable it to build. Automatic pushes always select all three platforms. No job publishes a GitHub Release or pushes generated artifacts. Missing values required by the selected mode stop its platform checks before building.

The workflow pins official stable Flutter 3.47.9. It runs focused signing/release tests, analyzes the app and runs linked updater tests before native compilation. The existing desktop validation workflow remains available without private credentials and keeps update feeds disabled.

## Version numbers

Versions do not automatically increase. Both manual and automatic runs use the committed `pubspec.yaml` version and matching `lib/core/app_info.dart` value. The current app version is `0.4.10+19`: `0.4.10` is the visible release version, and `19` is the native build number (Android ARM64's actual version code is `2019`). A branch name does not override these values.

For the next release, update both files to `0.4.11+20`, commit and push to a release branch. Unpublished commits on that branch can rebuild the same version; once a version is publicly released, the workflow refuses to rebuild it until you increase the version. The workflow does not commit version bumps or derive versions from Actions run numbers.

## Personal-use mode (default)

Manual runs default to `desktop_signing: personal`; release-branch pushes also use personal mode. Android retains its original APK signing key. Desktop publisher certificates and macOS notarization are skipped: macOS keeps Flutter's ad-hoc app signature, and Windows has no Authenticode publisher signature. Installation warnings may appear. Sparkle and WinSparkle payload signatures remain required and verified against the embedded updater public keys.

Personal mode needs only the four Android variables and the existing Sparkle/WinSparkle key pairs. The eight desktop certificate/notarization variables may remain `-`. Select `trusted` manually in future to require all publisher certificates and notarization again. Unknown mode names fail rather than silently disabling signing.

Artifacts are named `personal-release-<platform>` / `complete-personal-release` and include `PERSONAL-USE.txt`. Trusted mode uses `trusted-release-<platform>` / `complete-trusted-release`. No mode automatically publishes a GitHub Release. This repository is public: Actions artifacts are not a private distribution channel. Use a private repository or local builds if build access must be restricted.

The generated appcasts still target the existing GitHub Releases HTTPS URLs. Preparing/signing them does not publish a feed or make private-repository assets anonymously accessible. Do not embed GitHub credentials in the app. Personal installs can be updated manually until an accessible update feed is deliberately published/configured.

## Actions Variables configuration

This workflow reads all signing values from repository Actions Variables, as explicitly requested. Variables are readable as plaintext in repository settings. Credential values are masked explicitly in workflow logs; their storage remains Variables. No signing Secrets are used.

## Local generated keys

New desktop updater key pairs were generated under ignored `.local/signing/`. Private files have owner-only permissions on this Mac. Keep a separate secure backup: subsequent releases must retain these keys.

| GitHub Actions Variable | Local file to paste verbatim |
| --- | --- |
| `MACOS_SPARKLE_PRIVATE_KEY` | `.local/signing/github-variables/MACOS_SPARKLE_PRIVATE_KEY.txt` |
| `WINDOWS_UPDATER_PRIVATE_KEY` | `.local/signing/github-variables/WINDOWS_UPDATER_PRIVATE_KEY.txt` |

The Sparkle file is already Base64; do not encode it again. The Windows file is raw PEM; paste the whole file, including its header/footer. Additional local copies are in `.local/signing/macos/` and `.local/signing/windows/`. Generated updater keys were checked with real native Sparkle signing/verification and WinSparkle-compatible OpenSSL DSA signing/verification.

Public configuration uses these repository Actions Variables:

| Variable | Value source |
| --- | --- |
| `MACOS_SPARKLE_PUBLIC_KEY` | `.local/signing/macos/sparkle-public-key.txt` |
| `WINDOWS_UPDATER_PUBLIC_KEY` | `.local/signing/windows/dsa_pub.pem` |
| `WINDOWS_TIMESTAMP_URL` | `http://timestamp.digicert.com` |

All three public values also appear in ignored `.local/signing/github-variables.json`. Public key copies in ignored `dsa_pub.pem` and `macos/Runner/Configs/Signing.xcconfig` support local configuration. The private files will not appear when cloning/pulling this repository on another laptop.

## Android: usable after entering the existing credentials

On your Windows laptop, from the repository, run:

```powershell
python tool/prepare_android_secret.py
```

Enter the path to your **original** `.jks`/`.keystore` when prompted. It creates ignored `.local/signing/github-variables/ANDROID_KEYSTORE_BASE64.txt` without printing its contents or changing the original key. Existing output files are never overwritten.

Open [repository Actions Variables](https://github.com/henrylyh3/expense-tracker/settings/variables/actions), choose **New repository variable**, and add:

| Variable | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Entire generated Base64 text file |
| `ANDROID_STORE_PASSWORD` | Existing `storePassword` from your original `android/key.properties` |
| `ANDROID_KEY_ALIAS` | Existing `keyAlias` |
| `ANDROID_KEY_PASSWORD` | Existing `keyPassword` |

Never generate a replacement Android key for existing installations. The runner restores the keystore into its temporary directory and creates ignored `android/key.properties`. The APK stage verifies ARM64, package/version/build and continuity with the latest previous local APK certificate. A wrong key blocks artifact creation.

## Windows: additional certificate required only in trusted mode

The generated WinSparkle key signs update packages; it is not a trusted Authenticode certificate. This workflow supports an exportable code-signing certificate with its private key in `.pfx` form. If a certificate provider requires hardware/cloud signing, use that provider's integration rather than exporting a non-exportable key; the current workflow does not implement a cloud/HSM signing provider.

Add these repository Variables:

| Variable | Value |
| --- | --- |
| `WINDOWS_UPDATER_PRIVATE_KEY` | Generated local PEM paste file above |
| `WINDOWS_CERTIFICATE_BASE64` | Base64 of the provider-issued signing `.pfx` including its private key |
| `WINDOWS_CERTIFICATE_PASSWORD` | Password protecting that `.pfx` |

The runner imports the certificate temporarily, signs/verifies the native app, creates the complete Windows ZIP and setup EXE, signs/verifies the installer, then signs the final installer for WinSparkle and generates its appcast. It checks private/public updater keys match before building. Cleanup deletes the imported identity/private key and temporary files.

## macOS: Apple credentials required only in trusted mode

The generated Sparkle key cannot replace an Apple Developer ID certificate. Export **Developer ID Application** with its private key as password-protected `.p12` from your Apple Developer setup. Obtain an App Store Connect API key allowed to submit notarization requests.

| Repository Variable | Value |
| --- | --- |
| `MACOS_SPARKLE_PRIVATE_KEY` | Generated local Base64 paste file above |
| `MACOS_CERTIFICATE_BASE64` | Base64 of your Developer ID `.p12`, including its private key |
| `MACOS_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `MACOS_NOTARY_KEY_BASE64` | Base64 of the Apple API `.p8` private-key file |

Add these non-secret values under [Actions Variables](https://github.com/henrylyh3/expense-tracker/settings/variables/actions):

| Variable | Value |
| --- | --- |
| `MACOS_CODESIGN_IDENTITY` | Full certificate identity beginning `Developer ID Application:` |
| `MACOS_NOTARY_KEY_ID` | Apple API key ID |
| `MACOS_NOTARY_ISSUER_ID` | Apple API issuer UUID |

The macOS runner checks the updater key pair, imports Developer ID into a temporary keychain, signs nested native code from the inside out while preserving helper entitlements, signs/notarizes/staples the app, packages it, then signs/notarizes/staples the DMG. Only then does it sign the final update ZIP and generate the appcast. The Sparkle private key is passed by file path, not as a command-line value. Cleanup deletes the temporary keychain and credential files.

## Download and finish a release

Single-platform jobs upload only that platform's current-version files under the selected mode’s `personal-release-*` or `trusted-release-*` artifact names. No private credentials or earlier releases are included.

Choosing `all` requires the credentials needed by every platform in the selected mode. When every job succeeds, the collector prepares Android's manifest and multi-platform checksums and uploads `complete-personal-release` or `complete-trusted-release`, preserving `android/`, `mac/` and `window/` folders. Extract this bundle into local `release/` and review/test native installations. Personal mode is for personal use; no public release is published. Trusted public releases additionally follow the publisher instructions in [Desktop releases](DESKTOP.md#publish-the-complete-release). A failed platform blocks complete collection. Individual artifacts are not a complete public release.

Automatic release-branch builds use the same complete collection. Merge the completed release source/artifacts into `main` before publishing; the publisher still requires the committed release to match `origin/main`.

Credentials enter workflows through environment variables. Native tool output is captured to avoid logging certificate passwords, and artifact export uses an explicit file list. See [GitHub Actions Variables](https://docs.github.com/en/actions/learn-github-actions/variables), [Sparkle manual code signing](https://sparkle-project.org/documentation/sandboxing/#code-signing) and [Microsoft SignTool](https://learn.microsoft.com/windows/win32/seccrypto/signtool).

Verification limit: credential-free tests and real updater-key compatibility checks can run now. Android signing uses your original keystore Variables. Trusted Windows/macOS publisher signing and notarization still need provider/Apple credentials; personal mode does not require them. No new app version is needed for this CI/tooling-only change.

Local validation passed: actionlint workflow/context checks, 37 focused Python checks (15 CI signing + 22 release-tool checks), 22 Flutter updater checks, and clean analysis on official stable Flutter 3.47.9. Real Sparkle 2.9.6 signing/verification, independent Ed25519 verification, CryptoKit public-key derivation and WinSparkle-compatible DSA signing/verification passed for the generated keys. Full certificate-backed signing/notarization has not been run.

GitHub requires a value when creating a repository Variable. At Henry's request, unavailable Android/certificate/notarization values use `-` until replaced. The workflow rejects empty values and `-` before installing credentials or building. Missing-value names are listed locally in `.local/signing/missing-variable-names.txt`.

Personal-mode update: 46 focused signing/release-tool tests and actionlint passed. The Android certificate parser now recognizes both numbered and SDK-range signer labels emitted by apksigner, excludes source-stamp identities and preserves exact signer-set/version-code continuity checks. No app source/version change is needed for this CI/tooling update.
