import 'package:flutter/foundation.dart';

/// P0U.4R — summary diagnostics for Timeline row-VM construction (no per-row spam).
abstract final class P0uTimelineVmBuildDiag {
  static bool _warmDisabledLogged = false;
  static final Set<String> _tracedDayKeys = {};

  /// Log once when [kTimelineAdjacentRowVmWarmup] is false.
  static void logWarmDisabledIfNeeded({required bool warmupEnabled}) {
    if (warmupEnabled || _warmDisabledLogged) return;
    _warmDisabledLogged = true;
    debugPrint('[P0U_TIMELINE_ADJ_VM_WARM_DISABLED] reason=killSwitch');
  }

  /// First full trace per calendar day per app session.
  static bool shouldTraceDay(String dateKey) {
    if (_tracedDayKeys.contains(dateKey)) return false;
    _tracedDayKeys.add(dateKey);
    return true;
  }

  static P0uTimelineVmBuildSession? beginDay({
    required String dateKey,
    required int records,
  }) {
    if (!shouldTraceDay(dateKey)) return null;
    debugPrint(
      '[P0U_TIMELINE_VM_BUILD_START] date=$dateKey records=$records',
    );
    return P0uTimelineVmBuildSession(dateKey: dateKey, records: records);
  }

  static const List<String> stepOrder = [
    'sort',
    'timeProjection',
    'timezone',
    'recurrence',
    'categoryLookup',
    'tags',
    'checklist',
    'progress',
    'textFormatting',
    'other',
  ];
}

/// Accumulates per-step ms for one day VM build (summary only).
final class P0uTimelineVmBuildSession {
  P0uTimelineVmBuildSession({
    required this.dateKey,
    required this.records,
  }) : _total = Stopwatch()..start();

  final String dateKey;
  final int records;
  final Stopwatch _total;
  final Map<String, int> _stepMs = {};
  int _slowestRecordMs = 0;
  String? _slowestRecordId;

  void addStep(String step, int ms) {
    if (ms <= 0) return;
    _stepMs[step] = (_stepMs[step] ?? 0) + ms;
  }

  T timeStep<T>(String step, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      addStep(step, sw.elapsedMilliseconds);
    }
  }

  void noteRecord(String recordId, int ms) {
    if (ms <= _slowestRecordMs) return;
    _slowestRecordMs = ms;
    _slowestRecordId = recordId;
  }

  void finish({required int rows}) {
    _total.stop();
    for (final step in P0uTimelineVmBuildDiag.stepOrder) {
      final ms = _stepMs[step] ?? 0;
      if (ms <= 0) continue;
      debugPrint(
        '[P0U_TIMELINE_VM_BUILD_STEP] date=$dateKey step=$step ms=$ms',
      );
    }
    var slowestStep = 'other';
    var slowestMs = 0;
    for (final e in _stepMs.entries) {
      if (e.value > slowestMs) {
        slowestMs = e.value;
        slowestStep = e.key;
      }
    }
    debugPrint(
      '[P0U_TIMELINE_VM_BUILD_DONE] date=$dateKey records=$records rows=$rows '
      'totalMs=${_total.elapsedMilliseconds} slowestStep=$slowestStep '
      'slowestMs=$slowestMs'
      '${_slowestRecordId != null && _slowestRecordMs > 50 ? ' slowestRecord=$_slowestRecordId slowestRecordMs=$_slowestRecordMs' : ''}',
    );
  }
}
