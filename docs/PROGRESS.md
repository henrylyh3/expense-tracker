# Development progress

## Desktop extension — 2026-11-09

macOS/Windows targets, application-data ledger storage, existing-layout reuse, foreground Discord progress, native updater integration and multi-platform packaging/release checks are implemented in source. Existing Android guests continue through Discord; the laptop is the ledger owner. No always-on service was added. Signed update feeds are opt-in and unconfigured in this checkout. Native builds/signing/device and upgrade validation are pending. See [DESKTOP.md](DESKTOP.md) for commands, storage, migration and remaining release requirements. Historical phase test counts below are earlier checkpoints.


### Verification for the desktop extension

- `flutter analyze`: passed with no issues.
- 69 focused Flutter tests across desktop storage, updater configuration, Discord sync/progress and linked Android updater/sharing/recovery behavior: passed. The full suite was not run.
- 7 Python release integrity tests: passed; `git diff --check`: passed.
- macOS build attempt: blocked because full Xcode is absent; CocoaPods is also missing.
- Windows build attempt: rejected on this macOS host; requires Windows with Visual Studio C++ tools.
- Android SDK and release signing configuration are absent. This environment's Flutter SDK reports `3.48.0-0.5.pre`; official stable SDK release validation remains required.
- Version reserved in source: **0.4.7+16**. No new native release artifacts have been published. Signing/feed setup, native packaging and real-device upgrade verification remain pending.

Last updated: 2026-11-05 (Malaysia).

| Phase | Status | Acceptance remaining |
| --- | --- | --- |
| 1 — Foundation | Source and host checks verified | Official stable SDK, native builds and storage/OS-backup device QA |
| 2 — Categories/currencies | Real repository/widget tests passed | Device CRUD/restart/layout checks |
| 3 — Money/transactions | Real domain/repository/widget tests passed | Native integration and force-stop persistence |
| 4 — Dashboard/reports | Real report/filter/chart widget tests passed | Device chart rendering/accessibility and layouts |
| 5 — Backup/restore | Real service/widget/restore-flow tests passed | Native save/share/picker, interruption, low-storage and OS checks |
| 6 — Release | Host verification and preparation implemented | Stable SDK, signing/identities/branding, native builds and release acceptance |

**Current verification is in Phase 6 below. Earlier phase results describe the
historical environment; package resolution and Flutter test execution now work.**

## Setup observations

- Initial repository contained README only; worktree was clean.
- Flutter is not on PATH. A locally available SDK reports a prerelease (`3.48.0-0.5.pre`), so use official stable for release validation.
- Earlier shell access could not resolve pub.dev. Required packages, including Drift, were not cached. Those blockers were cleared during Phase 6; see current results below.

## Phase 1 delivered (historical checkpoint)

- [x] Setup, dependency commands, technical decisions and target structure documented before implementation.
- [x] Android/iOS scaffolds; development bundle IDs/signing limitations documented.
- [x] Material 3 light/dark themes following the device theme.
- [x] GoRouter four-tab shell with branch stacks, Settings routes and Add Transaction route.
- [x] Clear placeholders for features planned in later phases.
- [x] Riverpod-owned lazy background database with loading, safe error display and manual retry.
- [x] Retry displays loading and hides the Retry action until opening finishes; automatic retries disabled.
- [x] Schema v1 for all four tables, with indexes, constraints and invariant triggers.
- [x] Transactional first-create defaults and explicit future migration policy.
- [x] Android no-backup directory/backup rules and iOS backup exclusion/file protection.
- [x] Database, startup/retry, navigation, text-scaling and native reconnect tests written.
- [x] README, summary, phase tracker and one-command verification script.
- [ ] Resolve all dependencies together on official stable Flutter and commit pubspec.lock.
- [ ] Generate app_database.g.dart and export/commit the v1 schema snapshot.
- [ ] Run complete Flutter analysis, unit/widget tests and native integration tests.
- [ ] Build Android/iOS and verify airplane-mode startup, force-stop persistence and OS backup exclusions on devices.

## Verification performed (initial checkpoint)

