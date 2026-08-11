from pathlib import Path

p = Path('lib/features/timeline/timeline_view.dart')
s = p.read_text()

def once(old: str, new: str, label: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f'missing anchor: {label}')
    s = s.replace(old, new, 1)

once(
    "import 'package:counter/features/timeline/timeline_day_page.dart';\n",
    "import 'package:counter/features/timeline/timeline_day_page.dart';\nimport 'package:counter/features/timeline/timeline_continuous_history.dart';\n",
    'continuous import',
)

once(
    "  bool _showStatsView = false;\n  String? _swipeFromDateKey;\n",
    "  bool _showStatsView = false;\n  DateTime? _continuousVisibleDate;\n  String? _swipeFromDateKey;\n",
    'continuous state',
)

once(
    "    _visiblePageIndex = _initialPage + daysOffset;\n    _controller = PageController(initialPage: _visiblePageIndex);\n",
    "    _visiblePageIndex = _initialPage + daysOffset;\n    _continuousVisibleDate = _dateOnly(widget.selectedDate);\n    _controller = PageController(initialPage: _visiblePageIndex);\n",
    'continuous init',
)

old_did = """  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.shellTabActive && widget.shellTabActive) {
"""
new_did = """  @override
  void didUpdateWidget(covariant TimelineSwipeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_showStatsView) {
      final oldD = _dateOnly(oldWidget.selectedDate);
      final newD = _dateOnly(widget.selectedDate);
      final current = _continuousVisibleDate;
      if (oldD != newD && (current == null || current != newD)) {
        setState(() => _continuousVisibleDate = newD);
      }
      return;
    }
    if (!oldWidget.shellTabActive && widget.shellTabActive) {
"""
once(old_did, new_did, 'list-mode didUpdate guard')

insert_before_build = """  @override
  Widget build(BuildContext context) {
"""
method = """  void _setStatsView(bool value) {
    if (_showStatsView == value) return;
    if (value) {
      final target = _continuousVisibleDate ?? _dateForIndex(_visiblePageIndex);
      final page = _pageIndexForDate(target);
      if (page >= 0 && page < _totalPageCount) {
        _visiblePageIndex = page;
        _settleGate.resetCommittedPage(page);
        if (_controller.hasClients) _controller.jumpToPage(page);
      }
      widget.onDateChanged(_dateOnly(target));
    } else {
      _continuousVisibleDate = _dateForIndex(_visiblePageIndex);
    }
    setState(() => _showStatsView = value);
  }

  @override
  Widget build(BuildContext context) {
"""
once(insert_before_build, method, 'stats mode method')

build_anchor = """    final visibleDate = _dateForIndex(_visiblePageIndex);
    try {
      return ScrollConfiguration(
"""
build_replacement = """    final visibleDate = _dateForIndex(_visiblePageIndex);
    if (!_showStatsView) {
      final continuousDate = _continuousVisibleDate ?? visibleDate;
      return TimelineContinuousPage(
        selectedDate: continuousDate,
        anchorToday: _anchorToday,
        shellTabActive: widget.shellTabActive,
        titleController: widget.titleController,
        titleFocus: widget.titleFocus,
        onStart: widget.onStart,
        onPlan: widget.onPlan,
        onNewTaskForPastDate: widget.onNewTaskForPastDate,
        onStopRecord: widget.onStopRecord,
        onDeleteRecord: widget.onDeleteRecord,
        onShowEditRecordSheet: widget.onShowEditRecordSheet,
        onShowStatsViewChanged: _setStatsView,
        onVisibleDateChanged: (date) {
          final next = _dateOnly(date);
          final current = _continuousVisibleDate;
          if (current != null && current == next) return;
          setState(() => _continuousVisibleDate = next);
          widget.onDateChanged(next);
        },
      );
    }
    try {
      return ScrollConfiguration(
"""
once(build_anchor, build_replacement, 'continuous build branch')

once(
    "                onShowStatsViewChanged: (v) =>\n                    setState(() => _showStatsView = v),\n",
    "                onShowStatsViewChanged: _setStatsView,\n",
    'stats callback',
)

p.write_text(s)
