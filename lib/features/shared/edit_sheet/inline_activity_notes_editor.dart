import 'package:counter/core/theme.dart';
import 'package:counter/features/shared/edit_sheet/quill_link_launcher.dart';
import 'package:counter/features/shared/edit_sheet/quill_toolbar_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Always-visible rich notes field shared by plan and record edit sheets.
///
/// Notes are primary edit content, not a secondary tab: the current text stays
/// visible while the user edits the rest of the activity.
class InlineActivityNotesEditor extends StatelessWidget {
  const InlineActivityNotesEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    super.key,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 720;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        height: compact ? 154 : 184,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Text(
                t(currentLocale.value, 'notes_tab'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kPlanningEditQuillToolbarMinHeight,
              ),
              child: QuillSimpleToolbar(
                controller: controller,
                config: planningTaskEditQuillToolbarConfig(context),
              ),
            ),
            Expanded(
              child: QuillEditor.basic(
                controller: controller,
                focusNode: focusNode,
                scrollController: scrollController,
                config: QuillEditorConfig(
                  expands: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  placeholder: t(currentLocale.value, 'notes_hint_flat'),
                  onLaunchUrl: launchUrlFromQuillEditor,
                  customStyles: DefaultStyles.getInstance(context),
                  keyboardAppearance: Theme.of(context).brightness == Brightness.dark
                      ? Brightness.dark
                      : Brightness.light,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
