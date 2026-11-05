import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/categories/presentation/categories_screen.dart';
import '../features/currencies/presentation/currencies_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/transactions/presentation/transaction_detail_screen.dart';
import '../features/transactions/presentation/transaction_editor_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../core/providers/ledger_operation_providers.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/startup_screen.dart';
import '../core/providers/database_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(ledgerResetSignalProvider);
  final router = GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final ready = ref.read(databaseReadyProvider);
      final starting = state.matchedLocation == '/startup';
      if (ready.asData == null) return starting ? null : '/startup';
      return starting ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'currencies',
                    builder: (context, state) => const CurrenciesScreen(),
                  ),
                  GoRoute(
                    path: 'backup',
                    builder: (context, state) => const BackupScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionEditorScreen(),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => TransactionEditorScreen(
              transactionId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Go home'),
        ),
      ),
    ),
  );
  ref.listen(databaseReadyProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
