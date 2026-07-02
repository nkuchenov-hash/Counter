/// Canonical profile timezone options for Profile settings + header quick picker.
/// [profileValue] is stored in `profiles.preferred_timezone` (USER_PROFILE_SOVEREIGNTY).
library;

import 'package:counter/core/app_icons.dart';
import 'package:timezone/timezone.dart' as tz;

class ProfileTimezoneCatalogEntry {
  const ProfileTimezoneCatalogEntry({
    required this.profileValue,
    required this.cityName,
    required this.code,
    required this.ianaId,
    required this.iconKey,
    this.fixed = false,
    this.showSeasonalAbbreviation = false,
    required this.fallbackOffsetHours,
    this.fixedMeta,
  });

  final String profileValue;
  final String cityName;
  final String code;
  final String ianaId;
  final AppTimezoneIconKey iconKey;
  final bool fixed;
  final bool showSeasonalAbbreviation;
  final int fallbackOffsetHours;
  final String? fixedMeta;

  String get shortLabel => code;
  int get offsetHours => fallbackOffsetHours;
  String get pickerLabel => formatProfileTimezonePickerLabel(this);

  String get searchHaystack =>
      '$profileValue $cityName $code $ianaId UTC$fallbackOffsetHours UTC+$fallbackOffsetHours'
          .toLowerCase();
}

const List<ProfileTimezoneCatalogEntry> kProfileTimezoneCatalog =
    <ProfileTimezoneCatalogEntry>[
      ProfileTimezoneCatalogEntry(
        profileValue: 'UTC',
        cityName: 'UTC',
        code: 'UTC',
        ianaId: 'Etc/UTC',
        iconKey: AppTimezoneIconKey.utc,
        fixed: true,
        fallbackOffsetHours: 0,
        fixedMeta: 'Fixed',
      ),
      ProfileTimezoneCatalogEntry(
        profileValue: 'London',
        cityName: 'London',
        code: 'LON',
        ianaId: 'Europe/London',
        iconKey: AppTimezoneIconKey.london,
        showSeasonalAbbreviation: true,
        fallbackOffsetHours: 0,
      ),
      ProfileTimezoneCatalogEntry(
        profileValue: 'Moscow',
        cityName: 'Moscow',
        code: 'MSK',
        ianaId: 'Europe/Moscow',
        iconKey: AppTimezoneIconKey.moscow,
        fallbackOffsetHours: 3,
      ),
      ProfileTimezoneCatalogEntry(
        profileValue: 'Dubai',
        cityName: 'Dubai',
        code: 'DXB',
        ianaId: 'Asia/Dubai',
        iconKey: AppTimezoneIconKey.dubai,
        fallbackOffsetHours: 4,
      ),
      ProfileTimezoneCatalogEntry(
        profileValue: 'New York',
        cityName: 'New York',
        code: 'NY',
        ianaId: 'America/New_York',
        iconKey: AppTimezoneIconKey.newYork,
        showSeasonalAbbreviation: true,
        fallbackOffsetHours: -5,
      ),
    ];

List<String> profileTimezoneProfileValues() =>
    kProfileTimezoneCatalog.map((e) => e.profileValue).toList(growable: false);

String formatProfileTimezoneOffsetHours(int offsetHours) {
  if (offsetHours == 0) return 'UTC+0';
  return offsetHours > 0 ? 'UTC+$offsetHours' : 'UTC\u2212${offsetHours.abs()}';
}

String formatProfileTimezonePrimaryLine(ProfileTimezoneCatalogEntry entry) {
  if (entry.code.isEmpty || entry.code == entry.cityName) {
    return entry.cityName;
  }
  return '${entry.cityName} · ${entry.code}';
}

String formatProfileTimezoneSecondaryLine(
  ProfileTimezoneCatalogEntry entry, {
  DateTime? atUtc,
}) {
  final info = profileTimezoneOffsetInfo(entry, atUtc: atUtc);
  if (entry.fixed) {
    final meta = entry.fixedMeta?.trim();
    return meta == null || meta.isEmpty
        ? info.offsetLabel
        : '$meta · ${info.offsetLabel}';
  }
  if (!entry.showSeasonalAbbreviation) {
    return info.offsetLabel;
  }
  return '${info.abbreviation} · ${info.offsetLabel}';
}