| Check | Result |
| --- | --- |
| Current ledger.drift, stdlib SQLite | Passed: 20 tests, including financial field constraints, history preservation, archive references, rollback and persistence |
| Isolated navigation/theme/presentation analysis | Passed with cached Riverpod 3.4.3 and GoRouter 17.5.0; excludes database/bootstrap and does not establish compatibility with declared GoRouter 18.1.3 |
| Dart formatting | Source/test files parsed and formatted; unresolved lint-include warnings until app dependencies resolve |
| iOS Info.plist | Passed plutil validation |
| Swift native source syntax | Passed swiftc parse for AppDelegate and SceneDelegate; not a native build/type check |
| Verification script syntax | Passed bash -n |
| Android XML and Markdown links | Parsed XML and checked local documentation links successfully |
| Full app offline dependency resolution | Failed: build_runner missing from cache; Drift and other packages also absent |
| Shell pub.dev access | Failed: DNS unavailable |
| Isolated Flutter navigation test execution | Runner could not start: local socket binding to 127.0.0.1 denied by the session; no widget tests executed |
| Full Flutter analysis/generation/tests and native builds | Pending; dependency/tooling restrictions prevent completion |

Isolated analysis used temporary copies of the actual navigation/theme/shared
widgets/feature screens and the navigation tests, with the cached router version.
The application manifest and requested dependency versions were not downgraded.
No generated Drift code, exported schema or resolved app lockfile was fabricated.

## Phase 2 delivered (historical checkpoint)

- [x] Validated category/currency drafts, shared transaction type and safe domain errors.
- [x] Exact decimal rate normalization and currency suggestions without invented rates.
- [x] Concrete Drift repositories with atomic create/edit/delete/archive/restore.
- [x] Reference counts; MYR, used-currency precision/code and used-category type protection.
- [x] Metadata/rate updates preserve archive state, creation times and transaction snapshots.
- [x] Reactive Riverpod lists and AsyncNotifier action state, with duplicate-submit guards.
- [x] Settings category filters, icon/color editor, currency templates/manual rates and confirmations.
- [x] Ten domain, nine repository and three management widget tests; navigation tests updated.
- [x] README, project summary and [Phase 2 implementation notes](PHASE_2_MANAGEMENT.md) updated.
- [ ] Complete generated-code compilation and real Drift repository tests.
- [ ] Execute widget/device tests and visually verify editor layouts and restart persistence.

### Phase 2 verification

- Passed all 10 domain-validation tests with a temporary pure Dart test runner,
  changing only the test import from flutter_test to test. The production domain
  source and test assertions were unchanged.
- Passed all 20 current SQLite schema checks.
- Prepared all 16 SQL statements extracted from the category/currency repositories
  against the actual SQLite schema with EXPLAIN. This checks SQL syntax/table
  compatibility, not Dart execution or reactive notifications.
- Passed isolated static analysis of actual app/UI/model/validation/view-model
  source and management/navigation/startup widget tests, using cached GoRouter
  17.5.0. Database/provider wiring and repositories were stubbed only in the
  temporary diagnostic package. Actual Drift repositories/generated code remain
  unverified; no stubs or downgraded dependencies were added to this repository.
- Full app analysis was attempted and blocked by unresolved packages/generated
  code. The normal manifest still declares GoRouter 18.1.3.

## Phase 3 delivered (historical checkpoint)

- [x] Currency-qualified Money, positive amount parsing, integer bounds and exact formatting.
- [x] Exact MYR conversion with one explicit half-up rounding operation.
- [x] Calendar-only date validation and bounded optional multiline notes.
- [x] Snapshot policy: preserve ordinary edits, saved-rate amount edits, explicit rate overrides and currency-change confirmation.
- [x] Atomic transaction CRUD, active/reference/type checks and stale-revision protection.
- [x] Incremental reactive history, detail/edit/delete and full transaction editor with MYR preview.
- [x] Eighteen domain, twelve repository and four editor widget tests; navigation tests updated.
- [x] Native transaction persistence integration test with unique fixture rows and cleanup (written, not executed).
- [x] README, summary and [Phase 3 implementation notes](PHASE_3_TRANSACTIONS.md) updated.
- [ ] Compile generated Drift code and execute transaction repository/widget tests.
- [ ] Verify Android/iOS layouts, force-stop/reopen persistence and editing/deletion flows.

### Phase 3 verification

- All 18 new money/date/snapshot-policy tests passed via the temporary pure Dart
  test-import adapter; includes 64-bit boundaries, exact formatting, half-sen ties,
  zero-decimal currencies and saved-rate preservation. Together with Phase 2,
  28 pure domain tests have passed.
- All 20 current SQLite checks still pass. All 25 extracted repository SQL statements
  prepare against the schema (nine transaction statements plus sixteen management statements).
- Isolated source analysis passed for app/UI/domain/view models and widget tests
  using the previously documented cached dependencies and database/repository stubs.
  Actual Drift repository/generated-code execution remains blocked.
