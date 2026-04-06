// Smart Plan: NL paragraph → AI schedule. Brick-builder dictation + STT.

import 'dart:async';
import 'dart:math' as math;

import 'package:counter/core/services/ai_service.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/core/services/speech_listen_locale.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef SmartPlanCommit =
    Future<int> Function(List<Map<String, dynamic>> items);

/// Bottom sheet: stacked editable "bricks", mic dictation, Generate → AI.
class SmartPlanSheet extends StatefulWidget {
  const SmartPlanSheet({super.key, required this.onCommit});

  final SmartPlanCommit onCommit;

  @override
  State<SmartPlanSheet> createState() => _SmartPlanSheetState();
}

class _SmartPlanSheetState extends State<SmartPlanSheet> {
  final List<TextEditingController> _brickControllers = [];
  final ScrollController _scrollBricks = ScrollController();
  final ValueNotifier<double> _micLevel = ValueNotifier<double>(0);
  final stt.SpeechToText _speech = stt.SpeechToText();

  int _activeBrickIndex = 0;
  bool _listening = false;
  bool _thinking = false;
  bool _speechInitialized = false;

  /// Latest engine transcript (partial or final); used with Web network blips when UI bricks lag.
  String _lastRecognizedWords = '';

  String? _inlineError;
  /// Non-error hint (e.g. Web STT dropped mid-phrase but text is preserved).
  String? _sttPositiveHint;
  String? _lastListenLocaleIdForRetry;

  @override
  void initState() {
    super.initState();
    _brickControllers.add(TextEditingController());
    _activeBrickIndex = 0;
    if (kIsWeb) {
      unawaited(_prewarmWebSpeechIfNeeded());
    }
  }

