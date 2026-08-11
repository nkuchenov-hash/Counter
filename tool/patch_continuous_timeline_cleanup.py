from pathlib import Path

p = Path('lib/features/timeline/timeline_continuous_history.dart')
s = p.read_text()
s = s.replace("import 'package:counter/data/models.dart';\n", '')
s = s.replace("import 'package:counter/features/timeline/timeline_helpers.dart';\n", '')
old = """    _topDate = _day(widget.initialDate);
    _reportedPinnedDate = _topDate;
    widget.onVisibleDateChanged(_topDate);
    _controller.addListener(_onScroll);
"""
new = """    _topDate = _day(widget.initialDate);
    _reportedPinnedDate = _topDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibleDateChanged(_topDate);
    });
    _controller.addListener(_onScroll);
"""
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)
