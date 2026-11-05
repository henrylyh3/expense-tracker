import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ledger_operation_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    const titles = ['Home', 'History', 'Reports', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[navigationShell.currentIndex]),
        leading: !busy && GoRouter.of(context).canPop()
            ? BackButton(onPressed: () => context.pop())
            : null,
      ),
      body: SafeArea(child: navigationShell),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => context.push('/transactions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: busy
            ? null
            : (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
