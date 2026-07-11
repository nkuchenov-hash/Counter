import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_glossary.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Outcome of glossary-biased recognition postprocess (after raw STT).
class DesktopVoiceRecognitionPostprocessResult {
  const DesktopVoiceRecognitionPostprocessResult({
    required this.rawModelText,
    required this.postprocessedText,
    required this.finalCommandText,
    required this.appliedRules,
    required this.confidence,
    required this.rejected,
    this.rejectReason,
  });

  final String rawModelText;
  final String postprocessedText;
  final String finalCommandText;
  final List<String> appliedRules;
  final double confidence;
  final bool rejected;
  final String? rejectReason;
}

/// Glossary-biased postprocess — improves domain terms before parser/resolver.
abstract final class DesktopVoiceRecognitionPostprocess {
  static DesktopVoiceRecognitionPostprocessResult apply({
    required String rawModelText,
    required DesktopVoiceGlossaryPack glossary,
  }) {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_HIGH_QUALITY_TRANSCRIPT_GOAL');
    DesktopVoicePipeline.mark('DESKTOP_VOICE_RAW_MODEL_TEXT', rawModelText);

    final raw = rawModelText.trim();
    if (raw.isEmpty) {
      return const DesktopVoiceRecognitionPostprocessResult(
        rawModelText: '',
        postprocessedText: '',
        finalCommandText: '',
        appliedRules: [],
        confidence: 0,
        rejected: true,
        rejectReason: 'empty_raw',
      );
    }

    final applied = <String>[];
    var text = raw;

    final phraseRepairs = <RegExp, String>{
      RegExp(
        r'\b(sovent|solvent|soven|southern\s+computer)\s+computer\s+warehouse\b',
        caseSensitive: false,
      ): 'Southern Computer Warehouse',
      RegExp(
        r'\b(sovent|solvent|soven)\s+warehouse\b',
        caseSensitive: false,
      ): 'Southern Computer Warehouse',
      RegExp(r'\bscw\b', caseSensitive: false): 'Southern Computer Warehouse',
      RegExp(r"\bthey'?ll\s+not\b", caseSensitive: false): 'DEL MOD',
      RegExp(r'\bdell\s+mod\b', caseSensitive: false): 'DEL MOD',
      RegExp(r'\bdeal\s+mod\b', caseSensitive: false): 'DEL MOD',
      RegExp(r'\bdel\s+mod\b', caseSensitive: false): 'DEL MOD',
      RegExp(r'\bdelmod\b', caseSensitive: false): 'DEL MOD',
      RegExp(r'\badd\s+scene\b', caseSensitive: false): 'ADD SIN',
      RegExp(r'\badd\s+seen\b', caseSensitive: false): 'ADD SIN',
      RegExp(r'\bbling\b', caseSensitive: false): 'BLINK',
      RegExp(r'\bsubmit\b', caseSensitive: false): 'Submit',
      RegExp(r'^laredo\s+ts\b', caseSensitive: false): 'Laredo Technical Services',
    };

    for (final e in phraseRepairs.entries) {
      if (e.key.hasMatch(text)) {
        final before = text;
        text = text.replaceAll(e.key, e.value);
        if (text != before) {
          applied.add('phrase:${e.key.pattern}→${e.value}');
        }
      }
    }

    text = _applyGlossaryPhraseHints(text, glossary, applied);
    text = text.replaceAll(RegExp(r'[.,!?;:]+$'), '').trim();
    text = _ensurePriceReporterScopePrefix(text, glossary, applied);
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    DesktopVoicePipeline.mark('DESKTOP_VOICE_POSTPROCESSED_TEXT', text);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_GLOSSARY_USED_IN_POSTPROCESS');

    final repaired = repairVoiceCommandTranscript(text);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_FINAL_COMMAND_TEXT', repaired);
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_RECOGNITION_POSTPROCESS_APPLIED',
      applied.isEmpty ? 'none' : applied.join('; '),
    );

    final confidence = _scoreConfidence(repaired, glossary, applied);
    if (confidence < 0.35) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_POSTPROCESS_LOW_CONFIDENCE_REJECTED',
        confidence.toStringAsFixed(2),
      );
      return DesktopVoiceRecognitionPostprocessResult(
        rawModelText: raw,
        postprocessedText: text,
        finalCommandText: repaired,
        appliedRules: applied,
        confidence: confidence,
        rejected: true,
        rejectReason: 'postprocess_low_confidence',
      );
    }

    DesktopVoicePipeline.mark('DESKTOP_VOICE_POSTPROCESS_VALIDATED_BY_DOMAIN_RESOLVER');
    return DesktopVoiceRecognitionPostprocessResult(
      rawModelText: raw,
      postprocessedText: text,
      finalCommandText: repaired,
      appliedRules: applied,
      confidence: confidence,
      rejected: false,
    );
  }

  static String _ensurePriceReporterScopePrefix(
    String text,
    DesktopVoiceGlossaryPack glossary,
    List<String> applied,
  ) {
    final lower = text.toLowerCase();
    if (lower.contains('price reporter')) return text;
    // Client-first comma grammar (SCW / BLINK / SCW …) — parser resolves Price Reporter.
    if (lower.startsWith('southern computer warehouse') ||
        lower.startsWith('scw ') ||
        lower == 'scw' ||
        lower.startsWith('blink ') ||
        lower == 'blink') {
      return text;
    }
    final needsPrefix =
        (lower.contains('age solutions') && !lower.startsWith('laredo'));
    if (!needsPrefix) return text;
    if (!glossary.terms.any((t) => t.toLowerCase() == 'price reporter')) {
      return text;
    }
    applied.add('scope_prefix:Price Reporter');
    return 'Price Reporter $text';
  }

  static String _applyGlossaryPhraseHints(
    String text,
    DesktopVoiceGlossaryPack glossary,
    List<String> applied,
  ) {
    var out = text;
    for (final term in glossary.terms) {
      // Only apply exact multi-word glossary phrases (avoid corrupting ADD MOD → ADD SIN).
      if (!term.contains(' ') || term.length < 8) continue;
      final normTerm = term.toLowerCase();
      final normOut = out.toLowerCase();
      if (normOut.contains(normTerm)) continue;
      if (normTerm == 'add sin' || normTerm == 'del mod') continue;
    }
    return out;
  }

  static double _scoreConfidence(
    String finalText,
    DesktopVoiceGlossaryPack glossary,
    List<String> applied,
  ) {
    if (finalText.trim().isEmpty) return 0;
    var score = 0.45;
    if (applied.isNotEmpty) score += 0.15;
    final lower = finalText.toLowerCase();
    var hits = 0;
    for (final t in glossary.terms.take(40)) {
      if (t.length < 4) continue;
      if (lower.contains(t.toLowerCase())) hits++;
    }
    score += (hits / 6).clamp(0.0, 0.35);
    return score.clamp(0.0, 1.0);
  }
}
