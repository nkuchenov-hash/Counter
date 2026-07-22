import 'dart:async';

import 'package:counter/shared/voice/recognition/speech_engine_handle.dart';
import 'package:counter/shared/voice/recognition/speech_listen_locale.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/voice/voice_command_parser.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum _DesktopVoicePanelPhase {
  listening,
  parsing,
  resolved,
  ambiguous,
  error,
  starting,
  done,
}

/// Minimal floating desktop panel for structured Price Reporter voice commands.
class DesktopVoiceCommandPanel extends StatefulWidget {
  const DesktopVoiceCommandPanel({
    super.key,
    required this.speechHandle,
    required this.categoryIndex,
    required this.setSpeechStatusCallback,
    required this.onStartRecord,
    this.onSpeechEngineHardReset,
  });

  final SpeechEngineHandle speechHandle;
  final VoiceCommandCategoryIndex categoryIndex;
  final void Function(void Function(String)?) setSpeechStatusCallback;
  final Future<bool> Function(VoiceCommandParseResult result) onStartRecord;
  final Future<void> Function()? onSpeechEngineHardReset;

  @override
  State<DesktopVoiceCommandPanel> createState() =>
      _DesktopVoiceCommandPanelState();
}

class _DesktopVoiceCommandPanelState extends State<DesktopVoiceCommandPanel> {
  _DesktopVoicePanelPhase _phase = _DesktopVoicePanelPhase.listening;
  String _statusLine = '';
  String _transcript = '';
  String? _errorDetail;
  VoiceCommandParseResult? _parseResult;
  bool _isListening = false;
  late String _speechUiCode;
  String? _activeListenLocaleId;

  stt.SpeechToText get _engine => widget.speechHandle.speech;

  @override
  void initState() {
    super.initState();
    _speechUiCode = resolvedUiLanguageCode(currentLocale.value);
    final loc = currentLocale.value;
    _statusLine = t(loc, 'desktop_voice_listening');
    unawaited(_beginListenSession());
  }

  @override
  void dispose() {
    try {
      _engine.stop();
      _engine.cancel();
    } catch (_) {}
    widget.setSpeechStatusCallback(null);
    super.dispose();
  }

