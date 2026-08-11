from pathlib import Path

p = Path('docs/APP_STRUCTURE.md')
s = p.read_text()
old = "| `timeline/` | `timeline_view.dart`, `timeline_header_controls.dart`, `timeline_day_page.dart`, `timeline_record_card.dart`, `timeline_helpers.dart` | `TimelineSwipeWrapper`, `TimelinePage`; header controls + day list + record cards |"
new = "| `timeline/` | `timeline_view.dart`, `timeline_continuous_history.dart`, `timeline_header_controls.dart`, `timeline_day_page.dart`, `timeline_record_card.dart`, `timeline_helpers.dart` | Timeline coordinator; continuous reverse-chronological history with pinned date headers in List mode; per-day Stats pager; header controls + record cards |"
if new in s:
    raise SystemExit(0)
if old not in s:
    raise SystemExit('timeline APP_STRUCTURE row not found')
p.write_text(s.replace(old, new, 1))
