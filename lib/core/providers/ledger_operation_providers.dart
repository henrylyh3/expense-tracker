import 'package:flutter_riverpod/flutter_riverpod.dart';

class LedgerTransferBusy extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final ledgerTransferBusyProvider = NotifierProvider<LedgerTransferBusy, bool>(
  LedgerTransferBusy.new,
);

class LedgerResetSignal extends Notifier<int> {
  @override
  int build() => 0;
  void restored() => state++;
}

final ledgerResetSignalProvider = NotifierProvider<LedgerResetSignal, int>(
  LedgerResetSignal.new,
);
