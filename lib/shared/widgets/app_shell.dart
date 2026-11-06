import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/ledger_operation_providers.dart';
import '../../core/providers/trip_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    required this.location,
    this.tripId,
    super.key,
  });

  final String location;
  final String? tripId;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    const titles = ['Home', 'History', 'Reports', 'Settings'];
    final title = tripId != null
        ? ref
                  .watch(tripsProvider)
                  .asData
                  ?.value
                  .where((trip) => trip.id == tripId)
                  .firstOrNull
                  ?.name ??
              'Trip rates'
        : location == '/settings/trips'
        ? 'Trips and profiles'
        : titles[navigationShell.currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: false,
        leading: !busy && location.startsWith('/settings/')
            ? BackButton(onPressed: () => context.pop())
            : null,
      ),
      body: SafeArea(child: navigationShell),
      floatingActionButton: navigationShell.currentIndex == 3
          ? null
          : FloatingActionButton.extended(
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
