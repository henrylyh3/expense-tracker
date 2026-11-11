import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/display_currency.dart';
import '../../../core/providers/default_currency_provider.dart';
import '../../../core/providers/trip_provider.dart';
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
    final display =
        ref.watch(defaultCurrencyProvider).asData?.value ?? DisplayCurrency.myr;
    final categories = ref.watch(categoriesProvider);
    final currencies = ref.watch(currenciesProvider);
    Widget loading() => const Center(child: CircularProgressIndicator());
    Widget failure(Object error, StackTrace stack) => ManagementLoadError(
      message: 'Unable to load the transaction editor.',
      onRetry: () {
        ref.invalidate(defaultCurrencyProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(currenciesProvider);
        if (transactionId != null) {
          ref.invalidate(transactionProvider(transactionId!));
        }
      },
    );
    final preference = ref.watch(defaultCurrencyProvider);
    if (preference.hasError) {
      return Scaffold(body: failure(preference.error!, StackTrace.empty));
    }
    if (preference.isLoading) return Scaffold(body: loading());
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
                display: display,
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
    required this.display,
    required this.categories,
    required this.currencies,
    super.key,
  });
  final LedgerTransaction? original;
  final DisplayCurrency display;
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
  late String _currencyCode;
  late CalendarDate _date;
  String? _targetTripId;
  String? _categoryId;
  bool _changedSelection = false;
  bool _customRate = false;
  bool _currencyConfirmed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Retain the revision actually opened by this editor. A stream refresh must
    // not silently overwrite user input or authorize a stale save.
    _original = widget.original;
    _targetTripId = _original?.tripId;
    _amount = TextEditingController(
      text: _original?.conversion.original.toInput() ?? '',
    );
    _note = TextEditingController(text: _original?.note ?? '');
    _rate = TextEditingController();
    _currencyCode =
        _original?.conversion.original.currencyCode ?? widget.display.key;
    _categoryId =
        _original?.categoryId ??
        widget.categories
            .where(
              (category) =>
                  !category.isArchived &&
                  category.type == TransactionType.expense &&
                  (category.id == 'seed-food' ||
                      category.name.toLowerCase() == 'food'),
            )
            .firstOrNull
            ?.id;
    _date = _original?.date ?? CalendarDate.today();
  }

  @override
  void didUpdateWidget(covariant _TransactionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_original == null &&
        !_changedSelection &&
        oldWidget.display.key != widget.display.key) {
      _currencyCode = widget.display.key;
    }
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
      if (currency.key == _currencyCode &&
          (currency.isActive ||
              currency.code == _original?.conversion.original.currencyCode)) {
        return currency;
      }
    }
    return null;
  }

  bool get _changedCurrency =>
      _original != null &&
      _currency?.code != _original.conversion.original.currencyCode;

  String _defaultRate(ConfiguredCurrency currency) =>
      currency.recordId != null && (_original == null || _changedSelection)
      ? currency.rateToMyr
      : currency.code == _original?.conversion.original.currencyCode
      ? _original!.conversion.exchangeRate
      : currency.rateToMyr;
  String _effectiveRate(ConfiguredCurrency currency) =>
      _customRate ? _rate.text : _defaultRate(currency);

  String _preview(ConfiguredCurrency? currency) {
    if (currency == null || _amount.text.trim().isEmpty) {
      return 'Enter an amount to preview the ${widget.display.code} equivalent.';
    }
    try {
      final money = Money.parseExpense(
        _amount.text,
        currencyCode: currency.code,
        decimalPlaces: currency.decimalPlaces,
      );
      final snapshot = resolveConversion(
        original: money,
        defaultRate: currency.rateToMyr,
        previous: _original?.conversion,
        currencyChangeConfirmed: true,
        rateOverride:
            _original == null ||
                _customRate ||
                _changedCurrency ||
                (_changedSelection && currency.recordId != null)
            ? _effectiveRate(currency)
            : null,
      );
      return '${widget.display.code} equivalent: ${widget.display.format(snapshot.myr.minorUnits)}';
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
        type: TransactionType.expense,
        categoryId: _categoryId!,
        currencyCode: currency.code,
        amountText: _amount.text,
        date: _date,
        targetTripId: _targetTripId,
        note: _note.text,
        rateOverride:
            _original == null ||
                _customRate ||
                _changedCurrency ||
                (_changedSelection && currency.recordId != null)
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
      } else {
        if (_original == null) {
          final amount = Money.parseExpense(
            input.amountText,
            currencyCode: currency.code,
            decimalPlaces: currency.decimalPlaces,
          );
          await showDialog<void>(
            context: context,
            builder: (context) {
              final colors = Theme.of(context).colorScheme;
              return AlertDialog(
                icon: CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: const Text('Expense saved'),
                content: Text(
                  amount.format(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          );
        }
        if (mounted) context.pop();
      }
    } on LedgerException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = _original;
    final trips = original == null
        ? const <({String id, String name})>[]
        : ref.watch(tripsProvider).asData?.value ??
              [(id: original.tripId, name: original.tripName)];
    final tripRates = _targetTripId == null
        ? const <String, TripCurrencyRate>{}
        : ref.watch(tripRatesProvider(_targetTripId!)).asData?.value ??
              const <String, TripCurrencyRate>{};
    final busy = ref.watch(transactionActionsProvider).isLoading;
    final currency = _currency;
    final categories = widget.categories
        .where(
          (item) =>
              item.type == TransactionType.expense &&
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
        if (original != null)
          DropdownButtonFormField<String>(
            key: const ValueKey('edit-profile'),
            initialValue: trips.any((trip) => trip.id == _targetTripId)
                ? _targetTripId
                : null,
            decoration: const InputDecoration(labelText: 'Profile'),
            isExpanded: true,
            items: [
              for (final trip in trips)
                DropdownMenuItem(
                  value: trip.id,
                  child: Text(trip.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: busy ? null : (id) => setState(() => _targetTripId = id),
            validator: (_) => trips.any((trip) => trip.id == _targetTripId)
                ? null
                : 'Choose a profile.',
          ),
        DropdownButtonFormField<String>(
          key: ValueKey('category:$categoryId'),
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
          key: ValueKey('currency:${currency?.key}'),
          initialValue: currency?.key,
          decoration: const InputDecoration(labelText: 'Currency'),
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final item in currencies)
              DropdownMenuItem(
                value: item.key,
                child: Text(
                  '${item.code} · ${item.name}${!item.isActive ? ' (archived)' : ''}',
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _changedSelection = true;
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
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          validator: (value) => currency == null
              ? 'Choose a currency.'
              : fieldError(
                  () => Money.parseExpense(
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
                _rate.text = currency.recordId != null
                    ? currency.rateToMyr
                    : tripRates[currency.code]?.rate ?? currency.rateToMyr;
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
