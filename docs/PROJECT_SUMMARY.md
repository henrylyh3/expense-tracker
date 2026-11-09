# Offline Flutter Expense Tracker — project summary

## Desktop extension — 2026-11-09

macOS/Windows targets, application-data ledger storage, existing-layout reuse, foreground Discord progress, native updater integration and multi-platform packaging/release checks are implemented in source. Existing Android guests continue through Discord; the laptop is the ledger owner. No always-on service was added. Signed update feeds are opt-in and unconfigured in this checkout. Current focused verification passes: analysis, 69 Flutter tests and 7 release-tool tests. Native builds/signing/device and upgrade validation are pending. See [DESKTOP.md](DESKTOP.md) for commands, storage, migration and remaining release requirements. Historical phase test counts below are earlier checkpoints.


Last updated: 2026-11-05 (Malaysia). This document is the handoff and decision record. See [Phase 1](PHASE_1_FOUNDATION.md) for setup and [progress](PROGRESS.md) for verified status.

Current implementation: Phases 1–5 are implemented, with Phase 6 host verification
and release preparation added. The real lockfile, generated Drift database,
versioned v1 snapshot and migration-test helper are present. All **194 Flutter
tests**, full analysis, schema comparison and **25 SQLite checks** pass. Native
builds/device QA, final identities/signing/branding and official stable-SDK
validation remain. See [Phase 6](PHASE_6_RELEASE.md) for commands and limitations.

## Product scope

Personal Android/iOS Flutter app. Entire ledger is stored locally in SQLite through Drift. No authentication, backend, account/wallet entities, telemetry, exchange-rate API, or runtime internet dependency. One unified income/expense ledger. Material 3 interface with Home, History, Reports, Settings and an accessible Add Transaction action.

### Features

- Home: monthly income, expenses, net cash flow, spending trends, category charts, recent transactions; all summaries in MYR.
- Transactions: create/read/update/delete, positive amount, income/expense type, original currency, matching category, calendar date, optional notes; search and filter by date, category, currency, type.
- Settings → Categories: CRUD; separate income and expense categories; stable icon keys, color, order; common defaults; archive referenced categories, delete unused ones. Archived items stay in history and are unavailable for new transactions.
- Settings → Currencies: CRUD for three-letter uppercase currency codes, names, symbols, precision and manually configured MYR rates. Archive used currencies, delete unused currencies. MYR is always active, precision 2, rate 1, and cannot be removed. Protect referenced code/precision. Existing snapshots never change when default rates change.
- Reports: monthly/yearly income vs expenses, category spending and trends using stored MYR equivalents. Do not sum different original currencies.
- Backup: native file picker, JSON export/save/share, validation, preview, explicit Replace All warning, offer safety export, atomic restore. No merge in version 1.

## Technical choices

Flutter/Dart; Riverpod; feature-first MVVM and concrete repositories; Drift/SQLite; GoRouter; decimal; intl; uuid; fl_chart; file_picker; share_plus; path_provider; drift_dev/build_runner. Use provider declarations directly initially; avoid a second generator for Riverpod until useful.

Flow: widget → view model/provider → repository → Drift. Widgets never write SQL. Repositories own atomic writes, validation and persistence mapping. Pure money/date logic has no Flutter dependency. Drift streams drive Riverpod StreamProviders and reactive widgets. Add DAOs only when query complexity warrants them; avoid generic repositories, CQRS, service locators and backend-style controllers.

Riverpod's ProviderScope resembles a NestJS application DI container or .NET service provider. A provider constructs/owns a dependency; ref.watch also subscribes to changes. A ConsumerWidget is a view. A Notifier/AsyncNotifier will be the feature's view model. Drift's generated database is analogous to EF Core's DbContext, with explicit stream queries for observable results. GoRouter handles navigation, not business rules.

## Data model (schema version 1)

| Table | Fields |
| --- | --- |
| categories | id TEXT PK; name TEXT; type TEXT income/expense; icon_key TEXT; color_hex TEXT #RRGGBB; sort_order INTEGER; is_archived BOOLEAN |
| currencies | code TEXT PK; name TEXT; symbol TEXT; decimal_places INTEGER; rate_to_myr TEXT; is_active BOOLEAN; created_at_utc INTEGER; updated_at_utc INTEGER |
| transactions | id TEXT PK UUID; category_id TEXT FK RESTRICT; type TEXT income/expense; amount_minor INTEGER; currency_code TEXT FK RESTRICT; exchange_rate_snapshot TEXT; amount_myr_minor INTEGER; transaction_date TEXT YYYY-MM-DD; note nullable TEXT; created_at_utc INTEGER; updated_at_utc INTEGER |
| app_settings | key TEXT PK; value TEXT |

