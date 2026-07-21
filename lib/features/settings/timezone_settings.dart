/// The Throne: timezone options + offsets (USER_PROFILE_SOVEREIGNTY).
/// No device timezone detection. No DateTime.toLocal().
library;

import 'package:counter/shared/time/profile_timezone_catalog.dart';

export 'package:counter/shared/time/category_timezone_options.dart';
export 'package:counter/shared/time/profile_timezone_catalog.dart';

class TimezoneOption {
  const TimezoneOption(this.label, this.offsetHours);

  final String label;
  final double offsetHours;
}

/// Legacy labels — prefer [kProfileTimezoneCatalog] for new UI.
const List<TimezoneOption> kTimezoneOptions = <TimezoneOption>[
  TimezoneOption('UTC', 0),
  TimezoneOption('London', 0),
  TimezoneOption('Moscow', 3),
  TimezoneOption('Dubai', 4),
  TimezoneOption('New York', -5),
];

double offsetForLabel(String label) {
  final entry = catalogEntryForStoredTimezone(label);
  if (entry != null) {
    return currentOffsetHoursForProfileTimezone(entry.profileValue).toDouble();
  }
  final l = label.trim();
  for (final o in kTimezoneOptions) {
    if (o.label == l) return o.offsetHours;
  }
  if (l == 'Moscow') return 3;
  if (l == 'Dubai') return 4;
  if (l == 'New York') return -5;
  if (l == 'London') return 0;
  return 0;
}
