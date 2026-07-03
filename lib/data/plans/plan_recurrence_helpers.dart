part of '../database_service.dart';

List<String> _parsePlanExceptionDatesForOffline(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().length >= 10)
        e.toString().trim().substring(0, 10),
  ];
}

String? _normPlanRecurrenceInstanceKey(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.length >= 10) return s.substring(0, 10);
  return null;
}

extension PlanRecurrenceExtension on DatabaseService {
  void _collectMaterializedRecurrenceSuppressionKeys(
    PlanningTask task,
    Set<String> keys,
  ) {
    if (_isJitVirtualPlanningTask(task)) return;
    final inst = task.recurrenceInstanceDateKey?.trim();
    if (inst == null || inst.length < 10) return;
    final instDay = inst.substring(0, 10);

    final seriesPb = task.parentPlanPocketId?.trim();
    if (seriesPb != null &&
        DatabaseService._isLikelyPocketBaseRowId(seriesPb)) {
      keys.add('$seriesPb|$instDay');
    }

    final pocket = task.pocketRecordId?.trim();
    if (pocket != null &&
        DatabaseService._isLikelyPocketBaseRowId(pocket) &&
        (seriesPb == null || seriesPb.isEmpty)) {
      keys.add('$pocket|$instDay');
    }

    final biz = _planBusinessUuidFromTask(task);
    if (biz != null && biz.isNotEmpty) {
      keys.add('biz:$biz|$instDay');
    }
  }

  String _normalizeRruleStringForDecoder(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.toUpperCase().startsWith('RRULE:')) {
      s = 'RRULE:$s';
    }
    return s;
  }

  DateTime? _utcDateOnlyFromPlanDateKey(String dk) {
    if (dk.length < 10) return null;
    final y = int.tryParse(dk.substring(0, 4));
    final m = int.tryParse(dk.substring(5, 7));
    final d = int.tryParse(dk.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// JIT: expand [PlanningTask.rrule] into virtual rows between [viewStart] and [viewEnd] (wall dates).
  List<PlanningTask> expandRecurringPlans(
    List<PlanningTask> allPlans,
    DateTime viewStart,
    DateTime viewEnd,
  ) {
    final out = <PlanningTask>[];
    final templates = allPlans
        .where((p) => (p.rrule?.trim().isNotEmpty ?? false))
        .toList();
    if (templates.isEmpty) return out;

    final materializedOccurrenceKeys = <String>{};
    for (final p in allPlans) {
      _collectMaterializedRecurrenceSuppressionKeys(
        p,
        materializedOccurrenceKeys,
      );
    }
    final emittedVirtKeys = <String>{};

    DateTime wallOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final startWall = wallOnly(viewStart);
    final endWall = wallOnly(viewEnd);
    if (endWall.isBefore(startWall)) return out;

    final windowStartUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          startWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$1;
    final windowEndUtc = wall_clock
        .utcWallClockDayBoundsUtc(
          endWall,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        )
        .$2;

    for (final template in templates) {
      if (template.isDone) continue;
      final pr = template.pocketRecordId?.trim() ?? '';
      if (pr.isEmpty) continue;
      RecurrenceRule rule;
      try {
        rule = RecurrenceRule.fromString(
          _normalizeRruleStringForDecoder(template.rrule!.trim()),
          options: const RecurrenceRuleFromStringOptions.lenient(),
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            '[RRULE] skip plan $pr: parse failed for "${template.rrule}"',
          );
        }
        continue;
      }

      final instants = _planUtcInstants(template);
      if (instants == null) continue;
      final baseStartUtc = instants.startUtc;
      final dur = instants.endUtc != null
          ? instants.endUtc!.difference(baseStartUtc)
          : Duration.zero;
      final durClamped = dur.isNegative ? Duration.zero : dur;

      final ex = <String>{
        for (final e in template.exceptionDates)
          if (e.trim().length >= 10) e.trim().substring(0, 10),
      };

      final List<DateTime> instances;
      try {
        instances = rule.getAllInstances(
          start: baseStartUtc.toUtc(),
          after: windowStartUtc,
          includeAfter: true,
          before: windowEndUtc,
          includeBefore: true,
        );
      } catch (_) {
        if (kDebugMode) {
          debugPrint('[RRULE] skip plan $pr: iteration failed');
        }
        continue;
      }

      for (final instanceUtc in instances) {
        final wall = _profileWallFromUtc(instanceUtc);
        final wallDay = wallOnly(wall);
        if (wallDay.isBefore(startWall) || wallDay.isAfter(endWall)) {
          continue;
        }
        final dk = '${wall.year}-${_two(wall.month)}-${_two(wall.day)}';
        if (ex.contains(dk)) continue;

        final virtKey = 'virt-$pr-$dk';
        if (materializedOccurrenceKeys.contains('$pr|$dk') ||
            materializedOccurrenceKeys.contains('biz:$pr|$dk') ||
            emittedVirtKeys.contains(virtKey)) {
          continue;
        }
        emittedVirtKeys.add(virtKey);

        final startWallInstance = _profileWallFromUtc(instanceUtc);
        DateTime? endWallInstance;
        if (durClamped.inSeconds > 0) {
          endWallInstance = _profileWallFromUtc(instanceUtc.add(durClamped));
        }

        out.add(
          template.copyWith(
            planRowId: 'virt-$pr-$dk',
            dateKey: dk,
            startTime: startWallInstance,
            date: _utcDateOnlyFromPlanDateKey(dk),
            endDateTime: endWallInstance,
            recurrenceInstanceDateKey: dk,
            clearRrule: true,
            exceptionDates: const [],
            startUtcInstant: instanceUtc.toUtc(),
            endUtcInstant: durClamped.inSeconds > 0
                ? instanceUtc.add(durClamped).toUtc()
                : null,
          ),
        );
      }
    }
    return out;
  }
}
