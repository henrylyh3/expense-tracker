"""Regenerate the bundled, offline ISO currency templates (no rates)."""
import json
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ISO_URL = 'https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml'
SYMBOL_URL = 'https://api.frankfurter.dev/v2/currencies'
FRIENDLY = {'JPY': 'Japanese Yen', 'KRW': 'South Korean Won', 'THB': 'Thai Baht', 'IDR': 'Indonesian Rupiah'}


def literal(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def main():
    root = ET.fromstring(urllib.request.urlopen(ISO_URL, timeout=30).read())
    symbols = {r['iso_code']: r.get('symbol') for r in json.load(urllib.request.urlopen(SYMBOL_URL, timeout=30))}
    rows = {}
    for row in root.iter('CcyNtry'):
        code, precision = row.findtext('Ccy'), row.findtext('CcyMnrUnts')
        if not code or not (precision or '').isdigit():
            continue  # No defined monetary precision: metals, test/non-currency codes.
        name = FRIENDLY.get(code, ' '.join(row.findtext('CcyNm').split()))
        symbol = symbols.get(code) or code
        if not symbol.strip() or len(symbol) > 12:
            symbol = code
        rows[code] = (name, symbol, int(precision))
    header = f'''/// Bundled ISO 4217 monetary templates; no runtime catalogue download.
/// SIX List One published {root.attrib['Pblshd']}; symbols from Frankfurter.
/// Source: {ISO_URL}
/// Regenerate: python tool/update_currency_catalog.py
class CurrencySuggestion {{
  const CurrencySuggestion(this.code, this.name, this.symbol, this.decimalPlaces);
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
}}

const currencyCatalog = [
'''
    lines = [f'  CurrencySuggestion({literal(code)}, {literal(name)}, {literal(symbol)}, {precision}),' for code, (name, symbol, precision) in sorted(rows.items())]
    (ROOT / 'lib/core/money/currency_catalog.dart').write_text(header + '\n'.join(lines) + '\n];\n', encoding='utf-8')
    print(f'Bundled {len(rows)} monetary currencies, sorted by code; ISO publication {root.attrib["Pblshd"]}.')


if __name__ == '__main__':
    main()
