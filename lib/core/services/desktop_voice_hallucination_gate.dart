import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';
import 'package:counter/core/services/desktop_voice_transcript_merge.dart';
import 'package:counter/data/category_fuzzy_match.dart';
import 'package:counter/data/models.dart';
import 'package:counter/data/voice_command_parser.dart';

/// Blocks duplicated, conflicting, or non-derivable voice command text.
class DesktopVoiceHallucinationResult {
  const DesktopVoiceHallucinationResult.clean({
    required this.canonicalTranscript,
  }) : detected = false,
       reason = null,
       duplicateTokens = const [],
       conflictingClientNames = const [],
       unsourcedTokens = const [];

  const DesktopVoiceHallucinationResult.blocked({
    required this.reason,
    required this.canonicalTranscript,
    this.duplicateTokens = const [],
    this.conflictingClientNames = const [],
    this.unsourcedTokens = const [],
  }) : detected = true;

  final bool detected;
  final String? reason;
  final String canonicalTranscript;
  final List<String> duplicateTokens;
  final List<String> conflictingClientNames;
  final List<String> unsourcedTokens;

  bool get writeBlocked => detected;
  bool get hallucinationGateTriggered => detected;
  bool get duplicateSegmentGateTriggered =>
      duplicateTokens.isNotEmpty || reason?.contains('duplicate') == true;
}

abstract final class DesktopVoiceHallucinationGate {
  static const markerHallucinatedBlocked =
      'DESKTOP_VOICE_HALLUCINATED_TEXT_BLOCKED';
  static const markerDuplicateTitleBlocked =
      'DESKTOP_VOICE_DUPLICATE_TITLE_SEGMENT_BLOCKED';
  static const markerConflictingClientBlocked =
      'DESKTOP_VOICE_CONFLICTING_CLIENT_COMMAND_BLOCKED';
  static const markerCorruptedNotWritten =
      'DESKTOP_VOICE_CORRUPTED_TITLE_NOT_WRITTEN';
  static const markerNoGarbageRecord = 'DESKTOP_VOICE_NO_GARBAGE_RECORD';

  static const Set<String> _allowedRepeatTokens = {
    'and',
    'the',
    'a',
    'an',
    'or',
  };

  static DesktopVoiceHallucinationResult evaluate({
    required String transcript,
    required List<CategoryRule> categoryRules,
    VoiceCommandParseResult? parsed,
  }) {
    final canonical = DesktopVoiceTranscriptMerge.dedupeCommaSegments(
      transcript.trim(),
    );
    final lower = canonical.toLowerCase();

    final duplicateSegments = _duplicateCommaSegments(canonical);
    final duplicateTokens = _duplicateContentTokens(canonical);
    final allDups = <String>{
      ...duplicateSegments,
      ...duplicateTokens,
    }.toList(growable: false);

    final conflicting = _conflictingScopeMentions(canonical, categoryRules);

    if (allDups.isNotEmpty) {
      return _blocked(
        reason: 'duplicate_segments:${allDups.join('|')}',
        canonical: canonical,
        duplicateTokens: allDups,
        conflicting: conflicting,
      );
    }

    if (conflicting.length > 1) {
      return _blocked(
        reason: 'conflicting_client_names:${conflicting.join('|')}',
        canonical: canonical,
        conflicting: conflicting,
      );
    }

    if (parsed != null &&
        parsed.confidence == VoiceCommandMatchConfidence.exact &&
        !_titleDerivableFromTranscript(
          transcript: canonical,
          title: parsed.recordTitle,
          path: parsed.matchedCategoryDisplayPath,
        )) {
      return _blocked(
        reason: 'title_not_derivable:${parsed.recordTitle}',
        canonical: canonical,
        conflicting: conflicting,
      );
    }

    // Live 34f2a43 corruption signature.
    if (lower.contains('logical marketing') &&
        lower.contains('technical marketing')) {
      return _blocked(
        reason: 'conflicting_marketing_scopes',
        canonical: canonical,
        conflicting: const ['Logical Marketing', 'Technical Marketing'],
      );
    }

    if (lower.contains('taxis') &&
        RegExp(r'\btaxis\b').allMatches(lower).length > 1) {
      return _blocked(
        reason: 'duplicate_token:taxis',
        canonical: canonical,
        duplicateTokens: const ['taxis'],
      );
    }

    return DesktopVoiceHallucinationResult.clean(
      canonicalTranscript: canonical,
    );
  }

  static List<String> _duplicateCommaSegments(String text) {
    final seen = <String>{};
    final dups = <String>[];
    for (final raw in splitVoiceCommandSegments(text)) {
      final seg = _normalizeSegment(raw);
      if (seg.isEmpty) continue;
      final key = seg.toLowerCase();
      if (!seen.add(key)) {
        dups.add(seg);
      }
    }
    return dups;
  }

