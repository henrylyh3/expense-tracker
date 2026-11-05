import 'dart:convert';

/// Synthetic fixtures only; no personal ledger data.
Map<String, dynamic> backupDocument() =>
    jsonDecode(
          jsonEncode({
            'format': 'expense-tracker',
            'format_version': 1,
            'schema_version': 1,
            'app_version': '0.1.0+1',
            'exported_at_utc': '2026-11-05T10:00:00.000Z',
            'base_currency': 'MYR',
            'counts': {
              'categories': 1,
              'currencies': 2,
              'transactions': 1,
              'settings': 1,
            },
            'data': {
              'categories': [
                {
                  'id': 'food',
                  'name': 'Food',
                  'type': 'expense',
                  'icon_key': 'restaurant',
                  'color_hex': '#EF6C00',
                  'sort_order': '0',
                  'is_archived': true,
                },
              ],
              'currencies': [
                {
                  'code': 'MYR',
                  'name': 'Malaysian Ringgit',
                  'symbol': 'RM',
                  'decimal_places': 2,
                  'rate_to_myr': '1',
                  'is_active': true,
                  'created_at_utc': '0',
                  'updated_at_utc': '1',
                },
                {
                  'code': 'USD',
                  'name': 'US Dollar',
                  'symbol': r'$',
                  'decimal_places': 2,
                  'rate_to_myr': '4.70',
                  'is_active': false,
                  'created_at_utc': '0',
                  'updated_at_utc': '1',
                },
              ],
              'transactions': [
                {
                  'id': '12345678-1234-4234-8234-123456789abc',
                  'category_id': 'food',
                  'type': 'expense',
                  'amount_minor': '1250',
                  'currency_code': 'USD',
                  'exchange_rate_snapshot': '4.5000',
                  'amount_myr_minor': '5625',
                  'transaction_date': '2026-11-04',
                  'note': 'Lunch\nNasi lemak 🍚',
                  'created_at_utc': '0',
                  'updated_at_utc': '1',
                },
              ],
              'settings': [
                {'key': 'theme_mode', 'value': 'dark'},
              ],
            },
          }),
        )
        as Map<String, dynamic>;
