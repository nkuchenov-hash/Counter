import 'package:flutter/foundation.dart';

/// P0U.4R3 — line-level Timeline row-VM build diagnostics (microsecond accounting).
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

  /// Preferred log order; unknown steps still print after these.
  static const List<String> stepOrder = [
    'recordMapRead',
    'canonicalPrimaryRunningBiz_once',
    'mapAccess_id',
    'mapAccess_recordId',
    'mapAccess_title',
    'mapAccess_type',
    'canonicalPrimaryRunningBiz_call',
    'runningState_call',
    'recordForTimelineCard_call',
    'startEndParse_call',
    'profileWallFromUtc_start_call',
    'profileWallFromUtc_end_call',
    'categoryDisplayColor_call',
    'categoryDisplayPath_call',
    'subtitle_function_total',
    'subtitle_durationPart',
    'subtitle_parentPart',
    'subtitle_checklistPart',
    'subtitle_notesPart',
    'color_toARGB32_call',
    'timelineRowVm_constructor',
    'cachePut',
    'loopOverhead',
    'unmeasuredOther',
  ];

  static int usToMs(int us) => (us + 999) ~/ 1000;
}

/// Per-record line-level timings (merged into day summary).
final class P0uTimelineVmRecordBuildSession {
  P0uTimelineVmRecordBuildSession() : _total = Stopwatch()..start();

  final Stopwatch _total;
  final Map<String, int> _stepUs = {};
  final Map<String, int> _nestedUs = {};
  bool _finished = false;

  Map<String, int> get stepsMs {
    final out = <String, int>{
      for (final e in _stepUs.entries)
        e.key: P0uTimelineVmBuildDiag.usToMs(e.value),
    };
    for (final e in _nestedUs.entries) {
      final ms = P0uTimelineVmBuildDiag.usToMs(e.value);
      if (ms <= 0) continue;
      out[e.key] = ms;
    }
    return out;
  }

  int get totalMs => P0uTimelineVmBuildDiag.usToMs(_total.elapsedMicroseconds);

