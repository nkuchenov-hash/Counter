import 'dart:async';

import 'package:flutter/foundation.dart';

/// Boot timing + post-first-frame deferral queue (P0U.3).
///
/// **Runtime behavior:** [scheduleAfterFirstFrame] must not be removed — Brain boot
/// defers warm-window work until after the first frame.
///
/// **Logging:** release prints nothing. Debug/profile prints only [emitFrameGapSummary]
/// and [_tryEmitBootSummary] (one line each). Per-stage spam removed.
abstract final class StartupLog {
  static final Stopwatch _sw = Stopwatch();
  static bool _started = false;
  static final List<({String name, int ms})> _stageMs = [];
  static int? _firstFrameMs;
  static int? _firstShellBuildTotalMs;
  static int? _interactiveMs;
  static bool _summaryEmitted = false;
  static bool _frameGapSummaryEmitted = false;

  static String _slowestWidget = '—';
  static int _slowestWidgetMs = 0;

  static final List<Future<void> Function()> _afterFirstFrameQueue = [];
  static bool _firstFrameMarked = false;

  /// Queue work that must not run until [markFirstFrame] (P0U.3).
  static void scheduleAfterFirstFrame(
    String name,
    Future<void> Function() work,
  ) {
    if (_firstFrameMarked) {
      unawaited(work());
      return;
    }
    _afterFirstFrameQueue.add(work);
  }

  static void armFirstFrameMarker() {
    ensureStarted();
  }

  static void _flushAfterFirstFrameQueue() {
    if (_afterFirstFrameQueue.isEmpty) return;
    final queue = List<Future<void> Function()>.from(_afterFirstFrameQueue);
    _afterFirstFrameQueue.clear();
    for (final work in queue) {
      unawaited(work());
    }
  }

  static void ensureStarted() {
    if (_started) return;
    _started = true;
    _sw.start();
    bootStage(name: 'mainStart', ms: 0, blocksFirstFrame: true);
  }

  static int get totalMs => _sw.elapsedMilliseconds;

  static void bootStage({
    required String name,
    required int ms,
    bool blocksFirstFrame = false,
  }) {
    ensureStarted();
    _stageMs.add((name: name, ms: ms));
    if (name == 'firstFrame') {
      _firstFrameMs = _sw.elapsedMilliseconds;
      _tryEmitBootSummary();
      emitFrameGapSummary();
    }
  }

  static Future<T> stageAsync<T>(
    String name,
    Future<T> Function() fn, {
    bool blocksFirstFrame = false,
  }) async {
    final t = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      t.stop();
      bootStage(
        name: name,
        ms: t.elapsedMilliseconds,
        blocksFirstFrame: blocksFirstFrame,
      );
    }
  }

  static void deferred({required String name, required String reason}) {}

  static void deferredConfirmedAfterFrame({required String name}) {}

  static void hiddenTabDeferred({required String tab, required String reason}) {}

  static void hiddenTabActivated({required String tab, required int ms}) {
    _trackWidgetBuild('tab:$tab', ms);
  }

  static void markFirstShellBuild() {
    _firstShellBuildTotalMs = _sw.elapsedMilliseconds;
    bootStage(name: 'firstShellBuild', ms: 0, blocksFirstFrame: true);
  }

  static void markFirstFrame() {
    if (_firstFrameMs != null) return;
    _firstFrameMarked = true;
    bootStage(name: 'firstFrame', ms: 0, blocksFirstFrame: true);
    _flushAfterFirstFrameQueue();
  }

  static void markInteractive() {
    if (_interactiveMs != null) return;
    _interactiveMs = _sw.elapsedMilliseconds;
    _tryEmitBootSummary();
  }

  static void shellBuild({
    required String activeTab,
    required int ms,
    required int builtTabs,
  }) {
    _trackWidgetBuild('shell:$activeTab', ms);
  }

  static void tabBuild({
    required String tab,
    required bool active,
    required int ms,
  }) {
    _trackWidgetBuild('tabBuild:$tab', ms);
  }

  static void _trackWidgetBuild(String key, int ms) {
    if (ms <= _slowestWidgetMs) return;
    _slowestWidgetMs = ms;
    _slowestWidget = key;
  }

  static void emitFrameGapSummary() {
    if (_frameGapSummaryEmitted || kReleaseMode) return;
    _frameGapSummaryEmitted = true;
    final shellMs = _firstShellBuildTotalMs;
    final frameMs = _firstFrameMs;
    if (shellMs == null || frameMs == null) return;
    final gap = frameMs - shellMs;
    debugPrint(
      '[P0U_FRAME_GAP_SUMMARY] shellToFrameMs=$gap '
      'slowestWidget=$_slowestWidget slowestMs=$_slowestWidgetMs',
    );
  }

  static void _tryEmitBootSummary() {
    if (_summaryEmitted || _firstFrameMs == null) return;
    _summaryEmitted = true;
    if (kReleaseMode) return;
    var slowest = 'mainStart';
    var slowestMs = 0;
    for (final s in _stageMs) {
      if (s.ms > slowestMs) {
        slowestMs = s.ms;
        slowest = s.name;
      }
    }
    debugPrint(
      '[P0U_BOOT_SUMMARY] firstFrameMs=${_firstFrameMs ?? '—'} '
      'interactiveMs=${_interactiveMs ?? '—'} slowestStage=$slowest slowestMs=$slowestMs',
    );
  }
}
