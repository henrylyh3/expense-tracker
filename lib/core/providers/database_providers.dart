import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final databaseReadyProvider = FutureProvider<void>(
  (ref) async => ref.watch(databaseProvider).initialize(),
  // Storage/schema failures require a deliberate user retry, not background
  // exponential retries that repeatedly reopen a failing financial database.
  retry: (retryCount, error) => null,
);
