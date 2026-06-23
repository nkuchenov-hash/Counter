/// Fixed IANA zones for per-category default plan times (DST-safe).
library;

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
