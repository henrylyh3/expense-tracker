import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_operation_providers.dart';
import '../../../core/providers/trip_provider.dart';
import '../../../core/backup/backup_validator.dart';
import 'backup_view_model.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    final state = ref.watch(backupActionsProvider);
    final actions = ref.read(backupActionsProvider.notifier);
    final preview = state.preview;
    final trips = ref.watch(tripsProvider).asData?.value;
    return PopScope(
      canPop: !busy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          Text(
            'Import and export',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Export all trips or choose which trips to include. JSON files contain unencrypted expenses and notes. Choose a private destination.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy || trips == null
                    ? null
                    : () async {
                        final choice = await _chooseExport(context, trips);
                        if (choice != null && context.mounted) {
                          await actions.save(tripIds: choice.tripIds);
                        }
                      },
                icon: const Icon(Icons.save_alt),
                label: const Text('Export JSON'),
              ),
              Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: busy || trips == null
                      ? null
                      : () async {
                          final box =
                              buttonContext.findRenderObject()! as RenderBox;
                          final origin =
                              box.localToGlobal(Offset.zero) & box.size;
                          final choice = await _chooseExport(context, trips);
                          if (choice != null && context.mounted) {
                            await actions.share(
                              origin,
                              tripIds: choice.tripIds,
                            );
                          }
                        },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share JSON'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text('Import JSON', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Import adds trips to this ledger. For each matching name, choose whether to merge into the existing trip or create a separate copy.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : actions.chooseBackup,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Choose JSON file'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Keep the app open until this finishes.'),
                ],
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(state.message!, semanticsLabel: state.message),
            ),
          if (preview != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validated backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Exported: ${preview.exportedAtUtc.toIso8601String()}',
                    ),
                    Text('App ${preview.appVersion} · Format 1 · MYR base'),
                    const SizedBox(height: 8),
                    Text(
                      '${preview.count('transactions')} transactions · ${preview.count('categories')} categories',
                    ),
                    Text(
                      '${preview.count('currencies')} currencies · ${preview.count('currency_rates')} named rates · ${preview.count('trips')} trips',
                    ),
                    if (preview.firstTransactionDate != null)
                      Text(
                        'Dates: ${preview.firstTransactionDate} to ${preview.lastTransactionDate}',
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy || trips == null
                          ? null
                          : () async {
                              final choices = await _chooseDestinations(
                                context,
                                preview,
                                trips,
                              );
                              if (choices != null && context.mounted) {
                                await actions.importTrips(choices);
                              }
                            },
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Import trips'),
                    ),
                    if (!preview.isTripExport)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final safety = await _confirmRestore(context);
                                if (safety != null && context.mounted) {
                                  await actions.restore(safetyBackup: safety);
                                }
                              },
                        child: const Text('Replace entire ledger'),
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

Future<({Set<String>? tripIds})?> _chooseExport(
  BuildContext context,
  List<({String id, String name})> trips,
) {
  final selected = <String>{};
  return showDialog<({Set<String>? tripIds})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Choose trips to export'),
        content: SizedBox(
          width: 400,
          height: 240,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final trip in trips)
                CheckboxListTile(
                  title: Text(trip.name),
                  value: selected.contains(trip.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      selected.add(trip.id);
                    } else {
                      selected.remove(trip.id);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, (tripIds: null as Set<String>?)),
            child: const Text('All trips'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, (
                    tripIds: Set<String>.of(selected) as Set<String>?,
                  )),
            child: const Text('Selected trips'),
          ),
        ],
      ),
    ),
  );
}

Future<Map<String, String?>?> _chooseDestinations(
  BuildContext context,
  ValidatedBackup backup,
  List<({String id, String name})> trips,
) async {
  final destinations = <String, String?>{};
  for (final row in backup.tables['trips']!) {
    final name = row['name'] as String;
    final matches = trips
        .where((trip) => trip.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (matches.isEmpty) continue;
    final choice = await showDialog<({String? tripId})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('“$name” already exists'),
        children: [
          for (final match in matches)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, (tripId: match.id as String?)),
              child: Text(
                matches.length == 1
                    ? 'Merge into ${match.name}'
                    : 'Merge into ${match.name} (${match.id})',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (tripId: null as String?)),
            child: const Text('Create a separate copy'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel import'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return null;
    destinations[row['id'] as String] = choice.tripId;
  }
  return destinations;
}

Future<bool?> _confirmRestore(BuildContext context) {
  var safety = true;
  var acknowledged = false;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Replace your entire ledger?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'All current ledger data and settings will be replaced. Invitations, guest caches and unsent guest expenses on this device will be removed.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: safety,
                onChanged: (value) => setState(() {
                  safety = value!;
                  acknowledged = false;
                }),
                title: const Text('Save a safety backup first'),
                subtitle: const Text(
                  'Cancelling or failing to save cancels the restore.',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) => setState(() => acknowledged = value!),
                title: Text(
                  safety
                      ? 'I understand all current data will be replaced.'
                      : 'Replace all data without a safety backup.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: acknowledged
                ? () => Navigator.pop(context, safety)
                : null,
            child: const Text('Replace all'),
          ),
        ],
      ),
    ),
  );
}
