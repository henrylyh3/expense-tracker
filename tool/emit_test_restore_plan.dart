// Synthetic test plan for verify_backup_restore.py, never a user's ledger.
import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/core/backup/backup_validator.dart';
import 'package:expense_tracker/core/backup/restore_plan.dart';

import '../test/support/backup_fixture.dart';

void main() {
  final normal = backupDocument();
  final empty = backupDocument();
  for (final name in ['categories', 'transactions']) {
    empty['data'][name].clear();
    empty['counts'][name] = 0;
  }
  final maximum = backupDocument();
  final row = maximum['data']['transactions'][0];
  row['currency_code'] = 'MYR';
  row['exchange_rate_snapshot'] = '1';
  row['amount_minor'] = row['amount_myr_minor'] = '9223372036854775807';
  stdout.write(
    jsonEncode({
      for (final entry in {
        'normal': normal,
        'empty': empty,
        'maximum': maximum,
      }.entries)
        entry.key: (() {
          final backup = BackupValidator.fromDocument(entry.value);
          return {
            'tables': backup.tables,
            'plan': replacementStatements(backup)
                .map(
                  (write) => {'sql': write.sql, 'arguments': write.arguments},
                )
                .toList(),
          };
        })(),
    }),
  );
}
