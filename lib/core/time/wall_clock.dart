/// PLANETARY_TIME (v5.0): Storage is UTC only.
/// USER_PROFILE_SOVEREIGNTY: Display and day-boundary logic uses the user's profile offset only.
/// BANNED: DateTime.toLocal(), system timezone, browser/device timezone.
library;

import 'package:timezone/timezone.dart' as tz;

/// True when [preferredTzLabel] should use IANA `America/New_York` (EST/EDT), not a fixed hour offset.
bool profileLabelUsesNewYorkWallClock(String preferredTzLabel) {
  final t = preferredTzLabel.trim().toLowerCase();
  return t.contains('new york');
}

/// Wall-clock view of [utc]: either fixed [offsetHours] or America/New_York with DST. Requires [tz.initializeTimeZones] in main.
DateTime toWallClockForLabel(
  DateTime utc,
  int offsetHours,
  String preferredTzLabel,
) {
  if (profileLabelUsesNewYorkWallClock(preferredTzLabel)) {
    final loc = tz.getLocation('America/New_York');
    final z = tz.TZDateTime.from(utc.toUtc(), loc);
    return DateTime(
      z.year,
      z.month,
      z.day,
      z.hour,
      z.minute,
      z.second,
      z.millisecond,
      z.microsecond,
    );
  }
  return toWallClock(utc, offsetHours);
}

/// Inverse of [toWallClockForLabel] for pickers / planning PATCH.
DateTime wallClockToUtcForLabel(
  DateTime wallClock,
  int offsetHours,
  String preferredTzLabel,
) {
  if (profileLabelUsesNewYorkWallClock(preferredTzLabel)) {
    final loc = tz.getLocation('America/New_York');
    final z = tz.TZDateTime(
      loc,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
      wallClock.microsecond,
    );
    return z.toUtc();
  }
  return wallClockToUtc(wallClock, offsetHours);
}

/// UTC bounds for the profile wall-calendar day (timeline / stats), honoring NY DST when label matches.
(DateTime startUtc, DateTime endUtc) utcWallClockDayBoundsUtc(
  DateTime wallClockDate,
  int offsetHours,
  String preferredTzLabel,
) {
  if (profileLabelUsesNewYorkWallClock(preferredTzLabel)) {
    final loc = tz.getLocation('America/New_York');
    final y = wallClockDate.year;
    final m = wallClockDate.month;
    final d = wallClockDate.day;
    final start = tz.TZDateTime(loc, y, m, d, 0, 0, 0);
    final end = tz.TZDateTime(loc, y, m, d, 23, 59, 59);
    return (start.toUtc(), end.toUtc());
  }
  final y = wallClockDate.year;
  final m = wallClockDate.month;
  final d = wallClockDate.day;
  return (
    DateTime.utc(y, m, d).add(Duration(hours: -offsetHours)),
    DateTime.utc(y, m, d + 1).add(Duration(hours: -offsetHours)),
  );
}

/// Convert a UTC timestamp to a wall-clock time using the profile offset.
DateTime toWallClock(DateTime utc, int offsetHours) {
  assert(
    utc.isUtc,
    'toWallClock requires a UTC anchor. Got isUtc=false; caller must pass a UTC DateTime (e.g., DateTime.parse(...).toUtc() or DatabaseService.getPlanetaryNow()).',
  );
  // CRITICAL: Return a "naive" DateTime (isUtc=false) so pickers/UI treat it as wall clock,
  // not as UTC. Device timezone is still irrelevant because we never call .toLocal().
  final u = utc.toUtc().add(Duration(hours: offsetHours));
  return DateTime(
    u.year,
    u.month,
    u.day,
    u.hour,
    u.minute,
    u.second,
    u.millisecond,
    u.microsecond,
  );
}

/// Convert naive wall-clock components in an IANA zone (DST-aware) to UTC storage.
DateTime wallClockToUtcForIanaId(DateTime wallClock, String ianaId) {
  final id = ianaId.trim();
  final loc = tz.getLocation(id);
  final z = tz.TZDateTime(
    loc,
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
    wallClock.microsecond,
  );
  return z.toUtc();
}

/// Convert a wall-clock time (naive picker value) to a UTC timestamp for storage.
///
/// Uses only calendar components of [wallClock] as the user's profile wall time
/// (see USER_PROFILE_SOVEREIGNTY) — never [DateTime.subtract] on a local DateTime,
/// which would mix in the device/browser timezone.
DateTime wallClockToUtc(DateTime wallClock, int offsetHours) {
  final y = wallClock.year;
  final mo = wallClock.month;
  final d = wallClock.day;
  final h = wallClock.hour;
  final mi = wallClock.minute;
  final s = wallClock.second;
  final ms = wallClock.millisecond;
  final mc = wallClock.microsecond;
  return DateTime.utc(y, mo, d, h, mi, s, ms, mc)
      .subtract(Duration(hours: offsetHours));
}

/// ISO-8601 offset like "+03:00" or "-05:00" from hours.
String offsetIso(int offsetHours) {
  final sign = offsetHours >= 0 ? '+' : '-';
  final abs = offsetHours.abs().toString().padLeft(2, '0');
  return '$sign$abs:00';
}

/// Build wall-clock day bounds as ISO strings with an explicit offset.
/// Returned strings are UTC ISO (ending in "Z") to avoid unencoded "+" issues in query strings.
/// Example (offset +3): "2026-03-16T21:00:00.000Z" .. "2026-03-17T20:59:59.000Z"
(String startIso, String endIso) wallClockDayBoundsIso(DateTime wallClockDate, int offsetHours) {
  final startWall = DateTime(wallClockDate.year, wallClockDate.month, wallClockDate.day, 0, 0, 0);
  final endWall = DateTime(wallClockDate.year, wallClockDate.month, wallClockDate.day, 23, 59, 59);
  final startUtc = wallClockToUtc(startWall, offsetHours);
  final endUtc = wallClockToUtc(endWall, offsetHours);
  return (startUtc.toIso8601String(), endUtc.toIso8601String());
}

