/// Recurrence edit/delete scope for Planning recurring tasks.
enum RecurrenceEditScope {
  /// Only the selected occurrence (exception + optional one-off materialize).
  singleOccurrence,

  /// Selected occurrence and every later occurrence. Implemented as a series split
  /// so occurrences before the selected boundary remain historically unchanged.
  thisAndFuture,

  /// Legacy internal value. Never expose in UI and never rewrite historical occurrences.
  @Deprecated('Use thisAndFuture; recurring history is immutable.')
  entireSeries,
}

/// User-supported recurrence mutation scopes.
bool recurrenceEditScopeIsSupported(RecurrenceEditScope scope) =>
    scope != RecurrenceEditScope.entireSeries;

/// Old callers that still pass `entireSeries` get the future-safe behavior.
RecurrenceEditScope canonicalRecurrenceEditScope(RecurrenceEditScope scope) =>
    scope == RecurrenceEditScope.entireSeries
        ? RecurrenceEditScope.thisAndFuture
        : scope;

String _rruleUtcStamp(DateTime value) {
  final u = value.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Returns the same recurrence cadence, ending immediately before [cutoffUtc].
/// COUNT/old UNTIL are replaced by one RFC5545 UNTIL boundary.
String recurrenceRruleEndingBefore(String raw, DateTime cutoffUtc) {
  final source = raw.trim();
  if (source.isEmpty) return source;
  final prefixed = source.toUpperCase().startsWith('RRULE:');
  final body = prefixed ? source.substring(source.indexOf(':') + 1) : source;
  final parts = body
      .split(';')
      .map((e) => e.trim())
      .where((e) =>
          e.isNotEmpty &&
          !e.toUpperCase().startsWith('UNTIL=') &&
          !e.toUpperCase().startsWith('COUNT='))
      .toList();
  final end = cutoffUtc.toUtc().subtract(const Duration(seconds: 1));
  parts.add('UNTIL=${_rruleUtcStamp(end)}');
  return '${prefixed ? 'RRULE:' : ''}${parts.join(';')}';
}

/// Preserves an original COUNT rule after [consumedCount] earlier occurrences.
/// Returns null when no occurrence remains. Rules without COUNT are unchanged.
String? recurrenceRruleWithRemainingCount(String raw, int consumedCount) {
  final source = raw.trim();
  if (source.isEmpty) return source;
  final prefixed = source.toUpperCase().startsWith('RRULE:');
  final body = prefixed ? source.substring(source.indexOf(':') + 1) : source;
  final parts = body.split(';').map((e) => e.trim()).toList();
  final index = parts.indexWhere((e) => e.toUpperCase().startsWith('COUNT='));
  if (index < 0) return source;
  final count = int.tryParse(parts[index].split('=').skip(1).join('='));
  if (count == null) return source;
  final remaining = count - consumedCount;
  if (remaining <= 0) return null;
  parts[index] = 'COUNT=$remaining';
  return '${prefixed ? 'RRULE:' : ''}${parts.join(';')}';
}
