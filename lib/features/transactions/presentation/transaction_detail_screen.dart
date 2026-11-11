import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/display_currency.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/ledger_transaction.dart';
import 'transaction_view_model.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.transactionId, super.key});
  final String transactionId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LedgerTransaction item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          '${item.conversion.original.format()} · ${item.categoryName}\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(transactionActionsProvider.notifier)
        .delete(item);
    if (!context.mounted) return;
    if (deleted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/history');
      }
    } else {
      showManagementMessage(
        context,
        ledgerErrorMessage(ref.read(transactionActionsProvider).error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display =
        ref.watch(defaultCurrencyProvider).asData?.value ?? DisplayCurrency.myr;
    final transaction = ref.watch(transactionProvider(transactionId));
    final busy = ref.watch(transactionActionsProvider).isLoading;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaction details')),
        body: SafeArea(
          child: transaction.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ManagementLoadError(
              message: 'Unable to load this transaction.',
              onRetry: () => ref.invalidate(transactionProvider(transactionId)),
            ),
            data: (item) => item == null
                ? const Center(
                    child: Text('This transaction no longer exists.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        display.format(item.conversion.myr.minorUnits),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Expense · ${item.categoryName}'),
                      Text('Date: ${item.date}'),
                      if (item.submittedByGuest case final name?)
                        Text('Submitted by: $name (guest)'),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Original: ${item.conversion.original.format()}',
                              ),
                              Text(
                                'MYR equivalent: ${item.conversion.myr.format()}',
                              ),
                              Text(
                                'Saved rate: 1 ${item.conversion.original.currencyCode} = ${item.conversion.exchangeRate} MYR',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This conversion uses the rate saved with this transaction.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (item.categoryArchived || !item.currencyActive)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'This transaction references an archived category or currency. Its original selection can be retained when editing.',
                          ),
                        ),
                      if (item.note != null) ...[
                        const SizedBox(height: 16),
                        const Text('Notes'),
                        SelectableText(item.note!),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => context.push(
                                    '/transactions/${item.id}/edit',
                                  ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _delete(context, ref, item),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
