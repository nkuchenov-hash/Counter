import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Result of the compact voice correction sheet.
class DesktopVoiceCorrectionResult {
  const DesktopVoiceCorrectionResult.confirmed({
    required this.title,
    required this.parseResult,
  }) : cancelled = false;

  const DesktopVoiceCorrectionResult.cancelled()
      : cancelled = true,
        title = '',
        parseResult = null;

  final bool cancelled;
  final String title;
  final VoiceCommandParseResult? parseResult;
}

/// Compact correction UI — title edit, confirm, cancel. No diagnostics.
Future<DesktopVoiceCorrectionResult?> showDesktopVoiceCorrectionSheet({
  required BuildContext context,
  required VoiceCommandParseResult parseResult,
  required String categoryPath,
}) async {
  return showModalBottomSheet<DesktopVoiceCorrectionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _DesktopVoiceCorrectionSheetBody(
        parseResult: parseResult,
        categoryPath: categoryPath,
      );
    },
  );
}

class _DesktopVoiceCorrectionSheetBody extends StatefulWidget {
  const _DesktopVoiceCorrectionSheetBody({
    required this.parseResult,
    required this.categoryPath,
  });

  final VoiceCommandParseResult parseResult;
  final String categoryPath;

  @override
  State<_DesktopVoiceCorrectionSheetBody> createState() =>
      _DesktopVoiceCorrectionSheetBodyState();
}

class _DesktopVoiceCorrectionSheetBodyState
    extends State<_DesktopVoiceCorrectionSheetBody> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.parseResult.recordTitle.trim(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  VoiceCommandParseResult _buildResult(String title) {
    return VoiceCommandParseResult(
      rootLabel: widget.parseResult.rootLabel,
      matchedCategoryPocketBaseId: widget.parseResult.matchedCategoryPocketBaseId,
      matchedCategoryDisplayPath: widget.parseResult.matchedCategoryDisplayPath,
      matchedLocalCategoryId: widget.parseResult.matchedLocalCategoryId,
      recordTitle: title.trim(),
      confidence: widget.parseResult.confidence,
      originalTranscript: widget.parseResult.originalTranscript,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(loc, 'desktop_voice_correction_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.categoryPath,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t(loc, 'desktop_voice_record_title'),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onConfirm(),
                ),
                const SizedBox(height: 8),
                Text(
                  t(loc, 'desktop_voice_correction_category_hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                AppButton.primary(
                  label: t(loc, 'desktop_voice_confirm_now'),
                  onPressed: _onConfirm,
                ),
                const SizedBox(height: 8),
                AppButton.secondary(
                  label: t(loc, 'desktop_voice_correction_cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      const DesktopVoiceCorrectionResult.cancelled(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      DesktopVoiceCorrectionResult.confirmed(
        title: title,
        parseResult: _buildResult(title),
      ),
    );
  }
}
