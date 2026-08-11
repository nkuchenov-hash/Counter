from pathlib import Path

p = Path('lib/features/timeline/timeline_view.dart')
s = p.read_text()
old = """      if (page >= 0 && page < _totalPageCount) {
        _visiblePageIndex = page;
        _settleGate.resetCommittedPage(page);
        if (_controller.hasClients) _controller.jumpToPage(page);
      }
"""
new = """      if (page >= 0 && page < _totalPageCount) {
        _visiblePageIndex = page;
        _settleGate.resetCommittedPage(page);
        if (_controller.hasClients) {
          _controller.jumpToPage(page);
        } else {
          // List mode does not mount the PageView. Recreate the controller so
          // its initial page matches the date currently pinned in Timeline;
          // otherwise Stats would reopen on the app's original launch date.
          _controller.removeListener(_onPageControllerTick);
          _controller.dispose();
          _controller = PageController(initialPage: page);
          _controller.addListener(_onPageControllerTick);
        }
      }
"""
if new in s:
    raise SystemExit(0)
if old not in s:
    raise SystemExit('stats controller anchor not found')
p.write_text(s.replace(old, new, 1))
