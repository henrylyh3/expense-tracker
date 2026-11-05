import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates/calendar_date.dart';
import '../../../core/models/ledger_types.dart';
import '../../../core/money/exchange_rate.dart';
import '../../../core/money/money.dart';
import '../../../core/validation/input_validation.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../../categories/domain/ledger_category.dart';
import '../../categories/presentation/category_view_model.dart';
import '../../currencies/domain/configured_currency.dart';
import '../../currencies/presentation/currency_view_model.dart';
import '../domain/conversion_policy.dart';
import '../domain/ledger_transaction.dart';
import '../domain/transaction_input.dart';
import 'transaction_view_model.dart';

class TransactionEditorScreen extends ConsumerWidget {
  const TransactionEditorScreen({this.transactionId, super.key});
  final String? transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final currencies = ref.watch(currenciesProvider);
    Widget loading() => const Center(child: CircularProgressIndicator());
    Widget failure(Object error, StackTrace stack) => ManagementLoadError(
      message: 'Unable to load the transaction editor.',
      onRetry: () {
        ref.invalidate(categoriesProvider);
        ref.invalidate(currenciesProvider);
        if (transactionId != null) {
          ref.invalidate(transactionProvider(transactionId!));
        }
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: SafeArea(
        child: categories.when(
          loading: loading,
          error: failure,
          data: (allCategories) => currencies.when(
            loading: loading,
            error: failure,
            data: (allCurrencies) {
              Widget form(LedgerTransaction? original) => _TransactionForm(
                key: ValueKey(transactionId ?? 'new'),
                original: original,
                categories: allCategories,
                currencies: allCurrencies,
              );
              if (transactionId == null) return form(null);
              return ref
                  .watch(transactionProvider(transactionId!))
                  .when(
                    loading: loading,
                    error: failure,
                    data: (original) => original == null
                        ? const Center(
                            child: Text('This transaction no longer exists.'),
                          )
                        : form(original),
                  );
            },
          ),
        ),
      ),
    );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({
    required this.original,
    required this.categories,
    required this.currencies,
    super.key,
  });
  final LedgerTransaction? original;
  final List<LedgerCategory> categories;
  final List<ConfiguredCurrency> currencies;
  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final LedgerTransaction? _original;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late final TextEditingController _rate;
  late TransactionType _type;
  late String _currencyCode;
  late CalendarDate _date;
  String? _categoryId;
  bool _customRate = false;
  bool _currencyConfirmed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Retain the revision actually opened by this editor. A stream refresh must
    // not silently overwrite user input or authorize a stale save.
    _original = widget.original;
    _amount = TextEditingController(
      text: _original?.conversion.original.toInput() ?? '',
    );
    _note = TextEditingController(text: _original?.note ?? '');
    _rate = TextEditingController();
    _type = _original?.type ?? TransactionType.expense;
    _currencyCode = _original?.conversion.original.currencyCode ?? 'MYR';
    _categoryId = _original?.categoryId;
    _date = _original?.date ?? CalendarDate.today();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _rate.dispose();
    super.dispose();
  }

  ConfiguredCurrency? get _currency {
    for (final currency in widget.currencies) {
      if (currency.code == _currencyCode &&
          (currency.isActive ||
              currency.code == _original?.conversion.original.currencyCode)) {
        return currency;
      }
    }
    return null;
  }

  bool get _changedCurrency =>
      _original != null &&
      _currencyCode != _original.conversion.original.currencyCode;

  String _defaultRate(ConfiguredCurrency currency) =>
      currency.code == _original?.conversion.original.currencyCode
      ? _original!.conversion.exchangeRate
      : currency.rateToMyr;
  String _effectiveRate(ConfiguredCurrency currency) =>
      _customRate ? _rate.text : _defaultRate(currency);

