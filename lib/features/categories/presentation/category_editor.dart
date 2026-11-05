import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ledger_types.dart';
import '../../../core/validation/input_validation.dart';
import '../../../shared/widgets/category_appearance.dart';
import '../../../shared/widgets/management_widgets.dart';
import '../domain/ledger_category.dart';
import 'category_view_model.dart';

class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({required this.initialType, this.category, super.key});
  final TransactionType initialType;
  final LedgerCategory? category;

  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _color;
  late TransactionType _type;
  late String _icon;
  Object? _inputError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _color = TextEditingController(
      text: widget.category?.colorHex ?? '#176B58',
    );
    _type = widget.category?.type ?? widget.initialType;
    _icon = widget.category?.iconKey ?? 'more_horiz';
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _inputError = null);
    try {
      final draft = CategoryDraft(
        name: _name.text,
        type: _type,
        iconKey: _icon,
        colorHex: _color.text,
      );
      final saved = await ref
          .read(categoryActionsProvider.notifier)
          .save(draft, id: widget.category?.id);
      if (mounted && saved) Navigator.pop(context, true);
    } on LedgerException catch (error) {
      if (mounted) setState(() => _inputError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryActionsProvider);
    final iconKeys = {...categoryIcons.keys, _icon};
    return EditorSheet(
      title: widget.category == null ? 'Add category' : 'Edit category',
      formKey: _formKey,
      busy: state.isLoading,
      error: _inputError ?? state.error,
      onSave: _save,
      fields: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Category name'),
          validator: (value) => fieldError(
            () => requiredText(
              value ?? '',
              label: 'Category name',
              maxLength: 80,
            ),
          ),
        ),
        DropdownButtonFormField<TransactionType>(
          initialValue: _type,
          decoration: InputDecoration(
            labelText: 'Type',
            helperText: widget.category?.isUsed == true
                ? 'Type is fixed because this category has transactions.'
                : null,
          ),
          items: [
            for (final type in TransactionType.values)
              DropdownMenuItem(
                value: type,
                child: Text(
                  type == TransactionType.income ? 'Income' : 'Expense',
                ),
              ),
          ],
          onChanged: widget.category?.isUsed == true
              ? null
              : (value) => setState(() => _type = value!),
        ),
        DropdownButtonFormField<String>(
          itemHeight: null,
          initialValue: _icon,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Icon'),
          items: [
            for (final key in iconKeys)
              DropdownMenuItem(
                value: key,
                child: Row(
                  children: [
                    Icon(categoryIcons[key] ?? Icons.more_horiz),
                    const SizedBox(width: 12),
                    Flexible(child: Text(key.replaceAll('_', ' '))),
                  ],
                ),
              ),
          ],
          onChanged: (value) => setState(() => _icon = value!),
        ),
        TextFormField(
          controller: _color,
          decoration: const InputDecoration(labelText: 'Color (#RRGGBB)'),
          validator: (value) =>
              fieldError(() => CategoryDraft.validateColorHex(value ?? '')),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in [
              '#176B58',
              '#EF6C00',
              '#8E24AA',
              '#1565C0',
              '#C62828',
              '#546E7A',
            ])
              Semantics(
                label: 'Choose color $color',
                child: IconButton.filledTonal(
                  tooltip: color,
                  onPressed: () => setState(() => _color.text = color),
                  icon: Icon(
                    _color.text.toUpperCase() == color
                        ? Icons.check_circle
                        : Icons.circle,
                    color: categoryColor(color),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
