// Shared mic / speech-to-text bottom sheet. Routing is defined by [VoiceCaptureConfig.submitIntent].
import 'dart:async';

import 'package:counter/core/services/speech_engine_handle.dart';
import 'package:counter/core/services/speech_listen_locale.dart';
import 'package:counter/data/voice_audio_stub.dart' if (dart.library.html) 'package:counter/data/voice_audio_web.dart' as voice_audio;
import 'package:counter/features/shared/voice_capture_config.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({
    super.key,
    required this.speechHandle,
    required this.setSpeechStatusCallback,
    required this.config,
    this.onSpeechEngineHardReset,
    this.onListeningChanged,
  });

  final SpeechEngineHandle speechHandle;
  final void Function(void Function(String)?) setSpeechStatusCallback;
  final Future<void> Function()? onSpeechEngineHardReset;
  final VoiceCaptureConfig config;
  final void Function(bool listening)? onListeningChanged;

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  bool _isListening = false;
  bool _isPulsing = false;
  late String _statusText;
  String? _error;
  bool _softErrorVisual = false;
  bool _voiceRecoveredCue = false;
  bool _hadErrorInSession = false;
  bool _isSaving = false;
  final ValueNotifier<double> _soundLevel = ValueNotifier(0.0);
  final TextEditingController _textController = TextEditingController();
  /// Finalized speech for this listen session (seeded from the field on start / locale switch).
  String _committedText = '';
  late String _speechUiCode;

  /// Field + committed text at the start of this listen attempt (restore on Web network failure).
  String _sttListenBaseline = '';
  /// After a Web STT network error, drop mixed-script results until the next session.
  bool _postWebNetworkSpeechGarbageFilter = false;
  String? _activeListenLocaleId;

  stt.SpeechToText get _engine => widget.speechHandle.speech;

  bool _isNetworkSttMessage(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('error_network') ||
        msg.contains('networkerror') ||
        msg.contains('network error') ||
        msg.contains('network')) {
      return true;
    }
    return msg.contains('failed to fetch') || msg.contains('net::err');
  }

  /// Web Speech API: treat plugin/network disconnect errors aggressively (avoid broad "network" substring).
  bool _isWebSttHardNetworkFailure(String raw) {
    final m = raw.toLowerCase();
    final trimmed = m.trim();
    return trimmed == 'network' ||
        m.contains('error_network') ||
        m.contains('networkerror') ||
        m.contains('network error') ||
        m.contains('failed to fetch') ||
        m.contains('net::err');
  }

  bool _hasLatinLetters(String s) => RegExp(r'[A-Za-z]').hasMatch(s);

  bool _hasCyrillicLetters(String s) => RegExp(r'[\u0400-\u04FF]').hasMatch(s);

  bool _isMixedLatinAndCyrillicScript(String s) =>
      _hasLatinLetters(s) && _hasCyrillicLetters(s);

  bool _shouldDiscardWebPostNetworkHallucination(String words) {
    if (!kIsWeb || !_postWebNetworkSpeechGarbageFilter) return false;
    if (words.trim().isEmpty) return false;
    return _isMixedLatinAndCyrillicScript(words);
  }

  Future<void> _abortWebSpeechDueToNetwork(String loc) async {
    _postWebNetworkSpeechGarbageFilter = true;
    try {
      await _engine.stop();
    } catch (_) {}
    try {
      await _engine.cancel();
    } catch (_) {}
    if (!mounted) return;
    final baseline = _sttListenBaseline;
    _committedText = baseline;
    _textController.value = TextEditingValue(
      text: baseline,
      selection: TextSelection.collapsed(offset: baseline.length),
    );
    setState(() {
      _error = t(loc, 'speech_error_network_browser');
      _softErrorVisual = false;
      _voiceRecoveredCue = false;
      _hadErrorInSession = true;
      _isPulsing = false;
      _isListening = false;
    });
    widget.onListeningChanged?.call(false);
    final snack = t(loc, 'speech_error_network_browser');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snack)),
      );
    });
  }

  void _onSpeechSttPluginError(String msg, String loc) {
    final isNetwork = _isNetworkSttMessage(msg);

    if (kIsWeb && _isWebSttHardNetworkFailure(msg)) {
      unawaited(_abortWebSpeechDueToNetwork(loc));
      return;
    }

    if (_messageIndicatesNoSpeech(msg)) {
      unawaited(_performSpeechEngineHardReset());
    }
    final String displayMsg;
    if (isNetwork) {
      displayMsg = t(loc, 'speech_error_network');
    } else if (SpeechListenLocale.messageIndicatesLanguageUnsupported(
      msg,
    )) {
      displayMsg = t(loc, 'speech_language_not_supported');
    } else {
      displayMsg = t(loc, 'speech_error_prefix').replaceFirst('%s', msg);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _error = displayMsg;
        _softErrorVisual = false;
        _hadErrorInSession = true;
        _isPulsing = false;
        _isListening = false;
      });
      widget.onListeningChanged?.call(false);
    });
  }

  /// Maps plugin dB/RMS to [0,1] for border/stripe/mic (all platforms; Web may stay 0 if no levels).
  double _normalizeSoundLevelForUi(double rawDb) {
    if (rawDb.isNaN || rawDb.isInfinite) return 0.0;
    if (rawDb < 0) {
      const floor = -52.0;
      const ceil = -15.0;
      if (rawDb <= floor) return 0.0;
      return ((rawDb - floor) / (ceil - floor)).clamp(0.0, 1.0);
    }
    const floorP = 2.5;
    const ceilP = 22.0;
    if (rawDb < floorP) return 0.0;
    return ((rawDb - floorP) / (ceilP - floorP)).clamp(0.0, 1.0);
  }

  bool _messageIndicatesNoSpeech(String raw) {
    final m = raw.toLowerCase();
    return m.contains('no_speech') ||
        m.contains('no speech') ||
        m.contains('speech_not_detected') ||
        m.contains('no-match') ||
        (m.contains('aborted') && m.contains('audio'));
  }

  Future<void> _performSpeechEngineHardReset() async {
    if (!mounted) return;
    try {
      await _engine.stop();
    } catch (_) {}
    try {
      await _engine.cancel();
    } catch (_) {}
    final reset = widget.onSpeechEngineHardReset;
    if (reset != null) {
      try {
        await reset();
      } catch (e, st) {
        debugPrint('[STT sheet] onSpeechEngineHardReset failed: $e\n$st');
      }
    } else {
      try {
        await _engine.initialize(
          onError: (e) {
            debugPrint(
              '[STT sheet] re-init onError: ${e.errorMsg} (permanent=${e.permanent})',
            );
          },
          debugLogging: false,
        );
      } catch (e, st) {
        debugPrint('[STT sheet] re-init (same instance) failed: $e\n$st');
      }
    }
  }

  void _playTone({required double freq, required double duration}) {
    voice_audio.playTone(freq: freq, duration: duration);
  }

  void _onAppLocaleChanged() {
    if (!mounted) return;
    _coerceSpeechUiCodeToPrimaryOrEnglish(
      resolvedUiLanguageCode(currentLocale.value),
    );
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    currentLocale.addListener(_onAppLocaleChanged);
    _textController.clear();
    _statusText = t(currentLocale.value, 'voice_input');
    _speechUiCode = resolvedUiLanguageCode(currentLocale.value);
    _coerceSpeechUiCodeToPrimaryOrEnglish(_speechUiCode);
    unawaited(_start());
  }

  void _onSpeechResult(SpeechRecognitionResult res) {
    if (!mounted || _isSaving) return;
    if (kDebugMode) {
      debugPrint(
        '[STT DEBUG] localeId=$_activeListenLocaleId speechUi=$_speechUiCode '
        'words: "${res.recognizedWords}" final: ${res.finalResult}',
      );
    }
    if (_shouldDiscardWebPostNetworkHallucination(res.recognizedWords)) {
      if (kDebugMode) {
        debugPrint(
          '[STT DEBUG] discarded post-network mixed-script localeId=$_activeListenLocaleId '
          'speechUi=$_speechUiCode words: "${res.recognizedWords}"',
        );
      }
      return;
    }
    final chunk = res.recognizedWords.trim();
    if (res.finalResult) {
      if (chunk.isNotEmpty) {
        _committedText = _committedText.isEmpty
            ? chunk
            : '$_committedText $chunk';
      }
      _textController.text = _committedText;
    } else {
      final rawPartial = res.recognizedWords;
      final partialTrim = rawPartial.trim();
      if (partialTrim.isEmpty) {
        _textController.text = _committedText;
      } else if (_committedText.isEmpty) {
        _textController.text = rawPartial;
      } else {
        _textController.text = '$_committedText $partialTrim';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    currentLocale.removeListener(_onAppLocaleChanged);
    _engine.stop();
    _engine.cancel();
    _committedText = '';
    _textController.dispose();
    _soundLevel.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.setSpeechStatusCallback(null);
      widget.onListeningChanged?.call(false);
    });
    super.dispose();
  }

  Future<void> _runSpeechListen(String? localeId) async {
    _activeListenLocaleId = localeId;
    try {
      await _engine.stop();
    } catch (_) {}
    try {
      await _engine.cancel();
    } catch (_) {}
    if (kDebugMode) {
      debugPrint(
        '[STT DEBUG] listen() after cancel/stop localeId=$localeId speechUi=$_speechUiCode web=$kIsWeb',
      );
    }
    await _engine.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        _soundLevel.value = _normalizeSoundLevelForUi(level);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 20),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
      ),
    );
  }

  void _coerceSpeechUiCodeToPrimaryOrEnglish(String appPrimaryResolved) {
    if (appPrimaryResolved == 'en') {
      _speechUiCode = 'en';
      return;
    }
    if (_speechUiCode != 'en' && _speechUiCode != appPrimaryResolved) {
      _speechUiCode = appPrimaryResolved;
    }
  }

  Future<void> _start() async {
    final loc = currentLocale.value;
    _coerceSpeechUiCodeToPrimaryOrEnglish(resolvedUiLanguageCode(loc));
    setState(() {
      _isPulsing = false;
      _statusText = t(loc, 'voice_status_say_task');
      _isListening = false;
      _error = null;
      _softErrorVisual = false;
      _voiceRecoveredCue = false;
      _hadErrorInSession = false;
    });
    if (kIsWeb) {
      _postWebNetworkSpeechGarbageFilter = false;
    }
    final baseline = _textController.text.trim();
    _committedText = baseline;
    _sttListenBaseline = baseline;
    _soundLevel.value = 0.0;
    widget.onListeningChanged?.call(false);
    _playTone(freq: 660, duration: 0.1);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    if (!kIsWeb) {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final res = await Permission.microphone.request();
        if (!res.isGranted) {
          if (!mounted) return;
          setState(() {
            _error = t(loc, 'microphone_permission');
            _softErrorVisual = false;
            _voiceRecoveredCue = false;
            _isPulsing = false;
            _isListening = false;
          });
          widget.onListeningChanged?.call(false);
          return;
        }
      }
    }
    if (!mounted) return;

    try {
      if (!_engine.isAvailable) {
        await _engine.initialize(
          onError: (e) {
            debugPrint(
              '[STT sheet] initialize onError: ${e.errorMsg} (permanent=${e.permanent})',
            );
          },
          debugLogging: false,
        );
      }
    } catch (e, st) {
      debugPrint('[STT sheet] initialize in sheet failed: $e\n$st');
    }
    if (!mounted) return;

    await _attachStatusAndListen(loc: loc);
  }

  Future<void> _attachStatusAndListen({required String loc}) async {
    _coerceSpeechUiCodeToPrimaryOrEnglish(resolvedUiLanguageCode(loc));
    _soundLevel.value = 0.0;
    widget.setSpeechStatusCallback((status) {
      if (status.startsWith('error:')) {
        final msg = status.replaceFirst('error:', '').trim();
        _onSpeechSttPluginError(msg, loc);
        return;
      }
      if (status == 'listening') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isPulsing = true;
            _isListening = true;
          });
          widget.onListeningChanged?.call(true);
        });
        return;
      }
      if (status == 'done' || status == 'notListening') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isPulsing = false;
            _isListening = false;
            if (!_hadErrorInSession) {
              _committedText = _textController.text.trim();
              _statusText = t(loc, 'voice_status_heard');
            }
          });
          widget.onListeningChanged?.call(false);
        });
      }
    });

    Future<bool> attemptListen(String? localeId) async {
      try {
        await _runSpeechListen(localeId);
        return true;
      } catch (e, st) {
        debugPrint('[STT listen] localeId=$localeId failed: $e\n$st');
        try {
          await _engine.stop();
          await _engine.cancel();
        } catch (_) {}
        return false;
      }
    }

    final String? chosen = kIsWeb
        ? SpeechListenLocale.webVoiceListenLocaleId(_speechUiCode)
        : await SpeechListenLocale.resolveListenLocaleId(
            speech: _engine,
            speechUiCode: _speechUiCode,
          );
    if (kDebugMode) {
      debugPrint(
        '[STT] speech.listen speechUi=$_speechUiCode localeId=$chosen web=$kIsWeb',
      );
    }

    try {
      var ok = await attemptListen(chosen);
      if (!ok && chosen != null) {
        if (kDebugMode) {
          debugPrint('[STT listen] retry localeId=null (device default)');
        }
        ok = await attemptListen(null);
        if (ok && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t(currentLocale.value, 'speech_locale_fallback_generic'),
                ),
              ),
            );
          });
        }
      }
      if (!ok && !kIsWeb) {
        try {
          ok = await attemptListen('en_US');
          if (ok && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t(currentLocale.value, 'speech_russian_engine_fallback'),
                  ),
                ),
              );
            });
          }
        } catch (e) {
          debugPrint('[STT listen] en_US fallback error: $e');
        }
      }
      if (!ok) {
        throw StateError('Speech listen failed for all tried locales');
      }
    } catch (firstErr) {
      debugPrint('[STT listen] fatal: $firstErr');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = t(loc, 'speech_error_prefix')
                .replaceFirst('%s', firstErr.toString());
            _isPulsing = false;
            _isListening = false;
          });
          widget.onListeningChanged?.call(false);
        }
        widget.setSpeechStatusCallback(null);
      });
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isListening = false);
        widget.onListeningChanged?.call(false);
      });
    }
  }

  Future<void> _onSpeechSttLocaleSelected(String nextCode) async {
    final resolvedNext = resolvedUiLanguageCode(nextCode);
    if (resolvedNext == _speechUiCode) return;
    final wasListening = _isListening || _engine.isListening;
    final preserved = _textController.text.trim();
    setState(() => _speechUiCode = resolvedNext);

    if (!wasListening) return;

    _committedText = preserved;
    _sttListenBaseline = preserved;
    try {
      await _engine.stop();
      await _engine.cancel();
    } catch (_) {}

    if (!mounted) return;
    await _attachStatusAndListen(loc: currentLocale.value);
  }

  Future<void> _stop() async {
    _committedText = '';
    if (kIsWeb) {
      _postWebNetworkSpeechGarbageFilter = false;
    }
    await _engine.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isPulsing = false;
        _statusText = t(currentLocale.value, 'voice_status_heard');
      });
      widget.onListeningChanged?.call(false);
    });
  }

  static final Color _sttReactiveGreen = Colors.green.shade700;

  Widget _buildTranscriptTextField({
    required ColorScheme scheme,
    required String loc,
  }) {
    final listening = _isListening && _isPulsing;
    return ValueListenableBuilder<double>(
      valueListenable: _soundLevel,
      builder: (context, level, _) {
        final v = level.clamp(0.0, 1.0);
        final borderW = listening ? 1.0 + 2.8 * v : 1.0;
        final borderColor = listening
            ? Color.lerp(
                scheme.outline.withValues(alpha: 0.4),
                _sttReactiveGreen,
                0.12 + 0.88 * v,
              )!
            : scheme.outline.withValues(alpha: 0.22);
        final stripeH = listening ? 3.0 + v * 5.0 : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: borderW),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: t(loc, 'say_task_title'),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) {
                    if (_voiceRecoveredCue) {
                      setState(() => _voiceRecoveredCue = false);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
            if (listening) ...[
              SizedBox(height: stripeH > 0 ? 6 : 0),
              if (stripeH > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: stripeH,
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: stripeH,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                      color: _sttReactiveGreen,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final canCreate = _textController.text.trim().isNotEmpty && !_isSaving;
    final cfg = widget.config;
    final listening = _isListening && _isPulsing;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _soundLevel,
                builder: (context, level, _) {
                  final v = level.clamp(0.0, 1.0);
                  final scale = 1.0 + (listening ? v * 0.35 : 0.0);
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      _isListening
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                      color: _isListening
                          ? Color.lerp(
                              scheme.onSurface,
                              _sttReactiveGreen,
                              0.35 + 0.65 * v,
                            )!
                          : scheme.onSurface,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _error != null
                    ? Text(
                        _error!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _softErrorVisual
                                  ? scheme.onSurfaceVariant
                                  : scheme.error,
                            ),
                      )
                    : Text(
                        _statusText,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _voiceRecoveredCue
                                  ? scheme.primary
                                  : null,
                              fontWeight:
                                  _voiceRecoveredCue ? FontWeight.w600 : null,
                            ),
                      ),
              ),
              if (_error != null || _voiceRecoveredCue)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _softErrorVisual = false;
                      _voiceRecoveredCue = false;
                      _hadErrorInSession = false;
                    });
                    _start();
                  },
                  tooltip: t(loc, 'try_again'),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              TextButton(
                onPressed: _isListening ? _stop : _start,
                child: Text(_isListening ? t(loc, 'stop') : t(loc, 'listen')),
              ),
            ],
          ),
          ValueListenableBuilder<String>(
            valueListenable: currentLocale,
            builder: (context, appLangRaw, _) {
              final appPrimary = resolvedUiLanguageCode(appLangRaw);
              final showSttLangToggle = appPrimary != 'en';
              if (!showSttLangToggle) {
                return const SizedBox(height: 10);
              }
              const segEn = 'en';
              final scheme = Theme.of(context).colorScheme;
              final primaryLabel =
                  kUiLanguageNativeDisplayNames[appPrimary] ?? appPrimary.toUpperCase();
              final englishLabel =
                  kUiLanguageNativeDisplayNames[segEn] ?? segEn.toUpperCase();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Tooltip(
                      message: '$primaryLabel · $englishLabel',
                      child: Material(
                        color:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              side: BorderSide.none,
                              backgroundColor: Colors.transparent,
                            ),
                            segments: [
                              ButtonSegment<String>(
                                value: appPrimary,
                                label: Text(
                                  appPrimary.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              ButtonSegment<String>(
                                value: segEn,
                                label: Text(
                                  segEn.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                            selected: {_speechUiCode},
                            onSelectionChanged: (set) {
                              if (set.isEmpty) return;
                              unawaited(_onSpeechSttLocaleSelected(set.first));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
          _buildTranscriptTextField(scheme: scheme, loc: loc),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCreate
                      ? () async {
                          if (_isSaving || !mounted) return;
                          final text = _textController.text.trim();
                          if (text.isEmpty) return;
                          _engine.stop();
                          _engine.cancel();
                          _committedText = '';
                          setState(() => _isSaving = true);
                          var ok = false;
                          try {
                            ok = await cfg.submitIntent(text);
                          } finally {
                            if (mounted) {
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t(loc, cfg.successL10nKey)),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _isSaving = false);
                              });
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t(loc, cfg.primaryActionL10nKey)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
