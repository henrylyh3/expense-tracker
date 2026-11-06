import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/appearance_provider.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/app_info.dart';
import '../../../core/models/ledger_types.dart';
import '../../currencies/presentation/currency_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
    children: [
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.luggage_outlined),
              title: const Text('Trips and profiles'),
              subtitle: const Text(
                'Choose a default trip and set its currency rates',
              ),
              onTap: () => context.push('/settings/trips'),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Manage categories'),
              subtitle: const Text('Expense categories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/categories'),
            ),
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('Manage currencies'),
              subtitle: const Text('Manual rates relative to MYR'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/currencies'),
            ),
            ListTile(
              title: const Text('Default currency'),
              subtitle: const Text(
                'New expenses and displayed totals. Base: MYR.',
              ),
              trailing: _DefaultCurrencyPicker(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.save_alt),
          title: const Text('Backup and restore'),
          subtitle: const Text('Save, share or replace from a JSON backup'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/backup'),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              subtitle: ref
                  .watch(appearanceProvider)
                  .when(
                    data: (mode) => DropdownButton<ThemeMode>(
                      value: mode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Device theme'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: ref.watch(appearanceActionsProvider).isLoading
                          ? null
                          : (mode) async {
                              if (mode == null) return;
                              await ref
                                  .read(appearanceActionsProvider.notifier)
                                  .set(mode);
                              if (!context.mounted) return;
                              final error = ref
                                  .read(appearanceActionsProvider)
                                  .error;
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ledgerErrorMessage(error)),
                                  ),
                                );
                              }
                            },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => TextButton(
                      onPressed: () => ref.invalidate(appearanceProvider),
                      child: const Text('Retry appearance'),
                    ),
                  ),
            ),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'Expense Tracker',
              applicationVersion: appVersion,
              child: Text('About and open-source licenses'),
            ),
            const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Stored on this device'),
              subtitle: Text(
                'No account or cloud sync. Base currency: MYR. '
                'Backups are saved or shared only when you choose.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DefaultCurrencyPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currenciesProvider);
    final preference = ref.watch(defaultCurrencyProvider);
    final options = currencies.asData?.value.where((item) => item.isActive);
    final selected = preference.asData?.value.code;
    if (currencies.hasError || preference.hasError) {
      return TextButton(
        onPressed: () {
          ref.invalidate(currenciesProvider);
          ref.invalidate(defaultCurrencyProvider);
        },
        child: const Text('Retry'),
      );
    }
    if (options == null || selected == null) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(),
      );
    }
    return DropdownButton<String>(
      value: options.any((item) => item.code == selected) ? selected : null,
      items: [
        for (final item in options)
          DropdownMenuItem(value: item.code, child: Text(item.code)),
      ],
      onChanged: ref.watch(defaultCurrencyActionsProvider).isLoading
          ? null
          : (code) async {
              if (code == null || code == selected) return;
              await ref.read(defaultCurrencyActionsProvider.notifier).set(code);
              if (!context.mounted) return;
              final error = ref.read(defaultCurrencyActionsProvider).error;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ledgerErrorMessage(error))),
                );
              }
            },
    );
  }
}
