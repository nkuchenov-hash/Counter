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
    if (message != null) lastError = message;
    notifyListeners();
  }

  void setLastError(String? error) {
    lastError = error;
    notifyListeners();
  }

  void clearErrors() {
    authPaused = false;
    lastError = null;
    notifyListeners();
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
