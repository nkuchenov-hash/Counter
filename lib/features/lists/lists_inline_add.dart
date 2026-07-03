import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Inline quick-add row shown when a category filter is active.
class ListsInlineAddRow extends StatelessWidget {
  const ListsInlineAddRow({
    super.key,
    required this.locale,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final String locale;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: t(locale, 'input_placeholder_list'),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.45),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add_rounded),
            label: Text(t(locale, 'add')),
          ),
        ],
      ),
    );
  }
}
