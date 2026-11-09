import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/money/currency_catalog.dart';
import '../../../core/money/exchange_rate.dart';
import '../../../core/validation/input_validation.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/configured_currency.dart';
import 'currency_view_model.dart';
import '../data/frankfurter_service.dart';

class CurrencyEditor extends ConsumerStatefulWidget {
  const CurrencyEditor({
    required this.configuredCodes,
    this.currency,
    super.key,
  });
  final Set<String> configuredCodes;
  final ConfiguredCurrency? currency;

  @override
  ConsumerState<CurrencyEditor> createState() => _CurrencyEditorState();
}

class _CurrencyEditorState extends ConsumerState<CurrencyEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _symbol;
  late final TextEditingController _rate;
  late int _precision;
  Object? _inputError;
  Timer? _lookupTimer;
  int _lookupGeneration = 0;
  String _lookupCode = '';
  bool _rateEdited = false;
  bool _fetchingRate = false;
  bool _lookupFailed = false;
  FrankfurterQuote? _quote;

  @override
  void initState() {
    super.initState();
    final currency = widget.currency;
    _code = TextEditingController(text: currency?.code ?? '');
    _name = TextEditingController(text: currency?.name ?? '');
    _symbol = TextEditingController(text: currency?.symbol ?? '');
    _rate = TextEditingController(text: currency?.rateToMyr ?? '');
    _precision = currency?.decimalPlaces ?? 2;
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _lookupGeneration++;
    _code.dispose();
    _name.dispose();
    _symbol.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _chooseTemplate(String? code) {
    if (code == null) return;
    final suggestion = currencyCatalog.firstWhere((item) => item.code == code);
    setState(() {
      _code.text = suggestion.code;
      _name.text = suggestion.name;
      _symbol.text = suggestion.symbol;
      _precision = suggestion.decimalPlaces;
      if (code != _lookupCode) _rate.clear();
    });
    _scheduleRateLookup(immediate: true);
  }

  void _scheduleRateLookup({bool immediate = false, bool retry = false}) {
    if (widget.currency != null) return;
    final code = _code.text.trim().toUpperCase();
    if (!retry && code == _lookupCode) return;
    _lookupCode = code;
    _lookupTimer?.cancel();
    final generation = ++_lookupGeneration;
    setState(() {
      _rateEdited = false;
      _fetchingRate = false;
      _lookupFailed = false;
      _quote = null;
      _rate.text = code == 'MYR' ? '1' : '';
    });
    if (code == 'MYR' || !RegExp(r'^[A-Z]{3}$').hasMatch(code)) return;
    if (immediate) {
      unawaited(_fetchRate(code, generation));
    } else {
      _lookupTimer = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_fetchRate(code, generation)),
      );
    }
  }

  Future<void> _fetchRate(String code, int generation) async {
    if (!mounted || generation != _lookupGeneration || _rateEdited) return;
    setState(() => _fetchingRate = true);
    try {
      final quote = await ref.read(frankfurterServiceProvider).fetch(code);
      if (!mounted || generation != _lookupGeneration) return;
      setState(() {
        if (!_rateEdited) {
          _rate.text = quote.rate;
          _quote = quote;
        }
      });
    } catch (_) {
      if (mounted && generation == _lookupGeneration && !_rateEdited) {
        setState(() => _lookupFailed = true);
      }
    } finally {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _fetchingRate = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _inputError = null);
    try {
      final draft = CurrencyDraft(
        code: _code.text,
        name: _name.text,
        symbol: _symbol.text,
        decimalPlaces: _precision,
        rateToMyr: _rate.text,
      );
      final saved = await ref
          .read(currencyActionsProvider.notifier)
          .save(draft, originalCode: widget.currency?.key);
      if (mounted && saved) Navigator.pop(context, true);
    } on LedgerException catch (error) {
      if (mounted) setState(() => _inputError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(currencyActionsProvider);
    final locked =
        widget.currency?.isBase == true ||
        widget.currency?.isUsed == true ||
        widget.currency?.recordId != null;
    final code = _code.text.trim().toUpperCase();
    final base = widget.currency?.isBase == true || code == 'MYR';
    return EditorSheet(
      title: widget.currency == null ? 'Add currency' : 'Edit currency',
      formKey: _formKey,
      busy: state.isLoading,
      error: _inputError ?? state.error,
      onSave: _save,
      fields: [
        if (widget.currency == null)
          DropdownButtonFormField<String>(
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'Currency template (optional)',
            ),
            isExpanded: true,
            items: [
              for (final suggestion in currencyCatalog)
                DropdownMenuItem(
                  value: suggestion.code,
                  enabled:
                      suggestion.code != 'MYR' ||
                      !widget.configuredCodes.contains('MYR'),
                  child: Text('${suggestion.code} · ${suggestion.name}'),
                ),
            ],
            onChanged: _chooseTemplate,
          ),
        TextFormField(
          controller: _code,
          readOnly: locked,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Currency code',
            helperText: locked
                ? 'Code and precision are fixed for MYR and used currencies.'
                : 'Three letters, such as USD, JPY or KRW',
          ),
          validator: (value) =>
              fieldError(() => CurrencyDraft.validateCode(value ?? '')),
          onChanged: (_) {
            setState(() {});
            _scheduleRateLookup();
          },
        ),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Currency name'),
          validator: (value) => fieldError(
            () => requiredText(
              value ?? '',
              label: 'Currency name',
              maxLength: 80,
            ),
          ),
        ),
        TextFormField(
          controller: _symbol,
          decoration: const InputDecoration(labelText: 'Symbol'),
          validator: (value) => fieldError(
            () => requiredText(value ?? '', label: 'Symbol', maxLength: 12),
          ),
        ),
        // Template selection changes precision after the field is mounted.
        DropdownButtonFormField<int>(
          key: ValueKey(_precision),
          initialValue: _precision,
          decoration: const InputDecoration(labelText: 'Decimal places'),
          items: [
            for (var value = 0; value <= 6; value++)
              DropdownMenuItem(value: value, child: Text('$value')),
          ],
          onChanged: locked
              ? null
              : (value) => setState(() => _precision = value!),
        ),
        TextFormField(
          controller: _rate,
          readOnly: base,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'MYR for 1 ${code.isEmpty ? 'unit' : code}',
            helperText: base
                ? 'The MYR base rate is always 1.'
                : 'Example: 4.50 means 1 ${code.isEmpty ? 'unit' : code} = 4.50 MYR.',
          ),
          validator: (value) =>
              fieldError(() => normalizeExchangeRate(value ?? '')),
          onChanged: (_) => setState(() {
            _rateEdited = true;
            _quote = null;
            _lookupFailed = false;
          }),
        ),
        if (_fetchingRate) ...[
          const LinearProgressIndicator(),
          const Text('Getting Frankfurter’s latest reference rate…'),
        ],
        if (_quote != null)
          Text(
            'Frankfurter reference rate · ${_quote!.date}\nPrefilled once. You can edit it before saving.',
          ),
        if (_lookupFailed) ...[
          const Text(
            'Could not get a reference rate. Enter your rate manually, or retry.',
          ),
          TextButton(
            onPressed: () => _scheduleRateLookup(immediate: true, retry: true),
            child: const Text('Retry rate lookup'),
          ),
        ],
        const Text(
          'Changing the default rate affects new transactions only. Existing conversion snapshots are preserved.',
        ),
      ],
    );
  }
}
