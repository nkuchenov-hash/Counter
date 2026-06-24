/// Canonical profile timezone options for Profile settings + header quick picker.
/// [profileValue] is stored in `profiles.preferred_timezone` (USER_PROFILE_SOVEREIGNTY).
library;

class ProfileTimezoneCatalogEntry {
  const ProfileTimezoneCatalogEntry({
    required this.profileValue,
    required this.cityName,
    required this.shortLabel,
    required this.offsetHours,
  });

  final String profileValue;
  final String cityName;
  final String shortLabel;
  final int offsetHours;

  String get pickerLabel => formatProfileTimezonePickerLabel(this);

  String get searchHaystack =>
      '$profileValue $cityName $shortLabel UTC$offsetHours UTC+$offsetHours'
          .toLowerCase();
}

const List<ProfileTimezoneCatalogEntry> kProfileTimezoneCatalog =
    <ProfileTimezoneCatalogEntry>[
  ProfileTimezoneCatalogEntry(
    profileValue: 'UTC',
    cityName: 'UTC',
    shortLabel: 'UTC',
    offsetHours: 0,
  ),
  ProfileTimezoneCatalogEntry(
    profileValue: 'London',
    cityName: 'London',
    shortLabel: 'LON',
    offsetHours: 0,
  ),
  ProfileTimezoneCatalogEntry(
    profileValue: 'Moscow',
    cityName: 'Moscow',
    shortLabel: 'MSK',
    offsetHours: 3,
  ),
  ProfileTimezoneCatalogEntry(
    profileValue: 'Dubai',
    cityName: 'Dubai',
    shortLabel: 'DXB',
    offsetHours: 4,
  ),
  ProfileTimezoneCatalogEntry(
    profileValue: 'New York',
    cityName: 'New York',
    shortLabel: 'NY',
    offsetHours: -5,
  ),
];

List<String> profileTimezoneProfileValues() => kProfileTimezoneCatalog
    .map((e) => e.profileValue)
    .toList(growable: false);

String formatProfileTimezoneOffsetHours(int offsetHours) {
  if (offsetHours == 0) return 'UTC+0';
  return offsetHours > 0 ? 'UTC+$offsetHours' : 'UTC$offsetHours';
}

String formatProfileTimezonePickerLabel(ProfileTimezoneCatalogEntry entry) {
  final off = formatProfileTimezoneOffsetHours(entry.offsetHours);
  if (entry.shortLabel.isEmpty || entry.shortLabel == entry.cityName) {
    return '${entry.cityName} · $off';
  }
  return '${entry.cityName} · ${entry.shortLabel} · $off';
}

ProfileTimezoneCatalogEntry? catalogEntryForStoredTimezone(String stored) {
  final raw = stored.trim();
  if (raw.isEmpty) return kProfileTimezoneCatalog.first;

  for (final entry in kProfileTimezoneCatalog) {
    if (entry.profileValue == raw) return entry;
  }

  final lower = raw.toLowerCase();
  if (lower == 'gmt+3' ||
      lower.contains('moscow') ||
      lower.contains('msk') ||
      lower.contains('utc+3')) {
    return kProfileTimezoneCatalog[2];
  }
  if (lower.contains('dubai') || lower.contains('utc+4')) {
    return kProfileTimezoneCatalog[3];
  }
  if (lower.contains('new york') ||
      lower.contains('utc-5') ||
      lower == 'ny') {
    return kProfileTimezoneCatalog[4];
  }
  if (lower.contains('london') || lower.contains('utc+0')) {
    return kProfileTimezoneCatalog[1];
  }
  if (lower == 'utc') {
    return kProfileTimezoneCatalog.first;
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
      .where((e) => e.searchHaystack.contains(q) || e.pickerLabel.toLowerCase().contains(q))
      .toList(growable: false);
}
