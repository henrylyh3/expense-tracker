import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:drift_flutter/drift_flutter.dart';

import '../database/app_database.dart';
import '../database/ledger_storage.dart';
import '../models/ledger_types.dart';
import 'backup_service.dart';
import 'backup_validator.dart';

enum RecoveryStage { preserving, closing, restoring, checking, activating }

class StartupRecoveryService {
  StartupRecoveryService({
    required this.storage,
    required this.closeCurrentDatabase,
    AppDatabase Function(File)? openCandidate,
  }) : _openCandidate = openCandidate ?? _openBackground;
  final Future<LedgerStorage> Function() storage;
  final Future<void> Function() closeCurrentDatabase;
  final AppDatabase Function(File) _openCandidate;
  bool _running = false;

  Future<void> recover(
    ValidatedBackup backup, {
    void Function(RecoveryStage)? onStage,
  }) async {
    if (_running) throw const LedgerException('Recovery is already running.');
    _running = true;
    try {
      final files = await storage();
      onStage?.call(RecoveryStage.preserving);
      // Startup has failed and no ledger UI/writers are active. Capture raw
      // files before close can checkpoint SQLite or remove its sidecars.
      final workspace = await files.preserveOriginals();
      onStage?.call(RecoveryStage.closing);
      await closeCurrentDatabase();
      onStage?.call(RecoveryStage.restoring);
      final candidate = _openCandidate(workspace.databaseFile);
      try {
        await candidate.initialize();
        await BackupService(candidate).restore(backup);
        onStage?.call(RecoveryStage.checking);
        await candidate.initialize();
        // Check data too: exact amounts/rate text/archives/settings round-trip.
        final exported = await BackupValidator.decodeInBackground(
          await BackupService(candidate).exportBytes(),
        );
        if (!await _sameLedgerData(backup, exported)) {
          throw const LedgerException(
            'The recovered ledger did not match the backup.',
          );
        }
      } finally {
        await candidate.close();
      }
      onStage?.call(RecoveryStage.activating);
      await files.activate(workspace);
      // The selector rename is the commit. Nothing fallible follows it here.
    } finally {
      _running = false;
    }
  }
}

AppDatabase _openBackground(File file) => AppDatabase.withExecutor(
  driftDatabase(
    name: 'expense_tracker_recovery',
    native: DriftNativeOptions(databasePath: () async => file.path),
  ),
);

// Rows are scalar JSON-safe values. Sort encoded records so table order is not
// significant, while every original integer and exact rate string is checked.
Future<bool> _sameLedgerData(ValidatedBackup a, ValidatedBackup b) =>
    Isolate.run(() {
      for (final table in backupColumns.entries) {
        if (_canonicalRows(a.tables[table.key]!, table.value) !=
            _canonicalRows(b.tables[table.key]!, table.value)) {
          return false;
        }
      }
      return true;
    });

String _canonicalRows(List<Map<String, Object?>> rows, List<String> columns) {
  final encoded =
      rows
          .map(
            (row) => jsonEncode(columns.map((column) => row[column]).toList()),
          )
          .toList()
        ..sort();
  return jsonEncode(encoded);
}
