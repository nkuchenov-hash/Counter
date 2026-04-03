// Smart Plan: NL paragraph → AI schedule. Mic uses same package as shell, minimal STT wiring.

import 'dart:async';

import 'package:counter/core/services/ai_service.dart';
import 'package:counter/core/services/speech_listen_locale.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef SmartPlanCommit =
    Future<int> Function(List<Map<String, dynamic>> items);

/// Bottom sheet: multiline text, mic (dictation), Generate → AI → [onCommit].
class SmartPlanSheet extends StatefulWidget {
  const SmartPlanSheet({super.key, required this.onCommit});

  final SmartPlanCommit onCommit;

  @override
  State<SmartPlanSheet> createState() => _SmartPlanSheetState();
}

class _SmartPlanSheetState extends State<SmartPlanSheet> {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  bool _thinking = false;
  bool _speechInitialized = false;

  /// Shown inside the sheet (not via [ScaffoldMessenger]) so errors stay
  /// visible above modal z-order issues.
  String? _inlineError;

  /// Last non-null [localeId] passed to [SpeechToText.listen]; drives one-shot
  /// fallback to `null` (device / browser default) on language errors.
  String? _lastListenLocaleIdForRetry;

  @override
  void dispose() {
    unawaited(_stopSpeechSession());
    _textController.dispose();
    super.dispose();
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
        break;
      default:
        break;
    }
  }

  void _setInlineError(String message) {
    if (!mounted) return;
    setState(() => _inlineError = message);
  }

  void _clearInlineError() {
    if (!mounted || _inlineError == null) return;
    setState(() => _inlineError = null);
  }

  void _onSpeechError(dynamic e) {
    if (e is! SpeechRecognitionError) {
      if (mounted) setState(() => _listening = false);
      unawaited(_stopSpeechSession());
      return;
    }
    if (kDebugMode) {
      debugPrint('[SmartPlan STT] ${e.errorMsg} permanent=${e.permanent}');
    }
    final msg = e.errorMsg.toLowerCase();
    if (msg.contains('already') && msg.contains('start')) {
      if (mounted) setState(() => _listening = false);
      unawaited(_stopSpeechSession());
      return;
    }
    final langUnsupported =
        SpeechListenLocale.messageIndicatesLanguageUnsupported(e.errorMsg);
    if (langUnsupported) {
      if (mounted) setState(() => _listening = false);
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
    unawaited(_stopSpeechSession());
    if (msg.contains('network')) {
      _setInlineError(t(currentLocale.value, 'speech_error_network'));
      return;
    }
    _setInlineError(
      t(currentLocale.value, 'speech_error_prefix')
          .replaceFirst('%s', e.errorMsg),
    );
  }

  /// Stops the native session and aligns UI. Safe to call when idle.
  Future<void> _stopSpeechSession() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    try {
      await _speech.cancel();
    } catch (_) {}
    if (mounted) setState(() => _listening = false);
  }

  /// One attempt to recover from `language-not-supported` after a non-null
  /// [localeId]; clears the tag so a second error surfaces the hard message.
  Future<void> _retryListenWithDeviceDefault() async {
    await _stopSpeechSession();
    if (!mounted) return;
    final loc = currentLocale.value;
    _setInlineError(t(loc, 'speech_locale_fallback_generic'));
    await _runSpeechListen(localeId: null);
  }

  Future<void> _runSpeechListen({required String? localeId}) async {
    if (!mounted) return;
    _lastListenLocaleIdForRetry = localeId;
    setState(() => _listening = true);
    try {
      if (_speech.isListening) {
        await _stopSpeechSession();
        if (!mounted) return;
        setState(() => _listening = true);
      }
      await _speech.listen(
        onResult: (res) {
          if (mounted && res.recognizedWords.isNotEmpty) {
            setState(() => _textController.text = res.recognizedWords);
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
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
        '[SmartPlan mic] tap registered thinking=$_thinking listening=$_listening',
      );
    }
    _clearInlineError();
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
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _clearInlineError();
    setState(() => _thinking = true);
    List<Map<String, dynamic>> items;
    try {
      items = await AiService.instance.processPlanningText(text);
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
                  child: TextField(
                    controller: _textController,
                    minLines: 4,
                    maxLines: 8,
                    enabled: !_thinking,
                    decoration: InputDecoration(
                      hintText: t(loc, 'smart_plan_hint'),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      if (_inlineError != null) {
                        setState(() => _inlineError = null);
                      }
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  tooltip: _listening ? t(loc, 'stop') : t(loc, 'voice_input'),
                  icon: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _listening
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  onPressed: _thinking
                      ? null
                      : () {
                          if (kDebugMode) {
                            debugPrint('[SmartPlan mic] IconButton onPressed');
                          }
                          unawaited(_toggleMic());
                        },
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
                onPressed: _textController.text.trim().isEmpty
                    ? null
                    : _generate,
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t(loc, 'smart_plan_submit')),
              ),
          ],
        ),
      ),
    );
  }
}
