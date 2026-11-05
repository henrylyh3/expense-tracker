# Phase 5 — Backup and restore

Current verification is recorded in [Phase 6](PHASE_6_RELEASE.md). Dependencies,
real Drift generation and the full Flutter suite now pass; the verification
notes below retain the results available when this phase was implemented.

Source implemented. Pure Dart and SQLite checks pass; full Drift generation,
Flutter execution and Android/iOS file-dialog verification remain pending.

## User workflow

Settings → Backup and restore provides **Save backup**, **Share backup** and
**Choose backup**. Export includes every category/currency (including archived
rows), transactions with their original currency and saved conversion, and settings.
Files contain readable financial data; the screen explains this before export.
Native destinations can be local or user-selected external/cloud providers.
The app itself has no network dependency or automatic synchronization.

Choosing a file performs bounded streaming, UTF-8/JSON validation and domain
integrity checks in a worker isolate. It makes no ledger changes. Preview shows
export timestamp, app/format version, record counts and transaction date bounds.
The selected, immutable validated data is retained; restore does not reread a
potentially changed external file.

Restore displays a **Replace All** warning and requires acknowledgment. A safety
backup is selected by default. Changing that choice resets acknowledgment.
When selected, restore takes the latest committed ledger snapshot and opens a
native Save dialog. Cancellation or an error aborts replacement. Sharing is not
used for this safety copy: a share result cannot establish that a usable file was
saved. The user can explicitly choose replacement without a safety copy.

During file operations, the app blocks taps, tab navigation, Add Transaction and
back navigation from the backup screen. Restore success returns Home, discards
open forms/search/period selection and refreshes streams. Appearance is persisted
in app_settings and restored to System, Light or Dark. Failure retains the ledger
and displays a safe error; it never resets the database.

## Version 1 contract

| Field | Representation |
| --- | --- |
| format | `expense-tracker` |
| format_version / schema_version | JSON integer `1` / `1`; separately versioned |
| app_version | Informational string, default `0.1.0+1` |
| exported_at_utc | Canonical UTC ISO-8601 with fractional seconds, e.g. `2026-11-05T10:00:00.000Z` |
| base_currency | `MYR` |
| counts | Exact category/currency/transaction/settings row counts |
| data | `categories`, `currencies`, `transactions`, `settings` arrays |
| Monetary minor units, audit epoch milliseconds, sort_order | Canonical unsigned decimal **strings**, including `9223372036854775807` without JSON double coercion |
| Rates | Precise decimal strings; historical spelling such as `4.5000` preserved |
| decimal_places | JSON integer 0–6 |
| Archive/active flags | JSON booleans |
| Notes | String or null; Unicode/newlines supported, NUL rejected |
| Settings | Required unique `theme_mode`: `system`, `light` or `dark` |

Rows use database column names, except the settings array maps to app_settings.
See [the complete synthetic fixture](../test/support/backup_fixture.dart) for the
full envelope and row fields. No live user data is included in fixtures.

Limits: 25 MiB encoded UTF-8, 100,000 rows per table, 16 JSON nesting levels.
Reject unsupported versions, missing/unknown fields, duplicate JSON object keys
(including escaped aliases), duplicate identities/category names, invalid
Unicode/dates/UUIDs, unsupported precision/settings, overflow and inconsistent
counts. Recompute every saved MYR amount with the same half-up rule used by
transactions. Require valid MYR and all parents/type matches. Archived historical
parents and zero-sen rounded foreign transactions are valid. Audit times must be
nonnegative, ordered and within year 9999; export time is not an upper bound
because device clocks can move backwards.

This is structural and financial integrity validation, not a cryptographic
signature or proof of the file's author. V1 backups and SQLite are not separately
encrypted. Future settings/format extensions require an explicit version change
and compatibility handling rather than silently ignoring data.

## Atomicity and concurrency

AppDatabase owns one non-reentrant LedgerWriteGate. Category, currency,
transaction and appearance writes use writeTransaction. It acts like a scoped
.NET unit-of-work mutex; Drift's SQLite transaction provides the actual atomic
commit/rollback. Do not call writeTransaction from inside an exclusive callback.

Export holds the gate and reads all four tables in one read transaction. Row and
raw payload limits are checked before materializing rows; a streaming JSON
encoder separately caps output including JSON escaping. Pure validation and
encoding run in worker isolates. This is JSON export, not a copy of a live
SQLite/WAL file.

Restore holds the same gate across the safety snapshot, native save callback and
replacement. One SQLite transaction:

1. Deletes transactions, categories, non-MYR currencies and settings.
2. Inserts currencies, categories and settings, then transactions, with bound
   arguments in batches of at most 500 statements.
3. Updates the protected MYR row using `ON CONFLICT DO UPDATE`; never deletes it,
   uses SQL REPLACE, drops tables or disables foreign keys.
4. Checks foreign_key_check and commits. Any error rolls back all writes.

