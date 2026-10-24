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

  /// A promise to do work is NOT a completed user-facing schedule.
  /// Retry it as an incomplete provider answer, not as another user request.
  static bool isUnfinishedScheduleReply(String message) {
    final value = message.trim().toLowerCase();
    if (value.isEmpty) return true;
    // A real itinerary can contain preparatory prose, but also has times.
    if (RegExp(r'\b\d{1,2}:\d{2}').allMatches(value).length >= 2) {
      return false;
    }
    return RegExp(
      r'^(?:сейчас\s+(?:провер|преобраз|пересчита|исправ|свер|'
      r'посмотр|состав|подготов|планир|обнов)|'
      r'сначала\s+(?:провер|свер|посмотр)|'
      r'проверяю|сверяю|начинаю\s+провер|'
      r'checking|i(?:\s+will|[\u2019\u0027]ll)\s+(?:check|review|prepare))',
      caseSensitive: false,
    ).hasMatch(value);
  }

  /// The server may lose an earlier draft after a series of nonanswers.
  /// Recover only an actual ASSISTANT itinerary with multiple timed rows.
  /// User-provided text must never be taken as an assistant draft.
  static String? lastTimedDraft(Iterable<Map<String, String>> turns) {
    for (final turn in turns.toList().reversed) {
      if (turn['role'] != 'assistant') continue;
      final text = (turn['content'] ?? '').trim();
      if (RegExp(r'\b\d{1,2}:\d{2}\s*[-–—]\s*\d{1,2}:\d{2}')
              .allMatches(text).length >= 3) {
        return text;
      }
    }
    return null;
  }

  /// A corrected multi-event draft must contain actual clock ranges,
  /// not merely "cancelled", "checking" or "I will replan" status text.
  static bool hasTimedItinerary(String message) =>
      RegExp(r'\b\d{1,2}:\d{2}\s*[-–—]\s*\d{1,2}:\d{2}')
          .allMatches(message).length >= 3;

  /// Clock preference for this draft; a city mentioned as a destination
  /// does not change the user's home/profile timezone.
  static String? explicitScheduleTimezone(String input) {
    final q = input.toLowerCase().trim();
    final iana = RegExp(
      r'\b(?:africa|america|antarctica|arctic|asia|atlantic|'
      r'australia|europe|indian|pacific)/[a-z0-9_+\-/]+',
    ).firstMatch(q);
    if (iana != null && (q == iana.group(0) ||
        RegExp(r'врем|часов|timezone|time\s*zone|пояс').hasMatch(q))) {
      return iana.group(0)!.split('/').map((part) =>
          part.split('_').map((word) =>
              word.isEmpty ? word
                  : word[0].toUpperCase() + word.substring(1)).join('_')
      ).join('/');
    }

    const aliases = <String, String>{
      r'москв|московск|мск\b': 'Europe/Moscow',
      r'перм|пермск|екатеринбург|екатеринбургск': 'Asia/Yekaterinburg',
      r'новосибирск': 'Asia/Novosibirsk',
      r'омск': 'Asia/Omsk',
      r'красноярск': 'Asia/Krasnoyarsk',
      r'иркутск': 'Asia/Irkutsk',
      r'владивосток': 'Asia/Vladivostok',
      r'самар|самарск': 'Europe/Samara',
      r'калининград': 'Europe/Kaliningrad',
      r'берлин|berlin': 'Europe/Berlin',
      r'нью[- ]йорк|new york': 'America/New_York',
    };
    final candidates = <(int, String)>[];
    for (final alias in aliases.entries) {
      for (final match in RegExp(alias.key, caseSensitive: false)
          .allMatches(q)) {
        final before = q.substring(0, match.start);
        final after = q.substring(match.end);
        final recent = before.length > 36
            ? before.substring(before.length - 36) : before;
        final positiveBefore = RegExp(
          r'по\s+(?:местному\s+)?(?:(?:времени|часам)\s+)?$|'
          r'время\s+(?:по|в)\s*$|'
          r'часовой\s+пояс\s*$',
        ).hasMatch(recent);
        final positiveAfter = RegExp(
          r'^\s*[а-яa-z]*\s*(?:времени|время|часам|пояс)',
        ).hasMatch(after);
        final abbreviation = match.group(0) == 'мск' &&
            !RegExp(r'^(?:почему|зачем)\b').hasMatch(q);
        if (positiveBefore || positiveAfter || abbreviation) {
          final negated = RegExp(
            r'(?:^|[,;]\s*|\s)не\s+(?:надо\s+|нужно\s+)?по\s*$',
          ).hasMatch(recent);
          if (!negated) candidates.add((match.start, alias.value));
        }
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    return candidates.last.$2;
  }

  /// The latest positive USER clock instruction applies to this dialogue,
  /// not to all users or to the persistent profile.
  static String? requestedScheduleTimezone({
    required String input,
    required Iterable<Map<String, String>> history,
  }) {
    final current = explicitScheduleTimezone(input);
    if (current != null) return current;
    for (final turn in history.toList().reversed) {
      if (turn['role'] != 'user') continue;
      final zone = explicitScheduleTimezone(turn['content'] ?? '');
      if (zone != null) return zone;
    }
    return null;
  }

  static bool mismatchedScheduleTimezone({
    required String message,
    required String input,
    required Iterable<Map<String, String>> history,
  }) {
    final expected = requestedScheduleTimezone(input: input, history: history);
    if (expected == null) return false;
    final entries = RegExp(
      r'\d{1,2}:\d{2}\s*[-–—]\s*\d{1,2}:\d{2}\s*\(([^)]{2,40})\)',
      caseSensitive: false,
    ).allMatches(message);
    for (final row in entries) {
      final declared = explicitScheduleTimezone(
          'время по ' + (row[1] ?? ''));
      if (declared != null && declared != expected) return true;
    }
    return false;
  }

  /// A conversation about revising an UNSAVED itinerary is a request for
  /// another draft, not an authorization to move already-saved plans.
  /// "Confirm/save/apply" remains an explicit separate user operation.
  static bool isDraftRevision({
    required String input,
    required Iterable<Map<String, String>> history,
  }) {
    if (lastTimedDraft(history) == null) return false;
    final q = input.toLowerCase().trim();
    if (RegExp(r'(?:подтверждаю|сохрани|запиши\s+в|применяй|'
        r'выполни\s+изменения|confirm|apply|save\b)').hasMatch(q)) {
      return false;
    }
    return RegExp(
      r'скоррект|подкоррект|передела|поменя|сдвин|пересостав|'
      r'встан|просну|подъ[её]м|вместо\s+\d|начн[её]м|'
      r'перенеси.*(?:время|начало)|почему|не\s+учт|пропуст|забыл|'
      r'где\s+.+|не\s+продуман|обнови\s+план|добав|'
      r'revise|adjust|draft|later|earlier|wake',
      caseSensitive: false,
    ).hasMatch(q);
  }

  /// A short explicit timezone correction to a previously proposed DRAFT
  /// changes the timezone LABEL of the wall-clock timetable, not its hours.
  /// No provider call or writes are needed to fix a mislabeled draft.
  ///
  /// Deliberately restricted to an unambiguous source label and an
  /// unambiguous explicitly named destination; other requests go to the model.
  static String? correctMislabeledMoscowDraft({
    required String input,
    required Iterable<Map<String, String>> history,
  }) {
    final q = input.toLowerCase().trim();
    if (!RegExp(r'(?:москв|москве|мск|moscow|europe/moscow)',
            caseSensitive: false).hasMatch(q) ||
        !RegExp(r'(?:врем|часов|часовому|пояс|timezone|time\s*zone|'
            r'мск|по\s+москве)', caseSensitive: false).hasMatch(q) ||
        q.length > 180) {
      return null;
    }
    final old = lastTimedDraft(history);
    if (old == null) return null;
    final marker = RegExp(
      r'\((?:New York|America/New_York|Нью[- ]Йорк)\)',
      caseSensitive: false,
    );
    if (!marker.hasMatch(old)) return null;
    final fixed = old.replaceAll(marker, '(Москва, МСК)');
    return 'Исправленный черновик — местное время Москвы (МСК). '
        'Часы сохранены как указанные тобой, без пересчёта '
        'из ошибочно подписанного New York.\n\n'
        '$fixed\n\nНичего в LIFE OS не сохранено.';
  }

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
