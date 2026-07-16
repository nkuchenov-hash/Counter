import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:counter/services/notifications/plan_alarm_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

part 'notifications/desktop_voice_notifications.dart';
part 'notifications/plan_alarm_notifications.dart';

const String _kPrefsNotifPermRequested = 'notif_perm_requested_v1';
const int _kNotificationTestId = 0x7f00d004;

enum NotificationPermissionStatus { allowed, denied, unavailable }

/// Result of replacing Counter's pending plan-reminder queue.
final class PlanAlarmSyncResult {
  const PlanAlarmSyncResult({
    required this.selected,
    required this.scheduled,
    required this.failed,
    required this.cancelFailed,
    this.unsupported = false,
  });

  const PlanAlarmSyncResult.unsupported()
    : selected = 0,
      scheduled = 0,
      failed = 0,
      cancelFailed = 0,
      unsupported = true;

  final int selected;
  final int scheduled;
  final int failed;
  final int cancelFailed;
  final bool unsupported;

  bool get succeeded => !unsupported && failed == 0 && cancelFailed == 0;
}

/// Device bridge for local notification initialization and permissions.
///
/// Plan-alarm and desktop-voice behavior live in focused parts under
/// `services/notifications/`; PocketBase and plan-domain orchestration stay in
/// the Brain.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Completer<void>? _initCompleter;
  String? _lastError;

  String? get lastError => _lastError;

  /// Initializes the platform bridge, then performs the existing one-time
  /// native permission prompt. Explicit requests from Settings bypass this
  /// one-time gate.
  Future<void> initializeAndRequestPermissionsIfNeeded() async {
    await ensureInitialized();
    await requestPermissionsIfNeeded();
  }

  /// Idempotent and safe for concurrent callers.
  Future<void> ensureInitialized() {
    if (kIsWeb) return Future.value();
    if (_initialized) return Future.value();
    final pending = _initCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<void>();
    _initCompleter = completer;
    unawaited(_initInner(completer));
    return completer.future;
  }

  Future<void> _initInner(Completer<void> completer) async {
    try {
      tz_data.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (error, stackTrace) {
        tz.setLocalLocation(tz.UTC);
        _recordError('timezone-fallback', error, stackTrace);
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final linux = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );
      final windows = WindowsInitializationSettings(
        appName: 'Counter',
        appUserModelId: 'com.example.counter',
        guid: '4dc83395-e2c3-4f1e-bfd2-4b17d774a0d8',
      );
      final initialized = await _plugin.initialize(
        settings: InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
          linux: linux,
          windows: windows,
        ),
      );
      if (initialized == false) {
        throw StateError('Local notification plugin returned false');
      }

      _initialized = true;
      _lastError = null;
      completer.complete();
    } catch (error, stackTrace) {
      _recordError('initialize', error, stackTrace);
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _initCompleter = null;
    }
  }

  Future<NotificationPermissionStatus> permissionStatus() async {
    if (kIsWeb) return NotificationPermissionStatus.unavailable;
    try {
      await ensureInitialized();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final enabled = await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled();
          return _statusFromNullableBool(enabled);
        case TargetPlatform.iOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
          return _statusFromDarwinOptions(options);
        case TargetPlatform.macOS:
          final options = await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
          return _statusFromDarwinOptions(options);
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return NotificationPermissionStatus.allowed;
        case TargetPlatform.fuchsia:
          return NotificationPermissionStatus.unavailable;
      }
    } catch (error, stackTrace) {
      _recordError('permission-status', error, stackTrace);
      return NotificationPermissionStatus.unavailable;
    }
  }

  /// Explicit user action. Unlike [requestPermissionsIfNeeded], this always
  /// reaches the platform API and therefore remains usable after a prior deny.
  Future<NotificationPermissionStatus> requestPermissions() async {
    if (kIsWeb) return NotificationPermissionStatus.unavailable;
    try {
      await ensureInitialized();
      return await _requestPermissionsInitialized();
    } catch (error, stackTrace) {
      _recordError('permission-request', error, stackTrace);
      return NotificationPermissionStatus.unavailable;
    }
  }

  /// One automatic native prompt per install. The persisted flag is written
  /// only after the platform request completes, not before it starts.
  Future<NotificationPermissionStatus> requestPermissionsIfNeeded() async {
    if (kIsWeb) return NotificationPermissionStatus.unavailable;
    try {
      await ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPrefsNotifPermRequested) ?? false) {
        return permissionStatus();
      }
      final status = await _requestPermissionsInitialized();
      if (status != NotificationPermissionStatus.unavailable) {
        await prefs.setBool(_kPrefsNotifPermRequested, true);
      }
      return status;
    } catch (error, stackTrace) {
      _recordError('automatic-permission-request', error, stackTrace);
      return NotificationPermissionStatus.unavailable;
    }
  }

  Future<NotificationPermissionStatus> _requestPermissionsInitialized() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        return granted == null
            ? permissionStatus()
            : _statusFromNullableBool(granted);
      case TargetPlatform.iOS:
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted == null
            ? permissionStatus()
            : _statusFromNullableBool(granted);
      case TargetPlatform.macOS:
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted == null
            ? permissionStatus()
            : _statusFromNullableBool(granted);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return NotificationPermissionStatus.allowed;
      case TargetPlatform.fuchsia:
        return NotificationPermissionStatus.unavailable;
    }
  }

  Future<bool> showTestNotification({
    required String title,
    required String body,
  }) async {
    final status = await permissionStatus();
    if (status != NotificationPermissionStatus.allowed) return false;
    return _showImmediate(
      id: _kNotificationTestId,
      title: title,
      body: body,
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'notification_test',
          'Notification test',
          channelDescription: 'Confirms that Counter notifications work',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }

  Future<bool> _showImmediate({
    required int id,
    required String title,
    String? body,
    required NotificationDetails details,
  }) async {
    if (kIsWeb) return false;
    try {
      await ensureInitialized();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return true;
    } catch (error, stackTrace) {
      _recordError('show-immediate', error, stackTrace);
      return false;
    }
  }

  NotificationPermissionStatus _statusFromNullableBool(bool? value) {
    if (value == null) return NotificationPermissionStatus.unavailable;
    return value
        ? NotificationPermissionStatus.allowed
        : NotificationPermissionStatus.denied;
  }

  NotificationPermissionStatus _statusFromDarwinOptions(
    NotificationsEnabledOptions? options,
  ) {
    if (options == null) return NotificationPermissionStatus.unavailable;
    return options.isEnabled || options.isProvisionalEnabled
        ? NotificationPermissionStatus.allowed
        : NotificationPermissionStatus.denied;
  }

  void _recordError(String operation, Object error, StackTrace stackTrace) {
    _lastError = '$operation: $error';
    if (kDebugMode) {
      debugPrint('[NOTIFICATIONS] $_lastError');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
