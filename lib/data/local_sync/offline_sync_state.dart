import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global offline / sync indicator state for [app_shell.dart].
///
/// Banner visibility (O1.4): quiet only when [pendingCount] is 0 and not syncing/error.
/// Online-with-pending shows a subtle pending label until [flushPendingLocalMutations] drains.
class OfflineSyncController extends ChangeNotifier {
  bool isOffline = false;
  int pendingCount = 0;
  bool isSyncing = false;
  bool authPaused = false;
  String? lastError;

  bool get isFullySynced =>
      !isSyncing &&
      !authPaused &&
      (lastError == null || lastError!.isEmpty) &&
      pendingCount == 0;

  bool get shouldShowBanner => !isFullySynced;

  void setConnectivityOffline(bool offline) {
    if (isOffline == offline) return;
    isOffline = offline;
    notifyListeners();
  }

  void setSyncing(bool syncing) {
    if (isSyncing == syncing) return;
    isSyncing = syncing;
    notifyListeners();
  }

  void setAuthPaused(bool paused, {String? message}) {
    authPaused = paused;
    if (paused) isSyncing = false;
    if (message != null) lastError = message;
    notifyListeners();
  }

  void setLastError(String? error) {
    lastError = error;
    if (error != null && error.isNotEmpty) {
      _debouncedSyncErrorLog(error);
    }
    notifyListeners();
  }

  void clearErrors() {
    authPaused = false;
    lastError = null;
    notifyListeners();
  }

  /// After drain attempt: hide error banner when no pending work remains.
  void reconcileAfterDrain() {
    if (pendingCount != 0 || authPaused || isSyncing) return;
    if (lastError == null || lastError!.isEmpty) {
      if (isOffline) {
        isOffline = false;
        notifyListeners();
      }
      return;
    }
    lastError = null;
    if (isOffline) isOffline = false;
    notifyListeners();
  }

  static String? _lastDebouncedLogLine;
  static DateTime? _lastDebouncedLogAt;
  static const Duration _syncLogDebounce = Duration(seconds: 15);

  void _debouncedSyncErrorLog(String error) {
    final now = DateTime.now();
    final line = 'SYNC_BANNER_ERROR: $error (pending=$pendingCount)';
    if (_lastDebouncedLogLine == line &&
        _lastDebouncedLogAt != null &&
        now.difference(_lastDebouncedLogAt!) < _syncLogDebounce) {
      return;
    }
    _lastDebouncedLogLine = line;
    _lastDebouncedLogAt = now;
    debugPrint(line);
  }

  /// Call when PocketBase session is valid again (login / tap-to-retry) so flush can resume.
  void resumeAfterAuthIfNeeded() {
    if (!authPaused) return;
    authPaused = false;
    lastError = null;
    notifyListeners();
  }

  Future<void> refreshPendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plans = await PlanMutationOutbox.load(prefs);
      final records = await RecordMutationOutbox.load(prefs);
      final next = plans.length + records.length;
      if (pendingCount != next) {
        pendingCount = next;
        notifyListeners();
      } else if (!shouldShowBanner) {
        notifyListeners();
      }
    } catch (_) {}
  }
}
