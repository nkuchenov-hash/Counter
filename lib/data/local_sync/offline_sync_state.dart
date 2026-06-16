import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global offline / sync indicator state for [app_shell.dart].
///
/// Banner visibility (O1.4): quiet only when [pendingCount] is 0 and not syncing/error.
/// Online-with-pending shows a subtle pending label until [flushPendingLocalMutations] drains.
///
/// [lastError] is **in-memory only** (not persisted). Stale errors clear via [reconcileAfterDrain].
class OfflineSyncController extends ChangeNotifier {
  bool isOffline = false;
  int pendingCount = 0;
  int recordsOutboxCount = 0;
  int plansOutboxCount = 0;
  bool isSyncing = false;
  bool authPaused = false;
  String? lastError;

  bool get isFullySynced =>
      !isSyncing &&
      !authPaused &&
      (lastError == null || lastError!.isEmpty) &&
      pendingCount == 0;

  bool get shouldShowBanner => !isFullySynced;

  /// Mirrors [_OfflineSyncStatusBar] label branch for diagnostics.
  String get bannerKindLabel {
    if (isSyncing) return 'syncing';
    if (authPaused) return 'auth_paused';
    if (lastError != null && lastError!.isNotEmpty) return 'sync_error';
    if (isOffline) return 'offline_pending';
    if (pendingCount > 0) return 'online_pending';
    return 'unknown';
  }

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
    if (paused && message != null) {
      _syncDiagPrint('SYNC_BANNER_ERROR: auth_paused message=$message');
    }
    notifyListeners();
  }

  void setLastError(String? error) {
    lastError = error;
    if (error != null && error.isNotEmpty) {
      _syncDiagPrint(
        'SYNC_BANNER_ERROR: $error pending=$pendingCount '
        'records=$recordsOutboxCount plans=$plansOutboxCount',
      );
    }
    notifyListeners();
  }

  void clearErrors() {
    authPaused = false;
    lastError = null;
    notifyListeners();
  }

  /// When outboxes are empty and auth is valid: drop stale in-memory error/offline flags.
  void reconcileAfterDrain() {
    if (authPaused || isSyncing) return;
    if (pendingCount != 0) return;
    final hadStaleError = lastError != null && lastError!.isNotEmpty;
    final hadOffline = isOffline;
    if (!hadStaleError && !hadOffline) return;
    lastError = null;
    isOffline = false;
    _syncDiagPrint(
      'SYNC_RECONCILE_CLEARED staleError=$hadStaleError staleOffline=$hadOffline',
    );
    notifyListeners();
  }

  /// Boot / foreground: load prefs counts, reconcile empty queues, notify UI.
  Future<void> bootstrapFromOutboxes({bool pbBackoffActive = false}) async {
    await refreshPendingCount(reconcile: true);
    if (pendingCount == 0 && !authPaused) {
      reconcileAfterDrain();
    }
    _syncDiagPrint(
      'SYNC_BOOTSTRAP pending=$pendingCount records=$recordsOutboxCount '
      'plans=$plansOutboxCount lastError=${lastError ?? '-'} '
      'authPaused=$authPaused backoff=$pbBackoffActive',
    );
  }

  static String? _lastVisibleDiagSignature;
  static bool _visibleDiagLoggedThisBoot = false;

  /// Called when the banner becomes visible — uses [print] (works in release web).
  Future<void> logVisibleBannerState({
    required String bannerKind,
    String? routeTab,
    bool pbBackoffActive = false,
  }) async {
    await refreshPendingCount();
    final sig =
        '$bannerKind|$pendingCount|${lastError ?? ''}|$authPaused|'
        '$recordsOutboxCount|$plansOutboxCount|$pbBackoffActive';
    if (_visibleDiagLoggedThisBoot && _lastVisibleDiagSignature == sig) {
      return;
    }
    _lastVisibleDiagSignature = sig;
    _visibleDiagLoggedThisBoot = true;
    _syncDiagPrint(
      'SYNC_BANNER_VISIBLE kind=$bannerKind pendingCount=$pendingCount '
      'lastError=${lastError ?? '-'} authPaused=$authPaused '
      'isOffline=$isOffline isSyncing=$isSyncing '
      'recordsOutbox=$recordsOutboxCount plansOutbox=$plansOutboxCount '
      'backoff=$pbBackoffActive controller=#$hashCode '
      'route=${routeTab ?? '-'}',
    );
  }

  static void resetVisibleDiagForNewSession() {
    _lastVisibleDiagSignature = null;
    _visibleDiagLoggedThisBoot = false;
  }

  void logTapRetry({required String phase}) {
    _syncDiagPrint(
      'SYNC_BANNER_${phase} pendingCount=$pendingCount '
      'lastError=${lastError ?? '-'} authPaused=$authPaused '
      'recordsOutbox=$recordsOutboxCount plansOutbox=$plansOutboxCount',
    );
  }

  /// Call when PocketBase session is valid again (login / tap-to-retry) so flush can resume.
  void resumeAfterAuthIfNeeded() {
    if (!authPaused) return;
    authPaused = false;
    lastError = null;
    notifyListeners();
  }

  Future<void> refreshPendingCount({bool reconcile = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plans = await PlanMutationOutbox.load(prefs);
      final records = await RecordMutationOutbox.load(prefs);
      recordsOutboxCount = records.length;
      plansOutboxCount = plans.length;
      final next = records.length + plans.length;
      pendingCount = next;
      if (reconcile && next == 0 && !authPaused && !isSyncing) {
        final hadStale = (lastError != null && lastError!.isNotEmpty) || isOffline;
        lastError = null;
        isOffline = false;
        if (hadStale) {
          _syncDiagPrint('SYNC_RECONCILE_ON_REFRESH cleared stale banner state');
        }
      }
      notifyListeners();
    } catch (e) {
      _syncDiagPrint('SYNC_REFRESH_PENDING_COUNT_FAIL: $e');
    }
  }

  /// Release-safe diagnostics ([debugPrint] is stripped on web release builds).
  static void _syncDiagPrint(String line) {
    // ignore: avoid_print
    print(line);
  }
}
