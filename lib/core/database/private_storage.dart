import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _privateStorage = MethodChannel('expense_tracker/private_storage');

/// The native bridge prepares backup exclusion/file protection before SQLite
/// creates files. A failed bridge must never fall back to another directory.
Future<String> prepareLedgerDirectory({
  TargetPlatform? platform,
  Future<Directory> Function()? supportDirectory,
}) async {
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.macOS || target == TargetPlatform.windows) {
    final support =
        await (supportDirectory ?? getApplicationSupportDirectory)();
    if (!p.isAbsolute(support.path) || support.path.contains('\u0000')) {
      throw StateError('Application data directory is invalid.');
    }
    final ledger = Directory(p.join(support.path, 'ledger'));
    await ledger.create(recursive: true);
    return ledger.path;
  }
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
