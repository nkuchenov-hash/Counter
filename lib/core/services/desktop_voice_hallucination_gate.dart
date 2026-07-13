import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Blocks duplicated, hallucinated, or conflicting transcript fragments.
class DesktopVoiceHallucinationGateResult {
  const DesktopVoiceHallucinationGateResult.clean({
    required this.canonicalTranscript,
  }) : detected = false,
       reason = null,
       duplicateTokens = const [],
       conflictingClients = const [],
       unsourcedTokens = const [];

  const DesktopVoiceHallucinationGateResult.blocked({
    required this.reason,
    required this.canonicalTranscript,
    this.duplicateTokens = const [],
    this.conflictingClients = const [],
    this.unsourcedTokens = const [],
  }) : detected = true;

  final bool detected;
  final String? reason;
  final String canonicalTranscript;
  final List<String> duplicateTokens;
  final List<String> conflictingClients;
  final List<String> unsourcedTokens;

  bool get writeBlocked => detected;
}

abstract final class DesktopVoiceHallucinationGate {
  static const markerHallucinationBlocked =
      'DESKTOP_VOICE_HALLUCINATED_TEXT_BLOCKED';
  static const markerDuplicateTitle =
      'DESKTOP_VOICE_DUPLICATE_TITLE_SEGMENT_BLOCKED';
  static const markerConflictingClient =
      'DESKTOP_VOICE_CONFLICTING_CLIENT_COMMAND_BLOCKED';
  static const markerNotWritten = 'DESKTOP_VOICE_CORRUPTED_TITLE_NOT_WRITTEN';
  static const markerNoGarbage = 'DESKTOP_VOICE_NO_GARBAGE_RECORD';

  /// Neutral whisper prompt — no business client/category names.
  static const neutralWhisperInitialPrompt =
      'English. Short voice task command. Comma-separated scope and action.';

  static DesktopVoiceHallucinationGateResult evaluate({
    required String transcript,
    required List<CategoryRule> categoryRules,
    VoiceCommandParseResult? parsed,
  }) {
    final canonical = DesktopVoiceTranscriptMerge.dedupeCommaSegments(
      transcript.trim(),
    );
    final lower = canonical.toLowerCase();

    final duplicateTokens = findDuplicateSignificantTokens(canonical);
    if (duplicateTokens.isNotEmpty) {
      return _blocked(
        reason: 'duplicate_token:${duplicateTokens.join('|')}',
        canonical: canonical,
        duplicateTokens: duplicateTokens,
      );
    }

    final conflicting = _detectConflictingCategoryNames(
      lower,
      categoryRules,
    );
    if (conflicting.length > 1) {
      return _blocked(
        reason: 'conflicting_client_names:${conflicting.join('|')}',
        canonical: canonical,
        conflictingClients: conflicting,
      );
    }

    if (_hasExcessCommaSegments(canonical)) {
      return _blocked(
        reason: 'excess_comma_segments',
        canonical: canonical,
      );
    }

    if (_logicalAndTechnicalMarketingConflict(lower)) {
      return _blocked(
        reason: 'logical_technical_marketing_conflict',
        canonical: canonical,
        conflictingClients: const ['Logical Marketing', 'Technical Marketing'],
      );
    }

    if (parsed != null && parsed.isSafeToStart) {
      final titleIssue = _titleDerivabilityIssue(
        canonical: canonical,
        parsed: parsed,
      );
      if (titleIssue != null) {
        return _blocked(
          reason: titleIssue,
          canonical: canonical,
        );
      }
    }

    return DesktopVoiceHallucinationGateResult.clean(
      canonicalTranscript: canonical,
    );
  }

  static List<String> findDuplicateSignificantTokens(String text) {
    final lower = text.toLowerCase();
    final tokens = RegExp(r"[a-z']{4,}")
        .allMatches(lower)
        .map((m) => m.group(0)!)
        .where((t) => !_stopWords.contains(t))
        .toList();
    final counts = <String, int>{};
    for (final t in tokens) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList(growable: false);
  }

  static bool _hasExcessCommaSegments(String text) {
    if (!text.contains(',')) return false;
    final segments = splitVoiceCommandSegments(text);
    return segments.length > 3;
  }

  static bool _logicalAndTechnicalMarketingConflict(String lower) {
    final hasLogical = lower.contains('logical marketing');
    final hasTechnical = lower.contains('technical marketing');
    return hasLogical && hasTechnical;
  }

