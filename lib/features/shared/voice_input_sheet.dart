// Shared mic / speech-to-text bottom sheet. Routing is defined by [VoiceCaptureConfig.submitIntent].
import 'dart:async';

import 'package:counter/data/voice_audio_stub.dart' if (dart.library.html) 'package:counter/data/voice_audio_web.dart' as voice_audio;
import 'package:counter/features/shared/voice_capture_config.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({
    super.key,
    required this.speech,
    required this.setSpeechStatusCallback,
    required this.config,
    this.onListeningChanged,
  });

  final stt.SpeechToText speech;
  final void Function(void Function(String)?) setSpeechStatusCallback;
  final VoiceCaptureConfig config;
  final void Function(bool listening)? onListeningChanged;

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  bool _isPulsing = false;
  late String _statusText;
  String? _error;
  bool _hadErrorInSession = false;
  bool _isSaving = false;
  final ValueNotifier<double> _soundLevel = ValueNotifier(0.0);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _textController = TextEditingController();

  void _playTone({required double freq, required double duration}) {
    voice_audio.playTone(freq: freq, duration: duration);
  }

  @override
  void initState() {
    super.initState();
    _statusText = t(currentLocale.value, 'voice_input');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    unawaited(_start());
  }

  void _onSpeechResult(dynamic res) {
    if (!mounted || _isSaving) return;
    _textController.text = res.recognizedWords;
  }

  @override
  void dispose() {
    widget.speech.stop();
    widget.speech.cancel();
    _textController.dispose();
    _pulseController.dispose();
    _soundLevel.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.setSpeechStatusCallback(null);
      widget.onListeningChanged?.call(false);
    });
    super.dispose();
  }

  Future<String> _resolveSpeechListenLocale() async {
    const hardcodedRuIds = <String>[
      'ru_RU',
      'ru-RU',
      'ru',
      'ru_MD',
      'ru_KZ',
      'ru_BY',
      'ru_UA',
    ];
    List<dynamic> list = const [];
    try {
      list = await widget.speech.locales();
    } catch (e) {
      debugPrint('[STT locale] locales() failed: $e');
    }
    final idsForLog = <String>[
      for (final l in list) l.localeId.toString(),
    ];
    debugPrint(
      '[STT locale] locales count=${idsForLog.length} ids=${idsForLog.join(", ")}',
    );

    int ruLocalePreferenceScore(String localeId) {
      final id = localeId.trim();
      if (id.isEmpty) return -1;
      final lower = id.toLowerCase().replaceAll('-', '_');
      if (!lower.startsWith('ru')) return -1;
      if (lower == 'ru_ru') return 1000;
      if (lower.startsWith('ru_')) return 800;
      if (lower == 'ru') return 600;
      return 400;
    }

    String? bestRuId;
    var best = -1;
    for (final l in list) {
      final lid = l.localeId.toString();
      var sc = ruLocalePreferenceScore(lid);
      try {
        final dynamic raw = l;
        final n = (raw.name as String?)?.toLowerCase() ?? '';
        if (n.contains('russian') ||
            n.contains('русск') ||
            n.contains('russia')) {
          sc = sc < 0 ? 500 : (sc > 500 ? sc : 500);
        }
      } catch (_) {}
      if (sc > best) {
        best = sc;
        bestRuId = lid;
      }
    }
    if (bestRuId != null && best > 0) {
      debugPrint(
        '[STT locale] chosen Russian from enumerated list: $bestRuId (score=$best)',
      );
      return bestRuId;
    }

    final lowerSet = idsForLog.map((e) => e.toLowerCase()).toSet();
    for (final h in hardcodedRuIds) {
      if (lowerSet.contains(h.toLowerCase())) {
        final exact = idsForLog.firstWhere(
          (e) => e.toLowerCase() == h.toLowerCase(),
          orElse: () => h,
        );
        debugPrint('[STT locale] chosen exact catalog id: $exact');
        return exact;
      }
    }

    if (currentLocale.value == 'ru') {
      for (final id in idsForLog) {
        final n = id.toLowerCase().replaceAll('-', '_');
        if (n.startsWith('ru')) {
          debugPrint('[STT locale] UI=ru, first ru* in device list: $id');
          return id;
        }
      }
      debugPrint(
        '[STT locale] UI=ru, no ru in enumerated list — listen() will use ru_RU',
      );
      return 'ru_RU';
    }

    try {
      final sys = await widget.speech.systemLocale();
      final id = sys?.localeId.trim() ?? '';
      if (id.isNotEmpty) {
        debugPrint('[STT locale] systemLocale: $id');
        return id;
      }
    } catch (e) {
      debugPrint('[STT locale] systemLocale() failed: $e');
    }

    debugPrint('[STT locale] final fallback en_US');
    return 'en_US';
  }

  Future<void> _runSpeechListen(String localeId) async {
    await widget.speech.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) => _soundLevel.value = level,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      onDevice: false,
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> _start() async {
    final loc = currentLocale.value;
    setState(() {
      _isPulsing = true;
      _statusText = t(loc, 'voice_status_say_task');
      _isListening = true;
      _error = null;
      _hadErrorInSession = false;
    });
    _textController.clear();
    widget.onListeningChanged?.call(true);
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
            _isPulsing = false;
            _isListening = false;
          });
          widget.onListeningChanged?.call(false);
          return;
        }
      }
    } else {
      debugPrint(
        '[STT] Web: microphone access is handled by the browser when listening starts.',
      );
    }
    if (!mounted) return;

    try {
      if (!widget.speech.isAvailable) {
        await widget.speech.initialize(
          onError: (e) {
            debugPrint(
              '[STT sheet] initialize onError: ${e.errorMsg} (permanent=${e.permanent})',
            );
          },
        );
      }
    } catch (e, st) {
      debugPrint('[STT sheet] initialize in sheet failed: $e\n$st');
    }
    if (!mounted) return;

    widget.setSpeechStatusCallback((status) {
      if (status.startsWith('error:')) {
        final msg = status.replaceFirst('error:', '').trim();
        final displayMsg = msg.toLowerCase().contains('network')
            ? t(loc, 'speech_error_network')
            : t(loc, 'speech_error_prefix').replaceFirst('%s', msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _error = displayMsg;
            _hadErrorInSession = true;
            _isPulsing = false;
          });
        });
        return;
      }
      if (status == 'listening') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _isPulsing = true);
        });
        return;
      }
      if (status == 'done' || status == 'notListening') {
        if (_hadErrorInSession) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isPulsing = false;
            _statusText = t(loc, 'voice_status_heard');
            _isListening = false;
          });
          widget.onListeningChanged?.call(false);
        });
      }
    });

    Future<bool> attemptListen(String localeId) async {
      try {
        await _runSpeechListen(localeId);
        return true;
      } catch (e, st) {
        debugPrint('[STT listen] localeId=$localeId failed: $e\n$st');
        try {
          await widget.speech.stop();
          await widget.speech.cancel();
        } catch (_) {}
        return false;
      }
    }

    final chosen = await _resolveSpeechListenLocale();
    debugPrint('[STT] speech.listen primary localeId=$chosen');

    try {
      var ok = await attemptListen(chosen);
      if (!ok && currentLocale.value == 'ru') {
        for (final alt in <String>['ru_RU', 'ru-RU', 'ru']) {
          if (alt == chosen) continue;
          debugPrint('[STT listen] retry localeId=$alt');
          ok = await attemptListen(alt);
          if (ok) {
            if (!mounted) break;
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
            break;
          }
        }
      }
      if (!ok) {
        try {
          final sys = await widget.speech.systemLocale();
          final fallback = (sys?.localeId ?? '').trim().isNotEmpty
              ? sys!.localeId
              : 'en_US';
          if (fallback != chosen) {
            ok = await attemptListen(fallback);
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
          }
        } catch (e) {
          debugPrint('[STT listen] system locale fallback error: $e');
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
          });
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

  Future<void> _stop() async {
    await widget.speech.stop();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final canCreate = _textController.text.trim().isNotEmpty && !_isSaving;
    final cfg = widget.config;

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
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _soundLevel,
                    builder: (context, level, _) {
                      final levelClamped = level.clamp(0.0, 1.0);
                      final pulse = _isPulsing ? 0.15 * _pulseAnimation.value : 0.0;
                      final soundScale = _isPulsing ? levelClamped * 0.35 : 0.0;
                      final scale = 1.0 + pulse + soundScale;
                      final scheme = Theme.of(context).colorScheme;
                      return Transform.scale(
                        scale: scale,
                        child: Icon(
                          _isPulsing ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                          color: _isPulsing ? scheme.primary : scheme.onSurface,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _error != null
                    ? Text(
                        _error!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.error),
                      )
                    : Text(
                        _statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
              if (_error != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
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
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t(loc, 'say_task_title'),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
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
                          widget.speech.stop();
                          widget.speech.cancel();
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
