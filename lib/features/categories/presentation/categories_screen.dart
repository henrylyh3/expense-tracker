import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/category_appearance.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/ledger_category.dart';
import 'category_editor.dart';
import 'category_view_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _showArchived = false;

  Future<void> _edit([LedgerCategory? category]) async {
    ref.read(categoryActionsProvider.notifier).clearError();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CategoryEditor(category: category),
    );
    if (mounted && saved == true) {
      showManagementMessage(context, 'Category saved.');
    }
  }

  Future<void> _remove(LedgerCategory category) async {
    if (!await confirmRemoval(
          context,
          name: category.name,
          used: category.isUsed,
        ) ||
        !mounted) {
      return;
    }
    final result = await ref
        .read(categoryActionsProvider.notifier)
        .remove(category.id);
    if (!mounted) return;
    showManagementMessage(
      context,
      result == null
          ? ledgerErrorMessage(ref.read(categoryActionsProvider).error)
          : result == RemovalOutcome.archived
          ? 'Category archived.'
          : 'Category deleted.',
    );
  }

  Future<void> _restore(LedgerCategory category) async {
    final restored = await ref
        .read(categoryActionsProvider.notifier)
        .restore(category.id);
    if (mounted) {
      showManagementMessage(
        context,
        restored
            ? 'Category restored.'
            : ledgerErrorMessage(ref.read(categoryActionsProvider).error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final busy = ref.watch(categoryActionsProvider).isLoading;
    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ManagementLoadError(
        onRetry: () => ref.invalidate(categoriesProvider),
      ),
      data: (all) {
        final items = all
            .where(
              (item) =>
                  item.type == TransactionType.expense &&
                  (_showArchived || !item.isArchived),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          children: [
            Text(
              'Manage categories',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show archived'),
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
            FilledButton.icon(
              onPressed: busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No categories for this filter.'),
              ),
            for (final category in items)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor(
                      category.colorHex,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      categoryIcons[category.iconKey] ?? Icons.more_horiz,
                      color: categoryColor(category.colorHex),
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    '${category.usageCount} transactions${category.isArchived ? ' · Archived' : ''}',
                  ),
                  onTap: busy ? null : () => _edit(category),
                  trailing: PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'Actions for ${category.name}',
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          await _edit(category);
                        case 'restore':
                          await _restore(category);
                        case 'remove':
                          await _remove(category);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (category.isArchived)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        ),
                      if (!category.isArchived || !category.isUsed)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(category.isUsed ? 'Archive' : 'Delete'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