  String _preview(ConfiguredCurrency? currency) {
    if (currency == null || _amount.text.trim().isEmpty) {
      return 'Enter an amount to preview the MYR equivalent.';
    }
    try {
      final money = Money.parsePositive(
        _amount.text,
        currencyCode: currency.code,
        decimalPlaces: currency.decimalPlaces,
      );
      final snapshot = resolveConversion(
        original: money,
        defaultRate: currency.rateToMyr,
        previous: _original?.conversion,
        currencyChangeConfirmed: true,
        rateOverride: _customRate || _changedCurrency
            ? _effectiveRate(currency)
            : null,
      );
      return 'MYR equivalent: ${snapshot.myr.format()}';
    } on LedgerException catch (error) {
      return error.message;
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date.toLocalDateTime(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (mounted && value != null) {
      setState(() => _date = CalendarDate.fromDateTime(value));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      final currency = _currency;
      if (currency == null || _categoryId == null) {
        throw const LedgerException('Choose a category and currency.');
      }
      if (_changedCurrency && !_currencyConfirmed) {
        throw const LedgerException(
          'Confirm the new currency and conversion before saving.',
        );
      }
      final input = TransactionInput(
        type: _type,
        categoryId: _categoryId!,
        currencyCode: currency.code,
        amountText: _amount.text,
        date: _date,
        note: _note.text,
        rateOverride: _customRate || _changedCurrency
            ? _effectiveRate(currency)
            : null,
        currencyChangeConfirmed: _currencyConfirmed,
      );
      final id = await ref
          .read(transactionActionsProvider.notifier)
          .save(
            input,
            id: _original?.id,
            expectedUpdatedAtUtc: _original?.updatedAtUtc,
          );
      if (!mounted) return;
      if (id == null) {
        setState(() => _error = ref.read(transactionActionsProvider).error);
      } else if (_original == null) {
        context.replace('/transactions/$id');
      } else {
        context.pop();
      }
    } on LedgerException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(transactionActionsProvider).isLoading;
    final currency = _currency;
    final categories = widget.categories
        .where(
          (item) =>
              item.type == _type &&
              (!item.isArchived || item.id == _original?.categoryId),
        )
        .toList();
    final categoryId = categories.any((item) => item.id == _categoryId)
        ? _categoryId
        : null;
    final currencies = widget.currencies
        .where(
          (item) =>
              item.isActive ||
              item.code == _original?.conversion.original.currencyCode,
        )
        .toList();
    return EditorSheet(
      title: _original == null ? 'Add transaction' : 'Edit transaction',
      formKey: _formKey,
      busy: busy,
      error: _error,
      onSave: _save,
      includeKeyboardInsets: false,
      fields: [
        DropdownButtonFormField<TransactionType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final type in TransactionType.values)
              DropdownMenuItem(
                value: type,
                child: Text(
                  type == TransactionType.income ? 'Income' : 'Expense',
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _type = value!;
            _categoryId = null;
          }),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('category:${_type.name}:$categoryId'),
          initialValue: categoryId,
          decoration: const InputDecoration(labelText: 'Category'),
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final item in categories)
              DropdownMenuItem(
                value: item.id,
                child: Text(
                  '${item.name}${item.isArchived ? ' (archived)' : ''}',
                ),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
          validator: (value) => value == null ? 'Choose a category.' : null,
        ),
        if (categories.isEmpty)
          TextButton(
            onPressed: () => context.go('/settings/categories'),
            child: const Text('Create a category in Settings'),
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('currency:${currency?.code}'),
          initialValue: currency?.code,
          decoration: const InputDecoration(labelText: 'Currency'),
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final item in currencies)
              DropdownMenuItem(
                value: item.code,
                child: Text(
                  '${item.code} · ${item.name}${!item.isActive ? ' (archived)' : ''}',
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _currencyCode = value!;
            _customRate = false;
            _currencyConfirmed = false;
          }),
          validator: (value) => value == null ? 'Choose a currency.' : null,
        ),
        TextFormField(
          controller: _amount,
          decoration: const InputDecoration(
            labelText: 'Amount',
            helperText: 'Use a decimal point; no grouping separators.',
          ),
          keyboardType: TextInputType.numberWithOptions(
            decimal: (currency?.decimalPlaces ?? 2) > 0,
          ),
          onChanged: (_) => setState(() {}),
          validator: (value) => currency == null
              ? 'Choose a currency.'
              : fieldError(
                  () => Money.parsePositive(
                    value ?? '',
                    currencyCode: currency.code,
                    decimalPlaces: currency.decimalPlaces,
                  ),
                ),
        ),
        if (currency != null) ...[
          Text(
            '1 ${currency.code} = ${_customRate ? _rate.text : _defaultRate(currency)} MYR',
          ),
          if (!currency.isBase)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Edit conversion rate'),
              value: _customRate,
              subtitle: Text(
                _original != null && !_changedCurrency
                    ? 'Ordinary edits retain the saved rate.'
                    : 'Default rate comes from Settings.',
              ),
              onChanged: (value) => setState(() {
                _rate.text = _effectiveRate(currency);
                _customRate = value;
                _currencyConfirmed = false;
              }),
            ),
          if (_customRate)
            TextFormField(
              controller: _rate,
              decoration: const InputDecoration(
                labelText: 'MYR for 1 currency unit',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _currencyConfirmed = false),
              validator: (value) =>
                  fieldError(() => normalizeExchangeRate(value ?? '')),
            ),
          if (_original != null && !_changedCurrency && !currency.isBase)
            TextButton(
              onPressed: () => setState(() {
                _customRate = true;
                _rate.text = currency.rateToMyr;
              }),
              child: const Text('Use current configured rate'),
            ),
          Text(
            _preview(currency),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_changedCurrency)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _currencyConfirmed,
              title: const Text(
                'Use this currency and conversion for the transaction',
              ),
              onChanged: (value) =>
                  setState(() => _currencyConfirmed = value ?? false),
            ),
        ],
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text('Date: $_date'),
        ),
        TextFormField(
          controller: _note,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          validator: (value) =>
              fieldError(() => TransactionInput.normalizeNote(value)),
        ),
      ],
    );
  }
}