  Future<void> _prewarmWebSpeechIfNeeded() async {
    if (!kIsWeb || !mounted || _speechInitialized) return;
    try {
      final ok = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,
      );
      if (!mounted) return;
      if (ok) setState(() => _speechInitialized = true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SmartPlan STT prewarm] $e');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_stopSpeechSession());
    _micLevel.dispose();
    _scrollBricks.dispose();
    for (final c in _brickControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _concatenateBricks() {
    return _brickControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  bool get _hasBrickContent => _concatenateBricks().isNotEmpty;

  bool get _hasAnyRecognizedText =>
      _hasBrickContent || _lastRecognizedWords.trim().isNotEmpty;

  void _resetMicLevel() {
    _micLevel.value = 0;
  }

  void _onMicSoundLevel(double level) {
    double n;
    if (level.isNaN) {
      n = 0;
    } else if (level >= 0 && level <= 1.0) {
      n = level.clamp(0.0, 1.0);
    } else {
      n = ((level + 45) / 45).clamp(0.0, 1.0);
    }
    _micLevel.value = n;
  }

  /// Before starting STT: ensure an empty editable target; append a brick if
  /// the current active one already has text.
  void _prepareActiveBrickForNewSession() {
    if (_brickControllers.isEmpty) {
      _brickControllers.add(TextEditingController());
      _activeBrickIndex = 0;
    } else {
      final cur = _brickControllers[_activeBrickIndex];
      if (cur.text.trim().isNotEmpty) {
        _brickControllers.add(TextEditingController());
        _activeBrickIndex = _brickControllers.length - 1;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollBricks.hasClients) return;
      final off = _scrollBricks.position.maxScrollExtent;
      _scrollBricks.animateTo(
        off,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
    setState(() {});
  }

  bool _isBenignSttDoubleStart(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('invalidstateerror') ||
        s.contains('already started') ||
        s.contains('recognition has already started');
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    switch (status) {
      case 'listening':
        setState(() => _listening = true);
        break;
      case 'notListening':
      case 'done':
        setState(() => _listening = false);
        _resetMicLevel();
        break;
      default:
        break;
    }
  }

  void _setInlineError(String message) {
    if (!mounted) return;
    setState(() {
      _inlineError = message;
      _sttPositiveHint = null;
    });
  }

  void _clearInlineError() {
    if (!mounted) return;
    if (_inlineError == null && _sttPositiveHint == null) return;
    setState(() {
      _inlineError = null;
      _sttPositiveHint = null;
    });
  }

  bool _isNetworkSpeechIssue(String rawMsg) {
    final msg = rawMsg.toLowerCase();
    if (msg.contains('error_network') ||
        msg.contains('networkerror') ||
        msg.contains('network error') ||
        msg.contains('network')) {
      return true;
    }
    if (msg.contains('failed to fetch') || msg.contains('net::err')) {
      return true;
    }
    return false;
  }

  void _onSpeechError(dynamic e) {
    if (e is! SpeechRecognitionError) {
      if (mounted) setState(() => _listening = false);
      _resetMicLevel();
      unawaited(_stopSpeechSession());
      return;
    }
    if (kDebugMode) {
      debugPrint('[SmartPlan STT] ${e.errorMsg} permanent=${e.permanent}');
    }
    final msg = e.errorMsg.toLowerCase();
    if (msg.contains('already') && msg.contains('start')) {
      if (mounted) setState(() => _listening = false);
      _resetMicLevel();
      unawaited(_stopSpeechSession());
      return;
    }
    final langUnsupported =
        SpeechListenLocale.messageIndicatesLanguageUnsupported(e.errorMsg);
    if (langUnsupported) {
      if (mounted) setState(() => _listening = false);
      _resetMicLevel();
      if (_lastListenLocaleIdForRetry != null) {
        unawaited(_retryListenWithDeviceDefault());
        return;
      }
      if (!mounted) return;
      unawaited(_stopSpeechSession());
      _setInlineError(t(currentLocale.value, 'speech_language_not_supported'));
      return;
    }
    if (!mounted) return;
    setState(() => _listening = false);
    _resetMicLevel();
    unawaited(_stopSpeechSession());
    if (_isNetworkSpeechIssue(e.errorMsg)) {
      if (kIsWeb && _hasAnyRecognizedText) {
        if (!mounted) return;
        setState(() {
          _inlineError = null;
          _sttPositiveHint =
              t(currentLocale.value, 'smart_plan_stt_recovered_hint');
        });
        return;
      }
      if (kIsWeb && !_hasAnyRecognizedText) {
        _setInlineError(t(currentLocale.value, 'speech_error_network_soft'));
        return;
      }
      _setInlineError(t(currentLocale.value, 'speech_error_network'));
      return;
    }
    _setInlineError(
      t(currentLocale.value, 'speech_error_prefix')
          .replaceFirst('%s', e.errorMsg),
    );
  }

  Future<void> _stopSpeechSession() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}
    _resetMicLevel();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _retryListenWithDeviceDefault() async {
    await _stopSpeechSession();
    if (!mounted) return;
    final loc = currentLocale.value;
    _setInlineError(t(loc, 'speech_locale_fallback_generic'));
    await _runSpeechListen(localeId: null);
  }

  TextEditingController? get _activeController {
    if (_activeBrickIndex < 0 || _activeBrickIndex >= _brickControllers.length) {
      return null;
    }
    return _brickControllers[_activeBrickIndex];
  }

  Future<void> _runSpeechListen({required String? localeId}) async {
    if (!mounted) return;
    _lastListenLocaleIdForRetry = localeId;
    try {
      if (_speech.isListening) {
        await _stopSpeechSession();
        if (!mounted) return;
      }
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted) return;
      await _speech.listen(
        onResult: (res) {
          final text = res.recognizedWords;
          if (!mounted) return;
          if (text.isNotEmpty) {
            _lastRecognizedWords = text;
          }
          if (text.isEmpty) return;
          final brick = _activeController;
          if (brick == null) return;
          brick.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
        onSoundLevelChange: _onMicSoundLevel,
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 15),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      if (_isBenignSttDoubleStart(e)) {
        await _stopSpeechSession();
        return;
      }
      if (mounted) {
        setState(() => _listening = false);
        _resetMicLevel();
        _setInlineError(
          t(currentLocale.value, 'speech_error_prefix')
              .replaceFirst('%s', '$e'),
        );
      }
    }
  }

  Future<void> _toggleMic() async {
    if (kDebugMode) {
      debugPrint(
        '[SmartPlan mic] tap thinking=$_thinking listening=$_listening',
      );
    }
    _clearInlineError();
    _lastRecognizedWords = '';
    final loc = currentLocale.value;

    if (_listening) {
      await _stopSpeechSession();
      return;
    }

    if (_speech.isListening) {
      await _stopSpeechSession();
    }

    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          if (!mounted) return;
          _setInlineError(t(loc, 'microphone_permission'));
          return;
        }
      }
    }

    try {
      if (!_speechInitialized) {
        if (kDebugMode) debugPrint('[SmartPlan mic] initializing SpeechToText…');
        final available = await _speech.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
          debugLogging: false,
        );
        if (kDebugMode) {
          debugPrint('[SmartPlan mic] initialize result available=$available');
        }
        if (!available) {
          if (!mounted) return;
          _setInlineError(t(loc, 'speech_unavailable'));
          return;
        }
        _speechInitialized = true;
      }
    } catch (e) {
      if (!mounted) return;
      if (_isBenignSttDoubleStart(e)) {
        await _stopSpeechSession();
        return;
      }
      _setInlineError(t(loc, 'speech_error_prefix').replaceFirst('%s', '$e'));
      return;
    }

    if (!mounted) return;

    _prepareActiveBrickForNewSession();

    final String? listenLocaleId =
        await SpeechListenLocale.resolveListenLocaleId(
      speech: _speech,
      appLoc: loc,
    );
    if (!mounted) return;
    await _runSpeechListen(localeId: listenLocaleId);
  }

