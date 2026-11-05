import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/database_providers.dart';
import '../data/currency_repository.dart';
import '../domain/configured_currency.dart';

final currencyRepositoryProvider = Provider<CurrencyRepository>(
  (ref) => CurrencyRepository(ref.watch(databaseProvider)),
);

final currenciesProvider = StreamProvider<List<ConfiguredCurrency>>(
  (ref) => ref.watch(currencyRepositoryProvider).watchAll(),
  retry: (count, error) => null,
);

final currencyActionsProvider = AsyncNotifierProvider<CurrencyActions, void>(
  CurrencyActions.new,
);

class CurrencyActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<bool> save(CurrencyDraft draft, {String? originalCode}) => _perform(
    () => ref
        .read(currencyRepositoryProvider)
        .save(draft, originalCode: originalCode),
  );

  Future<bool> restore(String code) =>
      _perform(() => ref.read(currencyRepositoryProvider).restore(code));

  Future<bool> _perform(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<RemovalOutcome?> remove(String code) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await ref.read(currencyRepositoryProvider).remove(code);
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
