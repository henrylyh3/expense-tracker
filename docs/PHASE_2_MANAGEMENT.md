# Phase 2 — category and currency management

Current verification is recorded in [Phase 6](PHASE_6_RELEASE.md). Dependencies,
real Drift generation and the full Flutter suite now pass; the verification
notes below retain the results available when this phase was implemented.

Source implemented on 2026-11-05. Database integration/widget execution and device
validation remain pending because of the [recorded tooling restrictions](PROGRESS.md).
Schema version remains 1; this phase does not alter the initial table definitions.

## Category behavior

Settings → Manage categories opens income/expense filter chips, active categories,
an optional archived filter and Add category. Editors support names, stable named
icons, a palette and custom #RRGGBB colors. Unknown historical icon keys display a
fallback; icons use named constants so release icon tree shaking is retained.

- New categories receive UUID v4 IDs and an appended sort order.
- Names are trimmed, at most 80 characters, and unique ignoring case within their
  income/expense type. Archived rows also participate in duplicate checks; restore
  or edit them rather than creating an indistinguishable duplicate.
- Delete checks live transaction references inside the same database transaction
  as the write: unused rows are deleted; referenced rows are archived.
- Archived rows can be edited/restored. The later transaction editor must exclude
  them from new selections while preserving historical display.
- Categories with references cannot change type. Name, icon and color remain
  editable and update the historical display metadata.

## Currency behavior

Settings → Manage currencies displays MYR first, each configured rate, precision,
usage and archive state. The editor supports a suggested template or a custom
three-letter code. Templates fill names/symbols/precision, leaving the rate empty
for explicit manual entry. USD/JPY/KRW/SGD/EUR/THB/TWD/IDR are suggestions only.

- Codes are trimmed and uppercased. Name/symbol limits are 80/12 Unicode code points.
- Precision is 0–6; JPY/KRW templates use 0, USD uses 2.
- Rates must be positive decimal strings with up to 12 integer and 12 fractional
  digits, without exponents or grouping. `decimal` normalizes `4.5000` to `4.5`;
  no rate is parsed through double.
- MYR is fixed to code MYR, precision 2 and rate 1. Its name/symbol can be edited.
  Delete/archive actions are absent in the UI and rejected by the repository.
- Referenced currencies cannot change code/precision. These fields are locked in
  the editor and independently protected by repository checks and schema triggers.
- Unused currency codes/precision can be edited, subject to uniqueness.
- Rate/metadata edits do not update any transaction rows. Creation time and archive
  state are preserved. Updated timestamps never go backwards when the device clock
  moves backwards.
- Delete archives used currencies and deletes unused ones. Restore reactivates an
  archived currency with its configured manual rate. Historical snapshots are retained.

## Files and architecture

| Files | Responsibility |
| --- | --- |
| lib/core/models/ledger_types.dart | Shared transaction type, removal result, safe domain errors |
| lib/core/validation/input_validation.dart | Shared metadata/form validation |
| lib/core/money/exchange_rate.dart | Exact positive decimal rate parsing/normalization |
| lib/core/money/currency_catalog.dart | Currency suggestions without assumed rates |
| lib/features/categories/domain/ledger_category.dart | Management projection and validated category draft |
| lib/features/categories/data/category_repository.dart | Atomic writes, reference counts, duplicate/type rules, reactive query |
| lib/features/categories/presentation/ | Stream provider, AsyncNotifier actions, list/filter screen and editor |
| lib/features/currencies/domain/configured_currency.dart | Currency management projection and validated currency draft |
| lib/features/currencies/data/currency_repository.dart | Atomic writes, MYR/identity rules, snapshots preserved, reactive query |
| lib/features/currencies/presentation/ | Providers, action state, currency list and editor |
| lib/shared/widgets/management_widgets.dart | Keyboard-aware editor layout, confirmation and safe feedback |
| lib/shared/widgets/category_appearance.dart | Stable icon lookup and color presentation |
| test/features/settings/ | Domain, repository and widget tests |

StreamProviders observe Drift query streams. Custom SELECTs declare both their
management table and transactions as dependencies so usage counts update when a
transaction is added/deleted. Custom writes identify affected tables and update
kinds so Drift invalidates streams after commit. No manual list refresh is needed
after successful CRUD. Widgets do not execute SQL.

AsyncNotifiers coordinate actions and expose saving/error state. Repeated writes
are guarded while an operation is running; editor dismissal is blocked during
save. Validation is shared with forms, and database errors are shown as generic
feedback rather than exposing SQL, paths or financial values.

## Tests and acceptance

| Check | Status |
| --- | --- |
| 10 pure domain tests | Passed using the temporary Dart runner adapter; actual domain logic and assertions unchanged |
| 20 schema tests | Passed against the current ledger.drift source |
| Repository SQL preparation | All 16 extracted SELECT/INSERT/UPDATE/DELETE statements prepared successfully against SQLite schema; syntax check only |
| UI/domain/view-model static analysis | Passed in isolation; cached GoRouter 17.5.0, database and repository stubs |
| 9 real-Drift repository tests | Written, not executed; packages/code generation unavailable |
| 3 management widget tests and updated navigation tests | Written and analyzed in isolation; not executed due Flutter runner socket restriction |
| Full app analysis, code generation and Android/iOS builds | Pending |

Run the normal checks when the development environment supports packages/tests:

```sh
bash tool/check.sh
flutter test test/features/settings/
```

Device review should cover add/edit/delete of unused items, used-item archive and
restore, MYR field protection, new USD manual rate entry, JPY/KRW zero precision,
form error recovery, keyboard/text scaling and persistence after a force-stop.
Reference-dependent flows can currently be exercised by repository tests; the
transaction UI will arrive in Phase 3.
