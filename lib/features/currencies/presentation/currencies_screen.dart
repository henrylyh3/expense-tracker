import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/configured_currency.dart';
import 'currency_editor.dart';
import 'currency_view_model.dart';

class CurrenciesScreen extends ConsumerStatefulWidget {
  const CurrenciesScreen({super.key});
  @override
  ConsumerState<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends ConsumerState<CurrenciesScreen> {
  bool _showArchived = false;

  Future<void> _edit(
    List<ConfiguredCurrency> all, [
    ConfiguredCurrency? currency,
  ]) async {
    ref.read(currencyActionsProvider.notifier).clearError();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CurrencyEditor(
        currency: currency,
        configuredCodes: all.map((item) => item.code).toSet(),
      ),
    );
    if (mounted && saved == true) {
      showManagementMessage(context, 'Currency saved.');
    }
  }

  Future<void> _remove(ConfiguredCurrency currency) async {
    if (!await confirmRemoval(
          context,
          name: currency.code,
          used: currency.isUsed,
        ) ||
        !mounted) {
      return;
    }
    final result = await ref
        .read(currencyActionsProvider.notifier)
        .remove(currency.key);
    if (!mounted) return;
    showManagementMessage(
      context,
      result == null
          ? ledgerErrorMessage(ref.read(currencyActionsProvider).error)
          : result == RemovalOutcome.archived
          ? 'Currency archived.'
          : 'Currency deleted.',
    );
  }

  Future<void> _restore(ConfiguredCurrency currency) async {
    final restored = await ref
        .read(currencyActionsProvider.notifier)
        .restore(currency.key);
    if (mounted) {
      showManagementMessage(
        context,
        restored
            ? 'Currency restored.'
            : ledgerErrorMessage(ref.read(currencyActionsProvider).error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies = ref.watch(currenciesProvider);
    final busy = ref.watch(currencyActionsProvider).isLoading;
    return currencies.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ManagementLoadError(
        onRetry: () => ref.invalidate(currenciesProvider),
      ),
      data: (all) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          Text(
            'Manage currencies',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'MYR is your fixed base currency. All rates mean 1 unit of the selected currency in MYR.',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show archived'),
            value: _showArchived,
            onChanged: (value) => setState(() => _showArchived = value),
          ),
          FilledButton.icon(
            onPressed: busy ? null : () => _edit(all),
            icon: const Icon(Icons.add),
            label: const Text('Add currency'),
          ),
          const SizedBox(height: 16),
          for (final currency in all.where(
            (item) => _showArchived || item.isActive,
          ))
            Card(
              child: ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  child: FittedBox(child: Text(currency.code)),
                ),
                title: Text('${currency.name} (${currency.symbol})'),
                subtitle: Text(
                  '1 ${currency.code} = ${currency.rateToMyr} MYR\n'
                  '${currency.decimalPlaces} decimal places · ${currency.usageCount} transactions'
                  '${currency.isBase
                      ? ' · Base currency'
                      : !currency.isActive
                      ? ' · Archived'
                      : ''}',
                ),
                onTap: busy ? null : () => _edit(all, currency),
                trailing: PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: 'Actions for ${currency.code}',
                  onSelected: (action) async {
                    switch (action) {
                      case 'trip-default':
                        try {
                          final trip =
                              ref.read(activeTripProvider).asData?.value ??
                              personalTripId;
                          await ref
                              .read(tripActionsProvider)
                              .setDefaultCurrency(trip, currency.key);
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ledgerErrorMessage(error))),
                          );
                        }
                      case 'default':
                        await ref
                            .read(defaultCurrencyActionsProvider.notifier)
                            .set(currency.key);
                        if (!context.mounted) return;
                        final error = ref
                            .read(defaultCurrencyActionsProvider)
                            .error;
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ledgerErrorMessage(error))),
                          );
                        }
                      case 'edit':
                        await _edit(all, currency);
                      case 'restore':
                        await _restore(currency);
                      case 'remove':
                        await _remove(currency);
                    }
                  },
                  itemBuilder: (context) => [
                    if (currency.isActive)
                      const PopupMenuItem(
                        value: 'trip-default',
                        child: Text('Make default for current trip'),
                      ),
                    if (currency.isActive)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Make default'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (!currency.isActive)
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore'),
                      ),
                    if (!currency.isBase &&
                        (currency.isActive || !currency.isUsed))
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(currency.isUsed ? 'Archive' : 'Delete'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
