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

