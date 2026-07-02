import 'dart:async';/// Debounced background sync for edit sheets; [flush] on explicit Save / close.
class EditSheetAutosaveGate {
  EditSheetAutosaveGate({this.debounce = const Duration(milliseconds: 650)});

  final Duration debounce;
  Timer? _timer;
  bool _dirty = false;

  bool get isDirty => _dirty;

  void markDirty() => _dirty = true;

  void markClean() => _dirty = false;

  void schedule(void Function() action) {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (_dirty) action();
    });
  }

  /// Runs [action] immediately and cancels any pending debounce.
  /// When [force] is true (explicit Save), runs even if not dirty.
  void flush(void Function() action, {bool force = false}) {
    _timer?.cancel();
    if (force || _dirty) {
      action();
    }
    _dirty = false;
  }

  void dispose() => _timer?.cancel();
}
