import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/trip_provider.dart';
import '../../currencies/presentation/currency_view_model.dart';
import '../../reports/presentation/report_view_model.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../reports/domain/report_period.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(activeTripProvider).asData?.value ?? personalTripId;
    final trips = ref.watch(tripsProvider);
    final actions = ref.read(tripActionsProvider);
    return trips.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(tripsProvider),
          child: const Text('Retry loading trips'),
        ),
      ),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('New expenses go to the default trip.'),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New trip or profile'),
            onPressed: () async {
              final name = await _newTripName(context);
              if (name != null && context.mounted) {
                await _run(context, () => actions.create(name));
              }
            },
          ),
          for (final trip in items)
            Card(
              child: ListTile(
                title: Text(trip.name),
                subtitle: Text(
                  trip.id == active ? 'Default trip' : 'Tap for summary',
                ),
                onTap: () => context.push(
                  '/settings/trips/${Uri.encodeComponent(trip.id)}',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Trip options',
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'currencies',
                      child: Text('Currency settings'),
                    ),
                    if (trip.id != active)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Make default'),
                      ),
                    if (trip.id != personalTripId)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete trip'),
                      ),
                  ],
                  onSelected: (choice) async {
                    if (choice == 'currencies') {
                      await context.push<void>(
                        '/settings/trips/${Uri.encodeComponent(trip.id)}/currencies',
                      );
                    } else if (choice == 'default') {
                      await _run(context, () => actions.activate(trip.id));
                    } else {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete ${trip.name}?'),
                          content: const Text(
                            'Its expenses will move to Personal with their saved rates. Its trip currency settings will be removed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete trip'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await _run(context, () => actions.delete(trip.id));
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final tripSummaryProvider = StreamProvider.family(
  (ref, String id) => ref
      .watch(reportRepositoryProvider)
      .watchPeriod(
        ReportPeriod.trip(),
        expensesOnly: true,
        tripId: id,
        includeCurrencyTotals: true,
      ),
  retry: (count, error) => null,
);

class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(tripSummaryProvider(id));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(tripSummaryProvider(id)),
            child: const Text('Retry summary'),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripCurrencySummary(
                expenseCount: value.expenseCount,
                currencyTotals: value.currencyTotals,
                expenses: value.expenses,
                currencyRates: value.currencyRates,
              ),
              const SizedBox(height: 16),
              SpendingBreakdown(categories: value.categories),
            ],
          ),
        ),
      ],
    );
  }
}

class TripRatesScreen extends ConsumerWidget {
  const TripRatesScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currenciesProvider);
    final rates = ref.watch(tripRatesProvider(id));
    final options = currencies.asData?.value.where(
      (item) => item.isActive && !item.isBase && (item.recordId == null),
    );
    final overrides = rates.asData?.value;
    if (currencies.hasError || rates.hasError) {
      return Center(
        child: TextButton(
          onPressed: () {
            ref.invalidate(currenciesProvider);
            ref.invalidate(tripRatesProvider(id));
          },
          child: const Text('Retry loading rates'),
        ),
      );
    }
    if (options == null || overrides == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Give a currency a name and a manual rate for this trip. Saved expenses keep their original rates.',
        ),
        if (options.isEmpty)
          const Text('Add a foreign currency in Manage currencies first.'),
        for (final item in options)
          ListTile(
            title: Text(
              '${item.code} · ${overrides[item.code]?.name ?? item.name}',
            ),
            subtitle: Text(
              '1 ${item.code} = ${overrides[item.code]?.rate ?? item.rateToMyr} MYR${overrides.containsKey(item.code) ? ' · Trip rate' : ' · Default rate'}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final value = await _editRate(
                context,
                item.code,
                overrides[item.code],
                item.rateToMyr,
              );
              if (value == null || !context.mounted) return;
              await _run(
                context,
                () => ref
                    .read(tripActionsProvider)
                    .setRate(id, item.code, value.rate, name: value.name),
              );
            },
          ),
      ],
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ledgerErrorMessage(error))));
  }
}

Future<String?> _newTripName(BuildContext context) {
  var name = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New trip or profile'),
      content: TextFormField(
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (value) => name = value,
        onFieldSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, name),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<TripCurrencyRate?> _editRate(
  BuildContext context,
  String code,
  TripCurrencyRate? current,
  String defaultRate,
) {
  var name = current?.name ?? '';
  var rate = current?.rate ?? defaultRate;
  return showDialog<TripCurrencyRate>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$code for this trip'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: name,
            decoration: const InputDecoration(
              labelText: 'Trip currency name (optional)',
            ),
            onChanged: (value) => name = value,
          ),
          TextFormField(
            initialValue: rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'MYR per unit',
              helperText: 'Blank clears the trip name and rate',
            ),
            onChanged: (value) => rate = value,
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (rate: '', name: null, recordId: null)),
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            rate: rate,
            name: name,
            recordId: current?.recordId,
          )),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
