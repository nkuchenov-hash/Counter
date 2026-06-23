import 'package:flutter/foundation.dart';

/// P0U.4R2 — per-day + slowest-record Timeline row-VM build diagnostics (no per-row spam).
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
    'recordMapRead',
    'recordForTimelineCard',
    'timeProjection',
    'timezoneFormat',
    'categoryLookup',
    'breadcrumbPath',
    'checklistNotesFlags',
    'progressDuration',
    'subtitleBuild',
    'colorConversion',
    'objectCreate',
    'unmeasuredOther',
  ];
}

/// Per-record step timings (merged into day summary; one slowest breakdown only).
final class P0uTimelineVmRecordBuildSession {
  P0uTimelineVmRecordBuildSession() : _total = Stopwatch()..start();

  final Stopwatch _total;
  final Map<String, int> _stepMs = {};
  bool _finished = false;

  Map<String, int> get steps => Map.unmodifiable(_stepMs);

  int get totalMs => _total.elapsedMilliseconds;

  T timeStep<T>(String step, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      _addStep(step, sw.elapsedMilliseconds);
    }
  }

  void _addStep(String step, int ms) {
    if (ms <= 0) return;
    _stepMs[step] = (_stepMs[step] ?? 0) + ms;
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _total.stop();
    final measured = _stepMs.values.fold<int>(0, (a, b) => a + b);
    final gap = _total.elapsedMilliseconds - measured;
    if (gap > 0) {
      _addStep('unmeasuredOther', gap);
    }
  }
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
  Map<String, int> _slowestRecordSteps = {};

  void addStep(String step, int ms) {
    if (ms <= 0) return;
    _stepMs[step] = (_stepMs[step] ?? 0) + ms;
  }

  void mergeRecord(P0uTimelineVmRecordBuildSession record, String recordId) {
    for (final e in record.steps.entries) {
      addStep(e.key, e.value);
    }
    if (record.totalMs <= _slowestRecordMs) return;
    _slowestRecordMs = record.totalMs;
    _slowestRecordId = recordId;
    _slowestRecordSteps = Map<String, int>.from(record.steps);
  }

  void finish({required int rows}) {
    _total.stop();
    final totalMs = _total.elapsedMilliseconds;
    for (final step in P0uTimelineVmBuildDiag.stepOrder) {
      final ms = _stepMs[step] ?? 0;
      if (ms <= 0) continue;
      debugPrint(
        '[P0U_TIMELINE_VM_BUILD_STEP_TOTAL] date=$dateKey step=$step ms=$ms',
      );
    }
    final explainedMs = _stepMs.values.fold<int>(0, (a, b) => a + b);
    final unexplainedMs = totalMs > explainedMs ? totalMs - explainedMs : 0;
    var slowestStep = 'unmeasuredOther';
    var slowestMs = 0;
    for (final e in _stepMs.entries) {
      if (e.value > slowestMs) {
        slowestMs = e.value;
        slowestStep = e.key;
      }
    }
    debugPrint(
      '[P0U_TIMELINE_VM_BUILD_DONE] date=$dateKey records=$records rows=$rows '
      'totalMs=$totalMs explainedMs=$explainedMs unexplainedMs=$unexplainedMs '
      'slowestStep=$slowestStep slowestMs=$slowestMs'
      '${_slowestRecordId != null ? ' slowestRecord=$_slowestRecordId slowestRecordMs=$_slowestRecordMs' : ''}',
    );
    if (_slowestRecordId != null && _slowestRecordMs > 0) {
      _logSlowestRecord();
    }
  }

  void _logSlowestRecord() {
    final id = _slowestRecordId ?? '?';
    final parts = <String>[
      'date=$dateKey',
      'id=$id',
      'totalMs=$_slowestRecordMs',
    ];
    for (final step in P0uTimelineVmBuildDiag.stepOrder) {
      final ms = _slowestRecordSteps[step] ?? 0;
      if (ms <= 0) continue;
      parts.add('$step=$ms');
    }
    debugPrint('[P0U_TIMELINE_VM_SLOWEST_RECORD] ${parts.join(' ')}');
  }
}
