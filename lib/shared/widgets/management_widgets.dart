import 'package:flutter/material.dart';

import '../../core/models/ledger_types.dart';

class EditorSheet extends StatelessWidget {
  const EditorSheet({
    required this.title,
    required this.formKey,
    required this.fields,
    required this.busy,
    required this.onSave,
    this.error,
    this.includeKeyboardInsets = true,
    this.saveLabel = 'Save',
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final bool busy;
  final VoidCallback onSave;
  final Object? error;
  final bool includeKeyboardInsets;
  final String saveLabel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 +
            (includeKeyboardInsets
                ? MediaQuery.viewInsetsOf(context).bottom
                : 0) +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            AbsorbPointer(
              absorbing: busy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in fields) ...[
                    field,
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            if (error != null) ...[
              Text(
                ledgerErrorMessage(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : onSave,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(saveLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmRemoval(
  BuildContext context, {
  required String name,
  required bool used,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${used ? 'Archive' : 'Delete'} $name?'),
        content: Text(
          used
              ? 'Historical transactions will retain this item. It will no longer be available for new transactions.'
              : 'Unused items are permanently deleted. Items referenced by transactions are archived to preserve history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(used ? 'Archive' : 'Delete'),
          ),
        ],
      ),
    ) ??
    false;

void showManagementMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ManagementLoadError extends StatelessWidget {
  const ManagementLoadError({
    required this.onRetry,
    this.message = 'Unable to load these settings.',
    super.key,
  });
  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
