import 'package:counter/core/p0u_platform.dart';
import 'package:flutter/foundation.dart';

/// P0U.1 boot stage timings — summary-level only (Performance Kill Switch Law).
abstract final class P0uStartupDiag {
  static final Stopwatch _sw = Stopwatch();
  static bool _started = false;
  static final List<({String name, int ms})> _stageMs = [];
  static int? _firstFrameMs;
  static int? _interactiveMs;
  static bool _summaryEmitted = false;

  static void ensureStarted() {
    if (_started) return;
    _started = true;
    _sw.start();
    bootStage(name: 'mainStart', ms: 0, blocksFirstFrame: true);
  }

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
      _tryEmitSummary();
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

  static void markFirstShellBuild() {
    bootStage(name: 'firstShellBuild', ms: 0, blocksFirstFrame: true);
  }

  static void markFirstFrame() {
    if (_firstFrameMs != null) return;
    bootStage(name: 'firstFrame', ms: 0, blocksFirstFrame: true);
  }

  static void markInteractive() {
    if (_interactiveMs != null) return;
    _interactiveMs = _sw.elapsedMilliseconds;
    _tryEmitSummary();
  }

  static void _tryEmitSummary() {
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
