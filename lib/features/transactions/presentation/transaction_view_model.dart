import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/models/ledger_types.dart';
import '../data/transaction_repository.dart';
import '../domain/ledger_transaction.dart';
import '../domain/transaction_input.dart';
import '../domain/transaction_filter.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(databaseProvider)),
);

class HistoryLimit extends Notifier<int> {
  @override
  int build() => 100;
  void loadMore() => state += 100;
  void reset() => state = 100;
}

final historyLimitProvider = NotifierProvider<HistoryLimit, int>(
  HistoryLimit.new,
);

class HistoryFilter extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter.empty();
  void set(TransactionFilter filter) {
    if (state == filter) return;
    ref.read(historyLimitProvider.notifier).reset();
    state = filter;
  }

  void search(String query) => set(state.withQuery(query));
  void clear() => set(const TransactionFilter.empty());
}

final historyFilterProvider =
    NotifierProvider<HistoryFilter, TransactionFilter>(HistoryFilter.new);
final transactionsProvider = StreamProvider<List<LedgerTransaction>>(
  (ref) => ref
      .watch(transactionRepositoryProvider)
      .watchHistory(
        limit: ref.watch(historyLimitProvider),
        tripId: ref.watch(activeTripProvider).asData?.value ?? personalTripId,
        filter: ref.watch(historyFilterProvider).expensesOnly,
      ),
  retry: (count, error) => null,
);
final transactionProvider = StreamProvider.autoDispose
    .family<LedgerTransaction?, String>(
      (ref, id) => ref
          .watch(transactionRepositoryProvider)
          .watchById(id)
          .map((item) => item?.type == TransactionType.expense ? item : null),
      retry: (count, error) => null,
    );
final transactionActionsProvider =
    AsyncNotifierProvider<TransactionActions, void>(TransactionActions.new);

class TransactionActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<String?> save(
    TransactionInput input, {
    String? id,
    int? expectedUpdatedAtUtc,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final saved = await ref
          .read(transactionRepositoryProvider)
          .save(input, id: id, expectedUpdatedAtUtc: expectedUpdatedAtUtc);
      if (ref.mounted) state = const AsyncData(null);
      return saved;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return null;
    }
  }

  Future<bool> delete(LedgerTransaction transaction) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref
          .read(transactionRepositoryProvider)
          .delete(
            transaction.id,
            expectedUpdatedAtUtc: transaction.updatedAtUtc,
          );
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return false;
    }
  }
}
