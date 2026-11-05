# Phase 1 — technical setup and initialization plan

Current verification is recorded in [Phase 6](PHASE_6_RELEASE.md). Dependencies,
real Drift generation and the full Flutter suite now pass; the verification
notes below retain the results available when this phase was implemented.

Prepared before implementing foundation source files. Requirements/decisions: [project summary](PROJECT_SUMMARY.md). Verified state: [progress](PROGRESS.md).

## Prerequisites

Install an official **stable** Flutter SDK and add its `bin` to PATH. Use its bundled Dart, not a separate Homebrew Dart. Run `flutter --version` and `flutter doctor -v`. Android development needs Android SDK/emulator, JDK and accepted licenses (`flutter doctor --android-licenses`). iOS development needs macOS, Xcode/command-line tools, simulator and the native dependency tooling requested by `flutter doctor`. Store signing is deferred to Phase 6.

The available local SDK currently reports `3.48.0-0.5.pre` despite a stable label; it is a prerelease and is not an approved release baseline. Dependency declarations are based on stable pub.dev releases checked on 2026-11-05. Compatibility is only established after `flutter pub get`, analysis, tests and platform builds succeed. Retain the resolved app lockfile once resolution succeeds. Development needs network access to obtain tools/packages; the installed app does not.

## Commands

For an empty repository, before custom source files exist:

```sh
flutter create --platforms=android,ios --org com.example --project-name expense_tracker .
flutter pub add flutter_riverpod go_router drift drift_flutter path_provider path
flutter pub add decimal intl uuid fl_chart file_picker share_plus
flutter pub add --dev drift_dev build_runner flutter_lints
```

`com.example.expense_tracker` is a development-only identifier; choose a permanent reverse-domain identifier before signing/distribution. The repository will contain the native scaffold, so do not re-run creation over implemented files during normal development.

After cloning / when packages are available:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart format lib test integration_test
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

Add future integration_test tests via the Flutter SDK (no separately versioned package). Introduce feature packages in their implementation phase if dependency resolution/platform minimums need to be managed separately.

## Target structure

Only create implementation directories when there is code for them; this tree describes the final architecture, not completed functionality.

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    database/
      app_database.dart
      database_connection.dart
      seed_data.dart
      tables/ledger.drift
      daos/                         # add as queries grow
      migrations/README.md
    money/
      money.dart                    # Phase 3
      currency_converter.dart       # Phase 3
      currency_catalog.dart         # Phase 2
    backup/
      backup_service.dart           # Phase 5
      backup_validator.dart         # Phase 5
    providers/database_providers.dart
  features/
    dashboard/presentation/dashboard_screen.dart
    transactions/
      data/transaction_repository.dart
      domain/transaction_input.dart
      presentation/transaction_editor_screen.dart
      presentation/transactions_screen.dart
      presentation/transaction_view_model.dart
    categories/{data,domain,presentation}/
    currencies/{data,domain,presentation}/
    reports/presentation/reports_screen.dart
    settings/presentation/settings_screen.dart
  shared/widgets/
    app_shell.dart
    feature_placeholder.dart
test/
  core/database/
  core/money/
  features/
  app/
integration_test/
drift_schemas/
docs/
android/
ios/
```

Use domain objects where they protect business rules; don't duplicate every Drift row with an identical domain class. Feature repositories may be concrete and replaceable through Riverpod provider overrides. A repository should not need a DAO and a generic service layer simply to insert a row.

## Dependency baseline

| Package | Stable declaration | Purpose |
| --- | --- | --- |
| flutter_riverpod | ^3.4.3 | DI, lifecycle, reactive view state |
| go_router | ^18.1.3 | Navigation and preserved tab stacks |
| drift | ^2.35.3 | Typed SQLite queries, streams, transactions |
| drift_flutter | ^0.3.1 | Native background connection |
| path_provider | ^2.1.6 | Backup/temp directories in Phase 5 |
| path | ^1.9.1 | Platform-safe paths |
| decimal | ^3.2.6 | Exact money/rate arithmetic |
| intl | ^0.20.3 | Locale-aware display |
| uuid | ^4.6.0 | Local IDs |
| fl_chart | ^1.3.0 | Phase 4 charts |
| file_picker | ^13.3.2 | Phase 5 native import/export |
| share_plus | ^13.3.1 | Phase 5 native sharing |
| drift_dev | ^2.35.2 | Database generator/schema tooling |
| build_runner | ^2.17.1 | Code generation |
| flutter_lints | ^6.0.0 | Analyzer rules |

## SQLite / Drift initialization sequence

1. Initialize Flutter bindings; create ProviderScope. Open no file synchronously in a widget's build.
2. A root-scoped provider owns one AppDatabase and closes it on disposal. An injectable executor allows real in-memory SQLite tests without path-provider plugins.
3. Resolve private ledger storage through a platform channel: Android `noBackupFilesDir/ledger`; iOS Application Support/ledger with backup exclusion and file protection. Configure protection before SQLite creates files. drift_flutter opens it on a background isolate.
4. Enable foreign keys on every open; do not depend on SQLite defaults. Schema version starts at 1.
5. Drift creates tables, indexes and triggers from the SQL schema inside an explicit creation transaction. Seed fixed MYR, stable common category IDs and default settings in that transaction only. Never re-seed at every launch or after user edits/restores.
6. Warm up through a provider watched by an app-level loading/error gate; errors show a safe retry and never delete/reset the file. Disable automatic retry; manual retry shows loading until opening finishes. No raw financial values appear in error logs.
7. Use reactive queries for later feature lists. Transaction snapshots are denormalized deliberately; current defaults and historical conversion facts have different lifetimes.
8. Export and commit the v1 schema after generation. For v2+, bump schemaVersion, write an explicit migration, snapshot it and test upgrades including skipped releases. Unknown migrations must fail safely, not recreate the ledger.

## Verification targets

Database creation/seeding; FK/trigger enforcement; MYR invariants; rate/date constraints; archive/reference rules; rollback; reopen without re-seeding; physical-file persistence. App tests cover tabs, Add action and safe startup failure/retry. Device checks cover private paths, native configuration and airplane-mode startup. No financial dashboard data or transaction form is claimed complete in Phase 1.

## Primary references

- [Flutter setup](https://docs.flutter.dev/install) and [SDK archive](https://docs.flutter.dev/install/archive)
- [Drift setup](https://drift.simonbinder.eu/setup/), [schema snapshots](https://drift.simonbinder.eu/migrations/exports/) and [migration tests](https://drift.simonbinder.eu/migrations/tests/)
- [Riverpod](https://riverpod.dev/) and [GoRouter](https://pub.dev/packages/go_router)
- [Android automatic backup](https://developer.android.com/identity/data/autobackup)
- [Apple backup exclusion](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup)
