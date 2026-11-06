"""Exercise the actual Drift SQL source using stdlib SQLite (no Flutter needed).

This is an additional schema check, not a replacement for Drift generation,
Flutter tests or mobile builds. Run: python3 tool/verify_sqlite_schema.py
"""

from contextlib import closing
from pathlib import Path
import sqlite3
import tempfile
import unittest


SCHEMA = (Path(__file__).resolve().parents[1] /
          "lib/core/database/tables/ledger.drift").read_text()
TX_ID = "123e4567-e89b-42d3-a456-426614174000"


def initialize(connection):
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript(SCHEMA)
    connection.execute("INSERT INTO currencies VALUES ('MYR', 'Ringgit', 'RM', 2, '1', 1, 0, 0)")
    connection.execute("INSERT INTO currencies VALUES ('USD', 'Dollar', '$', 2, '4.5', 1, 0, 0)")
    connection.execute("INSERT INTO categories VALUES ('food', 'Food', 'expense', 'restaurant', '#EF6C00', 0, 0)")
    connection.execute("INSERT INTO categories VALUES ('salary', 'Salary', 'income', 'payments', '#2E7D32', 1, 0)")
    connection.commit()


class LedgerSchemaTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        initialize(self.db)

    def tearDown(self):
        self.db.close()

    def insert(self, **changes):
        values = dict(id=TX_ID, category_id="food", type="expense",
                      amount_minor=1250, currency_code="USD",
                      exchange_rate_snapshot="4.5", amount_myr_minor=5625,
                      transaction_date="2026-11-05", note=None,
                      created_at_utc=0, updated_at_utc=0)
        values.update(changes)
        self.db.execute(
            f"INSERT INTO transactions ({','.join(values)}) "
            f"VALUES ({','.join('?' for _ in values)})", list(values.values()))

    def test_original_currency_and_snapshot_are_preserved(self):
        self.insert()
        self.db.execute("UPDATE currencies SET rate_to_myr = '4.7' WHERE code = 'USD'")
        row = self.db.execute("SELECT amount_minor, currency_code, exchange_rate_snapshot, amount_myr_minor FROM transactions").fetchone()
        self.assertEqual(row, (1250, "USD", "4.5", 5625))

    def test_foreign_keys_are_enabled(self):
        self.assertEqual(self.db.execute("PRAGMA foreign_keys").fetchone()[0], 1)
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert(currency_code="JPY")

    def test_category_reference_and_type_are_required(self):
        for changes in [dict(category_id="missing"), dict(type="income")]:
            with self.subTest(changes=changes), self.assertRaises(sqlite3.IntegrityError):
                self.insert(**changes)

    def test_editing_type_must_match_category(self):
        self.insert()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE transactions SET type = 'income'")
        self.db.execute("UPDATE transactions SET type = 'income', category_id = 'salary'")

    def test_referenced_parents_cannot_be_deleted(self):
        self.insert()
        for sql in ["DELETE FROM categories WHERE id = 'food'",
                    "DELETE FROM currencies WHERE code = 'USD'"]:
            with self.subTest(sql=sql), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_unreferenced_parents_can_be_deleted(self):
        self.db.execute("DELETE FROM currencies WHERE code = 'USD'")
        self.db.execute("DELETE FROM categories WHERE id = 'food'")

    def test_archiving_preserves_history(self):
        self.insert()
        self.db.execute("UPDATE categories SET is_archived = 1 WHERE id = 'food'")
        self.db.execute("UPDATE currencies SET is_active = 0 WHERE code = 'USD'")
        self.assertEqual(self.db.execute("SELECT count(*) FROM transactions").fetchone()[0], 1)
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_restore_accepts_archived_historical_references(self):
        self.db.execute("UPDATE categories SET is_archived = 1 WHERE id = 'food'")
        self.db.execute("UPDATE currencies SET is_active = 0 WHERE code = 'USD'")
        self.insert()

    def test_used_currency_cannot_change_precision_or_code(self):
        self.insert()
        for sql in ["UPDATE currencies SET decimal_places = 0 WHERE code = 'USD'",
                    "UPDATE currencies SET code = 'USX' WHERE code = 'USD'"]:
            with self.subTest(sql=sql), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_unused_currency_can_change_precision_and_code(self):
        self.db.execute("UPDATE currencies SET code = 'JPY', decimal_places = 0 WHERE code = 'USD'")

    def test_used_category_cannot_change_type(self):
        self.insert()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE categories SET type = 'income' WHERE id = 'food'")

    def test_myr_is_protected(self):
        for sql in ["DELETE FROM currencies WHERE code = 'MYR'",
                    "UPDATE currencies SET code = 'XYZ' WHERE code = 'MYR'",
                    "UPDATE currencies SET rate_to_myr = '2' WHERE code = 'MYR'",
                    "UPDATE currencies SET decimal_places = 0 WHERE code = 'MYR'",
                    "UPDATE currencies SET is_active = 0 WHERE code = 'MYR'"]:
            with self.subTest(sql=sql), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_myr_transaction_must_have_identity_conversion(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert(currency_code="MYR")
        self.insert(currency_code="MYR", exchange_rate_snapshot="1", amount_myr_minor=1250)

    def test_rates_reject_zero_negative_exponents_and_malformed_text(self):
        for rate in ["", "0", "0.000", "-1", "1e2", "1.2.3", ".1", "1.", "01.2", "1,200", "NaN", " 4.5", "1000000000000", "0.0000000000001"]:
            with self.subTest(rate=rate), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("UPDATE currencies SET rate_to_myr = ? WHERE code = 'USD'", [rate])
            with self.subTest(snapshot=rate), self.assertRaises(sqlite3.IntegrityError):
                self.insert(exchange_rate_snapshot=rate)

    def test_small_positive_rate_is_valid(self):
        self.db.execute("UPDATE currencies SET rate_to_myr = '0.000000000001' WHERE code = 'USD'")
        self.insert(exchange_rate_snapshot="0.000000000001", amount_myr_minor=0)

    def test_amounts_reject_nonpositive_fractional_and_overflow_values(self):
        for amount in [0, -1, 1.5, "9223372036854775808"]:
            with self.subTest(amount=amount), self.assertRaises(sqlite3.IntegrityError):
                self.insert(amount_minor=amount)
        with self.assertRaises(sqlite3.IntegrityError):
            self.insert(amount_myr_minor=-1)

    def test_calendar_dates_reject_impossible_days(self):
        for date in ["2026-02-29", "2026-04-31", "2026-13-01", "2026-00-01", "2026-11-00", "2026-1-01", "0000-01-01", "2026-11-05T00:00:00Z"]:
            with self.subTest(date=date), self.assertRaises(sqlite3.IntegrityError):
                self.insert(transaction_date=date)
        self.insert(transaction_date="2024-02-29")

    def test_invalid_currency_precision_and_codes_are_rejected(self):
        for code in ["usd", "US", "USDD", "U1D"]:
            with self.subTest(code=code), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("UPDATE currencies SET code = ? WHERE code = 'USD'", [code])
        for precision in [-1, 7, 2.5]:
            with self.subTest(precision=precision), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("UPDATE currencies SET decimal_places = ? WHERE code = 'USD'", [precision])

    def test_failed_replace_all_rolls_back_original_ledger(self):
        self.insert()
        self.db.commit()
        with self.assertRaises(sqlite3.IntegrityError), self.db:
            self.db.execute("DELETE FROM transactions")
            self.db.execute("DELETE FROM currencies WHERE code <> 'MYR'")
            self.insert(currency_code="BAD")
        self.assertEqual(self.db.execute("SELECT amount_myr_minor FROM transactions").fetchone()[0], 5625)
        self.assertIsNotNone(self.db.execute("SELECT * FROM currencies WHERE code = 'USD'").fetchone())

    def test_file_persistence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.sqlite"
            with closing(sqlite3.connect(path)) as disk:
                initialize(disk)
                disk.execute("INSERT INTO app_settings VALUES ('theme_mode', 'dark')")
                disk.commit()
            with closing(sqlite3.connect(path)) as disk:
                self.assertEqual(disk.execute("SELECT value FROM app_settings").fetchone()[0], "dark")
                self.assertEqual(disk.execute("PRAGMA integrity_check").fetchone()[0], "ok")


if __name__ == "__main__":
    unittest.main(verbosity=2)
