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

  /// A model can mistakenly request another turn without providing a read.
  /// Correct that once rather than asking the user to retry a safe command.
  static bool hasEmptyReadContinuation({
    required bool needsMoreContext,
    required bool hasActions,
  }) => needsMoreContext && !hasActions;

  /// Voice dictation can contain a trailing explicit cancellation after an
  /// earlier instruction. It must never be sent to the model as a mutation.
  static bool isExplicitCancellation(String input) =>
      RegExp(r'(?:^|[\s,!.?;:])(?:отмена|cancel)'
          r'(?:[\s,!.?;:]+(?:отмена|cancel))*[\s,!.?;:]*$',
          caseSensitive: false).hasMatch(input.trim());

  /// A read-only user question may still require multiple tools (search
  /// documents, then read the exact source). Only direct day listing is a
  /// complete observation without another model turn.
  /// A direct answer about a specific line must be grounded in the
  /// complete document, not search-result snippets. Request the next
  /// bounded observation even when a provider forgot continue:true.
  static bool requiresDocumentRead({
    required String input,
    required List<String> actions,
  }) {
    if (!RegExp(r'строк|строч|line|процитир|цитат|quote|'
        r'содержани|текст\s+стих', caseSensitive: false).hasMatch(input)) {
      return false;
    }
    return actions.any((name) =>
        name == 'search_notes' || name == 'search_record_notes') &&
      !actions.any((name) =>
        name == 'read_note' || name == 'read_record_note');
  }

  static bool isDirectDayListResult({
    required String input,
    required List<String> toolNames,
  }) => isReadOnlyRequest(input) &&
      toolNames.isNotEmpty &&
      toolNames.every((tool) => tool == 'list_day_plans');

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
