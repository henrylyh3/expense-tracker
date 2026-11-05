import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'backup_reader.dart';

class BackupFiles {
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose an Expense Tracker backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    return readBackupStream(
      file.readAsByteStream(),
      reportedLength: await file.length(),
    );
  }

  Future<bool> save(Uint8List bytes, {bool safety = false}) async =>
      await FilePicker.saveFile(
        fileName: _fileName(safety: safety),
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: safety
            ? 'Save safety backup before replacing your ledger'
            : 'Save ledger backup',
      ) !=
      null;

  Future<ShareResultStatus> share(Uint8List bytes, Rect origin) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, 'ledger_backup_shares'),
    );
    await directory.create(recursive: true);
    await _cleanOldShares(directory);
    final file = File(
      p.join(directory.path, 'ledger-${const Uuid().v4()}.json'),
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: [_fileName()],
          sharePositionOrigin: origin,
        ),
      );
      // Recipients can read lazily after the share sheet closes. Keep the file
      // in OS cache; only age out our own files on a subsequent share.
      return result.status;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  String _fileName({bool safety = false}) =>
      'expense-tracker-${safety ? 'safety-' : ''}${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.json';

  Future<void> _cleanOldShares(Directory directory) async {
    final before = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(
            r'^ledger-[0-9a-f-]{36}\.json$',
          ).hasMatch(p.basename(entry.path))) {
        continue;
      }
      try {
        if ((await entry.lastModified()).isBefore(before)) await entry.delete();
      } on FileSystemException {
        // A cache cleanup failure must not discard a new backup.
      }
    }
  }
}
