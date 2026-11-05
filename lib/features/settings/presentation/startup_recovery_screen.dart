import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/startup_recovery_service.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import 'startup_recovery_view_model.dart';

class StartupRecoveryScreen extends ConsumerWidget {
  const StartupRecoveryScreen({required this.onCancel, super.key});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(ledgerTransferBusyProvider);
    final state = ref.watch(startupRecoveryProvider);
    final actions = ref.read(startupRecoveryProvider.notifier);
    final backup = state.preview;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recover from backup'),
          leading: IconButton(
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Use a JSON backup to create a fresh ledger when this one cannot open. '
                'Your current database files will be retained privately before switching. '
                'Nothing changes until you confirm recovery.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : actions.chooseBackup,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose recovery backup'),
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(switch (state.stage) {
                        RecoveryStage.preserving =>
                          'Saving original ledger files…',
                        RecoveryStage.closing => 'Closing local storage…',
                        RecoveryStage.restoring => 'Restoring backup…',
                        RecoveryStage.checking => 'Checking recovered ledger…',
                        RecoveryStage.activating =>
                          'Switching to recovered ledger…',
                        null => 'Reading and validating backup…',
                      }),
                      const Text('Keep the app open until recovery finishes.'),
                    ],
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (state.message != null) Text(state.message!),
              if (backup != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validated recovery backup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Exported: ${backup.exportedAtUtc.toIso8601String()}',
                        ),
                        Text('App ${backup.appVersion} · Format 1 · MYR base'),
                        Text(
                          '${backup.count('transactions')} transactions · ${backup.count('categories')} categories',
                        ),
                        Text(
                          '${backup.count('currencies')} currencies · ${backup.count('settings')} settings',
                        ),
                        if (backup.firstTransactionDate != null)
                          Text(
                            'Dates: ${backup.firstTransactionDate} to ${backup.lastTransactionDate}',
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await _confirm(context) == true &&
                                      context.mounted) {
                                    await actions.recover();
                                  }
                                },
                          icon: const Icon(Icons.restore),
                          label: const Text('Recover using this backup'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Raw preservation copies are not JSON backups and may contain damaged data. '
                'After recovery, save a new JSON backup to a private destination. '
                'No old preservation copies are deleted automatically.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirm(BuildContext context) {
  var acknowledged = false;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Recover and replace the active ledger?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The backup will become your active ledger, including its currencies, categories and settings. '
                'There is no merge. Original database files will be retained privately, but may be unreadable. '
                'A valid JSON safety backup of the failed ledger cannot be guaranteed.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) => setState(() => acknowledged = value!),
                title: const Text(
                  'I understand the backup will replace my active ledger.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: acknowledged ? () => Navigator.pop(context, true) : null,
            child: const Text('Recover ledger'),
          ),
        ],
      ),
    ),
  );
}