- No schema change was needed; schema version is still 1.

## Phase 4 delivered (historical checkpoint)

- [x] Validated month/year ranges, leap-day buckets and maximum-year boundaries.
- [x] Exact saved-MYR report totals, net, counts, category grouping and zero-filled trends.
- [x] Aggregate overflow detection using BigInt, without SQL SUM/TOTAL or floating-point finance.
- [x] Reactive Home summaries, selected-month recent items and yearly monthly trends.
- [x] Monthly/yearly Reports, category charts, cash-flow bars and exact-value tables.
- [x] Period/category drill-down into constrained History.
- [x] Literal debounced search and combined type/category/currency/inclusive-date filters.
- [x] Archived history options, pagination reset, clear/reset, stale-search cancellation and loading/empty states.
- [x] Offline English date labels, plus updated startup/navigation fixtures.
- [x] Seventeen domain, ten real-Drift and three report/filter widget tests written.
- [x] README, project summary and [Phase 4 notes](PHASE_4_REPORTS.md) updated.
- [ ] Run real Drift report/filter tests and widget tests with the declared packages.
- [ ] Build/inspect actual charts and Android/iOS layouts, text scaling and interactions.

### Phase 4 verification

- All 45 pure domain tests passed together (17 new report/filter/date-label tests).
  Uses the same temporary import adapter; production domain logic/assertions unchanged.
- All 20 SQLite schema checks passed.
- Ran the actual Dart history predicate builder for 13 scenarios against SQLite
  fixtures before and after archiving: 26 successful query executions. Includes
  literal wildcard/SQL syntax, Unicode, all filter fields, one-sided dates and
  archived category/currency selection.
- Prepared all 27 repository SQL statements/period-bound variants against SQLite.
- Isolated analysis passed using cached GoRouter 17.5.0 plus temporary database,
  repository and chart-constructor API stubs. Actual Drift/generated code and
  fl_chart internals/rendering remain unverified. No stubs or downgraded dependencies
  were added to the application manifest or source.
- Schema version remains 1; this phase does not modify table definitions.

## Phase 5 delivered (historical checkpoint)

- [x] Versioned JSON contract and private, deeply immutable validated data.
- [x] Exact integer/rate serialization; duplicate-key, size/depth/row-count and Unicode validation.
- [x] References, MYR/type/precision/audit/date/settings and exact conversion integrity checks.
- [x] Bounded native file streaming, native Save dialog and iPad-aware share sheet.
- [x] Consistent snapshot export and worker-isolate validation/encoding.
- [x] Read-only preview, explicit Replace All acknowledgment and default safety save.
- [x] Cancellation/failure-safe safety backup and transactional, FK-preserving restore.
- [x] Shared write queue, stale-generation rejection and committed-only stream refresh.
- [x] Navigation/form/filter reset after restore; persisted System/Light/Dark appearance.
- [x] Sixty new pure checks, six real-Drift service tests and three widget tests written.
- [x] Production-plan SQLite QA added to tool/check.sh.
- [x] README, summary and [Phase 5 notes](PHASE_5_BACKUP.md) updated.
- [ ] Resolve/generate actual Drift and execute backup service and widget tests.
- [ ] Verify native dialogs, cancellation, low storage, iPad sharing, restore/restart and OS exclusions on test devices.

### Phase 5 verification

- All **105 pure Dart checks passed** together: 60 new codec/reader/plan/write-gate
  checks plus 45 prior business-rule tests. The temporary test-import adapter
  preserves production logic and assertions. Includes full int64 precision,
  historical rate text, malformed/duplicate JSON, reference/conversion failures,
  output growth from JSON escaping, bounded streams and stale queued writes.
- All **20 existing schema checks** and **5 new restore-plan SQLite checks** pass.
  The latter execute SQL emitted by the actual Dart validator/plan against the
  actual schema, checking replacement, late-failure rollback, empty data,
  int64 bound arguments and MYR protection.
- Isolated source analysis passed with real cached Riverpod/share_plus/path_provider,
  cached GoRouter 17.5.0 and temporary database/repository/Drift/file_picker/chart
  API stubs. Actual native plugin/Drift integration is not established. No stubs
  or dependency downgrades were added to app source or pubspec.
- Six backup service and three widget tests are written, not executed. The new
  widget suite was attempted in the diagnostic package but could not start:
  socket binding at 127.0.0.1 is denied by this session.
