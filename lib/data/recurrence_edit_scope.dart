/// Recurrence edit/delete scope for Planning recurring tasks.
enum RecurrenceEditScope {
  /// Only the selected occurrence (exception + optional one-off materialize).
  singleOccurrence,

  /// Selected occurrence and all future occurrences (series split when supported).
  thisAndFuture,

  /// The stored recurrence series row and all virtual instances.
  entireSeries,
}

/// Whether [scope] is implemented for network mutations (vs disabled in UI).
bool recurrenceEditScopeIsSupported(RecurrenceEditScope scope) {
  switch (scope) {
    case RecurrenceEditScope.singleOccurrence:
    case RecurrenceEditScope.entireSeries:
      return true;
    case RecurrenceEditScope.thisAndFuture:
      return false;
  }
}
