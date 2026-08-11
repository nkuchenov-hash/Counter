from pathlib import Path

p = Path('lib/features/timeline/timeline_view.dart')
s = p.read_text()
for line in [
    "import 'package:counter/core/app_colors.dart';\n",
    "import 'package:counter/features/shared/shared_widgets.dart';\n",
    "import 'package:counter/features/stats/stats_view.dart';\n",
    "import 'package:intl/intl.dart';\n",
]:
    s = s.replace(line, '')
block = """// --- Time helpers: device-local calendar for day strip; profile offset for clock labels only ---
DateTime _localToday() => timelineLocalToday();

bool _isToday(DateTime date) => timelineIsToday(date);

DateTime _dateOnlyCalendar(DateTime d) => timelineDateOnlyCalendar(d);

String _wallCalendarDayKeyFromUtcInstant(DateTime startUtcOrAny) =>
    timelineWallCalendarDayKeyFromUtcInstant(startUtcOrAny);

String _formatTimeOfDay(DateTime dt) => timelineFormatTimeOfDay(dt);

DateTime _utcToDisplay(DateTime utc) => timelineUtcToDisplay(utc);

String _formatDuration(Duration d) => timelineFormatDuration(d);

"""
s = s.replace(block, '')
p.write_text(s)
