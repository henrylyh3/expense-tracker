import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/trip_provider.dart';
import '../../currencies/presentation/currency_view_model.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ledgerErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(activeTripProvider).asData?.value ?? personalTripId;
    final trips = ref.watch(tripsProvider);
    final actions = ref.read(tripActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trips and profiles')),
      body: trips.when(
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
                final name = await _ask(context, 'New trip or profile', 'Name');
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
                    trip.id == active ? 'Default trip' : 'Tap to edit rates',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _TripRatesScreen(id: trip.id, name: trip.name),
                    ),
                  ),
                  trailing: trip.id == active
                      ? const Icon(Icons.check_circle)
                      : TextButton(
                          onPressed: () =>
                              _run(context, () => actions.activate(trip.id)),
                          child: const Text('Make default'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TripRatesScreen extends ConsumerWidget {
  const _TripRatesScreen({required this.id, required this.name});
  final String id;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currenciesProvider);
    final rates = ref.watch(tripRatesProvider(id));
    final options = currencies.asData?.value;
    final overrides = rates.asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: currencies.hasError || rates.hasError
          ? Center(
              child: TextButton(
                onPressed: () {
                  ref.invalidate(currenciesProvider);
                  ref.invalidate(tripRatesProvider(id));
                },
                child: const Text('Retry loading rates'),
              ),
            )
          : options == null || overrides == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Set MYR per unit for this trip. Saved expenses keep their original rates.',
                ),
                if (!options.any((item) => item.isActive && !item.isBase))
                  const Text(
                    'Add a foreign currency in Manage currencies first.',
                  ),
                for (final item in options.where(
                  (item) => item.isActive && !item.isBase,
                ))
                  ListTile(
                    title: Text('${item.code} · ${item.name}'),
                    subtitle: Text(
                      '1 ${item.code} = ${overrides[item.code] ?? item.rateToMyr} MYR${overrides.containsKey(item.code) ? ' · Trip rate' : ' · Default rate'}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final rate = await _ask(
                        context,
                        '${item.code} trip rate',
                        'MYR per unit (blank uses default)',
                        initial: overrides[item.code] ?? '',
                        numeric: true,
                      );
                      if (rate == null || !context.mounted) return;
                      try {
                        await ref
                            .read(tripActionsProvider)
                            .setRate(id, item.code, rate);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ledgerErrorMessage(error))),
                        );
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

Future<String?> _ask(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
  bool numeric = false,
}) async {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        autofocus: true,
        initialValue: initial,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onChanged: (text) => value = text,
        onFieldSubmitted: (text) => Navigator.pop(context, text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