- Full tool/check.sh --offline attempted; pub get fails because build_runner is
  not cached. Drift/file_picker remain unavailable. Generated files, schema and
  app lockfile remain pending; schema version stays 1.

## Phase 6 delivered

- [x] Real declared dependency graph resolved; pubspec.lock generated.
- [x] Drift parser keyword quoting fixed; real AppDatabase generated without warnings.
- [x] Initial v1 schema exported and historical test helper generated.
- [x] Baseline schema/data-preservation and unknown-future-version refusal tests.
- [x] Full actual-package analysis and all 194 Flutter tests passed.
- [x] Widget scrolling/dropdown tests corrected; missed taps made fatal.
- [x] Full real-Drift restore UI flow checks lock, safety snapshot, resets and theme.
- [x] Isolated native backup-file/reopen integration test written (device execution pending).
- [x] Private release-signing configuration; debug-key fallback removed.
- [x] iOS app privacy manifest/resource wiring and About/licenses entry.
- [x] CI workflow, enforced lockfile, temporary schema comparison and source config checks.
- [x] README, summary, privacy behavior and [Phase 6 guide](PHASE_6_RELEASE.md).
- [ ] Run on official stable Flutter; current local SDK is 3.48.0-0.5.pre.
- [ ] Execute remote CI after committing/pushing the project.
- [ ] Choose permanent identities/branding; configure private Android/iOS signing.
- [ ] Install native tooling, build Android/iOS and run integration/device acceptance.
- [ ] Verify physical-device file dialogs, share sheets, OS backups, interruption and accessibility.

### Phase 6 verification

- Complete `bash tool/check.sh --offline` passed: enforced package lock,
  real generation, formatting, full analysis, **194 Flutter tests**, schema
  comparison, project configuration and **25 SQLite checks**.
- Real packages include Drift 2.35.3, GoRouter 18.1.3, file_picker 13.3.2 and
  fl_chart 1.3.0. Current full-app checks use no diagnostic API stubs.
- The new real-Drift app flow exercises safety export, transfer lock, committed
  restore, navigation/filter reset and persisted theme with an in-memory native
  file adapter. Earlier six backup service tests now execute successfully.
- plutil validates Info/privacy manifests and the Xcode project; bash syntax and
  local Markdown links pass. This does not replace native builds.
- Full Xcode is absent (Command Line Tools only); Android SDK is not configured.
  Device tests, signed artifacts and remote workflow execution are unverified.
- No new production schema version or historical upgrade is invented; v1 is the
  initial baseline. No keys/identifiers, commits, pushes or publications were made.

## Phase 6 follow-up — startup/storage

- [x] Read-only startup checks for required schema objects/columns, SQLite
  quick_check, foreign-key enforcement/references, MYR and theme settings.
- [x] Missing/corrupt storage blocks navigation without repair, reseeding or reset.
- [x] Native private-directory bridge validates absolute paths; no fallback storage.
- [x] Twelve health, eight bridge-boundary and one real startup widget test added.
- [x] All 194 Flutter tests, full analysis, schema comparison and 25 SQLite checks pass.
- [x] [Startup/storage implementation notes](STARTUP_STORAGE.md), README and summary updated.
- [ ] Measure startup scan latency on large ledgers on supported devices.
- [ ] A separately confirmed recovery workflow for an unreadable database is not implemented.

Schema version remains 1 and its generated snapshot is unchanged. No dependencies
were added. Normal backup restore still requires a successfully opened ledger;
failed startup never deletes original SQLite/WAL files to recover.

## Next steps

Use official stable Flutter with full Android SDK and/or macOS/Xcode:

```sh
bash tool/check.sh
flutter test integration_test/foundation_test.dart -d <device-id>
flutter test integration_test/transaction_persistence_test.dart -d <device-id>
flutter test integration_test/backup_round_trip_test.dart -d <device-id>
```

Commit the generated database, lockfile, initial snapshot/helper, application source
and workflow together after review. Follow [Phase 6](PHASE_6_RELEASE.md) for signing
and release commands, permanent identities, branding/privacy and device QA.
Release acceptance remains open; do not label the application production-released
until those checks pass. Use a test installation for destructive restore tests.

## 2026-11-08 — v0.4.0 local shared trips

