from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}, found {count}: {old[:80]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


shell = "lib/features/planning/planning_page_shell.dart"
replace_once(
    shell,
    "  late int _visiblePageIndex;\n  int? _pendingExternalPage;",
    "  late int _visiblePageIndex;\n  late int _activePageIndex;\n  int? _pendingExternalPage;",
)
replace_once(
    shell,
    """    final cur = _controller.page?.round();
    if (cur == pending) return;
    _settleGate.resetCommittedPage(pending);
    setState(() => _visiblePageIndex = pending);
    _controller.jumpToPage(pending);
""",
    """    final cur = _controller.page?.round();
    _settleGate.resetCommittedPage(pending);
    setState(() {
      _visiblePageIndex = pending;
      _activePageIndex = pending;
    });
    if (cur == pending) return;
    _controller.jumpToPage(pending);
""",
)
replace_once(
    shell,
    """    setState(() => _visiblePageIndex = page);
    if (!_controller.hasClients) return;
""",
    """    _settleGate.resetCommittedPage(page);
    setState(() {
      _visiblePageIndex = page;
      _activePageIndex = page;
    });
    if (!_controller.hasClients) return;
""",
)
replace_once(
    shell,
    """    _visiblePageIndex = _initialPage + daysOffset;
    _controller = PageController(initialPage: _visiblePageIndex);
""",
    """    _visiblePageIndex = _initialPage + daysOffset;
    _activePageIndex = _visiblePageIndex;
    _settleGate.resetCommittedPage(_visiblePageIndex);
    _controller = PageController(initialPage: _visiblePageIndex);
""",
)
replace_once(
    shell,
    """    setState(() => _visiblePageIndex = page);
    if (_controller.hasClients) {
      final cur = _controller.page;
      if (cur != null && cur.round() == page) return;
      _settleGate.markProgrammaticAnimStart();
""",
    """    _settleGate.resetCommittedPage(page);
    if (_controller.hasClients) {
      final cur = _controller.page;
      if (cur != null && cur.round() == page) {
        setState(() {
          _visiblePageIndex = page;
          _activePageIndex = page;
        });
        return;
      }
      setState(() => _visiblePageIndex = page);
      _settleGate.markProgrammaticAnimStart();
""",
)
replace_once(
    shell,
    """          .whenComplete(() {
            if (mounted) _settleGate.markProgrammaticAnimEnd();
          });
    }
  }
""",
    """          .whenComplete(() {
            if (mounted) _settleGate.markProgrammaticAnimEnd();
          });
    } else {
      setState(() => _activePageIndex = page);
    }
  }
""",
)
replace_once(
    shell,
    """    if (targetIndex >= 0 &&
        targetIndex < _totalPageCount &&
        _controller.hasClients) {
      _controller.jumpToPage(targetIndex);
      widget.onDateChanged(dateOnly);
    }
  }
""",
    """    if (targetIndex >= 0 &&
        targetIndex < _totalPageCount &&
        _controller.hasClients) {
      _settleGate.resetCommittedPage(targetIndex);
      setState(() {
        _visiblePageIndex = targetIndex;
        _activePageIndex = targetIndex;
      });
      _controller.jumpToPage(targetIndex);
      widget.onDateChanged(dateOnly);
    }
  }

  void _activateVisiblePageAfterSettle() {
    final page = _visiblePageIndex;
    if (_activePageIndex != page) {
      setState(() => _activePageIndex = page);
    }
    _settleGate.onPageSettled(
      pageIndex: page,
      onShellCommit: (settledPage) {
        if (!mounted) return;
        final committed = _dateForIndex(settledPage);
        _schedulePrefetch(committed);
        widget.onDateChanged(_dateOnly(committed));
      },
    );
  }
""",
)
replace_once(
    shell,
    """          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
""",
    """          onNotification: (n) {
            if (n.depth != 0) return false;
            if (n is ScrollStartNotification && n.dragDetails != null) {
""",
)
replace_once(
    shell,
    """            if (n is ScrollEndNotification) {
              _settleGate.onUserDragEnd();
              _applyPendingExternalPageIfNeeded();
""",
    """            if (n is ScrollEndNotification) {
              _settleGate.onUserDragEnd();
              _activateVisiblePageAfterSettle();
              _applyPendingExternalPageIfNeeded();
""",
)
replace_once(
    shell,
    """            itemCount: _totalPageCount,
            onPageChanged: (int index) {
              if (index < 0 || index >= _totalPageCount) return;
              setState(() => _visiblePageIndex = index);
              _settleGate.onPageSettled(
                pageIndex: index,
                onShellCommit: (page) {
                  if (!mounted) return;
                  final committed = _dateForIndex(page);
                  _schedulePrefetch(committed);
                  widget.onDateChanged(_dateOnly(committed));
                },
              );
            },
""",
    """            itemCount: _totalPageCount,
            allowImplicitScrolling: true,
            onPageChanged: (int index) {
              if (index < 0 || index >= _totalPageCount) return;
              setState(() => _visiblePageIndex = index);
            },
""",
)
replace_once(
    shell,
    """              final isActive =
                  widget.shellTabActive && index == _visiblePageIndex;
""",
    """              final isActive =
                  widget.shellTabActive && index == _activePageIndex;
""",
)

planning = "lib/features/planning/planning_page.dart"
replace_once(
    planning,
    """    if (!widget.isActivePlanningDay) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }
    final wallDay = widget.selectedDate ?? _today;
    final planActualByPbId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
""",
    """    final wallDay = widget.selectedDate ?? _today;
    if (!widget.isActivePlanningDay) {
      if (_sortMode != PlanSortMode.time) {
        return const ColoredBox(
          color: Colors.transparent,
          child: SizedBox.expand(),
        );
      }
      if (tasks.isEmpty) {
        return TickerMode(
          enabled: false,
          child: IgnorePointer(
            child: PlanningDayEmptyState(onFocusQuickAdd: () {}),
          ),
        );
      }
      final frozenActualByPbId = DatabaseService.instance
          .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
      return TickerMode(
        enabled: false,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: timeView.buildHourGridView(tasks, frozenActualByPbId),
          ),
        ),
      );
    }
    final planActualByPbId = DatabaseService.instance
        .aggregateSourcePlanActualSecondsForWallCalendarDay(wallDay);
""",
)

test_path = Path("test/auto_plan_nearest_free_slot_test.dart")
test_text = test_path.read_text(encoding="utf-8")
needle = "\n}\n"
insert = r'''

  test('Time View date swipe prewarms adjacent day and activates after settle', () {
    final shell = File(
      'lib/features/planning/planning_page_shell.dart',
    ).readAsStringSync();
    expect(shell, contains('late int _activePageIndex;'));
    expect(shell, contains('allowImplicitScrolling: true,'));
    expect(shell, contains('index == _activePageIndex'));
    expect(shell, contains('if (n.depth != 0) return false;'));
    expect(shell, contains('_activateVisiblePageAfterSettle();'));

    final pageChangedStart = shell.indexOf('onPageChanged: (int index) {');
    final itemBuilderStart = shell.indexOf(
      'itemBuilder: (context, index) {',
      pageChangedStart,
    );
    expect(pageChangedStart, greaterThanOrEqualTo(0));
    expect(itemBuilderStart, greaterThan(pageChangedStart));
    final pageChangedBlock = shell.substring(pageChangedStart, itemBuilderStart);
    expect(pageChangedBlock, isNot(contains('_activePageIndex')));
    expect(pageChangedBlock, isNot(contains('onPageSettled(')));

    final planning = File(
      'lib/features/planning/planning_page.dart',
    ).readAsStringSync();
    final inactiveStart = planning.indexOf('if (!widget.isActivePlanningDay) {');
    final actualStart = planning.indexOf(
      'final planActualByPbId = DatabaseService.instance',
      inactiveStart,
    );
    expect(inactiveStart, greaterThanOrEqualTo(0));
    expect(actualStart, greaterThan(inactiveStart));
    final inactiveBlock = planning.substring(inactiveStart, actualStart);
    expect(inactiveBlock, contains('_sortMode != PlanSortMode.time'));
    expect(inactiveBlock, contains('TickerMode('));
    expect(inactiveBlock, contains('enabled: false'));
    expect(inactiveBlock, contains('IgnorePointer('));
    expect(inactiveBlock, contains('timeView.buildHourGridView('));
  });
'''
if not test_text.endswith(needle):
    raise SystemExit("Unexpected test file ending")
test_path.write_text(test_text[:-len(needle)] + insert + needle, encoding="utf-8")

changelog = Path("CHANGELOG.md")
changelog_text = changelog.read_text(encoding="utf-8")
entry = """## 2026-09-30 — Planning Time View date-swipe frame pacing [fix]\n- Adjacent Time View dates now render frozen snapshot content ahead of the horizontal swipe instead of staying blank until page activation.\n- Live Planning resources and shell date commits now switch only after the horizontal pager settles, removing recurrence/timezone/layout activation work from the swipe threshold without restoring the old multi-day mounted strip.\n- Nested vertical Time View scroll notifications no longer drive the horizontal date-pager settle gate.\n\n"""
if entry not in changelog_text:
    changelog.write_text(entry + changelog_text, encoding="utf-8")
