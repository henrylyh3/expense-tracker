import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ledger_operation_providers.dart';
import 'backup_view_model.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    final state = ref.watch(backupActionsProvider);
    final actions = ref.read(backupActionsProvider.notifier);
    final preview = state.preview;
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
            'Backups contain your full financial history and notes as unencrypted JSON. '
            'Choose a private destination. Files or sharing apps you select may store copies outside this device. '
            'Invitations, shared-trip caches and unsent guest expenses are excluded from exports. Import removes them from this device.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : actions.save,
                icon: const Icon(Icons.save_alt),
                label: const Text('Export JSON'),
              ),
              Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          final box =
                              buttonContext.findRenderObject()! as RenderBox;
                          actions.share(
                            box.localToGlobal(Offset.zero) & box.size,
                          );
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
            'Import replaces all expenses, trips, categories, currency records and settings. '
            'There is no merge. Choose a JSON file to validate and preview it first.',
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
                      onPressed: busy
                          ? null
                          : () async {
                              final safety = await _confirmRestore(context);
                              if (safety != null && context.mounted) {
                                await actions.restore(safetyBackup: safety);
                              }
                            },
                      icon: const Icon(Icons.restore),
                      label: const Text('Import this backup'),
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
                'All current ledger data and settings will be replaced. This cannot be undone without another backup.',
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
