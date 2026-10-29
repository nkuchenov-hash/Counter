import 'dart:async';
import 'dart:math' as math;

import 'package:counter/data/database_service.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/features/planning/plan_time_view_layout.dart';
import 'package:counter/features/sharing/shared_detail_page.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:flutter/material.dart';

/// A read-only projection into the *same* Y scale as native Time View.
///
/// Sharing is never represented as a PlanningTask, DragTarget, or a native
/// plan-card layer: a recipient must not be able to mutate owner-owned plans.
/// The private schedule keeps its ordinary width until there are visible
/// shared items; on narrow screens the viewer can switch between the two
/// full-width canvases rather than squeezing native cards into tiny columns.
class SharedTimeViewLane extends StatefulWidget {
  const SharedTimeViewLane({
    super.key,
    required this.wallDay,
    required this.grid,
    required this.rangeStart,
    required this.rangeEnd,
    required this.canvasHeight,
    required this.personalCanvasBuilder,
  });

  final String wallDay;
  final TimeViewYScale grid;
  final int rangeStart;
  final int rangeEnd;
  final double canvasHeight;
  final Widget Function(double canvasWidth) personalCanvasBuilder;

  @override
  State<SharedTimeViewLane> createState() => _SharedTimeViewLaneState();
}

class _SharedTimeViewLaneState extends State<SharedTimeViewLane> {
  List<SharedObject> _shares = const <SharedObject>[];
  Timer? _timer;
  int _generation = 0;
  bool _inFlight = false;
  bool _mobileShowShared = false;
  String? _error;

