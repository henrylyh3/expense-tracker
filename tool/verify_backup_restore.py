"""Run emitted production Dart restore SQL against the actual SQLite schema.

  dart run tool/emit_test_restore_plan.dart | python3 tool/verify_backup_restore.py
Only synthetic fixtures and an in-memory database are used.
"""
import json
from pathlib import Path
import sqlite3
import sys
import unittest

SCHEMA = (Path(__file__).resolve().parents[1] / 'lib/core/database/tables/ledger.drift').read_text()
PLANS = json.load(sys.stdin.buffer)
TABLES = {'categories': 'categories', 'currencies': 'currencies', 'transactions': 'transactions', 'settings': 'app_settings', 'trips': 'trips', 'trip_rates': 'trip_rates', 'currency_rates': 'currency_rates'}


class BackupRestoreChecks(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript(SCHEMA)
        self.db.execute("INSERT INTO trips VALUES ('personal', 'Personal')")
        self.db.execute("INSERT INTO currencies VALUES ('MYR','Old Ringgit','RM',2,'1',1,0,0)")
        self.db.execute("INSERT INTO categories VALUES ('old','Old category','expense','restaurant','#123456',0,0)")
        self.db.execute("INSERT INTO app_settings VALUES ('theme_mode','system')")
        self.db.execute("INSERT INTO transactions (id, category_id, type, amount_minor, currency_code, exchange_rate_snapshot, amount_myr_minor, transaction_date, note, created_at_utc, updated_at_utc, trip_id) VALUES ('00000000-0000-4000-8000-000000000000','old','expense',100,'MYR','1',100,'2026-01-01','Old data',0,0, 'personal')")

    def tearDown(self):
        self.db.close()

    def snapshot(self):
        return {name: sorted([dict(row) for row in self.db.execute(f'SELECT * FROM {table}')], key=str)
                for name, table in TABLES.items()}

    def restore(self, name):
        self.db.execute('BEGIN')
        try:
            for write in PLANS[name]['plan']:
                self.db.execute(write['sql'], write['arguments'])
            self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(), [])
            self.db.execute('COMMIT')
        except BaseException:
            self.db.execute('ROLLBACK')
            raise

    def test_replace_all_matches_validated_rows(self):
        self.restore('normal')
        self.assertEqual(self.snapshot(), {key: sorted(rows, key=str) for key, rows in PLANS['normal']['tables'].items()})
        self.assertEqual(self.db.execute('SELECT exchange_rate_snapshot FROM transactions').fetchone()[0], '4.5000')
        self.assertEqual(self.db.execute("SELECT rate_to_myr FROM currencies WHERE code='USD'").fetchone()[0], '4.70')
        self.assertEqual(self.db.execute('PRAGMA foreign_keys').fetchone()[0], 1)

    def test_late_failure_rolls_back_every_table(self):
        before = self.snapshot()
        self.db.execute("CREATE TRIGGER reject_restore BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        with self.assertRaises(sqlite3.IntegrityError):
            self.restore('normal')
        self.assertEqual(self.snapshot(), before)

    def test_empty_backup_does_not_reseed(self):
        self.restore('empty')
        self.assertEqual(self.db.execute('SELECT count(*) FROM categories').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT count(*) FROM transactions').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT value FROM app_settings').fetchone()[0], 'dark')

    def test_full_int64_survives_bound_arguments(self):
        self.restore('maximum')
        self.assertEqual(self.db.execute('SELECT amount_minor, amount_myr_minor FROM transactions').fetchone()[:], (2**63-1, 2**63-1))

    def test_myr_protection_survives_restore(self):
        self.restore('normal')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM currencies WHERE code='MYR'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE currencies SET rate_to_myr='2' WHERE code='MYR'")


if __name__ == '__main__':
    unittest.main()
