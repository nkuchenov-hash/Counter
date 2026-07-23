import 'dart:async';

/// Three-second visual commit countdown before [DatabaseService.writeRecord].
class DesktopVoiceConfirmationTimer {
  static const commitDuration = Duration(seconds: 3);

  DateTime? intendedStartTime;
  Timer? _tickTimer;
  int _elapsedMs = 0;
  bool _paused = false;
  bool _completed = false;

  void Function(double progress)? onProgress;
  VoidCallback? onComplete;

  bool get isActive => _tickTimer != null && !_completed;
  bool get isPaused => _paused;
  double get progress =>
      (_elapsedMs / commitDuration.inMilliseconds).clamp(0.0, 1.0);

  void start() {
    cancel();
    intendedStartTime = DateTime.now();
    _elapsedMs = 0;
    _paused = false;
    _completed = false;
    onProgress?.call(0);
    _tickTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void _tick() {
    if (_paused || _completed) return;
    _elapsedMs += 33;
    final p = progress;
    onProgress?.call(p);
    if (_elapsedMs >= commitDuration.inMilliseconds) {
      _complete();
    }
  }

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  void confirmNow() {
    if (_completed) return;
    _complete();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _tickTimer?.cancel();
    _tickTimer = null;
    onProgress?.call(1.0);
    onComplete?.call();
  }

  void cancel() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _completed = true;
    _paused = false;
    _elapsedMs = 0;
  }
}

typedef VoidCallback = void Function();