  T timeStep<T>(String step, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      _addStepUs(_stepUs, step, sw.elapsedMicroseconds);
    }
  }

  /// Subtitle internals — merged into slowest-record breakdown, not day totals.
  T timeNestedStep<T>(String step, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      _addStepUs(_nestedUs, step, sw.elapsedMicroseconds);
    }
  }

  Map<String, int> get dayMergeUs => Map.unmodifiable(_stepUs);

  Map<String, int> get nestedMergeUs => Map.unmodifiable(_nestedUs);

  int get subtitleFunctionTotalUs => _nestedUs.values.fold<int>(0, (a, b) => a + b);

  void _addStepUs(Map<String, int> target, String step, int us) {
    if (us <= 0) return;
    target[step] = (target[step] ?? 0) + us;
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _total.stop();
    final measuredUs = _stepUs.values.fold<int>(0, (a, b) => a + b) +
        _nestedUs.values.fold<int>(0, (a, b) => a + b);
    final gapUs = _total.elapsedMicroseconds - measuredUs;
    if (gapUs > 0) {
      _addStepUs(_stepUs, 'unmeasuredOther', gapUs);
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
  final Map<String, int> _stepUs = {};
  int _slowestRecordMs = 0;
  String? _slowestRecordId;
  Map<String, int> _slowestRecordStepsMs = {};

  void addStepUs(String step, int microseconds) {
    if (microseconds <= 0) return;
    _stepUs[step] = (_stepUs[step] ?? 0) + microseconds;
  }

  void addStep(String step, int milliseconds) {
    addStepUs(step, milliseconds * 1000);
  }

  void mergeRecord(P0uTimelineVmRecordBuildSession record, String recordId) {
    for (final e in record.dayMergeUs.entries) {
      addStepUs(e.key, e.value);
    }
    for (final e in record.nestedMergeUs.entries) {
      addStepUs(e.key, e.value);
    }
    if (record.totalMs <= _slowestRecordMs) return;
    _slowestRecordMs = record.totalMs;
    _slowestRecordId = recordId;
    _slowestRecordStepsMs = record.stepsMs;
  }

  Map<String, int> get _stepsMs => {
    for (final e in _stepUs.entries)
      e.key: P0uTimelineVmBuildDiag.usToMs(e.value),
  };

  static bool _isSubtitleNestedStep(String step) {
    return step == 'runningState_call' ||
        step == 'startEndParse_call' ||
        step == 'profileWallFromUtc_start_call' ||
        step == 'profileWallFromUtc_end_call' ||
        step == 'subtitle_durationPart';
  }

  void finish({required int rows}) {
    _total.stop();
    final totalMs = P0uTimelineVmBuildDiag.usToMs(_total.elapsedMicroseconds);
    final stepsMs = _stepsMs;
    final logged = <String>{};
    var subtitleFunctionTotalMs = 0;
    for (final step in P0uTimelineVmBuildDiag.stepOrder) {
      if (step == 'subtitle_function_total') continue;
      final ms = stepsMs[step] ?? 0;
      if (ms <= 0) continue;
      logged.add(step);
      debugPrint(
        '[P0U_TIMELINE_VM_BUILD_STEP_TOTAL] date=$dateKey step=$step ms=$ms',
      );
      if (_isSubtitleNestedStep(step)) {
        subtitleFunctionTotalMs += ms;
      }
    }
    if (subtitleFunctionTotalMs > 0) {
      debugPrint(
        '[P0U_TIMELINE_VM_BUILD_STEP_TOTAL] date=$dateKey '
        'step=subtitle_function_total ms=$subtitleFunctionTotalMs',
      );
    }
    for (final e in stepsMs.entries) {
      if (logged.contains(e.key) || e.value <= 0) continue;
      debugPrint(
        '[P0U_TIMELINE_VM_BUILD_STEP_TOTAL] date=$dateKey step=${e.key} ms=${e.value}',
      );
    }
    final explainedMs = stepsMs.values.fold<int>(0, (a, b) => a + b);
    final unexplainedMs = totalMs > explainedMs ? totalMs - explainedMs : 0;
    final unmeasuredOtherMs = stepsMs['unmeasuredOther'] ?? 0;
    var slowestStep = 'recordForTimelineCard_call';
    var slowestMs = 0;
    for (final e in stepsMs.entries) {
      if (e.key == 'unmeasuredOther' || e.key == 'loopOverhead') continue;
      if (e.value > slowestMs) {
        slowestMs = e.value;
        slowestStep = e.key;
      }
    }
    debugPrint(
      '[P0U_TIMELINE_VM_BUILD_DONE] date=$dateKey records=$records rows=$rows '
      'totalMs=$totalMs explainedMs=$explainedMs unexplainedMs=$unexplainedMs '
      'unmeasuredOtherMs=$unmeasuredOtherMs slowestStep=$slowestStep '
      'slowestMs=$slowestMs'
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
    final subtitleNestedMs = [
      'runningState_call',
      'startEndParse_call',
      'profileWallFromUtc_start_call',
      'profileWallFromUtc_end_call',
      'subtitle_durationPart',
    ].fold<int>(
      0,
      (sum, key) => sum + (_slowestRecordStepsMs[key] ?? 0),
    );
    if (subtitleNestedMs > 0) {
      parts.add('subtitle_function_total=$subtitleNestedMs');
    }
    final logged = <String>{};
    for (final step in P0uTimelineVmBuildDiag.stepOrder) {
      final ms = _slowestRecordStepsMs[step] ?? 0;
      if (ms <= 0) continue;
      logged.add(step);
      parts.add('$step=$ms');
    }
    for (final e in _slowestRecordStepsMs.entries) {
      if (logged.contains(e.key) || e.value <= 0) continue;
      parts.add('${e.key}=${e.value}');
    }
    debugPrint('[P0U_TIMELINE_VM_SLOWEST_RECORD] ${parts.join(' ')}');
  }
}
