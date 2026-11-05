import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../../categories/presentation/category_view_model.dart';
import '../../currencies/presentation/currency_view_model.dart';
import '../domain/transaction_filter.dart';

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({required this.initial, super.key});
  final TransactionFilter initial;
  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  final _formKey = GlobalKey<FormState>();
  TransactionType? _type;
  String? _category;
  String? _currency;
  CalendarDate? _from;
  CalendarDate? _to;
  Object? _error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial.type;
    _category = initial.categoryId;
    _currency = initial.currencyCode;
    _from = initial.from;
    _to = initial.to;
  }

  Future<void> _pickDate(bool from) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to)?.toLocalDateTime() ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (mounted && date != null) {
      setState(() {
        if (from) {
          _from = CalendarDate.fromDateTime(date);
        } else {
          _to = CalendarDate.fromDateTime(date);
        }
      });
    }
  }

  void _apply(String? category, String? currency) {
    try {
      final value = TransactionFilter(
        query: widget.initial.query,
        type: _type,
        categoryId: category,
        currencyCode: currency,
        from: _from,
        to: _to,
      );
      Navigator.pop(context, value);
    } on LedgerException catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final currencies = ref.watch(currenciesProvider);
    Widget loading() => const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    );
    Widget failure(Object error, StackTrace stack) => ManagementLoadError(
      onRetry: () {
        ref.invalidate(categoriesProvider);
        ref.invalidate(currenciesProvider);
      },
    );
    return categories.when(
      loading: loading,
      error: failure,
      data: (allCategories) => currencies.when(
        loading: loading,
        error: failure,
        data: (allCurrencies) {
          final available = allCategories
              .where((item) => _type == null || item.type == _type)
              .toList();
          final category = available.any((item) => item.id == _category)
              ? _category
              : null;
          final currency = allCurrencies.any((item) => item.code == _currency)
              ? _currency
              : null;
          return EditorSheet(
            title: 'Filter transactions',
            formKey: _formKey,
            busy: false,
            saveLabel: 'Apply filters',
            onSave: () => _apply(category, currency),
            error: _error,
            fields: [
              DropdownButtonFormField<TransactionType>(
                key: ValueKey('type:$_type'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  const DropdownMenuItem<TransactionType>(
                    child: Text('All types'),
                  ),
                  for (final type in TransactionType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(
                        type == TransactionType.income ? 'Income' : 'Expense',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _type = value;
                  _category = null;
                }),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('category:$category'),
                initialValue: category,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<String>(child: Text('All categories')),
                  for (final item in available)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.name} · ${item.type.name}${item.isArchived ? ' (archived)' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('currency:$currency'),
                initialValue: currency,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: [
                  const DropdownMenuItem<String>(child: Text('All currencies')),
                  for (final item in allCurrencies)
                    DropdownMenuItem(
                      value: item.code,
                      child: Text(
                        '${item.code} · ${item.name}${!item.isActive ? ' (archived)' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _currency = value),
              ),
              const Text(
                'Date boundaries include the selected days. Either boundary can be left empty.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_from == null ? 'From date' : 'From $_from'),
                  ),
                  if (_from != null)
                    IconButton(
                      tooltip: 'Clear start date',
                      onPressed: () => setState(() => _from = null),
                      icon: const Icon(Icons.clear),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_to == null ? 'To date' : 'To $_to'),
                  ),
                  if (_to != null)
                    IconButton(
                      tooltip: 'Clear end date',
                      onPressed: () => setState(() => _to = null),
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  _type = null;
                  _category = null;
                  _currency = null;
                  _from = null;
                  _to = null;
                  _error = null;
                }),
                child: const Text('Reset filters'),
              ),
            ],
          );
        },
      ),
    );
  }
}
