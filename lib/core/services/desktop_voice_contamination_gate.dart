import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_hallucination_gate.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Result of pre-confirm / pre-write contamination validation.
class DesktopVoiceContaminationResult {
  const DesktopVoiceContaminationResult.clean({
    required this.canonicalTranscript,
  }) : detected = false,
       reason = null,
       detectedClientLeaves = const [],
       repeatedSegments = const [],
       sourceSessionIds = const [];

  const DesktopVoiceContaminationResult.blocked({
    required this.reason,
    required this.canonicalTranscript,
    this.detectedClientLeaves = const [],
    this.repeatedSegments = const [],
    this.sourceSessionIds = const [],
  }) : detected = true;

  final bool detected;
  final String? reason;
  final String canonicalTranscript;
  final List<String> detectedClientLeaves;
  final List<String> repeatedSegments;
  final List<String> sourceSessionIds;

  bool get writeBlocked => detected;
}

/// Blocks multi-client / stale-fragment / duplicate-segment commands.
abstract final class DesktopVoiceContaminationGate {
  static const markerGate = 'DESKTOP_VOICE_CONTAMINATION_GATE';
  static const markerMultipleClient =
      'DESKTOP_VOICE_MULTIPLE_CLIENT_COMMAND_BLOCKED';
  static const markerDuplicateSegment =
      'DESKTOP_VOICE_DUPLICATE_COMMAND_SEGMENT_BLOCKED';
  static const markerNotWritten =
      'DESKTOP_VOICE_CONTAMINATED_TITLE_NOT_WRITTEN';

  /// Known stale fragments from contaminated live failure (67ea8eb).
  static const Set<String> forbiddenStaleFragments = {
    'blink',
    'laredo technical services',
    'laredo ts',
    'selvent',
    'sal intervened for liam',
  };

  static DesktopVoiceContaminationResult evaluate({
    required String transcript,
    required List<CategoryRule> categoryRules,
    String? expectedClientLeafHint,
    Set<String> forbiddenFragments = forbiddenStaleFragments,
    VoiceCommandParseResult? parsed,
  }) {
    final canonical = DesktopVoiceTranscriptMerge.dedupeCommaSegments(
      transcript.trim(),
    );

    final hallucination = DesktopVoiceHallucinationGate.evaluate(
      transcript: canonical,
      categoryRules: categoryRules,
      parsed: parsed,
    );
    if (hallucination.detected) {
      return _blocked(
        reason: hallucination.reason ?? 'hallucination',
        canonical: hallucination.canonicalTranscript,
        clients: hallucination.conflictingClients,
        repeated: hallucination.duplicateTokens,
      );
    }

    final lower = canonical.toLowerCase();
    final staleHits = <String>[];
    for (final frag in forbiddenFragments) {
      if (lower.contains(frag)) {
        staleHits.add(frag);
      }
    }

    final clientLeaves = _detectMultipleClientLeaves(
      canonical,
      categoryRules,
    );

    final repeated = <String>[];
    if (DesktopVoiceTranscriptMerge.hasRepeatedCommandSuffix(canonical)) {
      repeated.add('duplicate_suffix');
    }
    if (_hasDuplicateDelModSubmit(canonical)) {
      repeated.add('del_mod_submit_x2');
    }

    if (staleHits.isNotEmpty) {
      return _blocked(
        reason: 'stale_fragment:${staleHits.join('|')}',
        canonical: canonical,
        clients: clientLeaves,
        repeated: repeated,
      );
    }
    if (clientLeaves.length > 1) {
      return _blocked(
        reason: 'multiple_client_leaves',
        canonical: canonical,
        clients: clientLeaves,
        repeated: repeated,
      );
    }
    if (repeated.isNotEmpty) {
      return _blocked(
        reason: 'duplicate_segments',
        canonical: canonical,
        clients: clientLeaves,
        repeated: repeated,
      );
    }

    return DesktopVoiceContaminationResult.clean(
      canonicalTranscript: canonical,
    );
  }

  static bool isUsefulCandidate({
    required String transcript,
    required List<CategoryRule> categoryRules,
    required VoiceCommandParseResult parsed,
  }) {
    if (!parsed.isSafeToStart ||
        parsed.confidence != VoiceCommandMatchConfidence.exact) {
      return false;
    }
    final gate = evaluate(
      transcript: transcript,
      categoryRules: categoryRules,
      parsed: parsed,
    );
    if (gate.detected) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_CONTAMINATED_PARTIAL_NOT_COUNTED',
        gate.reason ?? 'contaminated',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_NO_FAKE_LATENCY_PASS');
      return false;
    }
    return true;
  }

  static List<String> _detectMultipleClientLeaves(
    String transcript,
    List<CategoryRule> categoryRules,
  ) {
    final lower = transcript.toLowerCase();
    final clientHits = <String>{};

    CategoryRule? priceReporter;
    void findPr(CategoryRule rule) {
      if (rule.name.toLowerCase().contains('price reporter')) {
        priceReporter = rule;
        return;
      }
      for (final c in rule.children ?? const <CategoryRule>[]) {
        findPr(c);
      }
    }
    for (final r in categoryRules) {
      findPr(r);
    }
    final pr = priceReporter;
    if (pr != null) {
      for (final client in pr.children ?? const <CategoryRule>[]) {
        if (_ruleMentionedInText(lower, client)) {
          clientHits.add(client.name);
        }
      }
    }

    // Heuristic multi-client markers when tree walk under-detects.
    if (lower.contains('laredo') &&
        (lower.contains('blink') || lower.contains('southern'))) {
      clientHits.add('laredo+cross_client');
    }
    if (lower.contains('blink') &&
        (lower.contains('southern') || lower.contains('warehouse')) &&
        !lower.contains('southern computer warehouse del mod')) {
      clientHits.add('blink+warehouse');
    }
    return clientHits.length > 1 ? clientHits.toList() : [];
  }

  static bool _ruleMentionedInText(String lower, CategoryRule rule) {
    final phrases = <String>[
      rule.name,
      ...(rule.keywords?['en'] ?? const <String>[]),
    ];
    for (final p in phrases) {
      final norm = normalizeCategoryLabel(p);
      if (norm.length < 4) continue;
      if (lower.contains(norm) || lower.contains(p.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static bool _hasDuplicateDelModSubmit(String text) {
    final re = RegExp(
      r'del\s*mod\s*,?\s*submit',
      caseSensitive: false,
    );
    final matches = re.allMatches(text);
    return matches.length > 1;
  }

  static DesktopVoiceContaminationResult _blocked({
    required String reason,
    required String canonical,
    required List<String> clients,
    required List<String> repeated,
  }) {
    DesktopVoicePipeline.mark(markerGate, reason);
    if (clients.length > 1) {
      DesktopVoicePipeline.mark(markerMultipleClient, clients.join('|'));
    }
    if (repeated.isNotEmpty) {
      DesktopVoicePipeline.mark(markerDuplicateSegment, repeated.join('|'));
    }
    DesktopVoicePipeline.mark(markerNotWritten);
    DesktopVoicePipeline.mark('contamination_detected', 'yes');
    DesktopVoicePipeline.mark('contamination_reason', reason);
    DesktopVoicePipeline.mark('canonical_transcript', canonical);
    return DesktopVoiceContaminationResult.blocked(
      reason: reason,
      canonicalTranscript: canonical,
      detectedClientLeaves: clients,
      repeatedSegments: repeated,
    );
  }
}
