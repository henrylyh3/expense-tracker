# Expense Tracker

A Flutter expense ledger with trip profiles, named manual currency rates and MYR accounting. Personal tracking works offline. Optional shared trips use local Wi-Fi or hotspot connections, with the host phone owning the ledger and guests keeping cached views and offline expense queues. No cloud database or exchange-rate API is required.

The current source passes 249 Flutter tests. Android builds and emulator checks are available. Physical two-phone Wi-Fi testing and iOS device validation remain separate checks.

See [Shared trips](docs/SHARING.md) for hosting, invitations, guest sync and data handling. Settings also provides JSON import/export and a confirmed reset to initial defaults.

## Project documentation

- [Project summary and technical decisions](docs/PROJECT_SUMMARY.md): full scope,
  schema, money rules, privacy, backup contract and phase acceptance criteria.
- [Phase 1 setup and final folder structure](docs/PHASE_1_FOUNDATION.md): prerequisites,
  dependency commands/versions, architecture and Drift initialization sequence.
- [Development progress](docs/PROGRESS.md): completed work, verification and blockers.
- [Phase 2 management](docs/PHASE_2_MANAGEMENT.md): repository rules, UI flows,
  tests and files for categories and currencies.
- [Phase 3 transactions](docs/PHASE_3_TRANSACTIONS.md): exact money, saved conversion
  policy, transactional CRUD, history/editor/details and verification scope.
- [Phase 4 reporting](docs/PHASE_4_REPORTS.md): dashboard, exact aggregation, charts,
  periods, history filters, drill-down and verification scope.
- [Phase 5 backup and restore](docs/PHASE_5_BACKUP.md): strict versioned JSON,
  native file workflow, preview, safety copy, atomic replacement and tests.
- [Phase 6 release preparation](docs/PHASE_6_RELEASE.md): real verification, CI,
  migration baseline, signing setup and device acceptance checks.
- [Startup/storage hardening](docs/STARTUP_STORAGE.md): read-only integrity checks,
  private-directory validation and failure preservation tests.
- [Privacy and local data](docs/PRIVACY.md): storage, exports and current privacy behavior.
- [Migration policy](lib/core/database/migrations/README.md): schema snapshots and
  future upgrade rules.

## Development setup

Install the official **stable** Flutter SDK and add its `bin` to PATH. Use Flutter's
bundled Dart. Install Android Studio/SDK for Android; macOS with Xcode is required
for iOS. Let `flutter doctor -v` identify missing platform tooling.

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
dart run build_runner build
bash tool/check_schema.sh
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Development tools/packages require network access initially; personal tracking works offline; shared-trip sync requires reaching the host.
The Android/iOS scaffold already exists. Do not run `flutter create` over it for
normal setup. Android/iOS still use template `com.example` identifiers; choose
permanent identifiers before release. Android release builds require a private
keystore configured using [key.properties.example](android/key.properties.example);
the debug-key fallback has been removed. Do not put real keys/passwords in git.

Declared package versions have now resolved together. The real `pubspec.lock`,
generated `app_database.g.dart`, v1 JSON snapshot and historical test helper are
included. Commit these with the source; no commit/push has been performed here.
Normal checks enforce the lockfile and compare the schema without overwriting
historical files. The local SDK reports `3.48.0-0.5.pre`, so release validation must
still run on official stable Flutter. Native Android SDK/Xcode are unavailable here.

## Architecture

Feature-first MVVM with Riverpod and concrete repositories:

```text
lib/app/                   Material 3 themes and GoRouter navigation
lib/core/database/         Drift connection, SQL schema, defaults and migrations
lib/core/providers/        Database, appearance and transfer lifecycle
lib/core/backup/           Codec, validation, native files and atomic restore
lib/features/              Feature views; repositories/view models added by phase
lib/shared/widgets/        Preserved tab shell and shared presentation
test/                      Domain, real Drift, schema baseline and widget tests
integration_test/          Native storage, transaction and backup-file reopen tests
drift_schemas/             Generated versioned database snapshots
docs/                      Architecture, setup, requirements and progress
tool/                      Full checks, schema comparison and SQLite/config QA
.github/workflows/         Stable Flutter CI verification
```

A widget observes a view model/provider; a repository validates and persists
changes through Drift. Add a DAO when queries become substantial. No generic
repository, backend controllers or extra service layers are needed.

For .NET/NestJS developers: ProviderScope is the DI container; providers construct
and own dependencies; `ref.watch` subscribes the view to state changes. Notifiers
hold view-model state. Drift resembles an EF Core DbContext, with explicit
observable queries through `watch()`. GoRouter preserves each bottom tab's stack.

## Database and money rules

The source schema is [ledger.drift](lib/core/database/tables/ledger.drift). Version 1
contains categories, currencies, transactions and app_settings, plus FK constraints,
indexes and invariant triggers. First creation atomically seeds MYR, ten common
categories and the system appearance default. Existing installations are never
re-seeded or reset after an open/migration error. Startup checks required schema
objects/columns, SQLite integrity, existing references, MYR and theme settings
before showing the ledger. Failed checks preserve the original data.

