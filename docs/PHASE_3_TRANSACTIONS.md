# Phase 3 — exact money and transaction management

Current verification is recorded in [Phase 6](PHASE_6_RELEASE.md). Dependencies,
real Drift generation and the full Flutter suite now pass; the verification
notes below retain the results available when this phase was implemented.

Source implemented on 2026-11-05. The financial/domain tests pass; actual Drift
execution, Flutter widget execution and device builds remain pending for the
[documented tooling reasons](PROGRESS.md). The database schema is still version 1:
this phase uses the original transaction columns and does not modify tables.

## Money policy

`Money` always carries original minor units, a currency code and explicit decimal
precision. `parsePositive` rejects zero/negative amounts, signs, grouping,
scientific notation and excess fractional digits—even trailing extra zeros.
MYR/USD 12.50 become 1250; JPY 500 becomes 500; KRW 15000 becomes 15000.

Inputs are parsed with BigInt before conversion to native Dart int, checking the
SQLite signed 64-bit range. Original transactions must be positive; a converted
MYR amount may round to zero. Generic Money values allow signed amounts for later
net-flow reporting. Aggregate overflow checks remain Phase 4 work.

Rates are validated/canonicalized with `decimal`. Conversion uses exact BigInt
numerator/denominator scaling:

```text
numerator = amount_minor × rate_coefficient × 100
denominator = 10^(original_precision + rate_fractional_digits)
MYR minor = quotient + 1 when 2 × remainder >= denominator
```

This applies round-half-up once, at MYR sen precision, without intermediate
rounding or floating-point division. `decimal/intl.dart` formats exact Decimal
values with intl; tests cover formatting at both signed 64-bit boundaries. Editor
values use an ungrouped, dot-decimal representation. History uses currency codes
for unambiguous foreign amounts and RM for MYR.

## Saved conversion behavior

| Operation | Rate and MYR behavior |
| --- | --- |
| New transaction | Uses the current configured rate, unless explicitly overridden |
| Edit notes, date, category or type without changing amount/currency | Retains the stored rate string and MYR amount exactly |
| Edit amount only | Recalculates MYR using the saved historical rate |
| Explicitly edit the rate / use current configured rate | Recalculates MYR using that explicitly chosen rate |
| Change currency | Requires explicit confirmation and an explicit rate value; uses the new currency precision |
| Change a configured default rate | No existing transaction rows are updated |

The currency-change checkbox confirms the conversion shown in the editor. That
rate is passed explicitly, rather than reading a potentially newer default after
confirmation. MYR is always precision 2 with rate 1.

## Persistence and safety

TransactionRepository validates current parent rows and writes within one Drift
transaction. Categories must match the income/expense type. New references must
be active. A historical transaction may retain its own archived category/currency;
it cannot switch to a different archived item. Used currency precision is protected
by the existing schema and management repository.

Create saves a UUID v4 ID, original amount/code, rate snapshot, MYR equivalent,
calendar date, optional notes and UTC audit milliseconds. Notes are trimmed,
optional and limited to 2000 Unicode code points; multiline notes are supported.
CalendarDate validates real YYYY-MM-DD dates, including leap years, without time
zone conversion. Only audit fields represent UTC instants.

Edit/delete require the `updated_at_utc` value the user originally opened. The
repository rejects stale revisions before changing data. Successful edits retain
creation time and strictly increase the update timestamp, including same-millisecond
saves or a backwards device clock. The editor retains its initial revision and
input across stream updates, preventing background refreshes from authorizing an
unseen overwrite. Cancel/reopen an editor to reload after a revision conflict.

Custom writes declare their affected tables, and reactive reads declare transaction,
category and currency dependencies. History and usage counts update after commit.
No list invalidation is needed after successful transaction writes.

## User flow and navigation

- The global Add Transaction action opens the real editor. New entries default to
  Expense/MYR and require an explicit category selection.
- The editor offers type/category/currency, exact amount input, date picker, notes,
  live MYR preview and explicit conversion edits. Changing currency clears its
  confirmation. Archived items appear only when they are the original selections.
- Saving a new entry opens its details; saving an edit returns to details.
- History displays date, type, category, original currency amount and foreign
  transactions' saved MYR equivalent. It loads 100 records initially and offers
  Load more with a one-row look-ahead. Rows are built lazily; current data is retained
  while the next batch loads. Search/filter controls arrive in Phase 4.
- Detail shows the original amount, saved rate, MYR equivalent and notes. Delete
  requires confirmation and checks the current revision before removing the row.
- Empty, loading, safe error/retry and missing-transaction states are included.
  Editor dismissal and repeated actions are blocked during a write.

Routes: `/transactions/new`, `/transactions/:id`, `/transactions/:id/edit`.

## Main files

| Path | Purpose |
| --- | --- |
| lib/core/money/money.dart | Exact parsing, bounds, editor representation and formatting |
| lib/core/money/currency_converter.dart | Exact MYR conversion and explicit half-up rounding |
| lib/core/dates/calendar_date.dart | Calendar-only validation and date-picker conversion |
| lib/features/transactions/domain/conversion_policy.dart | New/edit snapshot rules |
| lib/features/transactions/domain/transaction_input.dart | Validated transaction input and notes |
| lib/features/transactions/domain/ledger_transaction.dart | History/detail projection |
| lib/features/transactions/data/transaction_repository.dart | Atomic CRUD, parent/revision validation and reactive queries |
| lib/features/transactions/presentation/transaction_view_model.dart | Riverpod queries, history limit and action state |
| lib/features/transactions/presentation/transaction_editor_screen.dart | Editor and conversion confirmation |
| lib/features/transactions/presentation/transaction_detail_screen.dart | Detail, edit and confirmed delete |
| lib/features/transactions/presentation/transactions_screen.dart | Reactive incremental History list |
| test/core/money/money_test.dart | 18 exact money/date/edit-policy tests |
| test/features/transactions/ | 12 repository and 4 editor widget tests |
| integration_test/transaction_persistence_test.dart | Native financial row persistence across database reconnects, with isolated fixture cleanup |

## Verification and next steps

- Passed all 18 new domain tests using the same temporary Dart runner adapter as
  Phase 2; production logic/assertions unchanged, only flutter_test import adapted.
- Existing 20 SQLite schema tests pass; 25 SQL statements across all three feature
  repositories prepare against the actual schema. This does not execute Drift.
- Isolated app/model/UI/view-model analysis passes using cached GoRouter 17.5.0
  and temporary database/repository stubs. The project retains declared 18.1.3.
- Twelve real Drift transaction tests and four editor widget tests are written;
  generated-code compilation/execution and mobile integration remain unverified.

When the environment supports package access and Flutter tests:

```sh
bash tool/check.sh
flutter test test/core/money/ test/features/transactions/
flutter test integration_test/foundation_test.dart -d <device-id>
flutter test integration_test/transaction_persistence_test.dart -d <device-id>
```

Device QA must include force-stop/reopen persistence, keyboard and large-text
layouts, default-rate edits followed by historical transaction edits, archived
references, currency-change confirmation, stale saves and deletion recovery.
Phase 4 adds dashboard/report aggregation, search and filters.
