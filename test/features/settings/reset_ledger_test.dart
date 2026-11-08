import 'package:expense_tracker/features/settings/presentation/reset_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reset extends ResetLedger {
  _Reset(super.ref);
  int calls = 0;
  @override
  Future<void> run() async {
    calls++;
  }
}

void main() {
  testWidgets('reset needs explicit confirmation and Cancel preserves data', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [resetLedgerProvider.overrideWith(_Reset.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ResetLedgerTile())),
      ),
    );
    await tester.tap(find.text('Reset all data'));
    await tester.pumpAndSettle();
    expect((container.read(resetLedgerProvider) as _Reset).calls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((container.read(resetLedgerProvider) as _Reset).calls, 0);
    await tester.tap(find.text('Reset all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset all data'));
    await tester.pumpAndSettle();
    expect((container.read(resetLedgerProvider) as _Reset).calls, 1);
  });
}
