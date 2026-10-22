/// Provider-independent presentation of read-tool observations.
/// Models may request the same read repeatedly; an already validated
/// observation is a useful result, not an error or an instruction to mutate.
class ViktorReadAnswer {
  const ViktorReadAnswer._();

  /// A provider's continue flag is advisory, not a command to reject a
  /// valid write. After a read, a mutation proposal is a FINAL proposal and
  /// still goes through the usual Brain preview, confirmation and fresh write.
  /// Only a read-only proposal can request another observation.
  static bool shouldContinueReading({
    required bool needsMoreContext,
    required bool hasActions,
    required bool hasMutations,
  }) => needsMoreContext && hasActions && !hasMutations;

  static bool isReadOnlyRequest(String input) {
    final text = input.toLowerCase().trim();
    final startsWithRead = RegExp(
      r'^(?:покажи|покажите|найди|найдите|расскажи|какие|какой|что у меня|'
      r'выведи|перечисли|show|find|list|display|what are|what is)(?:\s|$)',
      unicode: true,
    ).hasMatch(text);
    if (!startsWithRead) return false;
    // Compound requests like "show and move" still require the model's
    // normal multi-step read -> preview -> write workflow.
    return !RegExp(
      r'(?:\b(?:and|then)\s+(?:create|add|move|delete|edit|change|'
      r'reschedule|update|rename|remove|start|stop)\b|'
      r'(?:^|\s)и\s+(?:добав|созда|перенес|перемест|удал|измен|'
      r'переимен|сдвин|запуст|останов))',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static String format(String originalRequest, String observation) {
    final lines = observation.trim().split('\n');
    if (lines.length <= 1) return observation.trim();
    final request = _normalize(originalRequest);
    final matched = <String>[];
    for (final line in lines) {
      // list_day_plans result: yyyy-MM-dd HH:mm  title.
      final match = RegExp(r'^\d{4}-\d\d-\d\d\s+\S+\s{2,}(.+)$')
          .firstMatch(line);
      if (match == null) continue;
      final title = _normalize(match.group(1)!);
      if (title.length >= 8 && request.contains(title)) matched.add(line);
    }
    return matched.isEmpty ? observation.trim() : matched.join('\n');
  }

  static String _normalize(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9а-яё]+', caseSensitive: false), ' ')
      .trim().replaceAll(RegExp(r'\s+'), ' ');
}