  static List<String> _detectConflictingCategoryNames(
    String lower,
    List<CategoryRule> categoryRules,
  ) {
    final hits = <String>{};
    void walk(CategoryRule rule, List<String> parts) {
      if (rule.isArchived) return;
      final name = rule.name.trim();
      if (name.length >= 4) {
        final norm = normalizeCategoryLabel(name).toLowerCase();
        if (norm.length >= 4 && lower.contains(norm)) {
          hits.add([...parts, name].join(' > '));
        }
        for (final kw in rule.keywords?['en'] ?? const <String>[]) {
          final kn = kw.trim().toLowerCase();
          if (kn.length >= 4 && lower.contains(kn)) {
            hits.add([...parts, name].join(' > '));
          }
        }
      }
      for (final c in rule.children ?? const <CategoryRule>[]) {
        walk(c, [...parts, name]);
      }
    }
    for (final r in categoryRules) {
      walk(r, const []);
    }
    if (hits.length <= 1) return [];
    // Allow parent path + leaf when one contains the other.
    final sorted = hits.toList()..sort((a, b) => a.length.compareTo(b.length));
    final unrelated = <String>[];
    for (var i = 0; i < sorted.length; i++) {
      var dominated = false;
      for (var j = 0; j < sorted.length; j++) {
        if (i == j) continue;
        if (sorted[j].toLowerCase().contains(sorted[i].toLowerCase()) &&
            sorted[j].length > sorted[i].length) {
          dominated = true;
          break;
        }
      }
      if (!dominated) unrelated.add(sorted[i]);
    }
    return unrelated.length > 1 ? unrelated : [];
  }

  static String? _titleDerivabilityIssue({
    required String canonical,
    required VoiceCommandParseResult parsed,
  }) {
    final title = parsed.recordTitle.trim();
    if (title.isEmpty) return null;
    final titleLower = title.toLowerCase();
    if (findDuplicateSignificantTokens(title).isNotEmpty) {
      return 'duplicate_title_token';
    }
    if (titleLower.contains(' and ') && title.split(' and ').length > 2) {
      return 'compound_hallucinated_title';
    }
    final path = (parsed.matchedCategoryDisplayPath ?? '').toLowerCase();
    if (path.isNotEmpty && titleLower.contains(path)) {
      return 'title_contains_path_crumbs';
    }
    final segments = splitVoiceCommandSegments(canonical);
    if (segments.length >= 2) {
      final expectedTitle = segments.last.trim().toLowerCase();
      if (expectedTitle.isNotEmpty &&
          !titleLower.contains(expectedTitle) &&
          findDuplicateSignificantTokens(canonical).isNotEmpty) {
        return 'title_not_from_canonical_tail';
      }
    }
    return null;
  }

  static DesktopVoiceHallucinationGateResult _blocked({
    required String reason,
    required String canonical,
    List<String> duplicateTokens = const [],
    List<String> conflictingClients = const [],
    List<String> unsourcedTokens = const [],
  }) {
    DesktopVoicePipeline.mark('hallucination_gate_triggered', 'yes');
    DesktopVoicePipeline.mark('write_blocked', 'yes');
    DesktopVoicePipeline.mark('write_block_reason', reason);
    DesktopVoicePipeline.mark('canonical_transcript', canonical);
    if (duplicateTokens.isNotEmpty) {
      DesktopVoicePipeline.mark('duplicate_segment_gate_triggered', 'yes');
      DesktopVoicePipeline.mark('duplicate_tokens', duplicateTokens.join('|'));
      DesktopVoicePipeline.mark(markerDuplicateTitle, duplicateTokens.join('|'));
    }
    if (conflictingClients.isNotEmpty) {
      DesktopVoicePipeline.mark(
        'conflicting_client_names',
        conflictingClients.join('|'),
      );
      DesktopVoicePipeline.mark(
        markerConflictingClient,
        conflictingClients.join('|'),
      );
    }
    DesktopVoicePipeline.mark(markerHallucinationBlocked, reason);
    DesktopVoicePipeline.mark(markerNotWritten);
    DesktopVoicePipeline.mark(markerNoGarbage);
    return DesktopVoiceHallucinationGateResult.blocked(
      reason: reason,
      canonicalTranscript: canonical,
      duplicateTokens: duplicateTokens,
      conflictingClients: conflictingClients,
      unsourcedTokens: unsourcedTokens,
    );
  }

  static const Set<String> _stopWords = {
    'and',
    'the',
    'for',
    'with',
    'from',
    'that',
    'this',
    'your',
  };
}
