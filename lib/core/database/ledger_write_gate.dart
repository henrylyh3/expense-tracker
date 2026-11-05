import 'dart:async';

import '../models/ledger_types.dart';

/// One queue per open ledger. The tail never completes with an error, so a
/// failed operation cannot poison later work. Exclusive callbacks must not nest.
class LedgerWriteGate {
  Future<void> _tail = Future.value();
  int _generation = 0;
  int get generation => _generation;

  Future<T> exclusive<T>(Future<T> Function() action) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  Future<T> write<T>(Future<T> Function() action) {
    final openedGeneration = _generation;
    return exclusive(() async {
      if (openedGeneration != _generation) {
        throw const LedgerException(
          'The ledger was restored. Reopen the form before saving changes.',
        );
      }
      return action();
    });
  }

  /// Only call after a replacement transaction commits, while holding exclusive.
  void restored() => _generation++;
}