- Added host-owned trip sharing over local Wi-Fi/hotspot, separate guest invitations, encrypted sync, revocation, cached summaries and persistent offline expense queues.
- Guest expenses are committed to the host ledger once, including retries after a lost acknowledgement or a host-side deletion. Guests cannot edit/delete existing host expenses.
- Shared expense choices include the trip's selected named currency rate. Sharing is foreground-only; the host must stay open and awake.
- Added confirmed reset of all local ledger/sharing data and completed the Settings import/export controls. JSON backups exclude invitation secrets, guest caches and unsent queues.
- Upgraded local database schema from 4 to 5 with migration coverage. Release version is 0.4.0+9, retaining the package identity and signing key.
- Validation: 249 Flutter tests, clean analysis, source configuration checks, and Android API 36 encrypted host/guest sync smoke test. Physical two-phone Wi-Fi/hotspot and iOS testing remain pending.
- Signed ARM64 APK: release/expense-tracker-0.4.0-arm64-release.apk.
- Usage and limitations: [SHARING.md](SHARING.md).
- Release artifact verified: package com.example.expense_tracker, versionName 0.4.0, versionCode 2009 (previous 2007), arm64-v8a only, same signing certificate as v0.3.0.
- Signed release installed as an update on the API 36 emulator. Home, Settings, Shared trips and Start hosting opened successfully, with no AndroidRuntime/Flutter error log entries.
- APK SHA-256: FC7BC2006AE6D39E35DA88F8385F51A7028F6368D07F2073C608BD97B4DA8FE1.

## 2026-11-09 — v0.4.1 trip currency totals and version in Settings

- Added a Current version card at the top of Settings, displaying the same version/build identifier as the About dialog and backup metadata.
- Trip summaries now list all original expense totals grouped by currency, then a combined MYR total calculated from saved transaction rates. Named rate records for the same currency are combined in the original currency total.
- Removed the trip summary currency dropdown. The category chart uses MYR; trip expense currency defaults remain managed through trip currency settings.
- Increased app version to 0.4.1+10. Retained the Android package identity and release signing key for updates over existing installations.
- This change does not add automatic updates. APK updates can be installed over the existing app; an in-app download/update flow would need a hosted APK and Android installation approval.
- Signed ARM64 APK: release/expense-tracker-0.4.1-arm64-release.apk.
- Validation: clean flutter analyze, all 251 Flutter tests passed, and project configuration checks passed. Added checks cover original currency totals, mixed saved rates across months, archived currencies, trip isolation, live deletion updates and a narrow trip summary with enlarged text.
- Signed APK verified: com.example.expense_tracker, versionName 0.4.1, versionCode 2010 (previous 2009), arm64-v8a only, same signing certificate as v0.4.0.
- API 36 emulator update smoke test: created an RM 12.50 expense in v0.4.0, installed v0.4.1 over it and confirmed the expense persisted. Settings displayed 0.4.1+10; trip summary showed original and combined MYR totals, an MYR category chart and no currency dropdown. No app runtime errors were recorded.
- APK SHA-256: 3E87DAB9D37D388B98D35103295826018A02484EB6C451C6EB59F12A0914E35C.

## 2026-11-09 — v0.4.2 automatic Android updates

- Added a once-per-cold-launch GitHub Release check after successful ledger startup. A newer build prompts Update now or Later; offline/error checks do not block tracking.
- Added cancellable APK download progress, GitHub manifest/asset digest validation, HTTPS host restrictions and bounded downloads. Android verifies the actual checksum, package, newer version code, ARM64 libraries and existing signing certificate before the installer opens.
- Added Android installation permission handling and automatic installer opening after the user returns from granting permission. Ledger storage is unchanged. iOS skips this Android-only updater.
- Added release publishing tooling and a maintained release workflow: commit signed APK/manifest/notes, push, then publish verified assets through a GitHub draft release. Publishing credentials remain on the developer machine.
- Validation: clean Flutter analysis, all 259 Flutter tests passed, project configuration checks passed, and an API 36 Android integration test confirmed invalid APKs/paths are rejected.
- APK: release/expense-tracker-0.4.2-arm64-release.apk. Release guide: UPDATES.md. The first updater-enabled APK needs one manual installation.
- Release artifact verified: package com.example.expense_tracker, versionName 0.4.2, versionCode 2011 (previous 2010), ARM64 only, and the same signing certificate as v0.4.1. Final small-screen prompt tests passed with long release notes and visible download progress.

## 2026-11-09 — v0.4.3 saved rates and clearer expense lists

