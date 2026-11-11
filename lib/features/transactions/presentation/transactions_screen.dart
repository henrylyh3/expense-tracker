import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/display_currency.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/category_appearance.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/transaction_filter.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_view_model.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _search;
  Timer? _debounce;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(historyFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _applySearch() {
    try {
      ref.read(historyFilterProvider.notifier).search(_search.text);
      setState(() => _searchError = null);
      return true;
    } on LedgerException catch (error) {
      setState(() => _searchError = error.message);
      return false;
    }
  }

  Future<void> _filters() async {
    _debounce?.cancel();
    if (!_applySearch()) return;
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          TransactionFilterSheet(initial: ref.read(historyFilterProvider)),
    );
    if (mounted && result != null) {
      ref.read(historyFilterProvider.notifier).set(result);
    }
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _searchError = null);
    ref.read(historyFilterProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final display =
        ref.watch(defaultCurrencyProvider).asData?.value ?? DisplayCurrency.myr;
    final filter = ref.watch(historyFilterProvider);
    ref.listen(historyFilterProvider, (previous, next) {
      if (previous?.query != next.query && _search.text.trim() != next.query) {
        _search.text = next.query;
      }
    });
    final history = ref.watch(transactionsProvider);
    final limit = ref.watch(historyLimitProvider);
    return history.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ManagementLoadError(
        message: 'Unable to load transactions.',
        onRetry: () => ref.invalidate(transactionsProvider),
      ),
      data: (all) {
        final visible = all.take(limit).toList(growable: false);
        final more = all.length > limit;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          itemCount: visible.length + 1 + (more ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction history',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (history.isLoading) const LinearProgressIndicator(),
                  TextField(
                    controller: _search,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'Search transactions',
                      hintText: 'Notes, category or currency',
                      prefixIcon: const Icon(Icons.search),
                      errorText: _searchError,
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      final scheduledFilter = ref.read(historyFilterProvider);
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted &&
                            ref.read(historyFilterProvider) ==
                                scheduledFilter) {
                          _applySearch();
                        }
                      });
                    },
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      _applySearch();
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _filters,
                        icon: const Icon(Icons.filter_list),
                        label: Text(
                          filter.fieldCount == 0
                              ? 'Filters'
                              : 'Filters (${filter.fieldCount})',
                        ),
                      ),
                      if (filter.hasConstraints || _search.text.isNotEmpty)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                  if (filter.from != null || filter.to != null)
                    Text(
                      '${filter.from ?? 'Beginning'} through ${filter.to ?? 'Latest'}',
                    ),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        history.isLoading
                            ? 'Updating results…'
                            : filter.hasConstraints
                            ? 'No transactions match these filters.'
                            : 'No transactions yet. Add your first expense.',
                      ),
                    ),
                ],
              );
            }
            if (index > visible.length) {
              return TextButton(
                onPressed: () =>
                    ref.read(historyLimitProvider.notifier).loadMore(),
                child: const Text('Load more'),
              );
            }
            final item = visible[index - 1];
            final displayedAmount = display.format(
              item.conversion.myr.minorUnits,
            );
            final originalAmount = item.conversion.original.format();
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: categoryColor(
                    item.categoryColorHex,
                  ).withValues(alpha: .12),
                  child: Icon(
                    categoryIcons[item.categoryIconKey] ?? Icons.more_horiz,
                    color: categoryColor(item.categoryColorHex),
                  ),
                ),
                title: Text(item.categoryName),
                subtitle: Text(
                  '${item.date}\n$displayedAmount'
                  '\nProfile: ${item.tripName}'
                  '${originalAmount == displayedAmount ? '' : '\nOriginal: $originalAmount'}'
                  '${item.submittedByGuest == null ? '' : '\nGuest: ${item.submittedByGuest}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/transactions/${item.id}'),
              ),
            );
          },
        );
      },
    );
  }
}
