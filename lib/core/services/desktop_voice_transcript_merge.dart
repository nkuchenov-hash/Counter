/// Transcript hypothesis merge rules — replace, never concatenate full phrases.
abstract final class DesktopVoiceTranscriptMerge {
  static const String markerFinalReplacesPartial =
      'DESKTOP_VOICE_FINAL_REPLACES_PARTIAL';
  static const String markerNoConcat =
      'DESKTOP_VOICE_NO_FULL_HYPOTHESIS_CONCATENATION';
  static const String markerOverlapDeduped =
      'DESKTOP_VOICE_ROLLING_OVERLAP_DEDUPED';

  /// Final authoritative text replaces any partial hypothesis.
  static String applyFinal({
    required String? partial,
    required String finalText,
  }) {
    final f = finalText.trim();
    if (f.isEmpty) return partial?.trim() ?? '';
    return f;
  }

  /// Rolling partial replaces prior partial (never appends full phrase).
  static String applyPartial({
    required String? previous,
    required String partial,
  }) {
    final p = partial.trim();
    if (p.isEmpty) return previous?.trim() ?? '';
    return p;
  }

  /// Remove duplicate comma-separated segments (case-insensitive).
  static String dedupeCommaSegments(String text) {
    final raw = text.trim();
    if (!raw.contains(',')) return raw;
    final seen = <String>{};
    final out = <String>[];
    for (final part in raw.split(',')) {
      var seg = part.trim().replaceAll(RegExp(r'[.!?]+$'), '').trim();
      seg = seg
          .replaceFirst(RegExp(r'^and\s+', caseSensitive: false), '')
          .trim();
      if (seg.isEmpty) continue;
      final key = seg.toLowerCase();
      if (seen.add(key)) {
        out.add(seg);
      }
    }
    return out.join(', ');
  }

  /// Detect repeated full suffix like "DEL MOD Submit" appearing twice.
  static bool hasRepeatedCommandSuffix(String text, {int minLen = 8}) {
    if (_hasDuplicateDelModSubmit(text)) return true;
    final norm = text.trim().toLowerCase();
    if (norm.length < minLen * 2) return false;
    for (var len = minLen; len <= norm.length ~/ 2; len++) {
      final suffix = norm.substring(norm.length - len);
      final before = norm.substring(0, norm.length - len).trim();
      if (before.endsWith(suffix)) return true;
    }
    return false;
  }

  static bool _hasDuplicateDelModSubmit(String text) {
    final re = RegExp(
      r'del\s*mod\s*,?\s*submit',
      caseSensitive: false,
    );
    return re.allMatches(text).length > 1;
  }
}
