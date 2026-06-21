import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
/// Master switch — off in release; enable locally with `--dart-define=PERF_DIAG=true`.
const bool kPerfDiagnosisEnabled = bool.fromEnvironment(
  'PERF_DIAG',
  defaultValue: false,
);

/// Runs one automated left/right swipe sequence after boot (diagnosis only).
const bool kPerfAutoSwipeBenchmark = false;

/// Temporary P0 performance diagnosis (no behavior changes).
class PerfDiag {
  PerfDiag._();
  static final PerfDiag instance = PerfDiag._();

  bool _attached = false;
  String? _activeAction;
  String? _activeSection;
  String? _swipeFromDate;
  String? _swipeToDate;
  PerfSwipePhase _phase = PerfSwipePhase.idle;
  final Stopwatch _swipeStopwatch = Stopwatch();
  final Stopwatch _settleStopwatch = Stopwatch();
  DateTime? _lastDragLogAt;
  int _dragLogCount = 0;

  final Map<String, int> _rebuildCounts = {};
  final List<_FrameSample> _frameSamples = [];
  final List<_BlockSample> _blockSamples = [];
  final List<_PbSample> _pbSamples = [];
  final List<_StateSample> _stateSamples = [];

  int _framesOver16 = 0;
  int _framesOver32 = 0;
  int _framesOver50 = 0;
  int _framesOver100 = 0;
  int _framesOver500 = 0;
  double _worstBuildMs = 0;
  double _worstRasterMs = 0;
  double _worstTotalMs = 0;
  final Set<String> _autoSwipeDoneForSection = {};

