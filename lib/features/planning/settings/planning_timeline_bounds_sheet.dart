import 'package:counter/features/planning/planning_day_start_prefs.dart';import 'package:flutter/material.dart';/// Bottom sheet: local timeline hour range (0–23) for the Planning grid.
class PlanningTimelineBoundsSheet extends StatefulWidget {
  const PlanningTimelineBoundsSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.onBoundsChanged,
    required this.title,
    required this.helper,
    required this.valueSummaryBuilder,
    required this.prevDayMarker,
    required this.nextDayMarker,
    this.header,
  });

  final int initialStart;
  final int initialEnd;
  final void Function(int start, int end) onBoundsChanged;
  final String title;
  final String helper;
  final String Function(int start, int end) valueSummaryBuilder;
  final String prevDayMarker;
  final String nextDayMarker;
  final Widget? header;

  @override
  State<PlanningTimelineBoundsSheet> createState() =>
      PlanningTimelineBoundsSheetState();
}

class PlanningTimelineBoundsSheetState
    extends State<PlanningTimelineBoundsSheet> {
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    final range = PlanningSheetTimelinePrefs.normalizeExtendedRange(
      widget.initialStart,
      widget.initialEnd,
    );
    _range = RangeValues(range.start.toDouble(), range.end.toDouble());
  }

  void _commit(RangeValues values) {
    var start = values.start.round();
    var end = values.end.round();
    final normalized = PlanningSheetTimelinePrefs.normalizeExtendedRange(
      start,
      end,
    );
    setState(() {
      _range = RangeValues(
        normalized.start.toDouble(),
        normalized.end.toDouble(),
      );
    });
    widget.onBoundsChanged(normalized.start, normalized.end);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = _range.start.round();
    final end = _range.end.round();
    final summary = widget.valueSummaryBuilder(start, end);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) widget.header!,
          if (widget.header != null) const Divider(height: 1),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.helper,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          RangeSlider(
            values: _range,
            min: PlanningSheetTimelinePrefs.extendedMin.toDouble(),
            max: PlanningSheetTimelinePrefs.extendedMax.toDouble(),
            divisions: PlanningSheetTimelinePrefs.rangeSliderDivisions,
            labels: RangeLabels(
              PlanningSheetTimelinePrefs.formatExtendedHourClock(start) +
                  (start < 0 ? ' ${widget.prevDayMarker}' : ''),
              PlanningSheetTimelinePrefs.formatExtendedHourClock(end) +
                  (end > 24 ? ' ${widget.nextDayMarker}' : ''),
            ),
            onChanged: _commit,
          ),
        ],
      ),
    );
  }
}
