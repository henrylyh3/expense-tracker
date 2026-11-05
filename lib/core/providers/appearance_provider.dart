import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_providers.dart';

final appearanceProvider = StreamProvider<ThemeMode>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        "SELECT value FROM app_settings WHERE key = 'theme_mode'",
        readsFrom: {db.appSettings},
      )
      .watch()
      .map(
        (rows) => switch (rows.firstOrNull?.read<String>('value')) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      );
}, retry: (count, error) => null);

final appearanceActionsProvider =
    AsyncNotifierProvider<AppearanceActions, void>(AppearanceActions.new);

class AppearanceActions extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}
  Future<void> set(ThemeMode mode) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final db = ref.read(databaseProvider);
    final result = await AsyncValue.guard<void>(
      () => db.writeTransaction(() async {
        await db.customUpdate(
          "INSERT INTO app_settings (key, value) VALUES ('theme_mode', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
          variables: [Variable.withString(mode.name)],
          updates: {db.appSettings},
        );
      }),
    );
    if (ref.mounted) state = result;
  }
}
