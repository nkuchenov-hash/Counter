import 'dart:async';

/// Debounced background sync for edit sheets; [flush] on explicit Save / close.
///
/// Correctness rule: completion of an older async save must never cancel a
/// newer edit that is still waiting for its debounce window. A pending timer
/// therefore represents unsent user intent and cannot be cleared by
/// [markClean].
class EditSheetAutosaveGate {
  EditSheetAutosaveGate({this.debounce = const Duration(milliseconds: 100)});

  final Duration debounce;
  Timer? _timer;
  bool _dirty = false;
  int _revision = 0;
  int _lastDispatchedRevision = 0;

  bool get isDirty => _dirty;

  /// Monotonic local edit generation for diagnostics/tests.
  int get revision => _revision;

  void markDirty() {
    _dirty = true;
    _revision++;
  }

  /// Marks the sheet clean only when there is no newer debounced edit waiting
  /// to be sent. This prevents an older network request from suppressing the
  /// next rename/edit while it is still inside the debounce window.
  void markClean() {
    if (_timer != null) return;
    _dirty = false;
  }

  void schedule(void Function() action) {
    markDirty();
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      _lastDispatchedRevision = _revision;
      // The timer itself is proof that this user edit was scheduled. Run it
      // even if an older async completion attempted to mark the sheet clean.
      action();
    });
  }

  /// Runs [action] immediately and cancels any pending debounce.
  /// When [force] is true (explicit Save), runs even if not dirty.
  void flush(void Function() action, {bool force = false}) {
    _timer?.cancel();
    _timer = null;
    if (force || _dirty) {
      _lastDispatchedRevision = _revision;
      action();
    }
    _dirty = false;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
