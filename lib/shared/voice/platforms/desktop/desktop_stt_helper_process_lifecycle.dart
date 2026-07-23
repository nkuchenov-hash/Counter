part of 'desktop_stt_helper_service.dart';

/// Spawns, restarts, and kills the GOLOS STT helper process; resolves helper/model paths.
extension DesktopSttHelperProcessLifecycle on DesktopSttHelperService {
  String? get helperPath => _resolveHelperExe();

  String? modelPathFor(DesktopVoiceEngineId engine) {
    final exe = helperPath;
    if (exe == null) return null;
    return '${File(exe).parent.path}${Platform.pathSeparator}models'
        '${Platform.pathSeparator}${engine.helperEngineId}';
  }

  int? get helperPid => _process?.pid;

  bool _helperProcessAlive() {
    // Synchronous best-effort probe: Process.exitCode returns a Future that only
    // completes when the process exits. There is no synchronous liveness API,
    // so this call uses the cached exit code observed by the async probe in
    // [_helperExitCodeIfAnyLive]. Returns true only if we have a process and
    // have not observed it exit yet.
    return _process != null && _helperExitCodeObserved == null;
  }

  Future<int?> _helperExitCodeIfAnyLive() async {
    final p = _process;
    if (p == null) return null;
    try {
      return await p.exitCode.timeout(const Duration(milliseconds: 50));
    } catch (_) {
      // Timeout → process still running.
      return null;
    }
  }

  void _appendStderrTail(String chunk) {
    for (final line in chunk.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      _helperStderrTail.add(t);
      if (_helperStderrTail.length > 12) {
        _helperStderrTail.removeAt(0);
      }
    }
  }

  void _appendStdoutTail(String chunk) {
    // GOLOS emits status lines like "[parakeet] loaded OK", "inference error:
    // parakeet not loaded" on STDOUT. Without this capture the user has no
    // visibility into why a transcribe returned HTTP 500 between model loads.
    for (final line in chunk.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      _helperStdoutTail.add(t);
      if (_helperStdoutTail.length > 12) {
        _helperStdoutTail.removeAt(0);
      }
    }
  }

  String get _helperStdoutTailJoined =>
      _helperStdoutTail.isEmpty ? '' : _helperStdoutTail.join(' | ');

  String get _helperStderrTailJoined =>
      _helperStderrTail.isEmpty ? '' : _helperStderrTail.join(' | ');

  String? get helperSettingsPath {
    final exe = helperPath;
    if (exe == null) return null;
    return '${File(exe).parent.path}${Platform.pathSeparator}settings.json';
  }

  Future<bool> ensureStarted({
    DesktopVoiceEngineId? engine,
    Duration maxWait = const Duration(seconds: 15),
    bool allowRestart = true,
  }) async {
    final target = engine ?? resolveProductionEngine();
    if (target == DesktopVoiceEngineId.windowsSpeech) return true;

    final key = target.helperEngineId;
    if (_ready && _engineReady[key] == true && _finalTranscribeReady) {
      return true;
    }

    final deadline = DateTime.now().add(maxWait);
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    if (_starting) {
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (_ready && _engineReady[key] == true && _finalTranscribeReady) {
          return true;
        }
      }
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_TIMEOUT', 'wait_starting');
      return false;
    }

    _starting = true;
    try {
      var ok = await _ensureHelperRunning(deadline, target);
      if (!ok && allowRestart && !pastDeadline()) {
        ok = await _restartHelper(deadline, target);
      }
      return ok;
    } finally {
      _starting = false;
    }
  }

  Future<bool> _ensureHelperRunning(
    DateTime deadline,
    DesktopVoiceEngineId target,
  ) async {
    bool pastDeadline() => !DateTime.now().isBefore(deadline);

    if (!await _ping(markStatus: true)) {
      final exe = _resolveHelperExe();
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_HELPER_PATH_CHECK',
        exe ?? 'not_found',
      );
      if (exe == null) {
        _lastError = 'STT helper not found';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_SPAWN_FAILED', 'not_found');
        return false;
      }
      final workingDir = File(exe).parent.path;
      _spawnAttempted = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_SPAWN_ATTEMPT', workingDir);
      try {
        _process = await Process.start(
          exe,
          ['--port', '${DesktopSttHelperService._port}'],
          workingDirectory: workingDir,
        );
        _process?.stdout.transform(utf8.decoder).listen(_appendStdoutTail);
        _process?.stderr.transform(utf8.decoder).listen(_appendStderrTail);
        // Watch the process so [_helperProcessAlive] can update without a
        // synchronous blocking probe.
        unawaited(_process!.exitCode.then((c) {
          _helperExitCodeObserved = c;
        }));
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_SPAWN_SUCCESS',
          'pid=${_process?.pid}',
        );
      } catch (e) {
        _lastError = 'Failed to start STT helper: $e';
        DesktopVoicePipeline.mark(
          'DESKTOP_VOICE_HELPER_SPAWN_FAILED',
          'exception $e',
        );
        return false;
      }
      while (!pastDeadline()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final exitCode = await _helperExitCodeIfAnyLive();
        if (exitCode != null) {
          _lastError = 'STT helper exited (code=$exitCode) before responding';
          DesktopVoicePipeline.mark(
            'DESKTOP_VOICE_HELPER_SPAWN_FAILED',
            'process_crashed exit=$exitCode',
          );
          return false;
        }
        if (await _ping(markStatus: true)) {
          _ready = true;
          break;
        }
      }
      if (!_ready) {
        _lastError = 'STT helper did not respond';
        DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_STATUS_TIMEOUT', 'ping');
        return false;
      }
    } else {
      _ready = true;
    }

    return _configureAndWaitReady(target, deadline);
  }

  Future<bool> _restartHelper(
    DateTime deadline,
    DesktopVoiceEngineId target,
  ) async {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_ATTEMPT');
    _killHelperProcess();
    _ready = false;
    _engineReady.clear();
    final ok = await _ensureHelperRunning(deadline, target);
    if (ok) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_SUCCESS');
    } else {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_HELPER_RESTART_FAILED');
    }
    return ok;
  }

  void _killHelperProcess() {
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
    _ready = false;
    _helperExitCodeObserved = null;
  }

  String? _resolveHelperExe() {
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 6; i++) {
        final candidate = File(
          '${dir.path}${Platform.pathSeparator}stt_helper'
          '${Platform.pathSeparator}counter_stt_helper.exe',
        );
        if (candidate.existsSync()) return candidate.path;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
    return null;
  }
}
