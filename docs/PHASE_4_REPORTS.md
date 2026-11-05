# Phase 4 — dashboard, reports and filtered history

Current verification is recorded in [Phase 6](PHASE_6_RELEASE.md). Dependencies,
real Drift generation and the full Flutter suite now pass; the verification
notes below retain the results available when this phase was implemented.

Source implemented on 2026-11-05. Domain and direct SQLite checks pass. Full Drift
execution, actual fl_chart rendering, widget execution and mobile builds remain
pending under the [recorded tooling restrictions](PROGRESS.md). Schema version is
still 1; this phase adds queries and application logic without changing tables.

## Dashboard and reports

Home shows monthly income, expenses and net cash flow, a spending-by-category
breakdown, recent transactions for the selected month and monthly cash-flow trends
for the selected year. Month controls and Current period are available. The year
trend is explicitly labeled so its range is distinct from the monthly totals.

Reports has independent Monthly/Yearly selection. Monthly reports contain daily
trend buckets; yearly reports contain twelve monthly buckets. Empty buckets remain
zero-filled. Switching back from yearly restores the previously selected month.
Category rows open History with expense, category and period constraints applied;
Home's View period history applies just its selected date range.

Financial summaries, category totals and exact trend values are all MYR. Charts
provide comparison while an expandable table exposes exact amounts. Income and
expense legends accompany the bars, and text labels/amounts accompany category
colors. Pie charts use the five largest positive categories plus an Other slice;
the list retains every actual category and its exact amount. Zero spending has an
explicit empty state and never produces a divide-by-zero chart.

## Financial calculation contract

Reports sum only `transactions.amount_myr_minor`. They never use current exchange
rates or add original amounts from different currencies. Archived parent rows remain
included. Category names/colors/icons come from current metadata, grouped by ID.

One date-bounded SQLite result supplies amounts and category metadata. Its rows feed
the pure FinancialReport model for totals, buckets and category grouping. This keeps
each report internally consistent rather than combining independently refreshed
totals/categories queries.

Aggregation uses BigInt and checks signed 64-bit bounds before creating Money values.
SQLite integer SUM could overflow before application validation, and TOTAL would
introduce floating-point money; neither is used. Overflow is rejected even if very
large income and expense totals would cancel to a small net figure. This approach
is linear in rows for the selected month/year and fetches only report-relevant columns.

Only chart coordinates use double. Stored facts, summary values, grouping totals,
labels and exact-value tables retain integer/decimal precision. Zero-sen converted
transactions still contribute to counts, even when no positive chart slice exists.

Report ranges are inclusive at the start and exclusive at the next period's start.
Year 9999/December 9999 use an absent upper bound rather than an incorrectly sorting
five-digit date. Calendar-only comparisons preserve the user's selected day. English
date labels use intl's bundled en_US date symbols and require no initialization or
I/O; MYR money formatting retains the existing exact decimal/intl path.

## History search and filters

- Search covers notes, category name and currency code, with a 300 ms debounce.
- SQL parameters contain all input. `instr(lower(...), lower(?))` performs literal
  substring matching: percent signs, underscores and SQL-looking text are not
  wildcard/query syntax. SQLite's built-in case behavior applies; Unicode text
  such as Chinese is matched literally, without promising full Unicode case folding.
- Type, category, currency and date bounds combine with AND before ordering/LIMIT.
- Both selected date boundaries are inclusive. Either boundary may be omitted;
  reversed ranges are rejected.
- Category/currency selectors include archived rows for historical searches.
- Changing a query/filter resets incremental loading to 100 records. A matching
  look-ahead row drives Load more. Old data can remain during reload with an explicit
  updating indicator; it is not presented as a settled empty result.
- Clear all cancels pending search work. A delayed search will not overwrite a
  newer external filter selection. Normalization does not strip a user's pending
  space while typing the next word.

Filters/period selections are UI state rather than financial settings. They survive
tab switches but are not persisted as ledger data or added to the backup contract.

## Files

| Path | Purpose |
| --- | --- |
| lib/core/dates/date_labels.dart | Offline English calendar labels |
| lib/features/reports/domain/report_period.dart | Validated month/year ranges and shifting |
| lib/features/reports/domain/financial_report.dart | Exact totals, categories, counts and zero-filled buckets |
| lib/features/reports/data/report_repository.dart | Bounded reactive SQLite report reads |
| lib/features/reports/presentation/report_view_model.dart | Period selection and report/recent providers |
| lib/features/reports/presentation/report_widgets.dart | Summary cards, accessible charts and exact-value tables |
| lib/features/reports/presentation/reports_screen.dart | Monthly/yearly reports and history drill-down |
| lib/features/dashboard/presentation/dashboard_screen.dart | Monthly Home summary, year trend and recent items |
| lib/features/transactions/domain/transaction_filter.dart | Validated immutable filter values |
| lib/features/transactions/data/history_predicate.dart | Pure bound SQL predicate builder |
| lib/features/transactions/data/transaction_repository.dart | Filtering before history pagination |
| lib/features/transactions/presentation/transaction_filter_sheet.dart | Type/category/currency/date controls |
| lib/features/transactions/presentation/transactions_screen.dart | Debounced search, reset and filtered list |
| test/features/reports/ | Domain, real-Drift and widget tests |

Riverpod report families use value-equal ReportPeriod keys, sharing matching reads
between tabs. Category/transaction changes refresh reports; currency-default changes
cannot recalculate history and are not report dependencies. History reads still
observe currency metadata for active/archive display.

## Verification

| Check | Result |
| --- | --- |
| New report/filter/date-label domain tests | 17 passed |
| Combined pure domain regression suite | 45 passed (10 management + 18 money/transactions + 17 reporting) |
| Existing SQLite schema tests | 20 passed |
| Actual Dart predicate builder + SQLite fixtures | 13 scenarios passed before and after archiving: 26 query executions |
| Repository SQL preparation | 27 statements/period-bound variants prepared successfully |
| Isolated source analysis | Passed with cached GoRouter 17.5.0 and temporary database/repository/chart-API stubs; actual library integration excluded |
| New real-Drift repository tests | 10 written, not executed |
| New report/filter widget tests | 3 written and analyzed in isolation, not executed |

The pure suite uses the previously documented temporary Dart test-import adapter.
Predicate checks execute SQL produced by the actual Dart builder against the real
schema/fixture rows, including literal wildcard/SQL text, Unicode text, combined
filters and archived references. They do not replace actual Drift stream tests.
No diagnostic stubs or dependency downgrades were added to the application.

When normal package access and Flutter test execution are available:

```sh
bash tool/check.sh
flutter test test/features/reports/
```

Device QA remains necessary for chart rendering, text scaling, keyboard/filter
interactions, clear/debounce behavior, period/category drill-down and reactive
updates after transaction edits/deletes. The next phase is versioned JSON backup,
preview, safety export and transactional Replace All restore.
