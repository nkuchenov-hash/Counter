import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

DateTime shellDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool shellSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String shellTwoDigits(int n) => n.toString().padLeft(2, '0');

DateTime shellLocalToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

bool shellIsNewPlanningDraft(PlanningTask t) {
  if (t.id != 0) return false;
  final p = t.planRowId?.trim() ?? '';
  return p.isEmpty;
}

const String shellPrefsRecordLinkSuggestionsEnabled =
    'plans_record_link_suggestions_enabled';
const String shellPrefsRecordLinkSuggestionMode =
    'plans_record_link_suggestion_mode';
const String shellPrefsRecordLinkSuggestionDismissed =
    'plans_record_link_suggestion_dismissed_record_ids';
const String shellRecordLinkSuggestionModeAsk = 'ask';
const String shellRecordLinkSuggestionModeAuto = 'auto';
