import 'dart:async';

import 'package:counter/shared/diagnostics/performance/runtime_flags.dart';
import 'package:counter/services/plan_alarm_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

export 'package:counter/services/plan_alarm_schedule.dart';

const String _kPrefsNotifPermRequested = 'notif_perm_requested_v1';
const String _kPlanPayloadPrefix = 'plan:';
const String _kPeopleBirthdayPayloadPrefix = 'people:birthday:';

/// Stable Windows toast identity (CompanyName.ProductName from Runner.rc).
const String _kWindowsAppUserModelId = 'com.example.counter';
const String _kWindowsNotificationGuid = 'b7e3c4a1-5f2d-4e8b-9c1a-6d4f8e2b0a73';

/// Permission / platform diagnostic for plan alarms.
enum PlanAlarmPermissionStatus {
  allowed,
  denied,
  permanentlyDenied,
  unsupported,
  unknown,
}

/// Canonical OS scheduler for Life OS notifications.
///
/// Plan reminders and People birthday reminders share one plugin but keep
/// separate payload namespaces. Reconciliation for one owner must never cancel
/// notifications owned by another feature.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _schedulingSupported = false;
  Completer<void>? _initCompleter;
  String? _lastDiag;
  DateTime? _lastDiagAt;

  String? get lastDiagnostic => _lastDiag;

  bool get schedulingSupported => _schedulingSupported;

  /// Idempotent; safe to call from background. Web / unsupported = no-op success.
  Future<void> ensureInitialized() {
    if (kIsWeb || !_platformMaySchedule) {
      _initialized = true;
      _schedulingSupported = false;
      return Future.value();
    }
    if (_initialized) return Future.value();
    if (_initCompleter != null) return _initCompleter!.future;
    final c = Completer<void>();
    _initCompleter = c;
    unawaited(_initInner(c));
    return c.future;
  }

  bool get _platformMaySchedule {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<void> _initInner(Completer<void> completer) async {
    try {
      try {
        tz_data.initializeTimeZones();
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (_) {
        try {
          tz.setLocalLocation(tz.UTC);
        } catch (_) {}
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const windowsInit = WindowsInitializationSettings(
        appName: 'Life OS',
        appUserModelId: _kWindowsAppUserModelId,
        guid: _kWindowsNotificationGuid,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
        windows: windowsInit,
      );

      final ok = await _plugin.initialize(settings: initSettings);
      _initialized = true;
      _schedulingSupported = ok != false;
      completer.complete();
      // First-run permission only (persisted). Never blocks UI callers.
      unawaited(requestPermissionsIfNeeded());
    } catch (e, st) {
      _diag('init_failed', '$e');
      _initialized = true;
      _schedulingSupported = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
      _initCompleter = null;
      assert(() {
        debugPrint('[PLAN_ALARM] init_failed $e\n$st');
        return true;
      }());
    }
  }

  /// First run only (persisted flag). Does not re-prompt on every startup.
  Future<PlanAlarmPermissionStatus> requestPermissionsIfNeeded() async {
    if (kIsWeb || !_platformMaySchedule) {
      return PlanAlarmPermissionStatus.unsupported;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return PlanAlarmPermissionStatus.unknown;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPrefsNotifPermRequested) ?? false) {
      return permissionStatus();
    }
    await prefs.setBool(_kPrefsNotifPermRequested, true);
    return requestPermissions();
  }

  /// Explicit user flow (Profile). Always attempts a platform permission request.
  Future<PlanAlarmPermissionStatus> requestPermissions() async {
    if (kIsWeb || !_platformMaySchedule) {
      return PlanAlarmPermissionStatus.unsupported;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return PlanAlarmPermissionStatus.unknown;
    }
    if (!_schedulingSupported) {
      return PlanAlarmPermissionStatus.unsupported;
    }

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        _diag('permission_android', 'granted=$granted');
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _diag('permission_ios', 'granted=$granted');
      }

      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (mac != null) {
        final granted = await mac.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _diag('permission_macos', 'granted=$granted');
      }
    } catch (e) {
      _diag('permission_failed', '$e');
    }
    return permissionStatus();
  }

  Future<PlanAlarmPermissionStatus> permissionStatus() async {
    if (kIsWeb || !_platformMaySchedule) {
      return PlanAlarmPermissionStatus.unsupported;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return PlanAlarmPermissionStatus.unknown;
    }
    if (!_schedulingSupported) {
      return PlanAlarmPermissionStatus.unsupported;
    }

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == true) return PlanAlarmPermissionStatus.allowed;
        if (enabled == false) return PlanAlarmPermissionStatus.denied;
        return PlanAlarmPermissionStatus.unknown;
      }
      // iOS/macOS/Windows: plugin has no uniform query; treat as unknown unless
      // scheduling is unsupported.
      return PlanAlarmPermissionStatus.unknown;
    } catch (e) {
      _diag('permission_status_failed', '$e');
      return PlanAlarmPermissionStatus.unknown;
    }
  }

  /// Schedule or replace one plan reminder (same [PlanAlarmSpec.notificationId]).
  Future<bool> scheduleOrReplacePlanReminder(PlanAlarmSpec spec) async {
    if (!_canSchedule) return false;
    try {
      await ensureInitialized();
    } catch (_) {
      return false;
    }
    if (!_schedulingSupported) return false;
    return _scheduleOne(spec);
  }

  /// Cancel one plan reminder by notification id.
  Future<void> cancelPlanReminder(int notificationId) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      await _plugin.cancel(id: notificationId);
      _diag('cancel', 'id=$notificationId');
    } catch (e) {
      _diag('cancel_failed', 'id=$notificationId err=$e');
    }
  }

  String _planOccurrenceKeyFromPayload(String payload) {
    if (payload.startsWith(_kPlanPayloadPrefix)) {
      return payload.substring(_kPlanPayloadPrefix.length);
    }
    return payload;
  }

  bool _isPlanOwnedPayload(String payload) {
    if (payload.startsWith(_kPlanPayloadPrefix)) return true;
    if (payload.startsWith('people:')) return false;
    // Backward compatibility: releases before People stored raw occurrence keys.
    return payload.isNotEmpty;
  }

  /// Cancel reminders whose occurrence key belongs to [planStableKey]
  /// (exact match or `planStableKey|…` / `virt-planStableKey-…` prefixes).
  Future<void> cancelRemindersForPlan(String planStableKey) async {
    final key = planStableKey.trim();
    if (key.isEmpty || kIsWeb) return;
    try {
      await ensureInitialized();
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final rawPayload = p.payload ?? '';
        if (!_isPlanOwnedPayload(rawPayload)) continue;
        final payload = _planOccurrenceKeyFromPayload(rawPayload);
        if (payload == key ||
            payload.startsWith('$key|') ||
            payload.startsWith('virt-$key-')) {
          await _plugin.cancel(id: p.id);
        }
      }
      // Also cancel deterministic id for bare key (non-recurring without date).
      await _plugin.cancel(
        id: planAlarmNotificationIdFromStableKey(key),
      );
      _diag('cancel_plan', 'key=$key');
    } catch (e) {
      _diag('cancel_plan_failed', 'key=$key err=$e');
    }
  }

  /// Cancel every pending notification owned by plan alarms, preserving People
  /// birthday reminders and any future namespaced notification owners.
  Future<void> cancelAllPlanReminders() async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
      final pending = await _plugin.pendingNotificationRequests();
      var cancelled = 0;
      for (final request in pending) {
        final payload = request.payload ?? '';
        if (!_isPlanOwnedPayload(payload)) continue;
        await _plugin.cancel(id: request.id);
        cancelled++;
      }
      _diag('cancel_all_plans', 'cancelled=$cancelled');
    } catch (e) {
      _diag('cancel_all_plans_failed', '$e');
    }
  }

  /// Idempotent reconcile: replace pending plan queue with [specs] while leaving
  /// People and other notification namespaces untouched.
  ///
  /// Does not touch network. Safe after startup / resume / plan hydrate.
  Future<void> reconcilePlanAlarms(List<PlanAlarmSpec> specs) async {
    if (kIsWeb || !_platformMaySchedule) return;
    try {
      await ensureInitialized();
    } catch (_) {
      return;
    }
    if (!_schedulingSupported) {
      _diag('reconcile_skip', 'scheduling_unsupported');
      return;
    }

    final finalized = finalizePlanAlarmSpecs(specs);
    var scheduled = 0;
    var failed = 0;

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (_isPlanOwnedPayload(request.payload ?? '')) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (e) {
      _diag('reconcile_cancel_failed', '$e');
    }

    for (final s in finalized) {
      final ok = await _scheduleOne(s, quietSuccess: true);
      if (ok) {
        scheduled++;
      } else {
        failed++;
      }
    }

    _diag(
      'reconcile',
      'requested=${specs.length} finalized=${finalized.length} '
          'scheduled=$scheduled failed=$failed',
    );
  }

  /// Legacy Brain entry: maps expanded tasks via caller-built specs preferred.
  /// Prefer [reconcilePlanAlarms].
  @Deprecated('Use reconcilePlanAlarms with Brain-built PlanAlarmSpec list')
  Future<void> syncAlarms(List<PlanAlarmSpec> specs) =>
      reconcilePlanAlarms(specs);

  bool get _canSchedule => !kIsWeb && _platformMaySchedule;

  Future<bool> _scheduleOne(
    PlanAlarmSpec spec, {
    bool quietSuccess = false,
  }) async {
    final when = tz.TZDateTime.from(spec.fireUtc.toUtc(), tz.UTC);
    final now = tz.TZDateTime.now(tz.UTC);
    if (!when.isAfter(now)) {
      _diag('reject', 'past id=${spec.notificationId}');
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'plan_alarms',
      'Plan reminders',
      channelDescription: 'Reminders before scheduled plan start times',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    final body = spec.reminderMinutes == 1
        ? 'Starting in 1 minute'
        : 'Starting in ${spec.reminderMinutes} minutes';

    try {
      await _plugin.zonedSchedule(
        id: spec.notificationId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: spec.title,
        body: body,
        payload: '$_kPlanPayloadPrefix${spec.occurrenceKey}',
      );
      if (!quietSuccess) {
        _diag(
          'schedule',
          'id=${spec.notificationId} key=${spec.occurrenceKey} '
              'at=${spec.fireUtc.toIso8601String()}',
        );
      }
      return true;
    } catch (e) {
      _diag(
        'schedule_failed',
        'id=${spec.notificationId} key=${spec.occurrenceKey} err=$e',
      );
      return false;
    }
  }

  /// Schedule one People birthday notification. The payload namespace keeps it
  /// safe from plan reminder reconciliation.
  Future<bool> schedulePeopleBirthdayReminder({
    required int notificationId,
    required String personStableId,
    required DateTime fireUtc,
    required String title,
    required String body,
    required String occurrenceKey,
  }) async {
    final personId = personStableId.trim();
    if (personId.isEmpty || !_canSchedule) return false;
    try {
      await ensureInitialized();
    } catch (_) {
      return false;
    }
    if (!_schedulingSupported) return false;

    final when = tz.TZDateTime.from(fireUtc.toUtc(), tz.UTC);
    final now = tz.TZDateTime.now(tz.UTC);
    if (!when.isAfter(now)) return false;

    const androidDetails = AndroidNotificationDetails(
      'people_birthdays',
      'People birthdays',
      channelDescription: 'Birthday reminders for People tracked in Life OS',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    final payload =
        '$_kPeopleBirthdayPayloadPrefix$personId:${occurrenceKey.trim()}';
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload,
      );
      _diag(
        'people_birthday_schedule',
        'id=$notificationId person=$personId at=${fireUtc.toIso8601String()}',
      );
      return true;
    } catch (e) {
      _diag(
        'people_birthday_schedule_failed',
        'id=$notificationId person=$personId err=$e',
      );
      return false;
    }
  }

  /// Cancel only birthday reminders for one Person.
  Future<void> cancelPeopleBirthdayReminders(String personStableId) async {
    final personId = personStableId.trim();
    if (personId.isEmpty || kIsWeb) return;
    final prefix = '$_kPeopleBirthdayPayloadPrefix$personId:';
    try {
      await ensureInitialized();
      final pending = await _plugin.pendingNotificationRequests();
      var cancelled = 0;
      for (final request in pending) {
        if (!(request.payload ?? '').startsWith(prefix)) continue;
        await _plugin.cancel(id: request.id);
        cancelled++;
      }
      _diag(
        'people_birthday_cancel',
        'person=$personId cancelled=$cancelled',
      );
    } catch (e) {
      _diag('people_birthday_cancel_failed', 'person=$personId err=$e');
    }
  }

  void _diag(String kind, String detail) {
    _lastDiag = '$kind $detail';
    _lastDiagAt = DateTime.now();
    if (!kPlanAlarmDiag && !kDebugMode) return;
    // Avoid identical spam within 2s.
    final at = _lastDiagAt;
    assert(() {
      debugPrint('[PLAN_ALARM] $kind $detail');
      return true;
    }());
    if (kPlanAlarmDiag && !kDebugMode) {
      debugPrint('[PLAN_ALARM] $kind $detail @${at?.toIso8601String()}');
    }
  }

  static const int _kDesktopVoiceNotificationId = 0x7f00d001;
  static const int _kDesktopVoiceStopNotificationId = 0x7f00d002;
  static const int _kDesktopVoiceOverlayUnavailableId = 0x7f00d003;

  /// Immediate OS toast when a desktop voice command starts a record (tray-hidden).
  Future<bool> showDesktopVoiceRecordStarted({required String message}) async {
    return _showImmediate(
      id: _kDesktopVoiceNotificationId,
      message: message,
      channelId: 'desktop_voice',
      channelName: 'Desktop voice',
      channelDescription: 'Record started from desktop voice command',
    );
  }

  /// Immediate OS toast when the desktop voice hotkey stops a running record.
  Future<bool> showDesktopVoiceRecordStopped({required String message}) async {
    return _showImmediate(
      id: _kDesktopVoiceStopNotificationId,
      message: message,
      channelId: 'desktop_voice',
      channelName: 'Desktop voice',
      channelDescription: 'Record stopped from desktop voice hotkey',
    );
  }

  /// Tray-hidden hotkey fallback — voice overlay cannot show without a visible window.
  Future<bool> showDesktopVoiceOverlayUnavailable({
    required String message,
  }) async {
    return _showImmediate(
      id: _kDesktopVoiceOverlayUnavailableId,
      message: message,
      channelId: 'desktop_voice',
      channelName: 'Desktop voice',
      channelDescription: 'Desktop voice overlay unavailable',
    );
  }

  Future<bool> _showImmediate({
    required int id,
    required String message,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    if (kIsWeb) return false;
    try {
      await ensureInitialized();
    } catch (_) {
      return false;
    }
    if (!_schedulingSupported &&
        defaultTargetPlatform != TargetPlatform.windows) {
      // Windows may still show toasts after init even if flag is conservative.
    }
    try {
      await _plugin.show(
        id: id,
        title: message,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
          windows: const WindowsNotificationDetails(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
