from pathlib import Path

p = Path('lib/features/stats/plan_vs_fact_v2_tab.dart')
s = p.read_text()
start = s.find('String _duration(int seconds) {')
if start >= 0:
    end = s.find('\nString _durationCompact', start)
    if end >= 0:
        s = s[:start] + s[end + 1:]
s = s.replace("'${done}/${plans.length} ${_copy('done', 'выполнено')} · $worked ${_copy('worked', 'в работе')}'", "'$done/${plans.length} ${_copy('done', 'выполнено')} · $worked ${_copy('worked', 'в работе')}'")
p.write_text(s)
