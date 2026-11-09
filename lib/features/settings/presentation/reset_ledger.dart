import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/ledger_operation_providers.dart';
import '../../../core/providers/default_currency_provider.dart';
import 'backup_view_model.dart';
import 'ledger_view_reset.dart';
import '../../sharing/presentation/sharing_screen.dart';
import '../../sharing/presentation/discord_settings.dart';

final resetLedgerProvider = Provider<ResetLedger>(ResetLedger.new);

class ResetLedger {
  ResetLedger(this.ref);
  final Ref ref;

  Future<void> run() async {
    if (ref.read(ledgerTransferBusyProvider)) return;
    ref.read(ledgerTransferBusyProvider.notifier).set(true);
    try {
      await ref.read(sharingServiceProvider).stopHost();
      await ref.read(sharingServiceProvider).relaySecrets.clear();
      ref.invalidate(discordSettingsProvider);
      await ref.read(databaseProvider).resetLedger();
      ref.invalidate(sharedSessionsProvider);
      if (!ref.mounted) return;
      ref.invalidate(backupActionsProvider);
      ref.invalidate(defaultCurrencyActionsProvider);
      resetLedgerViews(ref);
    } finally {
      if (ref.mounted) ref.read(ledgerTransferBusyProvider.notifier).set(false);
    }
  }
}

class ResetLedgerTile extends ConsumerWidget {
  const ResetLedgerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: Icon(
        Icons.delete_forever_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: const Text('Reset all data'),
      subtitle: const Text('Clear expenses, trips, currencies and settings'),
      onTap: ref.watch(ledgerTransferBusyProvider)
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset all data?'),
                  content: const Text(
                    'This permanently removes all expenses, trips, custom categories, currencies and preferences from your current ledger. '
                    'Shared-trip invitations, cached views and unsent guest expenses will also be removed. '
                    'Sync queued expenses first. The app will return to its initial defaults. Export a backup first if you want to keep your ledger.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset all data'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                await ref.read(resetLedgerProvider).run();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ledgerErrorMessage(error))),
                );
              }
            },
    ),
  );
}
