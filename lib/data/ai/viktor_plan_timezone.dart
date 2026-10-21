import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:timezone/timezone.dart' as tz;
import 'viktor_date_scope.dart';

/// Dates in a model proposal refer to the requested timezone. Brain stores
/// schedules as the user's profile-wall times; convert explicitly instead of
/// interpreting an "NY" time as a clock in another profile timezone.
DateTime viktorPlanStartInProfileWall({
  required String wallDay,
  required String startTime,
  required String? timezone,
  required String profileTimezone,
  required DateTime Function(DateTime utc) toProfileWall,
}) {
  final day = ViktorDateScope.parseDay(wallDay);
  final parts = startTime.split(':').map(int.parse).toList();
  final requested = (timezone ?? '').trim();
  if (requested.isEmpty || requested == 'profile' ||
      profileTimezoneValuesMatch(requested, profileTimezone)) {
    return DateTime(day.year, day.month, day.day, parts[0], parts[1]);
  }
  final catalog = catalogEntryForStoredTimezone(requested);
  if (catalog == null) {
    throw StateError('Неизвестный часовой пояс встречи: $requested');
  }
  final zoned = tz.TZDateTime(tz.getLocation(catalog.ianaId),
      day.year, day.month, day.day, parts[0], parts[1]);
  if (zoned.year != day.year || zoned.month != day.month ||
      zoned.day != day.day || zoned.hour != parts[0] ||
      zoned.minute != parts[1]) {
    throw StateError('В это время переводятся часы. '
        'Уточните время встречи.');
  }
  return toProfileWall(zoned.toUtc());
}
