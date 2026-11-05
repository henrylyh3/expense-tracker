# Phase 6 — Testing and release preparation

Host verification and release-preparation source are implemented. This is not yet
a signed, device-verified release. Android SDK/Xcode, signing, final identifiers,
branding, physical-device QA and an official stable-SDK run remain required.

## What changed

- Resolved the declared dependencies together and generated pubspec.lock.
- Generated the real Drift database, exported drift_schema_v1.json and generated
  the historical v1 test helper. Drift required quoting the SQL identifiers
  `"replace"` (a function name) and `"key"`; SQLite behavior is unchanged. This is
  the initial v1 baseline, not an invented v1-to-v2 migration.
- Ran actual analysis and Flutter tests using real Drift, GoRouter, file_picker
  and fl_chart packages. Earlier diagnostic-package stubs are no longer the
  current verification baseline.
- Fixed two widget tests that tapped before scroll layout settled. Dropdown
  tests target the control itself. Missed taps now fail all widget tests.
- Added schema tests: fresh database vs exported v1, data-preserving opening of
  historical v1 without reseeding, and safe rejection of a synthetic future file.
- Added a full app/real-Drift restore widget test: safety save, navigation lock,
  committed data, Home reset, filter reset and restored appearance. Only the
  native file boundary is replaced by an in-memory test adapter.
- Added an isolated native backup-file/reopen integration test. It uses a
  synthetic database in OS cache, never the user's normal ledger.
- Android release builds use a configured private release keystore. The template
  debug-key fallback was removed; missing signing configuration fails release
  pre-build. Debug development remains available.
- Added an app-owned iOS privacy manifest for private/container file metadata and
  metadata of explicitly selected documents. It is included in Runner resources.
- Added Settings → About and open-source licenses.
- Added repeatable schema comparison, source privacy/version checks and a CI
  workflow. CI actions are pinned to specific release commits; CI uses a stable
  Flutter release and installs dependencies from the lockfile.

## Verification

The complete tool/check.sh pipeline passes locally:

| Check | Result |
| --- | --- |
| Declared dependency resolution and lockfile enforcement | Passed |
| Real build_runner/Drift generation | Passed, no parser warnings |
| Dart formatting | Passed |
| Full flutter analyze | Passed, no issues |
| Full flutter test | 194 passed |
| Exported v1 schema comparison | Passed; historical snapshot not overwritten |
| Existing SQLite schema tests | 20 passed |
| Production Dart restore-plan SQLite checks | 5 passed |
| Source version/permission/backup/privacy checks | Passed |
| iOS plist/privacy manifest/project syntax | plutil passed |
| GitHub workflow execution | Prepared, not run remotely |
| Android/iOS builds and device integration | Not run; native tooling unavailable |

The local SDK reports **3.48.0-0.5.pre**, Dart 3.13.3, despite a stable channel
label. Host results are real, but official stable Flutter still needs validation.
Xcode is not installed (only Command Line Tools); no Android SDK is configured.
No signing keys were created, no real ledger was restored, and nothing was
published. The former package/socket restrictions cleared during this phase;
prior phase notes retain the historical verification results.

## Startup/storage follow-up

Read-only startup integrity/schema checks, strict private-directory responses and
21 additional regression tests are implemented. See [STARTUP_STORAGE.md](STARTUP_STORAGE.md)
for scope, file paths and limits. Failed startup preserves original data; automatic
repair or restoration into an unreadable database is not implemented. Schema
version remains 1.

## Commands

Use official stable Flutter (Dart >=3.12, Flutter >=3.44) with Android SDK and/or
macOS/Xcode. The app remains offline; setup/build tools download dependencies.

