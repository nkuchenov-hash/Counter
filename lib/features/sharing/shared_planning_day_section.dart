import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/sharing/share_service.dart';
import 'package:counter/features/sharing/shared_detail_page.dart';
import 'package:counter/features/sharing/shared_inbox_section.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/time/wall_clock.dart' as wall_clock;
import 'package:flutter/material.dart';

/// A separate shared projection for the selected day. No personal [plans]
/// mutations, no callbacks into the native Plan card/drag/reorder engine.
/// Never fetches on an offscreen or inactive Planning day.
class SharedPlanningDaySection extends StatefulWidget {
  const SharedPlanningDaySection({
    super.key,
    required this.wallDay,
    required this.active,
    this.autoRefresh = true,
  });

  final String wallDay;
  final bool active;
  final bool autoRefresh;

  @override
  State<SharedPlanningDaySection> createState() =>
      _SharedPlanningDaySectionState();
}

class _SharedPlanningDaySectionState extends State<SharedPlanningDaySection> {
  List<SharedObject> _shares = const <SharedObject>[];
  Timer? _refreshTimer;
  bool _requestInFlight = false;
  int _requestGeneration = 0;
  bool _loaded = false;
  String? _error;

  bool get _ru => currentLocale.value == 'ru';
  String l(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    _updateActivation();
  }

  @override
  void didUpdateWidget(covariant SharedPlanningDaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallDay != widget.wallDay ||
        oldWidget.active != widget.active ||
        oldWidget.autoRefresh != widget.autoRefresh) {
      // Discard responses fetched for a previous selected day or inactive tab.
      _requestGeneration++;
      _shares = const <SharedObject>[];
      _error = null;
      _loaded = false;
      _requestInFlight = false;
      _updateActivation();
    }
  }

  void _updateActivation() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!widget.active) return;
    unawaited(_refresh());
    if (widget.autoRefresh) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted && widget.active && !_requestInFlight) {
          unawaited(_refresh());
        }
      });
    }
  }

  Future<void> _refresh() async {
    if (!widget.active || _requestInFlight) return;
    final generation = _requestGeneration;
    final day = widget.wallDay;
    _requestInFlight = true;
    try {
      final result = await ShareService.instance.listForDay(day);
      if (!mounted || !widget.active || _requestGeneration != generation ||
          widget.wallDay != day) return;
      setState(() {
        _shares = result;
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || !widget.active || _requestGeneration != generation) return;
      setState(() {
        _loaded = true;
        _error = error.toString();
      });
    } finally {
      if (_requestGeneration == generation) _requestInFlight = false;
    }
  }

  String _clockLabel(String raw) {
    if (raw.isEmpty) return '';
    final utc = DateTime.tryParse(raw)?.toUtc();
    if (utc == null) return '';
    final settings = DatabaseService.instance.settings;
    final clock = wall_clock.toWallClockForLabel(
      utc, settings.timezoneOffsetHours, settings.preferredTimeZone);
    return '${clock.hour.toString().padLeft(2, '0')}:'
        '${clock.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _open(SharedObject item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SharedDetailPage(shareId: item.id),
    ));
    if (mounted && widget.active) unawaited(_refresh());
  }

  @override
  void dispose() {
    _requestGeneration++;
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || (!_loaded && _shares.isEmpty)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    if (_shares.isEmpty) {
      if (_error == null) return const SizedBox.shrink();
      // One compact retry affordance; never replace personal Planning content.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _requestInFlight ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.sync_problem_outlined, size: 18),
            label: Text(l('Общие планы: повторить загрузку',
                'Shared plans: retry')),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final share in _shares.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_open(share)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.groups_outlined,
                              color: scheme.onSurfaceVariant, size: 19),
                          const SizedBox(width: 8),
                          Expanded(child: Text(share.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall)),
                          Text(l('Общий план', 'Shared'),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 19),
                        ]),
                        if (share.status != 'owner') ...[
                          for (final item in share.items.take(2))
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 27),
                              child: Row(children: [
                                if (_clockLabel(item.startTime).isNotEmpty) ...[
                                  Text(_clockLabel(item.startTime),
                                    style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: scheme.onSurfaceVariant)),
                                  const SizedBox(width: 8),
                                ],
                                Icon(
                                  share.myCompleted[item.planId] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 17, color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: share.myCompleted[item.planId] == true
                                      ? const TextStyle(
                                          decoration: TextDecoration.lineThrough)
                                      : null)),
                              ]),
                            ),
                          if (share.items.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 27),
                              child: Text(l('И ещё ${share.items.length - 2}',
                                           'And ${share.items.length - 2} more'),
                                  style: Theme.of(context).textTheme.labelSmall),
                            ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 3, left: 27),
                            child: Text(l('Участники видят ${share.items.length} задач',
                                          'Participants see ${share.items.length} tasks'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_shares.length > 2)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SharedInboxPage(),
                ),
              ),
              child: Text(l('Все общие планы (${_shares.length})',
                  'All shared plans (${_shares.length})')),
            ),
        ],
      ),
    );
  }
}
