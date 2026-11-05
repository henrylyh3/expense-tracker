import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const ledgerFileName = 'expense_tracker.sqlite';
const _selectorName = 'active-ledger.json';
final _generationPattern = RegExp(r'^generation-[A-Za-z0-9_-]{1,64}$');

/// Only this store creates workspaces. All paths are beneath private storage.
final class RecoveryWorkspace {
  RecoveryWorkspace._(this.directory, this._previousSelector);
  final Directory directory;
  final Uint8List? _previousSelector;
  String get id => p.basename(directory.path);
  File get databaseFile => File(p.join(directory.path, ledgerFileName));
  Directory get originals => Directory(p.join(directory.path, 'original'));
}

class LedgerStorage {
  LedgerStorage(this.directory);
  final Directory directory;
  File get _selector => File(p.join(directory.path, _selectorName));
  Directory get _recoveries => Directory(p.join(directory.path, 'recovery'));

  /// Missing selector means the original v1 path. Invalid selectors or missing
  /// selected databases fail closed, never seed a replacement at another path.
  Future<String> activeDatabasePath() async {
    final bytes = await _selectorBytes();
    if (bytes == null) {
      final legacy = p.join(directory.path, ledgerFileName);
      final type = await FileSystemEntity.type(legacy, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw StateError('The legacy ledger is not a regular file.');
      }
      return legacy;
    }
    final id = _decodeSelector(bytes);
    await _requireDirectory(_recoveries);
    final folder = Directory(p.join(_recoveries.path, id));
    await _requireDirectory(folder);
    final file = File(p.join(folder.path, ledgerFileName));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('The selected ledger is missing or unavailable.');
    }
    return file.path;
  }

  Future<RecoveryWorkspace> preserveOriginals() async {
    final previous = await _selectorBytes();
    final kind = await FileSystemEntity.type(
      _recoveries.path,
      followLinks: false,
    );
    if (kind == FileSystemEntityType.notFound) await _recoveries.create();
    await _requireDirectory(_recoveries);
    final folder = await _recoveries.createTemp('generation-');
    final workspace = RecoveryWorkspace._(folder, previous);
    await workspace.originals.create();
    final files = <Map<String, Object?>>[];
    if (previous != null) {
      await File(
        p.join(workspace.originals.path, _selectorName),
      ).writeAsBytes(previous, flush: true);
      files.add({'name': _selectorName, 'bytes': previous.length});
    }
    var source = File(p.join(directory.path, ledgerFileName));
    var selectionValid = previous == null;
    if (previous != null) {
      try {
        final id = _decodeSelector(previous);
        final selectedFolder = Directory(p.join(_recoveries.path, id));
        // Never follow symbolic links, even for preservation copies.
        await _requireDirectory(selectedFolder);
        source = File(p.join(selectedFolder.path, ledgerFileName));
        selectionValid = true;
      } on StateError {
        // A malformed selector cannot have opened a new SQLite connection.
        // Keep its bytes and the legacy files; all prior generations stay put.
      }
    }
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${source.path}$suffix');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('Ledger preservation cannot follow a link.');
      }
      final name = '$ledgerFileName$suffix';
      final bytes = await _copyFlushed(
        file,
        File(p.join(workspace.originals.path, name)),
      );
      files.add({'name': name, 'bytes': bytes});
    }
    await File(p.join(folder.path, 'preservation.json')).writeAsString(
      jsonEncode({
        'format_version': 1,
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'previous_selection_valid': selectionValid,
        'files': files,
      }),
      flush: true,
    );
    return workspace;
  }

  /// Final commit point: a flushed small file renamed within the same directory.
  /// No fallible filesystem operation is performed after a successful rename.
  Future<void> activate(RecoveryWorkspace workspace) async {
    if (p.dirname(workspace.directory.path) != _recoveries.path ||
        !_validGeneration(workspace.id)) {
      throw StateError('The recovery workspace is invalid.');
    }
    await _requireDirectory(workspace.directory);
    if (await FileSystemEntity.type(
          workspace.databaseFile.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      throw StateError('The recovered ledger is missing.');
    }
    if (!_sameBytes(await _selectorBytes(), workspace._previousSelector)) {
      throw StateError('The active ledger changed while recovery was running.');
    }
    final temporary = File(
      p.join(directory.path, '.active-${workspace.id}.tmp'),
    );
    await temporary.writeAsString(
      jsonEncode({'format_version': 1, 'id': workspace.id}),
      flush: true,
    );
    await temporary.rename(_selector.path);
  }

  Future<Uint8List?> _selectorBytes() async {
    final type = await FileSystemEntity.type(
      _selector.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw StateError('The ledger selection is not a regular file.');
    }
    final input = await _selector.open();
    try {
      final bytes = await input.read(4097);
      if (bytes.length > 4096) {
        throw StateError('The ledger selection exceeds its supported size.');
      }
      return bytes;
    } finally {
      await input.close();
    }
  }
}

bool _validGeneration(String value) =>
    _generationPattern.stringMatch(value) == value;

String _decodeSelector(Uint8List bytes) {
  try {
    final source = utf8.decode(bytes, allowMalformed: false);
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> ||
        value.length != 2 ||
        value['format_version'] is! int ||
        value['format_version'] != 1 ||
        value['id'] is! String ||
        !_validGeneration(value['id']! as String) ||
        source != jsonEncode({'format_version': 1, 'id': value['id']})) {
      throw const FormatException();
    }
    return value['id']! as String;
  } on FormatException {
    throw StateError('The active ledger selection is invalid.');
  }
}

Future<void> _requireDirectory(Directory directory) async {
  if (await FileSystemEntity.type(directory.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw StateError('A private ledger directory is unavailable.');
  }
}

bool _sameBytes(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<int> _copyFlushed(File source, File target) async {
  final before = await source.stat();
  final output = await target.open(mode: FileMode.write);
  var length = 0;
  try {
    await for (final chunk in source.openRead()) {
      await output.writeFrom(chunk);
      length += chunk.length;
    }
    await output.flush();
  } finally {
    await output.close();
  }
  final after = await source.stat();
  if (length != before.size ||
      after.size != before.size ||
      after.modified != before.modified) {
    throw StateError('The ledger changed during preservation.');
  }
  return length;
}
