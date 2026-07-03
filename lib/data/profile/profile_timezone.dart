part of '../database_service.dart';

String _normalizeTimezone(String timezone) {
  final t = timezone.trim();
  if (t.isEmpty) return 'UTC';
  final entry = catalogEntryForStoredTimezone(t);
  if (entry != null) return entry.profileValue;
  switch (t) {
    case 'London':
    case 'London (UTC+0)':
      return 'London';
    case 'Moscow':
    case 'Moscow (UTC+3)':
      return 'GMT+3';
    case 'Dubai':
    case 'Dubai (UTC+4)':
      return 'Dubai';
    case 'New York':
    case 'New York (UTC-5)':
      return 'New York';
    default:
      if (t.contains('Moscow') || t.contains('UTC+3')) return 'GMT+3';
      if (t.contains('Dubai') || t.contains('UTC+4')) return 'Dubai';
      if (t.contains('New York') || t.contains('UTC-5')) return 'New York';
      if (t.contains('London')) return 'London';
      if (t.contains('UTC+0')) return 'UTC';
      return t;
  }
}

int _fixedOffsetHoursFromLabel(String timezone) {
  final tz = _normalizeTimezone(timezone);
  final entry = catalogEntryForStoredTimezone(tz);
  if (entry != null) {
    return currentOffsetHoursForProfileTimezone(entry.profileValue);
  }
  switch (tz) {
    case 'UTC':
      return 0;
    case 'GMT+3':
      return 3;
    case 'Dubai':
      return 4;
    case 'New York':
      return -5;
    default:
      return 0;
  }
}

(DateTime, DateTime) utcRangeForDateInTimezone(
  DateTime selectedDate,
  String timezone,
) {
  final offset = _fixedOffsetHoursFromLabel(timezone);
  return wall_clock.utcWallClockDayBoundsUtc(
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    offset,
    timezone,
  );
}

(DateTime, DateTime) utcRangeForWallClockDate(
  DateTime wallClockDate,
  int offsetHours,
  String preferredTimeZone,
) {
  return wall_clock.utcWallClockDayBoundsUtc(
    wallClockDate,
    offsetHours,
    preferredTimeZone,
  );
}

extension ProfileTimezoneExtension on DatabaseService {
  static List<String> get validTimezonesForProfile =>
      profileTimezoneProfileValues();
  List<String> get profileTimezoneOptions => validTimezonesForProfile;

  DateTime getProjectedToday() {
    final utc = DateTime.now().toUtc();
    final view = _profileWallFromUtc(utc);
    return DateTime(view.year, view.month, view.day);
  }

  DateTime applyUserOffset(DateTime utcDate) {
    return _profileWallFromUtc(utcDate);
  }

  DateTime displayTimeToUtc(DateTime displayNaive) {
    return _profileUtcFromWall(displayNaive);
  }

  String getProjectedTodayDateKey() {
    final t = getProjectedToday();
    return '${t.year}-${_two(t.month)}-${_two(t.day)}';
  }

  /// Timeline calendar “today” / strip anchor: **profile wall-clock** ([getProjectedToday]), per [DATA_MAP] records §8 / [wall_clock] (not device TZ).
  DateTime getTimelineDeviceLocalToday() => getProjectedToday();

  String getTimelineDeviceLocalTodayDateKey() => getProjectedTodayDateKey();

  Future<bool> updateTimeZone(String label) async {
    final prev = _settings;
    final next = _settings.copyWith(
      preferredTimeZone: label,
      timezoneOffsetHours: _fixedOffsetHoursFromLabel(label),
    );
    final saveFuture = saveSettings(next);
    reprojectAllPlansForProfileTimezone();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    final ok = await saveFuture;
    if (!ok) {
      await saveSettings(prev);
      reprojectAllPlansForProfileTimezone();
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
      _notifyTimelineAfterRecordCacheMutation();
    }
    return ok;
  }

  Future<bool> updateUserTimezone(double offsetHours) async {
    final ok = await saveSettings(
      _settings.copyWith(timezoneOffsetHours: offsetHours.round()),
    );
    reprojectAllPlansForProfileTimezone();
    notifyPlanningRefresh(scheduleNetworkRefresh: false);
    _notifyTimelineAfterRecordCacheMutation();
    return ok;
  }
}