Audit timestamps are Unix milliseconds in UTC, not local date-times. Transaction dates represent the user's selected calendar day and never undergo timezone conversion. Month/year filters use inclusive start/exclusive next-period dates. IDs are UUID v4 for transactions/custom categories; seeded category IDs are stable strings.

Indexes: transaction date + id; category + date; currency + date; type + date. Foreign keys enabled on every connection. Constraints/triggers protect references, category/type agreement, base currency, used-currency precision, positive money and valid date/rate shapes. Exact conversion consistency is validated by the money domain/repository and backup validator, never SQL floating-point casts.

## Money and exchange-rate policy

- Positive integer minor units; type controls income/expense sign. Reject zero and negative original amounts. Converted MYR can round to zero for small foreign amounts.
- Precision 0–6, explicit per configured currency. MYR/USD 2; JPY/KRW 0. Reject excess amount fractional digits instead of silently rounding input.
- Canonical positive decimal rate strings: no exponent, sign, grouping or whitespace, at most 12 integer digits and 12 fractional digits. Convert/normalize user input in the domain layer. Never store rate or money as double.
- Formula: MYR minor = round-half-up(amount_minor × rate × 100 ÷ 10^currency_precision). Round once, to whole sen, at save time.
- Enforce signed SQLite 64-bit bounds before conversion to Dart int; use BigInt/Decimal intermediates. Reports must detect aggregate overflow. Chart doubles are presentation-only.
- MYR 12.50 → (1250, MYR, 1, 1250); USD 12.50 at 4.50 → (1250, USD, 4.5, 5625); JPY 500 → amount_minor 500; KRW 15,000 → amount_minor 15000. Original currency is always persisted.
- Changing the default USD rate from 4.5 to 4.7 affects new entries only. Editing notes/date/category preserves snapshot and MYR equivalent. Editing amount recalculates with the saved rate; changing currency requires explicit rate confirmation. An explicit rate edit recalculates MYR.
- Existing archived category/currency can remain on an edited historical transaction. Changing either reference requires an active replacement. A used category cannot change income/expense type. Category name/icon/color edits apply to historical display; transaction amount/code/rate history remains immutable unless explicitly edited.
- Only MYR is seeded as an active configured currency. USD/JPY/KRW are catalog suggestions in Phase 2, without invented exchange rates.

## Backup format and restore contract (Phase 5)

Envelope: format identifier `expense-tracker`, format_version 1, schema_version, app_version, exported_at_utc, base_currency MYR, counts and data (categories, currencies, transactions, settings). Rates are strings; export monetary integers as decimal strings to survive tools that coerce JSON numbers to IEEE doubles. Schema and backup format versions are separate.

Read a size-limited file (initial limit 25 MiB), parse into validated objects, reject unsupported future versions, duplicates, malformed IDs/dates/rates/amounts/settings, dangling references, category/type mismatch, missing/invalid MYR and incorrect saved MYR conversions. Historical references to archived rows are allowed. Recompute using the specified rounding policy; do not trust totals or row counts. No writes during preview.

Restore: serialize writes; offer a safety export and honor cancellation/failure; require explicit Replace All confirmation; one Drift transaction deletes child rows first, replaces parents/settings, then inserts transactions and runs integrity checks. Preserve/update the protected MYR row rather than deleting it; do not disable foreign keys. Any failure rolls back. Refresh reactive queries only after commit. Export reads a consistent database snapshot. Do not copy a live SQLite file (including WAL) as the JSON backup.

## Privacy and platform behavior

Use private Application Support/ledger storage, a background database isolate, and OS device encryption/sandboxing. SQLite and version-1 JSON backups are not separately encrypted. Export UI must disclose that backups contain readable financial data; native save/share destinations may be cloud-backed at the user's choice. No broad storage or network permissions in release.

Exclude internal ledger and temporary exports from Android cloud backup and device transfer via manifest/rules, and from iOS backups via resource values; apply iOS file protection. These controls require device verification and cannot promise protection from rooted devices or forensic access. Device loss/uninstall can lose all data without a manual backup. App-level encryption/biometrics/password-protected backups are later scope, requiring key recovery decisions.

