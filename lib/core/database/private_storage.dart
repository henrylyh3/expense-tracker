import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _privateStorage = MethodChannel('expense_tracker/private_storage');

/// The native bridge prepares backup exclusion/file protection before SQLite
/// creates files. A failed bridge must never fall back to another directory.
Future<String> prepareLedgerDirectory() async {
  final path = await _privateStorage.invokeMethod<String>(
    'prepareLedgerDirectory',
  );
  if (path == null ||
      path.isEmpty ||
      !p.isAbsolute(path) ||
      path.contains('\u0000')) {
    throw StateError('Private ledger storage is unavailable.');
  }
  return path;
}
