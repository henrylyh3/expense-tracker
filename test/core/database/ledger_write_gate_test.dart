import 'dart:async';

import 'package:expense_tracker/core/database/ledger_write_gate.dart';
import 'package:expense_tracker/core/models/ledger_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes serialize and release the queue after failure', () async {
    final gate = LedgerWriteGate();
    final release = Completer<void>();
    final events = <int>[];
    final first = gate.write(() async {
      events.add(1);
      await release.future;
      events.add(2);
      throw StateError('test');
    });
    final failure = expectLater(first, throwsStateError);
    final second = gate.write(() async => events.add(3));
    await Future<void>.delayed(Duration.zero);
    expect(events, [1]);
    release.complete();
    await failure;
    await second;
    expect(events, [1, 2, 3]);
  });
  test('committed restore rejects writes queued for the old ledger', () async {
    final gate = LedgerWriteGate();
    final release = Completer<void>();
    final restore = gate.exclusive(() async {
      await release.future;
      gate.restored();
    });
    var wrote = false;
    final stale = expectLater(
      gate.write(() async {
        wrote = true;
      }),
      throwsA(isA<LedgerException>()),
    );
    release.complete();
    await restore;
    await stale;
    expect(wrote, isFalse);
    await gate.write(() async {
      wrote = true;
    });
    expect(wrote, isTrue);
    expect(gate.generation, 1);
  });
  test('cancelled restore does not invalidate pending writes', () async {
    final gate = LedgerWriteGate();
    final release = Completer<void>();
    final restore = gate.exclusive(() => release.future);
    var wrote = false;
    final pending = gate.write(() async {
      wrote = true;
    });
    release.complete();
    await restore;
    await pending;
    expect(wrote, isTrue);
    expect(gate.generation, 0);
  });
}
