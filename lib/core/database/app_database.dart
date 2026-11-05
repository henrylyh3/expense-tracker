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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await seedDatabase(this);
    }),
    onUpgrade: (migrator, from, to) async {
      // Add ordered migrations when schemaVersion first increases.
      // Never delete/reset a user's ledger to recover from an upgrade error.
      throw UnsupportedError('No migration from schema $from to $to.');
    },
    beforeOpen: (details) async {
      // This pragma must run outside the completed migration transaction.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> initialize() async {
    // Opening/migrations finish before starting the read-only health snapshot.
    await customSelect('SELECT 1').getSingle();
    await verifyLedgerHealth(this);
  }
}