  Future<void> _generate() async {
    final loc = currentLocale.value;
    final text = _concatenateBricks();
    if (text.isEmpty) return;

    _clearInlineError();
    setState(() => _thinking = true);
    List<Map<String, dynamic>> items;
    try {
      final categoryNames =
          DatabaseService.instance.smartPlanAllowedCategoryLabels();
      items = await AiService.instance.processPlanningText(
        text,
        categoryNames,
      );
    } on AiServiceException catch (e) {
      if (mounted) {
        _setInlineError(
          t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        _setInlineError(
          t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _thinking = false);
    }

    if (!mounted) return;

    if (items.isEmpty) {
      _setInlineError(t(loc, 'smart_plan_empty'));
      return;
    }

    int created;
    try {
      created = await widget.onCommit(items);
    } catch (e) {
      if (mounted) {
        _setInlineError(
          t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
        );
      }
      return;
    }

    if (!mounted) return;

    if (created <= 0) {
      _setInlineError(t(loc, 'smart_plan_empty'));
      return;
    }
    final rootMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    rootMessenger.showSnackBar(
      SnackBar(
        content: Text(
          t(loc, 'smart_plan_added').replaceFirst('%s', '$created'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxListHeight = math.min(
      320.0,
      MediaQuery.sizeOf(context).height * 0.42,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(loc, 'smart_plan_sheet_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed:
                      _thinking ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: maxListHeight,
                    child: ListView.builder(
                      controller: _scrollBricks,
                      itemCount: _brickControllers.length,
                      itemBuilder: (context, index) {
                        final isActive =
                            index == _activeBrickIndex && _listening;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                width: isActive ? 2 : 1,
                              ),
                              color: scheme.surfaceContainerHighest,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: TextField(
                                controller: _brickControllers[index],
                                minLines: 2,
                                maxLines: 6,
                                enabled: !_thinking,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: index == 0
                                      ? t(loc, 'smart_plan_hint')
                                      : '${index + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_inlineError != null ||
                                      _sttPositiveHint != null) {
                                    setState(() {
                                      _inlineError = null;
                                      _sttPositiveHint = null;
                                    });
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  type: MaterialType.transparency,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _micLevel,
                    builder: (context, level, child) {
                      final pulse =
                          _listening ? 1.0 + 0.28 * level.clamp(0.0, 1.0) : 1.0;
                      return Transform.scale(scale: pulse, child: child);
                    },
                    child: IconButton(
                      tooltip:
                          _listening ? t(loc, 'stop') : t(loc, 'voice_input'),
                      icon: Icon(
                        _listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_none_rounded,
                        color: _listening
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      onPressed: _thinking
                          ? null
                          : () {
                              debugPrint('[BRICK] mic tap');
                              unawaited(_toggleMic());
                            },
                    ),
                  ),
                ),
              ],
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 8),
              Text(
                _inlineError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
              ),
            ] else if (_sttPositiveHint != null) ...[
              const SizedBox(height: 8),
              Text(
                _sttPositiveHint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            if (_thinking)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t(loc, 'smart_plan_thinking'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              FilledButton.icon(
                onPressed: !_hasBrickContent ? null : _generate,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t(loc, 'smart_plan_submit')),
              ),
          ],
        ),
      ),
    );
  }
}
