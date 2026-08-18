import 'package:counter/data/local_sync/plan_mutation_outbox.dart';
import 'package:counter/data/local_sync/record_mutation_outbox.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global offline / sync indicator state rendered by shell presentation.
///
/// **Invariant:** red sync-error banner only when [hasBlockingSyncError] is true
/// (pending work exists + [lastError]). Stale [lastError] with empty outbox is suppressed.
class OfflineSyncController extends ChangeNotifier {
  bool isOffline = false;
  int pendingCount = 0;
  int recordsOutboxCount = 0;
  int plansOutboxCount = 0;
  bool isSyncing = false;
  bool authPaused = false;
  String? lastError;

  /// Red sync-error banner: real failure with queued mutations only.
  bool get hasBlockingSyncError =>
      !authPaused &&
      pendingCount > 0 &&
      lastError != null &&
      lastError!.isNotEmpty;

  bool get isFullySynced =>
      !isSyncing &&
      !authPaused &&
      !hasBlockingSyncError &&
      pendingCount == 0;

  bool get shouldShowBanner =>
      isSyncing || authPaused || hasBlockingSyncError || pendingCount > 0;

  /// Mirrors [OfflineSyncStatusBar] label branches for diagnostics.
  String get bannerKindLabel {
    if (isSyncing) return 'syncing';
    if (authPaused) return 'auth_paused';
    if (hasBlockingSyncError) return 'sync_error';
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
    if (error == null || error.isEmpty) {
      if (lastError != null) {
        lastError = null;
        notifyListeners();
      }
      return;
    }
    lastError = error;
    _syncDiagPrint(
      'SYNC_BANNER_ERROR: $error pending=$pendingCount '
      'records=$recordsOutboxCount plans=$plansOutboxCount',
    );
    if (pendingCount == 0 && !authPaused) {
      suppressStaleErrorIfEmptyOutbox();
      return;
    }
    notifyListeners();
  }

  void clearErrors() {
    authPaused = false;
    lastError = null;
    notifyListeners();
  }

  /// Drop in-memory [lastError] when outboxes are empty — never user-facing.
  bool suppressStaleErrorIfEmptyOutbox() {
    if (authPaused || pendingCount != 0) return false;
    if (lastError == null || lastError!.isEmpty) {
      if (isOffline) {
        isOffline = false;
        notifyListeners();
      }
      return false;
    }
    final stale = lastError;
    lastError = null;
    isOffline = false;
    _syncDiagPrint(
      'SYNC_STALE_ERROR_SUPPRESSED pending=0 lastError=$stale',
    );
    notifyListeners();
    return true;
  }

  /// UI safety guard — call before reading [shouldShowBanner].
  void ensureBannerInvariant({bool syncFlushInFlight = false}) {
    suppressStaleErrorIfEmptyOutbox();
    reconcileStuckSyncingBanner(syncFlushInFlight: syncFlushInFlight);
  }

  /// Clears [isSyncing] when queues are empty and no flush is in flight.
  void reconcileStuckSyncingBanner({bool syncFlushInFlight = false}) {
    if (pendingCount == 0 &&
        recordsOutboxCount == 0 &&
        plansOutboxCount == 0 &&
        isSyncing &&
        !syncFlushInFlight) {
      setSyncing(false);
    }
  }

  /// When outboxes are empty and auth is valid: drop stale in-memory error/offline flags.
  void reconcileAfterDrain() {
    if (authPaused) return;
    reconcileStuckSyncingBanner();
    suppressStaleErrorIfEmptyOutbox();
  }

  /// Boot / foreground: load prefs counts, reconcile empty queues, notify UI.
  Future<void> bootstrapFromOutboxes({bool pbBackoffActive = false}) async {
    await refreshPendingCount(reconcile: true);
    suppressStaleErrorIfEmptyOutbox();
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
    ensureBannerInvariant();
    final sig =
        '$bannerKind|$pendingCount|${lastError ?? ''}|$authPaused|'
        '$recordsOutboxCount|$plansOutboxCount|$pbBackoffActive';
    if (_visibleDiagLoggedThisBoot && _lastVisibleDiagSignature == sig) {
      return;
    }
    _lastVisibleDiagSignature = sig;
    _visibleDiagLoggedThisBoot = true;
    _syncDiagPrint(
      'SYNC_BANNER_VISIBLE pendingCount=$pendingCount '
      'lastError=${lastError ?? '-'} authPaused=$authPaused '
      'kind=$bannerKind isOffline=$isOffline isSyncing=$isSyncing '
      'recordsOutbox=$recordsOutboxCount plansOutbox=$plansOutboxCount '
      'blockingError=$hasBlockingSyncError backoff=$pbBackoffActive '
      'controller=#$hashCode route=${routeTab ?? '-'}',
    );
  }

  static void resetVisibleDiagForNewSession() {
    _lastVisibleDiagSignature = null;
    _visibleDiagLoggedThisBoot = false;
  }

  void logTapRetry({required String phase}) {
    _syncDiagPrint(
      'SYNC_BANNER_$phase pendingCount=$pendingCount '
      'lastError=${lastError ?? '-'} authPaused=$authPaused '
      'blockingError=$hasBlockingSyncError '
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
      final countChanged = pendingCount != next;
      pendingCount = next;
      if (pendingCount == 0) {
        final suppressed = suppressStaleErrorIfEmptyOutbox();
        if (!suppressed && countChanged) notifyListeners();
      } else {
        notifyListeners();
      }
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
