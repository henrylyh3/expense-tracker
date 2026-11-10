# Signed builds from GitHub Actions

Run **Actions → Build signed release files → Run workflow** on `main`. Select `android`, `windows`, `macos` or `all`. Android is the default because the existing Android keystore is currently the only available app-signing credential. Keep `check_only` enabled for a configuration-only check; disable it to build. No job publishes a GitHub Release or pushes generated artifacts.

The workflow pins official stable Flutter 3.47.9. It runs focused signing/release tests, analyzes the app and runs linked updater tests before native compilation. The existing desktop validation workflow remains available without private credentials and keeps update feeds disabled.

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

## Windows: additional certificate required

The generated WinSparkle key signs update packages; it is not a trusted Authenticode certificate. This workflow supports an exportable code-signing certificate with its private key in `.pfx` form. If a certificate provider requires hardware/cloud signing, use that provider's integration rather than exporting a non-exportable key; the current workflow does not implement a cloud/HSM signing provider.

Add these repository Variables:

| Variable | Value |
| --- | --- |
| `WINDOWS_UPDATER_PRIVATE_KEY` | Generated local PEM paste file above |
| `WINDOWS_CERTIFICATE_BASE64` | Base64 of the provider-issued signing `.pfx` including its private key |
| `WINDOWS_CERTIFICATE_PASSWORD` | Password protecting that `.pfx` |

The runner imports the certificate temporarily, signs/verifies the native app, creates the complete Windows ZIP and setup EXE, signs/verifies the installer, then signs the final installer for WinSparkle and generates its appcast. It checks private/public updater keys match before building. Cleanup deletes the imported identity/private key and temporary files.

## macOS: Apple credentials required

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

Single-platform jobs upload only that platform's current-version files as `signed-release-android`, `signed-release-windows` or `signed-release-macos`. No private credentials or earlier releases are included.

Choosing `all` requires every platform's credentials. When every job succeeds, the collector prepares Android's manifest and multi-platform checksums and uploads `complete-signed-release`, preserving `android/`, `mac/` and `window/` folders. Extract this bundle into local `release/`, review/test native installations and signed upgrades, commit/push the artifacts and release notes, then use the publisher described in [Desktop releases](DESKTOP.md#publish-the-complete-release). A failed platform blocks complete collection. Individual artifacts are not a complete public release.

Credentials enter workflows through environment variables. Native tool output is captured to avoid logging certificate passwords, and artifact export uses an explicit file list. See [GitHub Actions Variables](https://docs.github.com/en/actions/learn-github-actions/variables), [Sparkle manual code signing](https://sparkle-project.org/documentation/sandboxing/#code-signing) and [Microsoft SignTool](https://learn.microsoft.com/windows/win32/seccrypto/signtool).

Verification limit: credential-free tests and real updater-key compatibility checks can run now. Full Android signing still needs your original keystore Variables; full Windows/macOS signed builds, notarization and installed upgrade tests need their provider/Apple credentials. No new app version is needed for this CI/tooling-only change.

Local validation passed: actionlint workflow/context checks, 34 focused Python checks (12 CI signing + 22 release-tool checks), 22 Flutter updater checks, and clean analysis on official stable Flutter 3.47.9. Real Sparkle 2.9.6 signing/verification, independent Ed25519 verification, CryptoKit public-key derivation and WinSparkle-compatible DSA signing/verification passed for the generated keys. Full certificate-backed signing/notarization has not been run.

GitHub requires a value when creating a repository Variable. At Henry's request, unavailable Android/certificate/notarization values use `-` until replaced. The workflow rejects empty values and `-` before installing credentials or building. Missing-value names are listed locally in `.local/signing/missing-variable-names.txt`.
