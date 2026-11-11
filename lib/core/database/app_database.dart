import 'package:drift/drift.dart';

import 'database_connection.dart';
import 'seed_data.dart';
import 'ledger_write_gate.dart';
import 'database_health.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'tables/ledger.drift'})
class AppDatabase extends _$AppDatabase {
  final _writeGate = LedgerWriteGate();
  AppDatabase() : super(openDatabaseConnection());

  /// Recovery supplies a separate background executor for a staged ledger.
  AppDatabase.withExecutor(super.executor);

  /// Tests inject SQLite without invoking platform-specific storage APIs.
  AppDatabase.forTesting(super.executor);

  Future<T> writeTransaction<T>(Future<T> Function() action) =>
      _writeGate.write(() => transaction(action));

  Future<T> exclusiveLedgerOperation<T>(Future<T> Function() action) =>
      _writeGate.exclusive(action);
  void markLedgerRestored() => _writeGate.restored();

  Future<void> resetLedger() => exclusiveLedgerOperation(() async {
    await transaction(() async {
      for (final table in [
        'shared_pending',
        'shared_receipts',
        'shared_sessions',
        'transactions',
        'trip_rates',
        'currency_rates',
        'trips',
        'categories',
        'app_settings',
      ]) {
        await customStatement('DELETE FROM $table');
      }
      await customStatement("DELETE FROM currencies WHERE code <> 'MYR'");
      await seedDatabase(this);
      await _seedPersonalTrip();
    });
    markLedgerRestored();
    notifyUpdates({
      for (final table in allTables) TableUpdate(table.actualTableName),
    });
  });

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await seedDatabase(this);
      await _seedPersonalTrip();
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= 7 || to != 7) {
        throw UnsupportedError('No migration from schema $from to $to.');
      }
      await transaction(() async {
        if (from < 5) {
          await migrator.createTable(sharedSessions);
          await migrator.createTable(sharedPending);
          await migrator.createTable(sharedReceipts);
        }
        if (from < 4) {
          await migrator.createTable(currencyRates);
          if (from >= 2) {
            if (from == 2) await migrator.addColumn(tripRates, tripRates.name);
            await migrator.addColumn(tripRates, tripRates.rateId);
          } else {
            await migrator.createTable(trips);
            await migrator.createTable(tripRates);
            await _seedPersonalTrip();
            await migrator.addColumn(transactions, transactions.tripId);
            await customStatement(
              'CREATE INDEX transactions_trip_date_idx ON transactions(trip_id, transaction_date DESC, id)',
            );
          }
          await customStatement(
            '''INSERT INTO currency_rates (id, currency_code, name, rate_to_myr)
          SELECT 'trip:' || r.trip_id || ':' || r.currency_code, r.currency_code,
            COALESCE(r.name, c.name), r.rate_to_myr
          FROM trip_rates r JOIN currencies c ON c.code = r.currency_code''',
          );
          await customStatement(
            "UPDATE trip_rates SET rate_id = 'trip:' || trip_id || ':' || currency_code",
          );
        }
        if (from < 6) {
          await migrator.addColumn(
            transactions,
            transactions.amountDecimalPlaces,
          );
        }
        await migrator.addColumn(transactions, transactions.submittedByGuest);
        await customStatement('''
          UPDATE transactions AS t SET submitted_by_guest = s.name
          FROM shared_receipts r JOIN shared_sessions s ON s.id = r.session_id
          WHERE r.transaction_id = t.id
            AND s.role = 'host' AND s.trip_id = t.trip_id
        ''');
      });
    },
    beforeOpen: (details) async {
      // This pragma must run outside the completed migration transaction.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedPersonalTrip() => customStatement(
    "INSERT INTO trips (id, name) VALUES ('personal', 'Personal')",
  );

  Future<void> initialize() async {
    // Opening/migrations finish before starting the read-only health snapshot.
    await customSelect('SELECT 1').getSingle();
    await verifyLedgerHealth(this);
  }
}
