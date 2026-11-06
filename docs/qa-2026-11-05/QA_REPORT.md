# Expense Tracker QA audit — 5 November 2026

**Android API 36 follow-up.** Installed JDK 17, Android SDK and the emulator on Windows. The standalone debug APK built successfully and its metadata confirms minimum API 24 and target API 36. All four Android integration tests passed across separate invocations on the API 36 emulator: backup round-trip, private storage reconnect, startup recovery and transaction persistence. The initial parallel build failed on a missing Gradle cache file, and the combined test run stalled after installing the second test APK. The serial build and individual test launches passed. Signed release, physical-device and iOS checks remain open. [Initial integration run](android-integration.log) · [Serial rerun](android-retry.log)

**Full Windows rerun.** The elevated Flutter coverage run passed all 231 tests in one invocation. The independent restore verifier also passed all five cases after making the Dart-to-Python JSON stream explicitly UTF-8. Android SDK, an Android target device or emulator, and release signing are still needed. iOS build and device QA require a Mac with Xcode and an iOS test destination. [Full Flutter run](windows-full-final.log)

**Windows Flutter results.** Flutter 3.47.9 and Dart 3.13.7 completed lockfile resolution, formatting and analysis. The full suite passed 230 tests. One test failed during setup because the shell lacked symbolic link privileges (Windows error 1314). An elevated rerun passed all 18 storage recovery tests, including the previously blocked symbolic link assertions. Every local Flutter test passed across the two runs. Native device and release checks remain open. [Full run](flutter-rerun.log) · [Elevated rerun](windows-elevated-recovery.log)

**6 November follow-up.** QA-001 was fixed in the test harness by closing both SQLite connections and explicitly committing the write. All 20 schema tests passed on Windows, including persistence and cleanup. See [rerun evidence](sqlite-schema-rerun.log). The original run is retained below.

Flutter 3.47.9 was checked out outside the repository. At the time of this follow-up, Flutter bootstrap was still downloading its Dart SDK. The queued lockfile resolution, formatting check, analysis, and coverage run record their output in [flutter-rerun.log](flutter-rerun.log). Native device and release checks remain open.

## A. Executive summary

**Overall: INCOMPLETE. Release readiness is unverified.** Audit executed against the checked-out project on Windows, using `QA_Test.txt`. No production files or existing tests were changed. No real ledger was opened. All database writes used synthetic, disposable databases.

Executed results:

- Source platform/privacy configuration check: PASS.
- Existing SQL suite: 20 tests executed; 19 PASS, one ERROR/FAIL in Windows temporary-file cleanup.
- Additional SQL checks: persistence after close/reopen, controlled financial dataset, historical snapshot after rate edit, rollback after invalid replacement, and integrity checks: PASS within the SQL-only scope.
- 100, 1,000, 10,000 and 50,000 synthetic rows: inserted and counted successfully. These are host SQLite measurements, not mobile app performance results.
- All ten financial fixture expectations independently reproduced using Python Decimal ROUND_HALF_UP. Production Dart conversion execution remains BLOCKED.
- Flutter/Dart analysis, formatting, unit/widget/integration tests, coverage, device workflows and native builds: BLOCKED; neither executable is available on PATH. iOS native builds additionally require macOS/Xcode.

No Critical or High application defect was confirmed in the executed scope. This is not evidence that none exist: core application behavior could not run. One Medium defect was reproduced in the existing QA harness. Financial, backup, offline and platform acceptance gates remain open. Do not recommend production release from these results.

## B. Environment and evidence

| Item | Observed |
| --- | --- |
| Date/time basis | 2026-11-05, Asia/Kuala_Lumpur |
| OS | Windows-10-10.0.19041-SP0 |
| Python | 3.8.5 |
| Host SQLite | 3.31.1; not the app's bundled SQLite version |
| Flutter / Dart | Not found by `where.exe`; versions unavailable |
| Devices/emulators | None used; Flutter device enumeration blocked |
| Initial git status | Clean |
| Dependencies | Declared constraints inspected; resolution/compatibility not verified |
| Test storage | In-memory SQLite and temporary synthetic files; connections explicitly closed in supplemental checks |

Commands attempted and errors are recorded in [flutter-environment.log](flutter-environment.log): `flutter --version`, `dart --version`, `flutter doctor -v`, `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter test --coverage`, `flutter devices`, `flutter test integration_test`, `flutter build apk --release`, `flutter build ios --release --no-codesign`. Every command was blocked before SDK execution. Lockfile enforcement was chosen to avoid silent dependency upgrades. No package upgrade or code generation ran.

