"""Disposable SQL checks and independent financial oracle; not Dart execution."""
import json
import sqlite3
import tempfile
import time
import uuid
from contextlib import closing
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = (ROOT / 'lib/core/database/tables/ledger.drift').read_text()
FIXTURES = [
    ('MYR', '12.50', '1', 1250), ('USD', '12.50', '4.50', 5625),
    ('USD', '10.00', '4.70', 4700), ('JPY', '500', '0.0300', 1500),
    ('KRW', '15000', '0.0035', 5250), ('SGD', '25.50', '3.40', 8670),
    ('KWD', '1.250', '14.25', 1781), ('USD', '0.01', '4.50', 5),
    ('JPY', '1', '0.015', 2), ('MYR', '0.01', '1', 1),
]


def initialize(db):
    db.execute('PRAGMA foreign_keys=ON')
    db.executescript(SCHEMA)
    for code, precision, rate in [('MYR', 2, '1'), ('USD', 2, '4.5'),
                                  ('JPY', 0, '0.03'), ('KRW', 0, '0.0035')]:
        db.execute('INSERT INTO currencies VALUES (?,?,?,?,?,1,0,0)',
                   (code, code, code, precision, rate))
    for category, kind in [('salary', 'income'), ('freelance', 'income'),
                           ('food', 'expense'), ('shopping', 'expense'),
                           ('travel', 'expense'), ('transport', 'expense')]:
        db.execute('INSERT INTO categories VALUES (?,?,?,?,?,0,0)',
                   (category, category, kind, 'payments', '#123456'))
    db.commit()


def insert(db, category, kind, amount, code, rate, myr, date='2026-11-05'):
    db.execute('INSERT INTO transactions VALUES (?,?,?,?,?,?,?,?,?,?,?)',
               (str(uuid.uuid4()), category, kind, amount, code, rate, myr,
                date, 'Synthetic QA only', 0, 0))


def main():
    result = {'scope': 'Actual SQL schema; independent Python oracle; no Flutter execution',
              'sqlite_version': sqlite3.sqlite_version, 'fx_oracle': []}
    for index, (code, amount, rate, expected) in enumerate(FIXTURES, 1):
        actual = int((Decimal(amount) * Decimal(rate) * 100).quantize(
            Decimal('1'), rounding=ROUND_HALF_UP))
        assert actual == expected
        result['fx_oracle'].append({'id': 'FX-%03d' % index, 'code': code,
                                    'expected_minor': expected, 'oracle_minor': actual,
                                    'production_status': 'BLOCKED'})
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'synthetic.sqlite'
        with closing(sqlite3.connect(str(path))) as db:
            initialize(db)
            for row in [('salary', 'income', 500000, 'MYR', '1', 500000),
                        ('freelance', 'income', 10000, 'USD', '4.5', 45000),
                        ('food', 'expense', 5000, 'MYR', '1', 5000),
                        ('shopping', 'expense', 2000, 'USD', '4.5', 9000),
                        ('travel', 'expense', 1000, 'JPY', '0.03', 3000),
                        ('transport', 'expense', 10000, 'KRW', '0.0035', 3500)]:
                insert(db, *row)
            db.commit()
        with closing(sqlite3.connect(str(path))) as db:
            db.execute('PRAGMA foreign_keys=ON')
            totals = dict(db.execute("SELECT type,SUM(amount_myr_minor) FROM transactions WHERE transaction_date >= '2026-11-01' AND transaction_date < '2026-12-01' GROUP BY type"))
            assert totals == {'income': 545000, 'expense': 20500}
            assert totals['income'] - totals['expense'] == 524500
            assert db.execute('SELECT COUNT(*) FROM transactions').fetchone()[0] == 6
            db.execute("UPDATE currencies SET rate_to_myr='4.7' WHERE code='USD'")
            assert db.execute("SELECT amount_myr_minor,exchange_rate_snapshot FROM transactions WHERE category_id='freelance'").fetchone() == (45000, '4.5')
            db.commit()
            before = list(db.execute('SELECT * FROM transactions ORDER BY id'))
            try:
                with db:
                    db.execute('DELETE FROM transactions')
                    insert(db, 'missing', 'expense', 1, 'MYR', '1', 1)
            except sqlite3.IntegrityError:
                pass
            else:
                raise AssertionError('Expected invalid reference rejection')
            assert list(db.execute('SELECT * FROM transactions ORDER BY id')) == before
            result['sql_checks'] = {'persistence': 'PASS', 'controlled_totals_minor': totals,
                                    'net_minor': 524500, 'snapshot_after_rate_edit': 'PASS',
                                    'failed_replacement_rollback': 'PASS'}
            result['performance_sql_only'] = []
            for count in [100, 1000, 10000, 50000]:
                db.execute('DELETE FROM transactions')
                started = time.perf_counter()
                with db:
                    for _ in range(count):
                        insert(db, 'food', 'expense', 1, 'MYR', '1', 1)
                insert_seconds = time.perf_counter() - started
                started = time.perf_counter()
                rows = db.execute('SELECT * FROM transactions ORDER BY transaction_date DESC,id LIMIT 101').fetchall()
                read_seconds = time.perf_counter() - started
                assert len(rows) == min(count, 101)
                assert db.execute('SELECT COUNT(*) FROM transactions').fetchone()[0] == count
                result['performance_sql_only'].append({'rows': count, 'insert_seconds': round(insert_seconds, 4), 'read_101_seconds': round(read_seconds, 4)})
            integrity = db.execute('PRAGMA integrity_check').fetchall()
            references = db.execute('PRAGMA foreign_key_check').fetchall()
            assert integrity == [('ok',)] and not references
            result['sql_checks']['integrity_check'] = integrity
            result['sql_checks']['foreign_key_check'] = references
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
