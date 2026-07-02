import 'package:counter/data/models.dart';enum PlanRepeatUi { none, daily, weekdays, weekly, monthly, yearly, custom }

String planRruleForUiParse(String? raw) {
  var s = (raw ?? '').trim();
  if (s.isEmpty) return s;
  if (s.toUpperCase().startsWith('RRULE:')) {
    s = s.substring(6).trim();
  }
  return s;
}

bool rruleHasFreqWeekly(String r) {
  return RegExp(r'FREQ\s*=\s*WEEKLY', caseSensitive: false).hasMatch(r);
}

bool rruleHasBydayClause(String r) {
  return RegExp(r'\bBYDAY\s*=', caseSensitive: false).hasMatch(r);
}

String? bydayClauseValue(String raw) {
  final m = RegExp(
    r'BYDAY\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  return m?.group(1)?.trim();
}

/// RFC 5545: Mon–Fri bundle (office weekdays), distinct from plain `FREQ=WEEKLY`.
bool isWeekdaysMoToFrRrule(String r) {
  if (!rruleHasFreqWeekly(r)) return false;
  final val = bydayClauseValue(r);
  if (val == null || val.isEmpty) return false;
  final tokens = val
      .split(',')
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  const want = {'MO', 'TU', 'WE', 'TH', 'FR'};
  return tokens.length == 5 && tokens.containsAll(want);
}

PlanRepeatUi planRepeatUiFromTask(PlanningTask t) {
  final r = planRruleForUiParse(t.rrule);
  if (r.isEmpty) return PlanRepeatUi.none;
  if (RegExp(r'FREQ\s*=\s*YEARLY', caseSensitive: false).hasMatch(r)) {
    return PlanRepeatUi.yearly;
  }
  if (RegExp(r'FREQ\s*=\s*DAILY', caseSensitive: false).hasMatch(r)) {
    return PlanRepeatUi.daily;
  }
  if (isWeekdaysMoToFrRrule(r)) {
    return PlanRepeatUi.weekdays;
  }
  if (RegExp(r'FREQ\s*=\s*MONTHLY', caseSensitive: false).hasMatch(r)) {
    return PlanRepeatUi.monthly;
  }
  if (rruleHasFreqWeekly(r)) {
    if (rruleHasBydayClause(r) && !isWeekdaysMoToFrRrule(r)) {
      return PlanRepeatUi.custom;
    }
    return PlanRepeatUi.weekly;
  }
  return PlanRepeatUi.custom;
}

String? rruleWireFromRepeatUi(PlanRepeatUi choice, String? customRaw) {
  switch (choice) {
    case PlanRepeatUi.none:
      return null;
    case PlanRepeatUi.daily:
      return 'FREQ=DAILY';
    case PlanRepeatUi.weekdays:
      return 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
    case PlanRepeatUi.weekly:
      return 'FREQ=WEEKLY';
    case PlanRepeatUi.monthly:
      return 'FREQ=MONTHLY';
    case PlanRepeatUi.yearly:
      return 'FREQ=YEARLY';
    case PlanRepeatUi.custom:
      final s = customRaw?.trim() ?? '';
      return s.isEmpty ? null : s;
  }
}