## Implementation phases and acceptance

1. Foundation: Android/iOS scaffold, dependency resolution/lockfile, theme, state-preserving four-tab shell, explicit future-feature placeholders, lazy private SQLite connection, schema v1/defaults/constraints, startup failure/retry, exported schema, foundation tests.
2. Categories/currencies: reactive lists, validated editors, archive/delete policy, MYR protection, manual rates, referenced precision/type rules; repository and widget tests.
3. Money/transactions: pure parsing/conversion/formatting, CRUD editor and detail/list, original currency and snapshots, explicit conversion edits, date semantics, restart persistence; financial boundary/property tests.
4. Dashboard/reports: checked exact aggregation in MYR, date boundaries, empty/error states, search/filters, accessible charts; aggregation and filter tests.
5. Backup/restore: codec/validation/preview, native save/share/pick, safety copy, Replace All transaction, rollback and malformed-file tests on Android/iOS.
6. Release: widget/integration tests, migration paths, accessibility/text scaling, physical-device offline/restart/backup tests, signing, identifiers, icons, privacy disclosures and store preparation.

Version 1 initialization is not an upgrade migration. Future versions require retained schema snapshots, explicit ordered migrations and tests for each supported upgrade path. Never reset a user's database on a migration/open error.

## Current implementation status

Phases 1–5 have source implementations, and Phase 6 host verification/release
preparation is implemented. Dependencies resolved together; the lockfile, real
Drift database, v1 snapshot and historical test helper are present. Native build
and device acceptance remains pending. Phase 5 adds strict JSON export/import, native save/share,
read-only preview, an explicit Replace All confirmation, default safety save,
transactional replacement and generation-aware write serialization. All category,
currency, transaction and appearance writes participate in the database gate.
Historical rate strings and original minor units are preserved; the base MYR row
is updated without deletion and foreign keys remain enabled. Successful restore
refreshes table streams, discards old navigation/forms/filters and applies the
saved theme. Cancelled/failed safety save leaves the current ledger intact.

The v1 JSON contract exports amounts, audit milliseconds and sort_order as decimal
strings; flags are booleans, precision/counts/version fields are small integers.
It requires theme_mode, rejects unknown extensions/duplicates, and supports up to
25 MiB / 100,000 rows per table. Pure parsing/validation/encoding run off the UI
isolate. Temporary share files remain in OS cache for lazy recipients, with owned
files older than 24 hours removed on the next share. Sharing is not proof of
durable backup storage and cannot serve as the restore safety-save callback.

Verification: **194 full Flutter tests**, full analysis, schema comparison and
**25 SQLite checks** pass with the real declared dependencies. This supersedes
the earlier diagnostic/stub-only results. Added v1 baseline/future-version refusal
tests, strict missed-tap checking, and a full real-Drift restore/navigation/theme
widget test. Native backup-file/reopen integration is written and not executed.

Phase 6 also adds stable-Flutter CI, lockfile/schema consistency checks, source
permission/privacy/version checks, private Android release-signing configuration
without debug-key fallback, an app-owned iOS file-metadata privacy manifest and
Settings About/licenses. No keys, signing identities or store publication were
created. Identifiers/icons are still templates.

The local SDK reports 3.48.0-0.5.pre; official stable-SDK and Android/iOS builds,
native file dialogs/share sheets, device persistence/interruption, OS backup
controls and accessibility QA are release gates. Full Xcode and Android SDK are
unavailable here. CI has been prepared, not executed remotely.
See [Phase 6 details](PHASE_6_RELEASE.md), [privacy behavior](PRIVACY.md),
[progress](PROGRESS.md) and README for commands and the acceptance work remaining.

## Startup/storage follow-up

Initialization now completes a consistent, read-only health check for required
schema objects/column names, SQLite quick_check, foreign-key enforcement/existing
references, MYR and theme settings. Failures preserve data and block ledger
navigation; they never auto-repair or reseed. The native private-directory bridge
rejects invalid paths and has no fallback to public storage. Twenty-one new
regression tests bring the real Flutter suite to 194. No dependency or schema
version changed. See [startup/storage notes](STARTUP_STORAGE.md) for file paths,
performance and validation limits. Recovery into a database that cannot open is
not yet implemented; this requires a separate, explicit original-file-preserving
workflow. Native/stable-SDK release gates remain unchanged.