  void _setPhase(_DesktopVoicePanelPhase phase, {String? status, String? error}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      if (status != null) _statusLine = status;
      if (error != null) {
        _errorDetail = error;
      } else if (phase != _DesktopVoicePanelPhase.error &&
          phase != _DesktopVoicePanelPhase.ambiguous) {
        _errorDetail = null;
      }
    });
  }

  Future<void> _beginListenSession() async {
    final loc = currentLocale.value;
    _setPhase(
      _DesktopVoicePanelPhase.listening,
      status: t(loc, 'desktop_voice_listening'),
    );
    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final res = await Permission.microphone.request();
        if (!res.isGranted) {
          _setPhase(
            _DesktopVoicePanelPhase.error,
            status: t(loc, 'microphone_permission'),
            error: t(loc, 'microphone_permission'),
          );
          return;
        }
      }
    }
    if (!mounted) return;

    try {
      if (!_engine.isAvailable) {
        await _engine.initialize(
          onError: (e) {
            if (!mounted) return;
            _setPhase(
              _DesktopVoicePanelPhase.error,
              status: t(loc, 'speech_error_prefix')
                  .replaceFirst('%s', e.errorMsg),
              error: e.errorMsg,
            );
          },
          debugLogging: false,
        );
      }
    } catch (e) {
      _setPhase(
        _DesktopVoicePanelPhase.error,
        status: t(loc, 'speech_unavailable'),
        error: e.toString(),
      );
      return;
    }
    if (!mounted) return;

    widget.setSpeechStatusCallback((status) {
      if (status.startsWith('error:')) {
        final msg = status.replaceFirst('error:', '').trim();
        _setPhase(
          _DesktopVoicePanelPhase.error,
          status: t(loc, 'speech_error_prefix').replaceFirst('%s', msg),
          error: msg,
        );
        return;
      }
      if (status == 'listening') {
        if (mounted) setState(() => _isListening = true);
        return;
      }
      if (status == 'done' || status == 'notListening') {
        if (mounted) setState(() => _isListening = false);
        unawaited(_finalizeTranscriptAndParse());
      }
    });

    try {
      await _engine.stop();
      await _engine.cancel();
    } catch (_) {}

    final chosen = await SpeechListenLocale.resolveListenLocaleId(
      speech: _engine,
      speechUiCode: _speechUiCode,
    );
    _activeListenLocaleId = chosen;
    try {
      await _engine.listen(
        onResult: _onSpeechResult,
        localeId: chosen,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          onDevice: false,
        ),
      );
    } catch (e) {
      _setPhase(
        _DesktopVoicePanelPhase.error,
        status: t(loc, 'speech_unavailable'),
        error: e.toString(),
      );
    }
  }

  void _onSpeechResult(SpeechRecognitionResult res) {
    if (!mounted) return;
    final text = res.recognizedWords.trim();
    if (text.isEmpty) return;
    setState(() => _transcript = text);
    if (res.finalResult) {
      unawaited(_finalizeTranscriptAndParse());
    }
  }

  Future<void> _finalizeTranscriptAndParse() async {
    if (!mounted) return;
    if (_phase == _DesktopVoicePanelPhase.starting ||
        _phase == _DesktopVoicePanelPhase.done) {
      return;
    }
    final loc = currentLocale.value;
    final text = _transcript.trim();
    if (text.isEmpty) {
      _setPhase(
        _DesktopVoicePanelPhase.error,
        status: t(loc, 'desktop_voice_no_speech'),
        error: t(loc, 'desktop_voice_no_speech'),
      );
      return;
    }

    _setPhase(
      _DesktopVoicePanelPhase.parsing,
      status: t(loc, 'desktop_voice_parsing'),
    );

    final parsed = parsePriceReporterVoiceCommand(
      index: widget.categoryIndex,
      transcript: text,
    );
    _parseResult = parsed;

    if (parsed.confidence == VoiceCommandMatchConfidence.exact &&
        parsed.isSafeToStart) {
      _setPhase(
        _DesktopVoicePanelPhase.resolved,
        status: t(loc, 'desktop_voice_resolved'),
      );
      await _tryStartRecord(parsed);
      return;
    }

    if (parsed.confidence == VoiceCommandMatchConfidence.ambiguous) {
      final names = parsed.ambiguousCandidates.join(', ');
      _setPhase(
        _DesktopVoicePanelPhase.ambiguous,
        status: t(loc, 'desktop_voice_ambiguous'),
        error: names.isEmpty
            ? (parsed.ambiguityReason ?? '')
            : names,
      );
      return;
    }

    _setPhase(
      _DesktopVoicePanelPhase.error,
      status: t(loc, 'desktop_voice_no_match'),
      error: parsed.ambiguityReason ?? t(loc, 'desktop_voice_no_match'),
    );
  }

  Future<void> _tryStartRecord(VoiceCommandParseResult parsed) async {
    if (!mounted) return;
    final loc = currentLocale.value;
    _setPhase(
      _DesktopVoicePanelPhase.starting,
      status: t(loc, 'desktop_voice_starting'),
    );
    var ok = false;
    try {
      ok = await widget.onStartRecord(parsed);
    } catch (e) {
      _setPhase(
        _DesktopVoicePanelPhase.error,
        status: t(loc, 'sync_failed_retry'),
        error: e.toString(),
      );
      return;
    }
    if (!mounted) return;
    if (ok) {
      _setPhase(
        _DesktopVoicePanelPhase.done,
        status: t(loc, 'record_synced'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    } else {
      _setPhase(
        _DesktopVoicePanelPhase.error,
        status: t(loc, 'sync_failed_retry'),
        error: t(loc, 'sync_failed_retry'),
      );
    }
  }

  Future<void> _onCancel() async {
    try {
      await _engine.stop();
      await _engine.cancel();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onRetryListen() async {
    _transcript = '';
    _parseResult = null;
    _errorDetail = null;
    await _beginListenSession();
  }

  Color _phaseColor(ColorScheme scheme) {
    switch (_phase) {
      case _DesktopVoicePanelPhase.listening:
      case _DesktopVoicePanelPhase.parsing:
        return scheme.primary;
      case _DesktopVoicePanelPhase.resolved:
      case _DesktopVoicePanelPhase.done:
        return scheme.tertiary;
      case _DesktopVoicePanelPhase.starting:
        return scheme.primary;
      case _DesktopVoicePanelPhase.ambiguous:
        return scheme.error;
      case _DesktopVoicePanelPhase.error:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final parsed = _parseResult;
    final accent = _phaseColor(scheme);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_none_rounded,
                        color: accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t(loc, 'desktop_voice_title'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: t(loc, 'cancel'),
                        onPressed: _onCancel,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_activeListenLocaleId != null && kDebugMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      'STT: $_activeListenLocaleId',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: t(loc, 'desktop_voice_transcript'),
                    value: _transcript.isEmpty ? '—' : _transcript,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: t(loc, 'desktop_voice_category_path'),
                    value: parsed?.matchedCategoryDisplayPath ?? '—',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: t(loc, 'desktop_voice_record_title'),
                    value: parsed?.recordTitle.isNotEmpty == true
                        ? parsed!.recordTitle
                        : '—',
                  ),
                  if (_errorDetail != null &&
                      (_phase == _DesktopVoicePanelPhase.error ||
                          _phase == _DesktopVoicePanelPhase.ambiguous)) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorDetail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: t(loc, 'try_again'),
                          variant: AppButtonVariant.secondary,
                          onPressed: _phase == _DesktopVoicePanelPhase.starting
                              ? null
                              : _onRetryListen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: t(loc, 'cancel'),
                          variant: AppButtonVariant.secondary,
                          onPressed: _phase == _DesktopVoicePanelPhase.starting
                              ? null
                              : _onCancel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Shows the desktop voice panel as a non-dismissible barrier dialog.
Future<void> showDesktopVoiceCommandPanel({
  required BuildContext context,
  required SpeechEngineHandle speechHandle,
  required VoiceCommandCategoryIndex categoryIndex,
  required void Function(void Function(String)?) setSpeechStatusCallback,
  required Future<bool> Function(VoiceCommandParseResult result) onStartRecord,
  Future<void> Function()? onSpeechEngineHardReset,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DesktopVoiceCommandPanel(
      speechHandle: speechHandle,
      categoryIndex: categoryIndex,
      setSpeechStatusCallback: setSpeechStatusCallback,
      onStartRecord: onStartRecord,
      onSpeechEngineHardReset: onSpeechEngineHardReset,
    ),
  );
}
