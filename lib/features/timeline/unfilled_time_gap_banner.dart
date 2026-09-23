import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/records/unfilled_time_gap_policy.dart';
import 'package:counter/data/records/unfilled_time_gap_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Legacy top-banner entry point.
///
/// Unfilled-time prompts are intentionally forbidden from occupying the top
/// shell/status area. Keep this as a no-op so an accidental legacy call cannot
/// reintroduce the full-width banner.
@Deprecated('Use UnfilledTimeGapSidebarCard in the desktop side navigation.')
class UnfilledTimeGapBanner extends StatelessWidget {
  const UnfilledTimeGapBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Compact desktop/web prompt that lives in the left navigation rail only.
class UnfilledTimeGapSidebarCard extends StatelessWidget {
  const UnfilledTimeGapSidebarCard({super.key});

  String _time(BuildContext context, DateTime utc) {
    final wall = DatabaseService.instance.applyUserOffset(utc.toUtc());
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(wall),
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
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(locale, 'unfilled_time_banner'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              range,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton.secondary(
                    label: t(locale, 'unfilled_time_fill'),
                    size: AppButtonSize.s,
                    fullWidth: true,
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

    var ok = false;
    try {
      ok = await UnfilledTimeGapService.instance
          .fillGap(gap, title)
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
    } catch (_) {
      ok = false;
    }

    if (!sheetContext.mounted) return;
    if (ok) {
      Navigator.of(sheetContext).pop();
      AppSnack.saved();
      return;
    }

    setSheetState(() => setSaving(false));
    AppSnack.failed();
  }
}