Executed commands and retained output:

```powershell
python tool/verify_project_config.py
python tool/verify_sqlite_schema.py -v
python docs/qa-2026-11-05/supplemental_checks.py
git diff --check
```

Evidence: [project-config.log](project-config.log), [sqlite-schema.log](sqlite-schema.log), [supplemental-results.json](supplemental-results.json). `git diff --check` returned success; untracked report artifacts were additionally inspected. Existing progress documentation records historical Flutter successes on a different environment; those results are not counted as executions in this audit.

## C. Implementation and feature matrix

Actual architecture matches feature-first presentation/view-model, domain and repository separation. Riverpod owns repositories/database and reactive streams; GoRouter provides four persistent tabs, management routes and transaction detail/edit routes. Drift schema v1 has four tables. Flutter Material 3, manual rates and local JSON backup match the intended architecture in source.

`pubspec.yaml` requires Dart >=3.12.0 and Flutter >=3.44.0. Dependencies include Riverpod 3.4.3, GoRouter 18.1.3, Drift 2.35.3, decimal 3.2.6, file_picker 13.3.2 and share_plus 13.3.1. The lockfile and generated Drift files exist. Compatibility, generation freshness and SDK compilation are not established by reading those files.

| Module | Implemented | Tested this run | Result | Notes |
| --- | --- | --- | --- | --- |
| Dashboard | Yes, source | SQL dataset only | BLOCKED | Actual dashboard/reactivity unexecuted |
| Transaction CRUD | Yes, source | Schema constraints/subset persistence | BLOCKED | Repository/form execution unavailable |
| Category CRUD | Yes, source | SQL delete/archive/type guards | BLOCKED | Duplicate-name/UI validation unexecuted |
| Currency CRUD | Yes, source | SQL protections/reference guards | BLOCKED | Native selectors and repository execution unavailable |
| Exchange snapshots | Yes, source | SQL preservation after rate change | BLOCKED | Dart conversion/edit policy unexecuted |
| Reporting | Yes, source | Controlled SQL totals | BLOCKED | Dart aggregation/chart rendering unexecuted |
| Backup | Yes, source | Static review | BLOCKED | Export, picker/share and byte validation unexecuted |
| Restore | Yes, source | Generic SQL rollback | BLOCKED | Production restore service not executed |
| Settings | Yes, source | Configuration review | BLOCKED | Theme persistence/UI unexecuted |
| Offline | Designed in source | Permission/source checks | BLOCKED | Airplane-mode device test required |
| Android | Scaffold/native storage bridge | Source config executed | BLOCKED | No app build/device run |
| iOS | Scaffold/native storage bridge | Source config executed | BLOCKED | Windows host, no Xcode/device |

No core module is classified Not Implemented simply because runtime validation is blocked. The unused `lib/shared/widgets/feature_placeholder.dart` class remains as dead scaffold; no reference to it was found outside its own definition. No production mock ledger or required network client was identified in the reviewed source. Final app identifiers/signing/store preparation remain release work, as already documented by the project.

## D. Detailed results

[test-case-results.csv](test-case-results.csv) lists every numbered case from the request with expected result, scope and status. App-level cases remain BLOCKED even where corresponding SQL behavior passed. This prevents substituting SQL tests for UI/repository execution.

| Check | Expected | Actual | Status | Evidence |
| --- | --- | --- | --- | --- |
| CONFIG-001 | No release network/broad storage permission; backup exclusion configured | Configuration assertions passed | PASS | project-config.log |
| SQL-EXISTING | All 20 schema tests complete | 19 passed; file-persistence test errored during cleanup | FAIL | sqlite-schema.log |
| SQL-PERSIST | Explicitly closed file survives reopen | Six full transactions survived reopen | PASS | supplemental-results.json |
| SQL-REPORT | Income 545000, expense 20500, net 524500 minor units; six records | Exact match | PASS | supplemental-results.json |
| SQL-SNAPSHOT | Editing USD default leaves historical 4.5/45000 unchanged | Exact match | PASS | supplemental-results.json |
| SQL-ROLLBACK | Invalid replacement preserves original transaction rows | Rows identical after rollback | PASS | supplemental-results.json |
| SQL-INTEGRITY | `integrity_check` = ok; foreign_key_check empty | Both matched after stress writes | PASS | supplemental-results.json |
| SQL-SCALE | 100/1,000/10,000/50,000 inserts counted correctly | All counts correct | PASS | supplemental-results.json |
| FX-ORACLE | Ten independent expected values agree | All agree | PASS | Independent oracle only, not app conversion |
| SDK-CHECKS | Analysis/tests/builds execute | Executables missing | BLOCKED | flutter-environment.log |

