import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/records/unfilled_time_gap_policy.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class UnfilledTimeGapBanner extends StatelessWidget {
  const UnfilledTimeGapBanner({super.key});

  String _time(BuildContext context, DateTime utc) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(utc.toLocal()),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TimelineGap?>(
      valueListenable: UnfilledTimeGapService.instance.currentGap,
      builder: (context, gap, _) {
        if (gap == null) return const SizedBox.shrink();
        final locale = currentLocale.value;
        final range =
            '${_time(context, gap.startUtc)}–${_time(context, gap.endUtc)}';
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.secondaryContainer,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${t(locale, 'unfilled_time_banner')} · $range',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton.secondary(
                    label: t(locale, 'unfilled_time_fill'),
                    size: AppButtonSize.s,
                    onPressed: () => _openEditor(context, gap),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, TimelineGap gap) async {
    final controller = TextEditingController();
    var saving = false;
    final locale = currentLocale.value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(locale, 'unfilled_time_sheet_title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: t(locale, 'unfilled_time_activity_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (!saving) {
                          _saveGap(
                            sheetContext,
                            gap,
                            controller,
                            setSheetState,
                            () => saving,
                            (value) => saving = value,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: t(locale, 'save'),
                      fullWidth: true,
                      loading: saving,
                      onPressed: saving
                          ? null
                          : () => _saveGap(
                              sheetContext,
                              gap,
                              controller,
                              setSheetState,
                              () => saving,
                              (value) => saving = value,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _saveGap(
    BuildContext sheetContext,
    TimelineGap gap,
    TextEditingController controller,
    StateSetter setSheetState,
    bool Function() isSaving,
    void Function(bool) setSaving,
  ) async {
    if (isSaving()) return;
    final title = controller.text.trim();
    if (title.isEmpty) return;
    setSheetState(() => setSaving(true));
    final ok = await UnfilledTimeGapService.instance.fillGap(gap, title);
    if (!sheetContext.mounted) return;
    if (ok) {
      Navigator.of(sheetContext).pop();
      AppSnack.saved();
    } else {
      setSheetState(() => setSaving(false));
      AppSnack.failed();
    }
  }
}
