// ---------------------------------------------------------------------------
// Shell layout — UI-only: FAB clearance vs mass-edit bars, active tab index.
// Not part of DatabaseService / PocketBase (domain isolation).
// ---------------------------------------------------------------------------

import 'package:flutter/widgets.dart';

/// Holds shell chrome layout driven by [LifeOSDashboard] and mass-edit on
/// Planning (tab 1) / Lists (tab 3).
class ShellLayoutController extends ChangeNotifier {
  int _primaryTabIndex = 0;
  double _fabBottomReservePx = 0;

  int get primaryTabIndex => _primaryTabIndex;

  double get fabBottomReservePx => _fabBottomReservePx;

  /// Called from the shell each build with the current [IndexedStack] index.
  /// Clears [fabBottomReservePx] when leaving Planning / Lists.
  void applyShellFrame(int shellPageIndex) {
    var changed = false;
    if (_primaryTabIndex != shellPageIndex) {
      _primaryTabIndex = shellPageIndex;
      changed = true;
    }
    if (shellPageIndex != 1 && shellPageIndex != 3 && _fabBottomReservePx != 0) {
      _fabBottomReservePx = 0;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Planning (1) / Lists (3) set extra bottom inset for the voice FAB.
  void setFabBottomReservePx(double px) {
    if (_primaryTabIndex != 1 && _primaryTabIndex != 3) {
      return;
    }
    if (_fabBottomReservePx == px) {
      return;
    }
    _fabBottomReservePx = px;
    notifyListeners();
  }
}

/// Provides [ShellLayoutController] to Planning / Lists without coupling them
/// to [DatabaseService].
class ShellLayoutScope extends InheritedNotifier<ShellLayoutController> {
  const ShellLayoutScope({
    super.key,
    required ShellLayoutController controller,
    required super.child,
  }) : super(notifier: controller);

  static ShellLayoutController? _maybeController(
    BuildContext context, {
    required bool listen,
  }) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<ShellLayoutScope>();
      return scope?.notifier;
    }
    final element =
        context.getElementForInheritedWidgetOfExactType<ShellLayoutScope>();
    final scope = element?.widget as ShellLayoutScope?;
    return scope?.notifier;
  }

  static ShellLayoutController read(BuildContext context, {bool listen = true}) {
    final c = _maybeController(context, listen: listen);
    assert(c != null, 'ShellLayoutScope missing above this context');
    return c!;
  }
}
