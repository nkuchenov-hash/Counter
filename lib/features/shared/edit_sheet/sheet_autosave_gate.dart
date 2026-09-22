import 'dart:async';

/// Debounced background sync for edit sheets; [flush] on explicit Save / close.
///
/// The gate is revision-aware: completion of an older async save must never
/// mark a newer local edit clean. This is a correctness invariant for live
/// optimistic editing, not merely a debounce helper.
class EditSheetAutosaveGate {
  EditSheetAutosaveGate({this.debounce = const Duration(milliseconds: 100)});

  final Duration debounce;
  Timer? _timer;
  bool _dirty = false;
  int _revision = 0;
  int _lastDispatchedRevision = 0;

  bool get isDirty => _dirty;

  /// Monotonic local edit generation. Useful in tests/diagnostics.
  int get revision => _revision;

  void markDirty() {
    _dirty = true;
    _revision++;
  }

  /// Marks clean only when no edit newer than the most recently dispatched
  /// save exists. An older request finishing after fresh typing is ignored.
  void markClean() {
    if (_revision != _lastDispatchedRevision) return;
    _dirty = false;
  }

  void schedule(void Function() action) {
    markDirty();
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      if (!_dirty) return;
      _lastDispatchedRevision = _revision;
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
    // The dispatched revision is locally clean. A later edit increments
    // [_revision], and completion of this request cannot clear that edit.
    if (_revision == _lastDispatchedRevision) {
      _dirty = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
