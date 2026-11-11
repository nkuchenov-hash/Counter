import 'dart:async';

/// Coordinates horizontal day pager: blocks external sync during user drag,
/// debounces shell date commits, and ignores duplicate page targets.
///
/// **Runtime behavior:** required by Timeline/Plans [PageView] date swipe — not diagnostic.
final class DatePagerSettleGate {
  DatePagerSettleGate({this.commitDebounce = const Duration(milliseconds: 36)});

  final Duration commitDebounce;

  Timer? _commitTimer;
  bool userDragInFlight = false;
  bool programmaticAnimInFlight = false;
  int? _lastCommittedPage;

  bool get blocksExternalDateSync =>
      userDragInFlight || programmaticAnimInFlight;

  void onUserDragStart() {
    userDragInFlight = true;
    _commitTimer?.cancel();
  }

  /// A second touch or button-driven animation can start within the 36ms
  /// settle debounce. Suppress stale shell commits until its final ScrollEnd.
  void cancelPendingCommit() => _commitTimer?.cancel();

  void onUserDragEnd() => userDragInFlight = false;

  void markProgrammaticAnimStart() => programmaticAnimInFlight = true;

  void markProgrammaticAnimEnd() => programmaticAnimInFlight = false;

  /// Updates visible page immediately; debounces [onShellCommit] for shell/prefetch.
  void onPageSettled({
    required int pageIndex,
    required void Function(int pageIndex) onShellCommit,
  }) {
    if (_lastCommittedPage == pageIndex) return;
    _commitTimer?.cancel();
    _commitTimer = Timer(commitDebounce, () {
      if (_lastCommittedPage == pageIndex) return;
      _lastCommittedPage = pageIndex;
      onShellCommit(pageIndex);
    });
  }

  void resetCommittedPage(int pageIndex) => _lastCommittedPage = pageIndex;

  void dispose() {
    _commitTimer?.cancel();
    _commitTimer = null;
  }
}
