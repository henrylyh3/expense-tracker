import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/database_providers.dart';
import '../data/category_repository.dart';
import '../domain/ledger_category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final categoriesProvider = StreamProvider<List<LedgerCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
  retry: (count, error) => null,
);

final categoryActionsProvider = AsyncNotifierProvider<CategoryActions, void>(
  CategoryActions.new,
);

class CategoryActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<bool> save(CategoryDraft draft, {String? id}) => _perform(() async {
    await ref.read(categoryRepositoryProvider).save(draft, id: id);
  });

  Future<bool> restore(String id) =>
      _perform(() => ref.read(categoryRepositoryProvider).restore(id));

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

  Future<RemovalOutcome?> remove(String id) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await ref.read(categoryRepositoryProvider).remove(id);
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
