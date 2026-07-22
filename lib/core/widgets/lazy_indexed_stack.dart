import 'package:counter/shared/diagnostics/startup_log.dart';
import 'package:flutter/material.dart';
/// [IndexedStack] that lazily builds children on first visit and pauses
/// off-screen tabs (no paint, no tickers) for smoother shell navigation.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  static bool _bootDeferLogged = false;
  static const List<String> _tabNames = [
    'Timeline',
    'Plans',
    'Calendar',
    'Lists',
    'Categories',
    'Profile',
  ];

  late List<bool> _visited;

  @override
  void initState() {
    super.initState();
    _visited = List<bool>.filled(widget.children.length, false);
    _markVisited(widget.index);
    if (!_bootDeferLogged) {
      _bootDeferLogged = true;
      for (var i = 0; i < _tabNames.length && i < widget.children.length; i++) {
        if (i != widget.index) {
          StartupLog.hiddenTabDeferred(
            tab: _tabNames[i],
            reason: 'firstFramePriority',
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _visited.length) {
      final next = List<bool>.filled(widget.children.length, false);
      for (var i = 0; i < next.length && i < _visited.length; i++) {
        next[i] = _visited[i];
      }
      _visited = next;
    }
    final idx = widget.index;
    final wasVisited = idx >= 0 && idx < _visited.length && _visited[idx];
    _markVisited(idx);
    if (!wasVisited &&
        idx >= 0 &&
        idx < _visited.length &&
        _visited[idx] &&
        idx < _tabNames.length) {
      final sw = Stopwatch()..start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sw.stop();
        StartupLog.hiddenTabActivated(
          tab: _tabNames[idx],
          ms: sw.elapsedMilliseconds,
        );
      });
    }
  }

  void _markVisited(int i) {
    if (i < 0 || i >= _visited.length) return;
    _visited[i] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_visited[i])
            Offstage(
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: RepaintBoundary(
                  child: widget.children[i],
                ),
              ),
            ),
      ],
    );
  }
}