```sh
flutter doctor -v
bash tool/check.sh
# Optional, after dependencies are cached:
bash tool/check.sh --offline

# Compare current schema without rewriting historical snapshots:
bash tool/check_schema.sh

# Only after intentionally adding a NEW schema version/migration:
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

CI runs the same checks and rejects uncommitted changes in the generated
AppDatabase, migration helper or lockfile. Commit the source, workflow, generated
files, lockfile and initial schema together. This phase does not create a commit
or push it. Retain every released schema; never edit a historical snapshot to
silence a failed comparison. There is no historical upgrade path before v1.

Run native tests on a **test installation**, never a personal production ledger:

```sh
flutter devices
flutter test integration_test/foundation_test.dart -d <device-id>
flutter test integration_test/transaction_persistence_test.dart -d <device-id>
flutter test integration_test/backup_round_trip_test.dart -d <device-id>
```

The new backup integration test exercises native temporary storage, file
write/read, safety export, exact snapshots, SQLite reopen and MYR reporting.
Native document-picker/share-sheet interactions still require manual device QA.

## Android release setup

1. Choose a permanent applicationId and namespace; replace com.example values
   and align the Kotlin MainActivity package/path. Changing a shipped identity
   creates a different app/data sandbox.
2. Generate your private upload keystore using the Flutter Android deployment
   guide. Keep a separate recoverable copy of the key and credentials. No
   credentials are included in this repository.
3. Copy android/key.properties.example to android/key.properties and replace all
   placeholders. storeFile is absolute or relative to android/app. Both the
   configuration file and keystores are gitignored.
4. Keep pubspec version and core/app_info.dart's default aligned. Source checks
   enforce this; a build-time APP_VERSION override must describe the same build.
5. After QA and stable-SDK checks, build the AAB/APK:

```sh
flutter build appbundle --release --dart-define=APP_VERSION=0.1.0+1
flutter build apk --release --dart-define=APP_VERSION=0.1.0+1
```

Gradle preReleaseBuild validates the private keystore configuration and existence.
AGP validates its passwords/alias. This wiring has not been built here. Verify
release certificates, merged manifest permissions, backup/transfer rules, native
SQLite libraries for each ABI and the installed release's offline behavior.
Debug/profile network permission is development-only. Do not publish the
com.example identifier, Flutter template icon or debug-signed artifacts.

Flutter restores its ignored Gradle wrapper when building. Native dependency
resolution and Gradle/Android SDK downloads are build-time requirements.

## iOS release setup

Open ios/Runner.xcworkspace in Xcode, choose the permanent Bundle Identifier,
select your Developer team and review signing. The current project uses Flutter's
Swift Package Manager integration; native plugins are wired by the build. The
minimum deployment target is 15.0. Verify actual plugin/package build support.

```sh
# Compile check without signing, on a Mac with full Xcode:
flutter build ios --release --no-codesign --dart-define=APP_VERSION=0.1.0+1
# After configuring identity/signing and completing QA:
flutter build ipa --release --dart-define=APP_VERSION=0.1.0+1
```

Inspect the archived application's aggregated privacy report, including framework
and plugin manifests, and reconcile it with current code and store disclosures.
Runner's own manifest declares no tracking/data collection. File-metadata reasons
C617.1 and 3B52.1 cover internal cache/ledger metadata and explicitly selected
backup documents. These declarations do not replace archive/device verification.
Do not add arbitrary network entitlements or broad storage access for backup.

## Device acceptance still required

| Area | Scenarios | Acceptance |
| --- | --- | --- |
| Offline/restart | Airplane mode, force stop/reopen, cold start, locked-device resume | Ledger persists; no login/network dependency; storage failures never reset data |
| Money/CRUD | MYR/USD/JPY/KRW, half-sen ties, amount/rate/currency edits | Originals and rate snapshots remain exact; explicit conversion changes required |
| Archive/filters | Referenced parents, archived history, combined search/date/type/currency filters | History remains accessible; active choices are enforced |
| Reports | Empty/month/year/leap-year/large totals, saved-rate histories | MYR totals agree with exact tables; labels remain accessible |
| Backup | Local save/share/pick, cancel/error/cloud-provider offline, low storage, 25 MiB limit | Clear result; no writes during preview; no false durable-share guarantee |
| Restore | Empty/populated/archived data, safety-save cancel/fail, invalid format/references | Full commit or original ledger; MYR/rates/settings preserved |
| Interruption | Kill process during replacement and reopen | SQLite recovery yields the committed old or new ledger; never partial rows |
| Presentation | Small Android/iPhone, iPad popover, landscape, keyboard, text scaling 200%, TalkBack/VoiceOver | Scrollable editors; readable exact figures; working labeled controls |
| Privacy | OS cloud backup/device transfer exclusion, iOS file protection, cache cleanup | Actual device behavior matches documented settings |
| Distribution | Release install/update, identities, icons, signing, licenses/store disclosures | Stable identity, valid signing and truthful privacy information |

Provide a publisher/contact and hosted policy URL if distributing through a store;
[PRIVACY.md](PRIVACY.md) documents current behavior for that policy. Select final
branding/icons/screenshots and verify notices from included dependencies. Recheck
store submission requirements at release time; they can change.

## Primary references

- [Flutter Android deployment](https://docs.flutter.dev/deployment/android)
- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [Drift schema exports](https://drift.simonbinder.eu/migrations/exports/)
- [Drift migration tests](https://drift.simonbinder.eu/migrations/tests/)
- [Apple required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
