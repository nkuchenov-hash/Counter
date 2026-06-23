import 'dart:async';

import 'package:counter/core/p0u_platform.dart';
import 'package:flutter/foundation.dart';

/// P0U.1+ boot / first-frame gap timings — summary-level only.
abstract final class P0uStartupDiag {
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
    if (!_firstFrameMarked) {
      deferredBeforeFrameGuard(name: name, allowed: false);
    }
    if (_firstFrameMarked) {
      unawaited(work());
      return;
    }
    _afterFirstFrameQueue.add(work);
  }

  static void deferredBeforeFrameGuard({
    required String name,
    required bool allowed,
  }) {
    debugPrint(
      '[P0U_DEFERRED_BEFORE_FRAME_GUARD] name=$name allowed=$allowed',
    );
  }

  static int? _firstFrameArmedTotalMs;

  static void armFirstFrameMarker() {
    ensureStarted();
    _firstFrameArmedTotalMs = _sw.elapsedMilliseconds;
    debugPrint(
      '[P0U_FIRST_FRAME_MARKER_ARMED] totalMs=$_firstFrameArmedTotalMs',
    );
  }

  static void deferredConfirmedAfterFrame({required String name}) {
    debugPrint('[P0U_BOOT_DEFERRED_CONFIRMED_AFTER_FRAME] name=$name');
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
    final total = _sw.elapsedMilliseconds;
    debugPrint(
      '[P0U_BOOT_STAGE] name=$name ms=$ms totalMs=$total '
      'blocksFirstFrame=$blocksFirstFrame platform=${p0uPlatformLabel()}',
    );
    if (name == 'firstFrame') {
      _firstFrameMs = total;
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

  static void deferred({required String name, required String reason}) {
    debugPrint('[P0U_BOOT_DEFERRED] name=$name reason=$reason');
  }

  static void hiddenTabDeferred({required String tab, required String reason}) {
    debugPrint('[P0U_HIDDEN_TAB_DEFERRED] tab=$tab reason=$reason');
  }

  static void hiddenTabActivated({required String tab, required int ms}) {
    debugPrint('[P0U_HIDDEN_TAB_ACTIVATED] tab=$tab ms=$ms');
    _trackWidgetBuild('tab:$tab', ms);
  }

  static void markFirstShellBuild() {
    _firstShellBuildTotalMs = _sw.elapsedMilliseconds;
    bootStage(name: 'firstShellBuild', ms: 0, blocksFirstFrame: true);
    debugPrint('[P0U_FRAME_GAP_START] totalMs=$_firstShellBuildTotalMs');
  }

  static void markFirstFrame() {
    if (_firstFrameMs != null) return;
    final callbackMs = _sw.elapsedMilliseconds;
    debugPrint('[P0U_FIRST_FRAME_CALLBACK_FIRED] totalMs=$callbackMs');
    _firstFrameMarked = true;
    bootStage(name: 'firstFrame', ms: 0, blocksFirstFrame: true);
    final shellMs = _firstShellBuildTotalMs;
    if (shellMs != null) {
      final gap = callbackMs - shellMs;
      var reason = 'unknown';
      if (gap > 2000) {
        reason = 'callbackDelay';
      } else if (_afterFirstFrameQueue.isNotEmpty) {
        reason = 'deferredWork';
      }
      debugPrint(
        '[P0U_FIRST_FRAME_MARKER_DELAY] shellToFrameMs=$gap reason=$reason',
      );
    }
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
    debugPrint(
      '[P0U_SHELL_BUILD] activeTab=$activeTab ms=$ms builtTabs=$builtTabs',
    );
  }

  static void tabBuild({
    required String tab,
    required bool active,
    required int ms,
  }) {
    final key = 'tabBuild:$tab';
    _trackWidgetBuild(key, ms);
    debugPrint('[P0U_TAB_BUILD] tab=$tab active=$active ms=$ms');
  }

  static void _trackWidgetBuild(String key, int ms) {
    if (ms <= _slowestWidgetMs) return;
    _slowestWidgetMs = ms;
    _slowestWidget = key;
  }

  static void emitFrameGapSummary() {
    if (_frameGapSummaryEmitted) return;
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
