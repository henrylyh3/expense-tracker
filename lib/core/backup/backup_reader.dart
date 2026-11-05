import 'dart:typed_data';

import '../models/ledger_types.dart';
import 'backup_validator.dart';

/// Stream even when the provider cannot report a length. Never trust extensions
/// or a provider's claimed size as validation of the content.
Future<Uint8List> readBackupStream(
  Stream<List<int>> stream, {
  int? reportedLength,
}) async {
  if (reportedLength != null &&
      (reportedLength <= 0 || reportedLength > backupMaxBytes)) {
    throw const LedgerException(
      'Choose a non-empty backup no larger than 25 MiB.',
    );
  }
  final bytes = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in stream) {
    length += chunk.length;
    if (length > backupMaxBytes) {
      throw const LedgerException('The backup exceeds the 25 MiB limit.');
    }
    bytes.add(chunk);
  }
  if (length == 0) throw const LedgerException('The selected backup is empty.');
  return bytes.takeBytes();
}