Only after commit does the database increment its ledger generation and publish
all four table updates. A write queued against an older generation fails instead
of silently editing replacement data. Cancellation/failure does not advance the
generation. Navigation reset discards forms that belong to the old ledger.
No defaults are re-seeded after restore; an intentionally empty ledger stays empty.

All future app writes must participate in this gate. It coordinates one app
process/database owner, not arbitrary external SQLite writers or OS processes.

## Platform integration

The file adapter uses file_picker 13's static pickFile/saveFile APIs and a bounded
readAsByteStream. Save completes only when the plugin returns a non-null URI.
It never treats a content URI as a filesystem path. No broad storage permission
is added. share_plus uses a temporary JSON file and the calling button's global
rectangle for iPad popovers. Share result text reports handoff/dismissal/unknown
without promising durable storage.

Share files live in OS cache with random owned filenames. They are kept after
handoff because recipients may read lazily. The next share deletes owned files
older than 24 hours; the OS can also purge cache. This is not a guaranteed timed
secure erase. Cache is not ledger storage; internal backup exclusions remain.
iOS deployment target is already 15.0, above file_picker 13's iOS 14 minimum.
Verify native configuration, share/FileProvider behavior and OS exclusions on devices.

App version metadata defaults to pubspec's current version. When releasing with
a different version, keep the default in core/app_info.dart aligned or supply
`--dart-define=APP_VERSION=<version+build>`. It never controls format compatibility.

## Important files

| Path | Purpose |
| --- | --- |
| lib/core/backup/backup_validator.dart | Immutable validated backup, strict codec and financial/reference validation |
| lib/core/backup/backup_reader.dart | Size-limited stream reader |
| lib/core/backup/restore_plan.dart | Lazy fixed-identifier, bound-argument replacement SQL |
| lib/core/backup/backup_service.dart | Consistent export, safety copy, gate and atomic restore |
| lib/core/backup/backup_files.dart | Native picker/save/share and temporary-file lifetime |
| lib/core/database/ledger_write_gate.dart | Write serialization and restore-generation checks |
| lib/core/providers/ledger_operation_providers.dart | Transfer lock and navigation reset signal |
| lib/core/providers/appearance_provider.dart | Reactive persisted appearance and gated setting writes |
| lib/features/settings/presentation/backup_view_model.dart | Transfer/error/preview state and restore orchestration |
| lib/features/settings/presentation/backup_screen.dart | Backup UI, preview and explicit destructive confirmation |
| test/core/backup/ | Codec/reader/plan and real-Drift service tests |
| test/core/database/ledger_write_gate_test.dart | Queue, failure release and restore-generation tests |
| test/features/settings/backup_widgets_test.dart | Preview, confirmation and cancellation widget tests |
| tool/emit_test_restore_plan.dart | Emits the production Dart plan for synthetic SQLite QA |
| tool/verify_backup_restore.py | Executes that plan with the actual SQL schema |

## Verification and release acceptance

- Pure suite: 105 tests passed, including 60 new codec/reader/plan/gate checks and
  45 prior business-rule tests. A temporary test-import adapter uses package:test
  instead of flutter_test, without changing production logic or assertions.
- SQLite: 20 existing schema tests and 5 new production-plan checks passed.
  New checks cover exact replacement, archived references/rate text, injected late
  failure rollback, empty ledger, full int64 values and retained MYR protection.
- Isolated source analysis: actual backup UI/view model/codec/file adapter analyzed
  with real cached Riverpod/share_plus/path_provider, cached GoRouter 17.5.0, and
  temporary database/repository/Drift/file_picker/chart API stubs. This checks Dart
  source compatibility within that harness, not real plugin/Drift integration.
- Six real-Drift backup service tests and three new widget tests are written;
  not executed. The Flutter runner cannot bind its local test socket here.
- Full check script was attempted; it stops at pub get because build_runner is not
  cached. Drift and file_picker are also unavailable. No app lockfile/generated
  database/schema or successful native build is claimed or fabricated.

In a normal environment with stable Flutter and network/package access:

```sh
bash tool/check.sh
flutter test test/core/backup/ test/core/database/ledger_write_gate_test.dart
flutter test test/features/settings/backup_widgets_test.dart
dart run tool/emit_test_restore_plan.dart | python3 tool/verify_backup_restore.py
```

On a test installation on Android, iPhone and iPad: airplane-mode export/import,
native save/share cancellation, external file-provider errors, import rejection,
safety-save failure, restoring empty/populated/archived ledgers, MYR and rate
snapshot preservation, themed restore, stream refresh, force-stop/reopen and
process termination during replacement. Test large supported files, text scaling,
share popover placement, cache/OS backup exclusions and low-storage errors.
Do not run destructive restore tests on a personal production ledger.

Next: Phase 6 release/test preparation and completion of all deferred generated
code, real Drift, native plugin, widget and physical-device checks.
