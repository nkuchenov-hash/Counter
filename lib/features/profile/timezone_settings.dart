/// The Throne: timezone options + offsets (USER_PROFILE_SOVEREIGNTY).
/// No device timezone detection. No DateTime.toLocal().
library;

class TimezoneOption {
  const TimezoneOption(this.label, this.offsetHours);

  final String label;
  final double offsetHours;
}

/// Professional, searchable list. Keep it short and stable.
/// Moscow hard-validated to +3.
const List<TimezoneOption> kTimezoneOptions = <TimezoneOption>[
  TimezoneOption('UTC', 0),
  TimezoneOption('London (UTC+0)', 0),
  TimezoneOption('Moscow (UTC+3)', 3),
  TimezoneOption('Dubai (UTC+4)', 4),
  TimezoneOption('New York (UTC-5)', -5),
];

/// Fixed IANA zones for per-category default plan times (DST-safe).
class CategoryDefaultTimezoneOption {
  const CategoryDefaultTimezoneOption({
    required this.ianaId,
    required this.searchLabel,
    required this.shortLabel,
  });

  final String ianaId;
  final String searchLabel;
  final String shortLabel;
}

const List<CategoryDefaultTimezoneOption> kCategoryDefaultTimezoneOptions =
    <CategoryDefaultTimezoneOption>[
  CategoryDefaultTimezoneOption(
    ianaId: 'UTC',
    searchLabel: 'UTC',
    shortLabel: 'UTC',
  ),
  CategoryDefaultTimezoneOption(
    ianaId: 'Europe/London',
    searchLabel: 'London',
    shortLabel: 'LON',
  ),
  CategoryDefaultTimezoneOption(
    ianaId: 'Europe/Moscow',
    searchLabel: 'Moscow',
    shortLabel: 'MSK',
  ),
  CategoryDefaultTimezoneOption(
    ianaId: 'Europe/Helsinki',
    searchLabel: 'Helsinki',
    shortLabel: 'HEL',
  ),
  CategoryDefaultTimezoneOption(
    ianaId: 'Asia/Dubai',
    searchLabel: 'Dubai',
    shortLabel: 'DXB',
  ),
  CategoryDefaultTimezoneOption(
    ianaId: 'America/New_York',
    searchLabel: 'New York',
    shortLabel: 'NY',
  ),
];

CategoryDefaultTimezoneOption? categoryDefaultTimezoneOptionForIana(
  String? ianaId,
) {
  final id = ianaId?.trim() ?? '';
  if (id.isEmpty) return null;
  for (final o in kCategoryDefaultTimezoneOptions) {
    if (o.ianaId == id) return o;
  }
  return null;
}

String shortLabelForCategoryDefaultTimezoneIana(String? ianaId) {
  final known = categoryDefaultTimezoneOptionForIana(ianaId);
  if (known != null) return known.shortLabel;
  final id = ianaId?.trim() ?? '';
  if (id.isEmpty) return '';
  final parts = id.split('/');
  return parts.isNotEmpty ? parts.last : id;
}

double offsetForLabel(String label) {
  final l = label.trim();
  for (final o in kTimezoneOptions) {
    if (o.label == l) return o.offsetHours;
  }
  // Fallback: accept legacy labels.
  if (l == 'Moscow') return 3;
  if (l == 'Dubai') return 4;
  if (l == 'New York') return -5;
  if (l == 'London') return 0;
  return 0;
}