The existing suite executed constraints for nonpositive/fractional/overflow amounts, archive preservation, calendar validation, category/type references, transaction type edits, rollback, foreign keys, currency code/precision validation, fixed MYR, identity conversion, snapshots, malformed rates, deletion guards, historical archived references, small positive rates, unused deletion and used-parent edits. The sole error is documented below.

## E. Verified defect

### QA-001 — P2 / Medium — SQLite persistence QA fails on Windows cleanup

- Module: QA tooling; no application data-loss defect established.
- Environment: Windows 10, Python 3.8.5, SQLite 3.31.1.
- Source: `tool/verify_sqlite_schema.py:164`, connection blocks at lines 166 and 169.
- Preconditions: clean checkout, Python available, no Flutter required.
- Reproduce: run `python tool/verify_sqlite_schema.py -v` from the project root.
- Expected: file-persistence assertions succeed and all temporary database handles close before directory deletion; suite passes.
- Actual: persistence/integrity assertions reach cleanup, then Windows raises WinError 32 on `ledger.sqlite`; cleanup eventually raises WinError 267. Suite ends `FAILED (errors=1)`.
- Root cause: a `sqlite3.Connection` context manager commits/rolls back transactions but does not close the connection. The second `disk` handle remains open when TemporaryDirectory exits. Windows prevents deletion of the open file.
- Evidence: full traceback in sqlite-schema.log. Supplemental persistence using explicit `contextlib.closing` succeeded.
- Smallest correction: explicitly close both SQLite connections before temporary-directory cleanup, for example with `contextlib.closing` and explicit commits where needed. Preserve all original assertions.
- Regression: rerun the original suite on Windows and Linux; require 20/20 and successful temporary cleanup. Do not mask cleanup errors or remove persistence assertions.

No production changes were made, in accordance with the audit instructions.

## F. Financial accuracy

Static review: `lib/core/money/money.dart` parses positive amounts into integer minor units, supports precision 0–6, enforces MYR precision 2 and signed 64-bit boundaries via BigInt. Excess precision is rejected, including extra zero digits. `exchange_rate.dart` accepts positive plain decimal rates with up to 12 digits before and after the decimal point; exponent notation and zero are rejected.

`currency_converter.dart:10` computes the exact rational value `minorUnits × rateCoefficient × 100 / 10^(sourcePrecision + rateFractionLength)` using BigInt, then rounds once by adding one when twice the remainder reaches the denominator. For positive transactions this implements ROUND_HALF_UP. Binary floating point is not used for this conversion.

| ID | Fixture | Expected MYR | Independent oracle | Production execution |
| --- | --- | --- | --- | --- |
| FX-001 | MYR 12.50 × 1 | 12.50 | 12.50 | BLOCKED |
| FX-002 | USD 12.50 × 4.50 | 56.25 | 56.25 | BLOCKED |
| FX-003 | USD 10.00 × 4.70 | 47.00 | 47.00 | BLOCKED |
| FX-004 | JPY 500 × 0.0300 | 15.00 | 15.00 | BLOCKED |
| FX-005 | KRW 15000 × 0.0035 | 52.50 | 52.50 | BLOCKED |
| FX-006 | SGD 25.50 × 3.40 | 86.70 | 86.70 | BLOCKED |
| FX-007 | KWD 1.250 × 14.25 | 17.81 | 17.81 | BLOCKED |
| FX-008 | USD 0.01 × 4.50 | 0.05 | 0.05 | BLOCKED |
| FX-009 | JPY 1 × 0.015 | 0.02 | 0.02 | BLOCKED |
| FX-010 | MYR 0.01 × 1 | 0.01 | 0.01 | BLOCKED |

Independent Python arithmetic validates the requested expectations, not the production converter. The existing money tests cover currency precisions, half-up boundaries, invalid MYR rates, overflow, formatting and snapshot policy; none ran here.