  static String _normalizeSegment(String seg) {
    return seg
        .trim()
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .replaceFirst(RegExp(r'^and\s+', caseSensitive: false), '')
        .trim();
  }

  static List<String> _duplicateContentTokens(String text) {
    final norm = normalizeCategoryLabel(text);
    final tokens = norm.split(RegExp(r'\s+')).where((t) => t.length > 3);
    final counts = <String, int>{};
    for (final t in tokens) {
      if (_allowedRepeatTokens.contains(t)) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList(growable: false);
  }

  static List<String> _conflictingScopeMentions(
    String transcript,
    List<CategoryRule> rules,
  ) {
    final lower = transcript.toLowerCase();
    final hits = <String>[];

    void walk(CategoryRule rule, List<String> path) {
      if (rule.isArchived) return;
      final pb = (rule.backendRowId ?? '').trim();
      final name = rule.name.trim();
      final normName = normalizeCategoryLabel(name);
      if (pb.isNotEmpty && normName.length >= 4) {
        if (lower.contains(name.toLowerCase()) ||
            lower.contains(normName)) {
          hits.add(name);
        }
      }
      for (final c in rule.children ?? const <CategoryRule>[]) {
        walk(c, [...path, name]);
      }
    }

    for (final r in rules) {
      walk(r, const []);
    }

    // Distinct top-level / scope roots only.
    final roots = <String>{};
    for (final h in hits) {
      final root = h.split('>').first.trim();
      if (root.isNotEmpty) roots.add(root);
    }
    // When both Logical Marketing and Technical Marketing appear as scopes.
    final distinct = hits.toSet().toList();
    if (distinct.contains('Logical Marketing') &&
        distinct.any((n) => n.toLowerCase().contains('technical marketing'))) {
      return distinct
          .where(
            (n) =>
                n.toLowerCase().contains('marketing') ||
                n.toLowerCase().contains('logical') ||
                n.toLowerCase().contains('technical'),
          )
          .toList();
    }
    return distinct.length > 2 ? distinct : [];
  }

  static bool _titleDerivableFromTranscript({
    required String transcript,
    required String title,
    required String? path,
  }) {
    final titleNorm = normalizeCategoryLabel(title);
    if (titleNorm.isEmpty) return false;
    var remainder = normalizeCategoryLabel(transcript);
    if (path != null && path.trim().isNotEmpty) {
      for (final part in path.split('>')) {
        final p = normalizeCategoryLabel(part.trim());
        if (p.isNotEmpty) {
          remainder = remainder.replaceFirst(p, '').trim();
        }
      }
    }
    if (remainder.contains(titleNorm)) return true;
    final segments = splitVoiceCommandSegments(transcript)
        .map(_normalizeSegment)
        .map(normalizeCategoryLabel)
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isNotEmpty &&
        segments.last == titleNorm) {
      return true;
    }
    // Single-title commands: last token group after scope strip.
    if (remainder.endsWith(titleNorm)) return true;
    return false;
  }

  static DesktopVoiceHallucinationResult _blocked({
    required String reason,
    required String canonical,
    List<String> duplicateTokens = const [],
    List<String> conflicting = const [],
    List<String> unsourced = const [],
  }) {
    DesktopVoicePipeline.mark(markerHallucinatedBlocked, reason);
    if (duplicateTokens.isNotEmpty) {
      DesktopVoicePipeline.mark(
        markerDuplicateTitleBlocked,
        duplicateTokens.join('|'),
      );
      DesktopVoicePipeline.mark('duplicate_segment_gate_triggered', 'yes');
      DesktopVoicePipeline.mark('duplicate_tokens', duplicateTokens.join('|'));
    }
    if (conflicting.isNotEmpty) {
      DesktopVoicePipeline.mark(
        markerConflictingClientBlocked,
        conflicting.join('|'),
      );
      DesktopVoicePipeline.mark(
        'conflicting_client_names',
        conflicting.join('|'),
      );
    }
    DesktopVoicePipeline.mark(markerCorruptedNotWritten);
    DesktopVoicePipeline.mark(markerNoGarbageRecord);
    DesktopVoicePipeline.mark('hallucination_gate_triggered', 'yes');
    DesktopVoicePipeline.mark('write_blocked', 'yes');
    DesktopVoicePipeline.mark('write_block_reason', reason);
    DesktopVoicePipeline.mark('canonical_transcript', canonical);
  return DesktopVoiceHallucinationResult.blocked(
      reason: reason,
      canonicalTranscript: canonical,
      duplicateTokens: duplicateTokens,
      conflictingClientNames: conflicting,
      unsourcedTokens: unsourced,
    );
  }
}