  bool get _ru => currentLocale.value == 'ru';
  String _l(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && !_inFlight) unawaited(_refresh());
    });
  }

  @override
  void didUpdateWidget(covariant SharedTimeViewLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallDay != widget.wallDay) {
      ++_generation;
      _shares = const <SharedObject>[];
      _mobileShowShared = false;
      _error = null;
      _inFlight = false;
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_inFlight) return;
    final generation = _generation;
    final day = widget.wallDay;
    _inFlight = true;
    try {
      final fresh = await ShareService.instance.listForDay(day);
      if (!mounted || generation != _generation || day != widget.wallDay) {
        return;
      }
      setState(() {
        _shares = fresh;
        _error = null;
        if (fresh.every((share) => share.items.isEmpty)) {
          _mobileShowShared = false;
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation || day != widget.wallDay) {
        return;
      }
      final revoked = error is ShareApiException &&
          (error.statusCode == 401 || error.statusCode == 403);
      setState(() {
        if (revoked) {
          _shares = const <SharedObject>[];
          _mobileShowShared = false;
        }
        _error = error.toString();
      });
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }

  Future<void> _openShare(String shareId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedDetailPage(shareId: shareId),
      ),
    );
    if (mounted) unawaited(_refresh());
  }

  // The UTC instant is rendered in *profile* wall time. Using DateTime.utc
  // for the two wall-calendar dates below is deliberate date arithmetic, not
  // an interpretation of wall time as a persisted UTC instant.
  double? _relativeMinute(String raw) {
    final instant = DateTime.tryParse(raw)?.toUtc();
    if (instant == null) return null;
    final settings = DatabaseService.instance.settings;
    final wall = wall_clock.toWallClockForLabel(
      instant,
      settings.timezoneOffsetHours,
      settings.preferredTimeZone,
    );
    final date = DateTime.tryParse(widget.wallDay);
    if (date == null) return null;
    final selected = DateTime.utc(date.year, date.month, date.day);
    final projected = DateTime.utc(
      wall.year, wall.month, wall.day, wall.hour, wall.minute,
    );
    return projected.difference(selected).inMinutes.toDouble() -
        widget.rangeStart * 60;
  }

  List<_SharedTimeSlot> _visibleSlots() {
    final slots = <_SharedTimeSlot>[];
    final total = (widget.rangeEnd - widget.rangeStart) * 60.0;
    for (final share in _shares) {
      for (final item in share.items) {
        final start = _relativeMinute(item.startTime);
        if (start == null) continue;
        final parsedEnd = _relativeMinute(item.endTime);
        final end = parsedEnd != null && parsedEnd > start
            ? parsedEnd
            : start + 30;
        if (end <= 0 || start >= total) continue;
        final clampedStart = start.clamp(0.0, total).toDouble();
        final clampedEnd = end.clamp(0.0, total).toDouble();
        final top = widget.grid.yForMinute(clampedStart);
        final exactHeight = widget.grid.yForMinute(clampedEnd) - top;
        final height = math.min(
          math.max(38.0, exactHeight),
          math.max(1.0, widget.canvasHeight - top),
        );
        if (height <= 0) continue;
        final startLabel = _clock(item.startTime);
        final endLabel = _clock(item.endTime);
        slots.add(_SharedTimeSlot(
          share: share,
          item: item,
          top: top,
          height: height,
          label: endLabel.isEmpty ? startLabel : '$startLabel–$endLabel',
        ));
      }
    }
    slots.sort((a, b) {
      final c = a.top.compareTo(b.top);
      return c != 0 ? c : a.item.planId.compareTo(b.item.planId);
    });
    return slots;
  }

  String _clock(String raw) {
    final instant = DateTime.tryParse(raw)?.toUtc();
    if (instant == null) return '';
    final settings = DatabaseService.instance.settings;
    final wall = wall_clock.toWallClockForLabel(
      instant, settings.timezoneOffsetHours, settings.preferredTimeZone,
    );
    return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
  }

  Widget _sharedCanvas(List<_SharedTimeSlot> slots, ColorScheme scheme) {
    // Never put shared content into the private drag-and-drop Stack.
    return SizedBox(
      height: widget.canvasHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final slot in slots)
            Positioned(
              top: slot.top,
              left: 4,
              right: 4,
              height: slot.height,
              child: Material(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(9),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => unawaited(_openShare(slot.share.id)),
                  child: Row(
                    children: [
                      Container(width: 4, color: scheme.primary),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              Text(
                                slot.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      decoration:
                                          slot.share.myCompleted[slot.item.planId] == true
                                          ? TextDecoration.lineThrough : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(Icons.group_outlined, size: 16),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final slots = _visibleSlots();
      if (slots.isEmpty) return widget.personalCanvasBuilder(width);
      final scheme = Theme.of(context).colorScheme;

      if (width < 640) {
        final displayShared = _mobileShowShared;
        return Stack(
          children: [
            if (displayShared)
              _sharedCanvas(slots, scheme)
            else
              widget.personalCanvasBuilder(width),
            Positioned(
              top: 4,
              right: 6,
              child: Material(
                elevation: 1,
                color: scheme.surface,
                borderRadius: BorderRadius.circular(9),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => setState(
                    () => _mobileShowShared = !_mobileShowShared,
                  ),
                  icon: Icon(
                    displayShared ? Icons.event_note_outlined : Icons.group_outlined,
                    size: 18,
                  ),
                  label: Text(
                    displayShared
                        ? _l('Личные', 'Personal')
                        : _l('Общие (${slots.length})', 'Shared (${slots.length})'),
                  ),
                ),
              ),
            ),
          ],
        );
      }

      // Dedicated parallel lane: same Y coordinates as the personal grid,
      // no overlap with private cards or their resize/drag hit targets.
      final sharedWidth = (width * 0.31).clamp(195.0, 300.0).toDouble();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: widget.personalCanvasBuilder(width - sharedWidth)),
          SizedBox(
            width: sharedWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Stack(children: [
                _sharedCanvas(slots, scheme),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2,
                      ),
                      color: scheme.surfaceContainerLow,
                      child: Text(
                        _l('Общие', 'Shared'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      );
    });
  }
}

class _SharedTimeSlot {
  const _SharedTimeSlot({
    required this.share,
    required this.item,
    required this.top,
    required this.height,
    required this.label,
  });

  final SharedObject share;
  final SharedPlanItem item;
  final double top;
  final double height;
  final String label;
}
