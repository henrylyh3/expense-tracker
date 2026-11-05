import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/database_providers.dart';
import '../core/providers/appearance_provider.dart';
import '../core/providers/ledger_operation_providers.dart';
import 'router.dart';
import 'theme.dart';

class ExpenseTrackerApp extends ConsumerStatefulWidget {
  const ExpenseTrackerApp({super.key});
  @override
  ConsumerState<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  @override
  Widget build(BuildContext context) {
    ref.listen(ledgerResetSignalProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messenger.currentState?.showSnackBar(
            const SnackBar(content: Text('Backup restored.')),
          );
        }
      });
    });
    final ready = ref.watch(databaseReadyProvider).asData != null;
    final mode = ready ? ref.watch(appearanceProvider).asData?.value : null;
    final busy = ref.watch(ledgerTransferBusyProvider);
    return MaterialApp.router(
      title: 'Expense Tracker',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode ?? ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          AbsorbPointer(absorbing: busy, child: child!),
    );
  }
}