`conversion_policy.dart:19` retains saved conversion facts for ordinary edits and uses the saved rate for amount changes in the same currency. A currency change requires confirmation and an explicit rate. `currency_repository.dart` edits defaults without updating transactions. `financial_report.dart` aggregates saved MYR integer values with BigInt and bounds totals before narrowing; `report_repository.dart` uses inclusive start and exclusive end calendar-date predicates. Static review found no discrepancy with the requested formula or summing stored rounded equivalents.

The six-fixture SQL test inserted expected equivalents directly. It verifies schema acceptance and SQL totals, not automatic conversion or production report calculation. Negative net flow, cumulative rounding, large aggregate overflow behavior, Unicode formatting and reactive chart totals require Dart execution.

## G. Database and backup integrity

- Schema source: `lib/core/database/tables/ledger.drift`. Four tables, primary keys, NOT NULL/CHECK rules, RESTRICT foreign keys and date/category/currency/type indexes are present. Guard triggers protect MYR, referenced currency precision/code and referenced category type. Transaction triggers enforce category type.
- `app_database.dart:44` enables foreign keys before normal operations. Enforcement passed in the host SQL tests. Actual Drift connection setup remains unexecuted.
- `PRAGMA integrity_check` returned `ok`; `PRAGMA foreign_key_check` returned no rows after 50,000-row synthetic writes. This establishes only the health of the disposable host database.
- Current schema is version 1. There is no prior released schema supplied for an actual version upgrade. `onUpgrade` throws rather than silently wiping data. Existing v1 baseline/reopen tests are present but BLOCKED. A v1-to-v2 migration is NOT IMPLEMENTED because schema v2 does not exist; it is required when a schema bump is introduced, not a current CRUD failure.
- Production writes use serialized transactional operations. The write gate rejects writes queued across a successful restore. Transaction revisions prevent stale edits/deletes; action view models guard repeat submissions. Concurrency and stream notifications remain source-review findings.
- `backup_service.dart` snapshots categories, currencies, transactions and settings consistently, with 25 MiB and 100,000-row-per-table limits. Encoding/validation runs off the main isolate.
- `backup_validator.dart` validates format/schema versions, canonical integer strings, unique IDs/names, references, rates, precision, settings, duplicate JSON keys and nesting. It recomputes saved conversions before accepting input (`CurrencyConverter.toMyr`, line 329). No checksum is implemented; checksum-specific optional case is NOT IMPLEMENTED.
- `restore_plan.dart` uses bound statements, deletes children first, retains/upserts MYR, and inserts parents before children. `backup_service.dart` wraps replacement in one transaction, checks foreign keys, and publishes updates after commit. Optional safety-save cancellation occurs before replacement.
- Generic SQL rollback passed; production backup export, decode, round-trip, replacement, failure recovery, interrupted restore, low storage, native picker cancellation and safety-save cancellation are BLOCKED. The Dart-emitted restore-plan/Python verification pipeline cannot run without Dart; it was not replaced with a handwritten plan and claimed equivalent.
- Cross-platform Android/iOS backup portability is unverified. Date-only strings and canonical integer strings are favorable source design, not portability evidence.

Potential risk, not a confirmed application bug: SQL CHECK rules do not recompute arbitrary foreign-currency conversion equivalents; startup health checks validate SQLite/schema/reference integrity rather than every conversion. Normal repository writes and backup validation perform conversion checks. Unexpected direct database modification could therefore leave mathematically inconsistent stored equivalents. Consider a targeted health test and an explicit policy for detecting such corruption; no normal UI reproduction was established.

## H. Security and offline compliance

Executed source-config assertions confirm the main Android manifest omits INTERNET and broad external-storage permissions, disables automatic backup, and references backup/transfer exclusions. iOS source does not enable file sharing, declares no tracking/collected data, and configures privacy metadata. Merged release manifests/dependency manifests and signed artifacts remain unverified.

Static source review found no required backend, auth, exchange API, analytics client or automatic cloud synchronization. Search results containing URLs were XML/plist metadata/comments rather than executable network clients. Native file/share services can expose user-selected cloud destinations; offline imports require locally available files. Airplane-mode launches, CRUD, reports, export and restore still need device execution. No network traffic capture was performed.

The database is ordinary SQLite without application-level encryption. Android private/no-backup storage and iOS directory/file protection are configured in native source. OS protection, backup exclusions, reboot/locked-device behavior and compromised-device exposure were not tested. Existing privacy documentation accurately discloses the lack of separate database encryption.

JSON backups are plaintext. `backup_files.dart:38` writes shared JSON into OS temporary cache. Cleanup at line 68 runs only on a later share and removes owned files older than 24 hours; it is not a guaranteed 24-hour expiry. This is documented behavior and a privacy risk to assess, not a newly verified security vulnerability. Device file-protection behavior and share-recipient access require native testing.

