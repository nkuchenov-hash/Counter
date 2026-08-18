import 'dart:async';

import 'package:counter/shared/voice/recognition/speech_engine_handle.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Owns the mutable SpeechToText instance and its initialization/reset lifecycle.
///
/// Shell/UI code may select when to start voice capture, but it should not own
/// plugin engine state or platform-specific initialization recovery.
final class SpeechEngineController {
  stt.SpeechToText? _speech;
  SpeechEngineHandle? _handle;
  void Function(String)? _statusCallback;
  bool _ready = false;
  bool _disposed = false;
  String? _lastInitError;

  bool get ready => _ready;
  String? get lastInitError => _lastInitError;

  SpeechEngineHandle get handle {
    final engine = _speech ??= stt.SpeechToText();
    final holder = _handle ??= SpeechEngineHandle(engine);
    holder.speech = engine;
    return holder;
  }

  void setStatusCallback(void Function(String)? callback) {
    _statusCallback = callback;
  }

  Future<void> ensureReady() async {
    if (_disposed || _ready) return;
    _speech ??= stt.SpeechToText();
    await _initializeCurrentEngine();
  }

  Future<void> hardReset() async {
    if (_disposed) return;
    final current = _speech;
    try {
      await current?.stop();
    } catch (_) {}
    try {
      await current?.cancel();
    } catch (_) {}

    final replacement = stt.SpeechToText();
    _speech = replacement;
    _handle?.speech = replacement;
    _ready = false;
    _lastInitError = null;
    await _initializeCurrentEngine();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _statusCallback = null;
    _ready = false;
    final current = _speech;
    try {
      await current?.stop();
    } catch (_) {}
    try {
      await current?.cancel();
    } catch (_) {}
  }

  Future<void> _initializeCurrentEngine() async {
    if (_disposed) return;
    final engine = _speech;
    if (engine == null) return;

    _lastInitError = null;
    try {
      final available = await engine.initialize(
        onStatus: (status) => _statusCallback?.call(status),
        onError: (error) {
          final message = error.errorMsg;
          debugPrint(
            '[STT] onError: $message (permanent=${error.permanent})',
          );
          _statusCallback?.call('error:$message');
        },
        debugLogging: false,
      );
      if (_disposed) return;

      if (!available) {
        const message = 'initialize() returned false';
        _lastInitError = message;
        _ready = false;
        debugPrint('[STT] $message');
        return;
      }

      _ready = true;
      _lastInitError = null;
      if (kIsWeb) {
        unawaited(_logLocalesBestEffortWeb(engine));
      } else {
        await _logLocalesBestEffort(engine);
      }
    } catch (error, stackTrace) {
      if (_disposed) return;
      _lastInitError = error.toString();
      _ready = false;
      debugPrint('[STT] initialize exception: $error\n$stackTrace');
    }
  }

  Future<void> _logLocalesBestEffort(stt.SpeechToText engine) async {
    try {
      final locales = await engine.locales();
      final ids = <String>[
        for (final locale in locales) locale.localeId.toString(),
      ];
      debugPrint(
        '[STT] initialize OK; locales (${locales.length}): ${ids.join(', ')}',
      );
    } catch (error, stackTrace) {
      debugPrint('[STT] locales() after init failed: $error\n$stackTrace');
    }
  }

  Future<void> _logLocalesBestEffortWeb(stt.SpeechToText engine) async {
    try {
      final locales = await engine.locales();
      final ids = <String>[
        for (final locale in locales) locale.localeId.toString(),
      ];
      debugPrint(
        '[STT] Web init OK; locales async (${locales.length}): ${ids.join(', ')}',
      );
    } catch (error, stackTrace) {
      debugPrint('[STT] Web locales() log failed: $error\n$stackTrace');
    }
  }
}
