# Currency templates and amount entry

The app bundles 165 current ISO 4217 monetary codes with defined minor units, using SIX List One published 2026-09-17. Precious-metal, testing and non-currency codes with no defined minor unit are not monetary templates. Users can still type a custom three-letter code.

The catalogue is available offline. Search accepts currency code or name, case-insensitively; all results and configured currencies are ordered by currency code. Names and symbols populate the new-currency form, and the existing one-time Frankfurter lookup supplies an editable reference rate where supported.

No decimal-places control is exposed. Templates retain standard formatting metadata internally, while foreign expense entry accepts up to six decimal places regardless of a currency's conventional minor unit. For example, JPY 100.50 can be entered and saved exactly. MYR input and totals remain at two decimal places. Exchange rates remain independently precise to twelve fractional digits. Existing per-code formatting metadata is retained when adding another named record, including legacy configurations that differ from the current ISO template.

Each expense stores the precision needed to interpret its integer amount. Database schema 6 adds a nullable amount_decimal_places column: old rows keep their original currency scale through a null fallback, so migration neither rescales nor rewrites existing amounts. Mixed-scale original-currency totals align units exactly before summing. JSON backup schema 5 includes the new field; schemas 1–4 remain importable. Older app versions cannot import schema 5 backups. Shared fractional expenses require an updated host.

New and renamed currency records require unique names across configured base and named records, including archived entries. Comparison ignores case and repeated whitespace. The check runs inside the write transaction as well as the form. Existing historical duplicate names remain editable when unchanged; imports do not rename old records. Multiple records with the same code remain supported when their names differ.

Regenerate templates with `python tool/update_currency_catalog.py`, then format the Dart output and verify tests. SIX supplies codes/names/minor units; Frankfurter supplies symbols where available, with currency code as the fallback symbol.

Sources:
- https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml
- https://api.frankfurter.dev/v2/currencies