Repository/history SQL binds user input. Table/column interpolation in backup code comes from fixed internal maps. No financial debug logging was identified in reviewed `lib` source. Malformed import rejection is implemented with bounds and validation, but adversarial Dart execution remains BLOCKED.

## I. Coverage, performance and gaps

There are 173 textual `test(`/`testWidgets(` declaration sites under `test` and `integration_test`; dynamic test generation means this is not an executed test count. Suites cover money, domain validation, real repositories, database health/write gates/schema baseline, backup validator/service/flows, startup recovery, navigation, widgets and native reconnect/round-trip scenarios. Coverage percentage is unavailable because `flutter test --coverage` could not run.

Host SQL measurements from one run, Python 3.8.5 / SQLite 3.31.1 / Windows, synthetic file database with four indexes and guard triggers:

| Rows | Insert seconds | Ordered 101-row query seconds |
| --- | --- | --- |
| 100 | 0.0168 | 0.0011 |
| 1,000 | 0.0981 | 0.0010 |
| 10,000 | 1.4858 | 0.0010 |
| 50,000 | 8.3286 | 0.0015 |

Insert timings include Python UUID generation, SQLite inserts and commit, one transaction per dataset. Query uses date/id ordering and LIMIT 101. These are single samples without a mobile responsiveness threshold; no rendering, memory, production report, backup or app startup benchmark was measured. The report stream materializes all rows in the requested period: profile its memory/latency on target devices at 50,000 rows before deciding whether optimization is needed. This is a potential performance risk, not a measured failure.

Missing executions: every production Dart test; real CRUD/form cancellations and rapid-tap behavior; true force-stop restart; backup platform I/O; SQL/Dart generated-schema equality; version migration; OS backup/restore; iOS/Android builds; light/dark visual inspection; 100/150/200% text scaling; safe areas/keyboard/accessibility; background/foreground; storage exhaustion; interruption recovery; network observation. These are BLOCKED or NOT RUN, never assumed passed. No manual app verification or screenshots were produced.

## J. Prioritized remediation and acceptance

1. Establish Flutter/Dart on PATH and resolve the committed dependency lockfile. Run analysis and all automated money/repository/report tests, then execute all ten exact FX fixtures against production Dart. Relevant files: `money.dart`, `currency_converter.dart`, `conversion_policy.dart`, transaction/report tests.
2. Execute production backup validator/service/flow and startup-recovery tests, including invalid/future/duplicate backups, rollback, cancellation and restore during edits. Relevant files: `backup_service.dart`, `backup_validator.dart`, `restore_plan.dart`, `startup_recovery_service.dart`. Do not change transactional behavior without a failing regression.
3. Correct QA-001 in `tool/verify_sqlite_schema.py:166` and `:169` by closing handles; rerun on Windows. This fixes the confirmed harness failure without changing application code.
4. Validate native persistence, platform file protection/backup exclusion, airplane mode, native export/share/restore and cross-platform round-trips. Relevant files: Android MainActivity/manifest/backup rules, iOS AppDelegate/Info.plist, `backup_files.dart`.
5. Run widget and device state/concurrency cases, including repeat save, stale revision, restore invalidation and returning from Settings. Relevant files: action view models, `ledger_write_gate.dart`, provider/reset/router code.
6. Profile 50,000-row reports/backups and memory on target devices; optimize only from measured failures. Then complete UI scaling/accessibility/visual device coverage.
7. Complete release identities/signing and Android release builds; use macOS/Xcode for iOS release validation. `android/app/build.gradle.kts` still uses `com.example.expense_tracker` and intentionally requires configured release signing.

Acceptance remains OPEN: implemented core CRUD/runtime, production conversion/snapshots/report totals, Drift database integrity and baseline reopen, backup/restore and failed-restore safety, offline operation, app restart state, automated Flutter tests, static analysis, Android release build, iOS build where supported, and signed-artifact privacy/security. No prior-schema upgrade can be accepted until a supported version transition exists and is tested. The SQL results are useful evidence but do not satisfy those app-level release gates.

## Files created by this audit

Only `docs/qa-2026-11-05/` was added: this report, command/test logs, supplemental test script/results, and the numbered-case CSV. No production files, lockfiles or existing tests were changed. No commit, push, deployment or user financial data mutation occurred.
