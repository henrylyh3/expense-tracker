# Reference rate prefill

When adding a new currency or named rate record, choosing a template or finishing a three-letter code requests the latest available rate for that currency to MYR from Frankfurter's HTTPS v2 single-pair endpoint. MYR remains fixed at 1 and needs no request.

The form fills the rate and shows the provider's observation date. Frankfurter supplies daily reference rates, which can differ from a card or money changer's actual rate. The value is editable before saving. Rate tokens are parsed as decimal values, rounded half up to the ledger's supported 12 fractional digits, and validated as positive rates. The bundled templates are searchable by code or name and sorted by code; see [CURRENCY_CATALOG.md](CURRENCY_CATALOG.md). There is no decimal-places setting, and foreign expense entry can retain up to six decimal places regardless of the template's standard formatting metadata.

This is a creation-time suggestion only. Existing currency records are not fetched when opened for editing, and saved currency/trip rates and transaction snapshots do not refresh over time. Reusing a currency code for a new named record fetches a fresh suggestion for that new record. Names such as THB 2025 do not select a historical quote; enter the intended historical or actual exchange rate manually.

Changing the selected currency ignores any pending response for the previous code. Typing a manual rate prevents an in-flight response from overwriting it. Failed, unsupported, offline or invalid responses leave manual entry available with an explicit retry action. Lookup does not lock the form or perform any ledger write; Save still uses the normal validated currency repository.

Requests send only the requested currency pair, require no API key and do not include ledger data. Service documentation: https://frankfurter.dev/.
