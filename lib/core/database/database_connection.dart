import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'private_storage.dart';
import 'ledger_storage.dart';
import 'dart:io';

QueryExecutor openDatabaseConnection() => driftDatabase(
  name: 'expense_tracker',
  native: DriftNativeOptions(
    databasePath: () async => LedgerStorage(
      Directory(await prepareLedgerDirectory()),
    ).activeDatabasePath(),
  ),
);