String formatProfileTimezonePickerLabel(
  ProfileTimezoneCatalogEntry entry, {
  DateTime? atUtc,
}) {
  return '${formatProfileTimezonePrimaryLine(entry)} · '
      '${formatProfileTimezoneSecondaryLine(entry, atUtc: atUtc)}';
}

({String abbreviation, int offsetHours, String offsetLabel})
profileTimezoneOffsetInfo(
  ProfileTimezoneCatalogEntry entry, {
  DateTime? atUtc,
}) {
  if (entry.fixed) {
    final offsetLabel = formatProfileTimezoneOffsetHours(
      entry.fallbackOffsetHours,
    );
    return (
      abbreviation: entry.code,
      offsetHours: entry.fallbackOffsetHours,
      offsetLabel: offsetLabel,
    );
  }

  try {
    final loc = tz.getLocation(entry.ianaId);
    final anchor = (atUtc ?? DateTime.now().toUtc()).toUtc();
    final zoned = tz.TZDateTime.from(anchor, loc);
    final offset = zoned.timeZoneOffset.inHours;
    final abbreviation = zoned.timeZoneName.trim().isEmpty
        ? entry.code
        : zoned.timeZoneName.trim();
    return (
      abbreviation: abbreviation,
      offsetHours: offset,
      offsetLabel: formatProfileTimezoneOffsetHours(offset),
    );
  } catch (_) {
    final offsetLabel = formatProfileTimezoneOffsetHours(
      entry.fallbackOffsetHours,
    );
    return (
      abbreviation: entry.code,
      offsetHours: entry.fallbackOffsetHours,
      offsetLabel: offsetLabel,
    );
  }
}

int currentOffsetHoursForProfileTimezone(String stored, {DateTime? atUtc}) {
  final entry =
      catalogEntryForStoredTimezone(stored) ?? kProfileTimezoneCatalog.first;
  return profileTimezoneOffsetInfo(entry, atUtc: atUtc).offsetHours;
}

String? ianaIdForProfileTimezoneLabel(String label) {
  return catalogEntryForStoredTimezone(label)?.ianaId;
}

ProfileTimezoneCatalogEntry? catalogEntryForStoredTimezone(String stored) {
  final raw = stored.trim();
  if (raw.isEmpty) return kProfileTimezoneCatalog.first;

  for (final entry in kProfileTimezoneCatalog) {
    if (entry.profileValue == raw || entry.ianaId == raw) return entry;
  }

  final lower = raw.toLowerCase();
  if (lower == 'utc' ||
      lower == 'etc/utc' ||
      lower == 'utc (utc+0)' ||
      lower == 'utc+0') {
    return kProfileTimezoneCatalog.first;
  }
  if (lower == 'gmt+3' ||
      lower.contains('moscow') ||
      lower.contains('msk') ||
      lower.contains('europe/moscow') ||
      lower.contains('utc+3')) {
    return kProfileTimezoneCatalog[2];
  }
  if (lower.contains('dubai') ||
      lower.contains('asia/dubai') ||
      lower.contains('dxb') ||
      lower.contains('utc+4')) {
    return kProfileTimezoneCatalog[3];
  }
  if (lower.contains('new york') ||
      lower.contains('america/new_york') ||
      lower == 'ny' ||
      lower.contains('utc-5') ||
      lower.contains('utc−5')) {
    return kProfileTimezoneCatalog[4];
  }
  if (lower.contains('london') ||
      lower.contains('europe/london') ||
      lower.contains('lon')) {
    return kProfileTimezoneCatalog[1];
  }
  return null;
}

bool profileTimezoneValuesMatch(String a, String b) {
  final ea = catalogEntryForStoredTimezone(a);
  final eb = catalogEntryForStoredTimezone(b);
  if (ea != null && eb != null) {
    return ea.profileValue == eb.profileValue;
  }
  return a.trim() == b.trim();
}

List<ProfileTimezoneCatalogEntry> filterProfileTimezoneCatalog(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kProfileTimezoneCatalog;
  return kProfileTimezoneCatalog
      .where(
        (e) =>
            e.searchHaystack.contains(q) ||
            formatProfileTimezonePickerLabel(e).toLowerCase().contains(q),
      )
      .toList(growable: false);
}