  void attachIfNeeded() {
    if (!kPerfDiagnosisEnabled || _attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _log('PERF_DIAG_ATTACHED commit=${_gitCommitHint()}');
  }

  static String _gitCommitHint() => 'dedad8f';

  void rebuild(String widgetName) {
    if (!kPerfDiagnosisEnabled) return;
    _rebuildCounts[widgetName] = (_rebuildCounts[widgetName] ?? 0) + 1;
  }

  void stateChange({
    required String source,
    required String field,
    bool duringSwipe = false,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    final ms = _swipeStopwatch.isRunning ? _swipeStopwatch.elapsedMilliseconds : -1;
    _stateSamples.add(
      _StateSample(source: source, field: field, msSinceSwipeStart: ms),
    );
  }

  T perfBlock<T>(String name, T Function() fn, {Map<String, Object?> meta = const {}}) {
    if (!kPerfDiagnosisEnabled) return fn();
    final sw = Stopwatch()..start();
    developer.Timeline.startSync('PERF_BLOCK:$name');
    try {
      return fn();
    } finally {
      developer.Timeline.finishSync();
      sw.stop();
      final sample = _BlockSample(name: name, ms: sw.elapsedMilliseconds, meta: meta);
      _blockSamples.add(sample);
      if (sw.elapsedMilliseconds >= 8) {
        _log(
          'PERF_BLOCK name=$name ms=${sw.elapsedMilliseconds} '
          '${_formatMeta(meta)} duringSwipe=${_swipeStopwatch.isRunning}',
        );
      }
    }
  }

  Future<T> perfBlockAsync<T>(
    String name,
    Future<T> Function() fn, {
    Map<String, Object?> meta = const {},
  }) async {
    if (!kPerfDiagnosisEnabled) return fn();
    final sw = Stopwatch()..start();
    developer.Timeline.startSync('PERF_BLOCK:$name');
    try {
      return await fn();
    } finally {
      developer.Timeline.finishSync();
      sw.stop();
      _blockSamples.add(_BlockSample(name: name, ms: sw.elapsedMilliseconds, meta: meta));
      _log(
        'PERF_BLOCK name=$name ms=${sw.elapsedMilliseconds} '
        '${_formatMeta(meta)} duringSwipe=${_swipeStopwatch.isRunning}',
      );
    }
  }

  void pbDuringSwipe({
    required String collection,
    required String method,
    required int durationMs,
    String action = 'swipe',
  }) {
    if (!kPerfDiagnosisEnabled) return;
    final sample = _PbSample(
      collection: collection,
      method: method,
      durationMs: durationMs,
      duringSwipe: _swipeStopwatch.isRunning,
      msSinceSwipeStart:
          _swipeStopwatch.isRunning ? _swipeStopwatch.elapsedMilliseconds : -1,
    );
    _pbSamples.add(sample);
    _log(
      'PB_DURING_SWIPE action=$action collection=$collection method=$method '
      'durationMs=$durationMs duringSwipe=${sample.duringSwipe} '
      'msSinceSwipeStart=${sample.msSinceSwipeStart}',
    );
  }

  void dateSwipeStart({
    required String section,
    required String fromDate,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _resetSwipeMetrics();
    _activeSection = section;
    _activeAction = section == 'Timeline' ? 'timelineSwipe' : 'planningSwipe';
    _swipeFromDate = fromDate;
    _phase = PerfSwipePhase.drag;
    _swipeStopwatch
      ..reset()
      ..start();
    _log('DATE_SWIPE_START section=$section fromDate=$fromDate');
  }

  void dateSwipeDrag({
    required String section,
    required int page,
    double? pageFraction,
  }) {
    if (!kPerfDiagnosisEnabled || _activeSection != section) return;
    final now = DateTime.now();
    if (_lastDragLogAt != null &&
        now.difference(_lastDragLogAt!) < const Duration(milliseconds: 120)) {
      return;
    }
    _lastDragLogAt = now;
    _dragLogCount++;
    _log(
      'DATE_SWIPE_DRAG section=$section page=$page '
      'fraction=${pageFraction?.toStringAsFixed(3) ?? '-'} dragLogs=$_dragLogCount',
    );
  }

  void dateSwipeSettleStart({
    required String section,
    required String fromDate,
    required String toDate,
    int? fromPage,
    int? toPage,
    bool hiddenPagerSync = false,
    String pagerOp = 'none',
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _phase = PerfSwipePhase.settle;
    _swipeToDate = toDate;
    _settleStopwatch
      ..reset()
      ..start();
    _log(
      'DATE_SWIPE_SETTLE_START section=$section fromDate=$fromDate toDate=$toDate '
      'fromPage=${fromPage ?? '-'} toPage=${toPage ?? '-'} '
      'hiddenPagerSync=$hiddenPagerSync pagerOp=$pagerOp',
    );
  }

  void dateSwipeSettleEnd({
    required String section,
    bool shellSetState = false,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _settleStopwatch.stop();
    _log(
      'DATE_SWIPE_SETTLE_END section=$section durationMs=${_settleStopwatch.elapsedMilliseconds} '
      'shellSetState=$shellSetState',
    );
    _phase = PerfSwipePhase.idle;
    _printRebuildSummary(action: _activeAction ?? section);
    _printFrameSummary(action: _activeAction ?? section, phase: 'settle');
  }

  void dateSwipeEnd({required String section}) {
    if (!kPerfDiagnosisEnabled) return;
    _swipeStopwatch.stop();
    _log(
      'DATE_SWIPE_END section=$section totalMs=${_swipeStopwatch.elapsedMilliseconds} '
      'fromDate=${_swipeFromDate ?? '-'} toDate=${_swipeToDate ?? '-'}',
    );
    _printFrameSummary(action: _activeAction ?? section, phase: 'total');
    _printBlockSummary();
    _printPbSummary();
    _printStateSummary();
    _activeAction = null;
    _activeSection = null;
    _phase = PerfSwipePhase.idle;
  }

  void pagerSync({
    required String section,
    required String op,
    required int targetPage,
    required bool shellTabActive,
    required bool hidden,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _log(
      'DATE_SWIPE_PAGER section=$section op=$op targetPage=$targetPage '
      'shellTabActive=$shellTabActive hidden=$hidden',
    );
  }

  void dateSwipeThreshold({
    required String section,
    required double dragFraction,
    required double velocity,
    required bool accepted,
    required int fromPage,
    required int toPage,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _log(
      'DATE_SWIPE_THRESHOLD section=$section dragFraction=${dragFraction.toStringAsFixed(3)} '
      'velocity=${velocity.toStringAsFixed(1)} accepted=$accepted '
      'fromPage=$fromPage toPage=$toPage',
    );
  }

  void logTimelineCacheHit({required String date, required int itemCount}) {
    if (!kPerfDiagnosisEnabled) return;
    _log('TIMELINE_CACHE_HIT date=$date itemCount=$itemCount');
  }

  void logTimelineCacheMiss({required String date}) {
    if (!kPerfDiagnosisEnabled) return;
    _log('TIMELINE_CACHE_MISS date=$date');
  }

  void logTimelinePrefetchStart({required List<String> dates}) {
    if (!kPerfDiagnosisEnabled) return;
    _log('TIMELINE_PREFETCH_START dates=${dates.join(',')}');
  }

  void logTimelinePrefetchEnd({
    required String date,
    required int ms,
    required int itemCount,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _log('TIMELINE_PREFETCH_END date=$date ms=$ms itemCount=$itemCount');
  }

  void logTimelineHistoryScan({
    required int count,
    required int ms,
    required int dayBuckets,
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _log(
      'TIMELINE_HISTORY_SCAN count=$count ms=$ms dayBuckets=$dayBuckets '
      'PB_TIMELINE_BROAD_QUERY used=true reason=flat_index_rebuild',
    );
  }

  void logPbTimelineQuery({
    required String date,
    required String filter,
    required int returned,
    required int ms,
    bool broad = false,
    String reason = '',
  }) {
    if (!kPerfDiagnosisEnabled) return;
    _log(
      'PB_TIMELINE_QUERY date=$date filter=$filter returned=$returned ms=$ms '
      'broad=$broad reason=$reason',
    );
    if (broad) {
      _log('PB_TIMELINE_BROAD_QUERY used=true reason=$reason');
    }
  }

  /// One-shot post-boot swipe sequence for profile/chrome diagnosis runs.
  void scheduleAutoSwipeSequence({
    required String section,
    required PageController controller,
    required int visiblePageIndex,
    required bool shellTabActive,
    required String Function(int pageIndex) dateKeyForPage,
    Duration delay = const Duration(seconds: 14),
  }) {
    if (!kPerfDiagnosisEnabled || !kPerfAutoSwipeBenchmark || !shellTabActive) {
      return;
    }
    if (_autoSwipeDoneForSection.contains(section)) return;
    _autoSwipeDoneForSection.add(section);
    Future<void>.delayed(delay, () async {
      if (!controller.hasClients) return;
      _log('PERF_AUTO_SWIPE_START section=$section');
      dateSwipeStart(
        section: section,
        fromDate: dateKeyForPage(visiblePageIndex),
      );
      final next = visiblePageIndex + 1;
      await controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final prev = visiblePageIndex - 1;
      await controller.animateToPage(
        prev,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _log('PERF_AUTO_SWIPE_END section=$section');
      dateSwipeEnd(section: section);
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!kPerfDiagnosisEnabled) return;
    if (_activeAction == null && !_swipeStopwatch.isRunning) return;
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = buildMs + rasterMs;
      _frameSamples.add(
        _FrameSample(
          action: _activeAction ?? 'unknown',
          phase: _phase.name,
          buildMs: buildMs,
          rasterMs: rasterMs,
          totalMs: totalMs,
        ),
      );
      if (totalMs > _worstTotalMs) {
        _worstBuildMs = buildMs;
        _worstRasterMs = rasterMs;
        _worstTotalMs = totalMs;
      }
      if (totalMs > 16) _framesOver16++;
      if (totalMs > 32) _framesOver32++;
      if (totalMs > 50) _framesOver50++;
      if (totalMs > 100) _framesOver100++;
      if (totalMs > 500) _framesOver500++;
      if (totalMs > 16) {
        _log(
          'PERF_FRAME_JANK action=${_activeAction ?? 'idle'} phase=${_phase.name} '
          'buildMs=${buildMs.toStringAsFixed(1)} '
          'rasterMs=${rasterMs.toStringAsFixed(1)} '
          'totalMs=${totalMs.toStringAsFixed(1)}',
        );
      }
    }
  }

  void _resetSwipeMetrics() {
    _rebuildCounts.clear();
    _frameSamples.clear();
    _blockSamples.clear();
    _pbSamples.clear();
    _stateSamples.clear();
    _framesOver16 = 0;
    _framesOver32 = 0;
    _framesOver50 = 0;
    _framesOver100 = 0;
    _framesOver500 = 0;
    _worstBuildMs = 0;
    _worstRasterMs = 0;
    _worstTotalMs = 0;
    _dragLogCount = 0;
    _lastDragLogAt = null;
  }

  void _printRebuildSummary({required String action}) {
    if (_rebuildCounts.isEmpty) return;
    final parts = _rebuildCounts.entries
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    _log('PERF_REBUILD_SUMMARY action=$action $parts');
  }

  void _printFrameSummary({required String action, required String phase}) {
    _log(
      'PERF_FRAME_SUMMARY action=$action phase=$phase '
      'worstBuildMs=${_worstBuildMs.toStringAsFixed(1)} '
      'worstRasterMs=${_worstRasterMs.toStringAsFixed(1)} '
      'worstTotalMs=${_worstTotalMs.toStringAsFixed(1)} '
      'over16=$_framesOver16 over32=$_framesOver32 over50=$_framesOver50 '
      'over100=$_framesOver100 over500=$_framesOver500',
    );
  }

  void _printBlockSummary() {
    if (_blockSamples.isEmpty) {
      _log('PERF_BLOCK_SUMMARY none');
      return;
    }
    final byName = <String, int>{};
    for (final s in _blockSamples) {
      byName[s.name] = (byName[s.name] ?? 0) + s.ms;
    }
    final ranked = byName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(8).map((e) => '${e.key}=${e.value}ms').join(' ');
    _log('PERF_BLOCK_SUMMARY top=$top');
  }

  void _printPbSummary() {
    if (_pbSamples.isEmpty) {
      _log('PB_DURING_SWIPE_SUMMARY count=0');
      return;
    }
    _log('PB_DURING_SWIPE_SUMMARY count=${_pbSamples.length}');
    for (final s in _pbSamples) {
      final tag = s.duringSwipe ? 'PB_DURING_SWIPE' : 'PB_AFTER_SETTLE';
      _log(
        '$tag collection=${s.collection} method=${s.method} '
        'durationMs=${s.durationMs} msSinceSwipeStart=${s.msSinceSwipeStart}',
      );
    }
  }

  void _printStateSummary() {
    if (_stateSamples.isEmpty) {
      _log('PERF_STATE_SUMMARY count=0');
      return;
    }
    _log('PERF_STATE_SUMMARY count=${_stateSamples.length}');
    for (final s in _stateSamples.take(20)) {
      _log(
        'PERF_STATE_CHANGE source=${s.source} field=${s.field} '
        'msSinceSwipeStart=${s.msSinceSwipeStart}',
      );
    }
  }

  static void _log(String line) {
    if (!kPerfDiagnosisEnabled) return;
    // ignore: avoid_print
    print(line);
  }

  static String _formatMeta(Map<String, Object?> meta) {
    if (meta.isEmpty) return '';
    return meta.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}

enum PerfSwipePhase { idle, drag, settle }

class _FrameSample {
  _FrameSample({
    required this.action,
    required this.phase,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
  });
  final String action;
  final String phase;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
}

class _BlockSample {
  _BlockSample({required this.name, required this.ms, required this.meta});
  final String name;
  final int ms;
  final Map<String, Object?> meta;
}

class _PbSample {
  _PbSample({
    required this.collection,
    required this.method,
    required this.durationMs,
    required this.duringSwipe,
    required this.msSinceSwipeStart,
  });
  final String collection;
  final String method;
  final int durationMs;
  final bool duringSwipe;
  final int msSinceSwipeStart;
}

class _StateSample {
  _StateSample({
    required this.source,
    required this.field,
    required this.msSinceSwipeStart,
  });
  final String source;
  final String field;
  final int msSinceSwipeStart;
}

/// Call at top of widget build methods.
void perfRebuildTick(String widgetName) {
  PerfDiag.instance.rebuild(widgetName);
}
