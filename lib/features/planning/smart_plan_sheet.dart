// Smart Plan: NL paragraph → AI schedule. Mic uses same package as shell, minimal STT wiring.

import 'dart:async';

import 'package:counter/core/services/ai_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void dispose() {
    unawaited(_speech.stop());
    unawaited(_speech.cancel());
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final loc = currentLocale.value;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(loc, 'microphone_permission'))),
          );
          return;
        }
      }
    }

    try {
      final available = await _speech.initialize(
        onError: (e) {
          if (kDebugMode) {
            debugPrint('[SmartPlan STT] ${e.errorMsg}');
          }
        },
      );
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'speech_unavailable'))),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(loc, 'speech_error_prefix').replaceFirst('%s', '$e'),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _listening = true);

    final localeId =
        loc == 'ru' ? 'ru_RU' : 'en_US';

    try {
      await _speech.listen(
        onResult: (res) {
          if (mounted && res.recognizedWords.isNotEmpty) {
            setState(() => _textController.text = res.recognizedWords);
          }
        },
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'speech_error_prefix').replaceFirst('%s', '$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _generate() async {
    final loc = currentLocale.value;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _thinking = true);
    List<Map<String, dynamic>> items;
    try {
      items = await AiService.instance.processPlanningText(text);
    } on AiServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
            ),
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _thinking = false);
    }

    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'smart_plan_empty'))),
      );
      return;
    }

    int created;
    try {
      created = await widget.onCommit(items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'smart_plan_failed_detail').replaceFirst('%s', '$e'),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (created <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(t(loc, 'smart_plan_empty'))),
      );
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
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
            TextField(
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
                suffixIcon: IconButton(
                  tooltip: _listening ? t(loc, 'stop') : t(loc, 'voice_input'),
                  icon: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _listening ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  onPressed: _thinking ? null : _toggleMic,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
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