- Trip summaries list the saved exchange rates under each original currency total. Distinct historical rates remain visible even after changing or archiving the currency; equivalent rate representations are deduplicated.
- History entries show the date and positive amount without a repeated expense type label or leading minus sign. Original currency amounts remain available where relevant.
- Currency settings visibly mark App default and Current trip default on the exact selected currency/rate record. Markers update live, including different named records sharing the same currency code. Already-selected default menu actions are disabled.
- Validation: clean Flutter analysis, all 261 Flutter tests passed, and project configuration checks passed. Tests cover mixed saved rates, rate removal after deleting an expense, narrow-screen display, named default records and History labels/amounts.
- Release version 0.4.3+12; signed ARM64 APK: release/expense-tracker-0.4.3-arm64-release.apk. Publish the APK and update manifest through the existing GitHub updater workflow.
- Signed artifact verified: com.example.expense_tracker, versionName 0.4.3, versionCode 2012 (previous 2011), arm64-v8a only, with the same signing certificate as v0.4.2.

## 2026-11-09 — v0.4.4 creation-time reference rates and reliable updates

- New currency/rate records prefill Frankfurter's latest available reference rate to MYR when a template or valid currency code is entered. The observation date is shown. The rate remains editable and is saved through the normal currency workflow.
- Existing currencies, trip rates and saved expense snapshots are never refreshed by this feature. Manual entry remains available offline or for unsupported currencies. Late responses cannot overwrite a manual edit or a different selected currency.
- Reference rate decimals are parsed from the original JSON number token, rounded half up to 12 fractional digits and validated without binary floating-point conversion of the saved rate.
- Fixed cached GitHub update/download requests with fresh initial URLs and no-cache headers while preserving signed redirect URLs. Temporary checks retry once, concurrent checks share a request, and updates discovered away from Home remain pending until the user returns.
- Added a Settings Check for updates button with visible success/failure and Retry. Foreground checks run after at least five minutes; Later defers the same version for the current session. No GitHub setup is needed on the phone.
- Validation: clean Flutter analysis, all 274 Flutter tests passed, project configuration checks passed. Coverage includes reference-pair validation, decimal rounding, offline input, races/manual overrides, saved-record no-fetch behavior, update cache busting, signed redirects, retries, pending prompts and foreground checks.
- Version: 0.4.4+13. Signed ARM64 APK: release/expense-tracker-0.4.4-arm64-release.apk. Guides: CURRENCY_RATES.md and UPDATES.md.
- Signed artifact verified: com.example.expense_tracker, versionName 0.4.4, versionCode 2013 (previous 2012), arm64-v8a only, with the same signing certificate as v0.4.3.
- Android API 36 release smoke test: installed over v0.4.3 with the RM 25.60 expense preserved; Settings update check completed visibly; selecting THB fetched Frankfurter rate 0.121 dated 2026-11-09; a manual override of 0.13 was saved and remained 0.13 on Edit currency without a new reference lookup. No app runtime errors were recorded.

## 2026-11-09 — v0.4.5 searchable currencies and flexible amount entry

- Expanded the offline hardcoded template list to 165 current ISO monetary codes with defined minor units. Search accepts code or name, case-insensitively; templates and configured records are sorted by currency code.
- Removed the decimal-places control and its settings-row label. Foreign expense input accepts up to six decimal places regardless of conventional currency precision, including JPY; MYR entry/totals remain two decimals.
- Added per-expense precision storage in database schema 6. Legacy rows retain a null fallback to their existing currency scale, preserving values without rescaling. Reports align mixed scales exactly; shared expense entry uses the same parsing rules.
- Backup schema 5 preserves each expense precision and accepts legacy schemas 1–4. Added tests for fractional history/report totals, export/restore and v5-to-v6 data preservation.
- Added unique currency-name validation in the form and inside the write transaction, comparing case and repeated whitespace across base/named/archived records. Distinct names may share a code; unchanged legacy names remain editable.
- Validation: clean Flutter analysis, all 281 Flutter tests passed, 20 SQLite schema tests and 5 backup SQL checks passed, and project configuration checks passed.
- Version 0.4.5+14. Signed ARM64 APK: release/expense-tracker-0.4.5-arm64-release.apk. Details and sources: CURRENCY_CATALOG.md.
- Android API 36 release verification: v0.4.4 data upgraded without losing the RM 25.60 expense; typing jpy selected the JPY template with reference-rate prefill; decimal controls were absent; JPY 100.50 saved and remained exact in History after reinstalling the final APK (MYR equivalent RM 2.58). No app runtime errors were recorded.
- Artifact verified: com.example.expense_tracker, versionName 0.4.5, versionCode 2014 (previous 2013), ARM64 only, same signing certificate as v0.4.4. Final compatibility tests also cover adding a named record for a legacy currency scale.
