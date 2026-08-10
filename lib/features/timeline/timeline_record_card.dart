import 'dart:async';

import 'package:counter/core/app_colors.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/timeline/timeline_helpers.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class TimelineRecordCard extends StatefulWidget {
  const TimelineRecordCard({
    required this.vm,
    this.currentActivityFromDate,
    required this.onStop,
    required this.onDelete,
    required this.onEdit,
  });

  final TimelineRecordRowVm vm;
  final String? currentActivityFromDate;
  final Future<void> Function(String systemRowId) onStop;
  final Future<void> Function(String systemRowId) onDelete;
  final VoidCallback onEdit;

  @override
  State<TimelineRecordCard> createState() => TimelineRecordCardState();
}

class TimelineRecordCardState extends State<TimelineRecordCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfRunning();
  }

  @override
  void didUpdateWidget(TimelineRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm.isCanonicalRunning != widget.vm.isCanonicalRunning) {
      _startTimerIfRunning();
    }
  }

  void _startTimerIfRunning() {
    _timer?.cancel();
    _timer = null;
    if (widget.vm.isCanonicalRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(currentLocale.value, 'delete_record_confirm')),
        content: Text(t(currentLocale.value, 'cannot_undo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t(currentLocale.value, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.onDelete(widget.vm.systemRowId);
    }
  }

  String _subtitleForBuild() {
    if (widget.vm.isPlanned) {
      return t(currentLocale.value, 'planned_label');
    }
    if (widget.vm.isCanonicalRunning) {
      final startTimeUtc = CategoryServiceExtension.startTimeFromRecord(
        widget.vm.rawData,
      );
      if (startTimeUtc != null) {
        final start = timelineFormatTimeOfDay(timelineUtcToDisplay(startTimeUtc));
        final duration = DatabaseService.getPlanetaryNow().difference(
          startTimeUtc,
        );
        return '$start — ... (${timelineFormatDuration(duration)})';
      }
      return t(currentLocale.value, 'running_label');
    }
    if (widget.vm.subtitle == 'planned' || widget.vm.subtitle == 'running') {
      return t(currentLocale.value, 'running_label');
    }
    return widget.vm.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRunning = widget.vm.isCanonicalRunning;
    final subtitle = _subtitleForBuild();
    final metaIcons = timelineRowMetaIconsFromVm(context, widget.vm);

    final runningFill = isRunning ? scheme.surfaceContainerHighest : null;
    final runningBorder = isRunning ? scheme.primary : Colors.transparent;
    final runningTextColor = isRunning ? scheme.onSurface : null;

    const cardRadius = 12.0;

    final paddedRow = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentActivityFromDate != null) ...[
                  Text(
                    t(
                      currentLocale.value,
                      'current_activity_from',
                    ).replaceFirst('%s', widget.currentActivityFromDate!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.vm.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (metaIcons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 4,
                          top: 1,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: metaIcons,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                CategoryBreadcrumb(
                  breadcrumbPath: widget.vm.categoryPath,
                  accentColor: widget.vm.categoryColor,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isRunning
                          ? runningTextColor
                          : scheme.onSurfaceVariant,
                      fontWeight: isRunning ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRunning)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: FilledButton.icon(
                onPressed: () => widget.onStop(widget.vm.systemRowId),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text(t(currentLocale.value, 'stop')),
              ),
            ),
          IconButton(
            style: IconButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: t(currentLocale.value, 'delete'),
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );

    return Material(
      elevation: isRunning ? 2 : 1,
      color: runningFill ?? scheme.surface,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(
          color: isRunning ? runningBorder : scheme.outlineVariant.withValues(alpha: 0.35),
          width: isRunning ? 2.0 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onEdit,
        borderRadius: BorderRadius.circular(cardRadius),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: widget.vm.categoryColor, width: 4),
            ),
          ),
          child: paddedRow,
        ),
      ),
    );
  }
}