- Always save original integer minor units **and currency code**.
- Save a precise decimal rate snapshot and the rounded MYR equivalent per entry.
- USD 12.50 at 4.50 MYR/USD stores `1250`, `USD`, `4.5`, `5625`.
- JPY/KRW use zero decimal places. Rate edits affect new transactions only.
- Round conversions half up once to MYR sen; never calculate money with doubles.
- Transaction dates are `YYYY-MM-DD` calendar dates; audit timestamps are UTC
  Unix milliseconds. Archive referenced categories/currencies; never cascade-delete history.
- MYR remains active with precision 2 and rate 1. Used currency codes/precision
  and used category types cannot change.

Category/currency validation and precise rate parsing are implemented in Phase 2.
Exact amount conversion/parsing and transaction CRUD are implemented in Phase 3.
SQL validates stored shape/references and MYR identity conversion; it intentionally
does not perform foreign-currency arithmetic with SQLite floating-point casts.

Settings → Manage Categories supports separate income/expense lists, name/icon/color
editing, an archived filter and restore. Names are case-insensitively unique within
each type, including archived categories. Settings → Manage Currencies supports
custom codes, currency templates (without assumed rates), precision and manual MYR
rates. Delete removes unused rows and archives referenced rows. Used identity/type
restrictions are checked again inside repository transactions, regardless of UI state.

Add Transaction opens a validated editor with a live MYR preview. History shows
original currency amounts and stored MYR equivalents, with detail/edit/confirmed
delete. Ordinary edits preserve the saved conversion; amount edits use the saved
rate, and currency changes require an explicitly confirmed rate. Stale edit/delete
requests are rejected using the revision originally opened by the user.

Home and Reports aggregate saved MYR equivalents using checked BigInt totals.
Reports support monthly/yearly periods, zero-filled trends and category breakdowns.
History supports literal notes/category/currency search and combined date, category,
currency and type filters, including archived references. Chart coordinates use
doubles only for presentation; financial figures and exact chart tables remain exact.

## Verification

Run the repeatable package generation, formatting, analyzer, Flutter test and
SQLite checks with:

```sh
bash tool/check.sh
```

The script enforces the committed lockfile and needs `flutter` and its bundled
`dart` on PATH (or `FLUTTER_BIN` and `DART_BIN` set to their paths), plus Python 3. It stops at the first failed step.
It compares a fresh temporary schema export with the saved version; it never
overwrites historical snapshots or runs device tests.
Optional `--offline` is forwarded to `flutter pub get` for an already cached setup.

Individual checks and device integration:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/foundation_test.dart -d <device-id>
flutter test integration_test/transaction_persistence_test.dart -d <device-id>
flutter test integration_test/backup_round_trip_test.dart -d <device-id>
python3 tool/verify_sqlite_schema.py
dart run tool/emit_test_restore_plan.dart | python3 tool/verify_backup_restore.py
```

The Python command executes the actual SQL schema with real SQLite and needs no
Flutter packages. It is an additional invariant check, not proof of Drift generation
or native builds. Device integration tests reconnect the database; manual force-stop,
airplane-mode, OS-backup and uninstall behavior must also be checked before release.
Run integration tests only on a test installation.

Current checks: **194 real Flutter tests, full analysis, schema comparison and
25 independent SQLite checks pass** through `bash tool/check.sh --offline`.
Tests use the actual declared packages and generated database, including the
export/restore service, historical schema baseline, real chart widget construction
and a real-Drift restore/navigation/theme flow. No diagnostic stubs are used in the
current full-app checks. Earlier isolated results are retained in progress history.

Source configuration, iOS plists/privacy manifest/project syntax and script syntax
also pass. The CI workflow is prepared but has not run remotely. Android/iOS
builds, native document dialogs, share sheets, signing, OS-backup behavior and
physical-device integration are unverified. Current tests ran on the local
prerelease SDK; official stable-SDK validation is a remaining release gate.
See [progress](docs/PROGRESS.md) and [Phase 6](docs/PHASE_6_RELEASE.md).

## Local data and backups

Android stores the ledger under private `noBackupFilesDir`; manifest/XML rules also
exclude automatic cloud backup and device transfer. iOS uses private Application
Support with backup exclusion and file protection. Native configuration still needs
physical-device validation. Release requests INTERNET for encrypted local peer sharing. Broad storage permissions remain excluded.

SQLite is not separately encrypted; protection relies on the OS sandbox and device
security. Settings → Backup and restore can save/share versioned JSON, validate and
preview an imported file, then replace the entire ledger in one SQLite transaction.
A safety backup is selected by default; cancellation/failure cancels replacement.
Version 1 has no merge. Imported historical rates and original currency amounts
are preserved. Restoring also applies the saved appearance preference.

Backups are **unencrypted readable financial data**. Native file/share destinations
can be cloud-backed if you choose them. Share files remain temporarily in OS cache
for recipient access; a subsequent share removes owned files older than 24 hours.
Without manual backups, uninstalling or losing the device can lose the ledger.
Supported backup limits are 25 MiB and 100,000 rows per table. See the
[format and restore contract](docs/PHASE_5_BACKUP.md) for details.

Next: complete [release acceptance](docs/PHASE_6_RELEASE.md) on official stable
Flutter with Android SDK/Xcode and test devices. Choose final application IDs,
branding/icons and signing before distribution. Keep backup/About app-version
metadata aligned with pubspec; source checks enforce the default, and release
commands can pass `--dart-define=APP_VERSION=<version+build>`.
