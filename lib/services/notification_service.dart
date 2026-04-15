import 'dart:async';

import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// OS plan reminders: [flutter_local_notifications] + [timezone] (@APP_STRUCTURE).
const int kPlanAlarmNotificationLimit = 50;

const String _kPrefsNotifPermRequested = 'notif_perm_requested_v1';

class _AlarmCandidate {
  _AlarmCandidate({
    required this.id,
    required this.when,
    required this.title,
    required this.reminderMinutes,
  });

  final int id;
  final tz.TZDateTime when;
  final String title;
  final int reminderMinutes;
}

/// 64-bit FNV-1a over UTF-16 code units, folded to a **positive 31-bit** int.
///
/// Stable across app restarts (unlike relying on VM [Object.hashCode] quirks).
/// [stableKey] must be [PlanningTask.recordIdForBackend] (PocketBase row id or `virt-…`).
int planAlarmNotificationIdFromStableKey(String stableKey) {
  var h = 0xcbf29ce484222325;
  for (final u in stableKey.codeUnits) {
    h ^= u;
    h = (h * 0x100000001b3) & 0xffffffffffffffff;
  }
  final hi = (h >> 32) & 0xffffffff;
  final lo = h & 0xffffffff;
  var x = hi ^ lo;
  x ^= x >> 16;
  x ^= x >> 8;
  return x & 0x7fffffff;
}

/// Singleton: timezone init, permissions, [syncAlarms] (@ARCHITECTURE.md — Brain calls only).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// Idempotent; safe to call from background. Does not block the UI isolate beyond `await` in callers.
  Future<void> ensureInitialized() {
    if (kIsWeb) return Future.value();
    if (_initialized) return Future.value();
    if (_initCompleter != null) return _initCompleter!.future;
    final c = Completer<void>();
    _initCompleter = c;
    unawaited(_initInner(c));
    return c.future;
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
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
      completer.complete();
      await requestPermissionsIfNeeded();
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      _initCompleter = null;
    }
  }

  /// First run only (persisted): Android 13+ notification permission + iOS alert/sound.
  Future<void> requestPermissionsIfNeeded() async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
    } catch (_) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPrefsNotifPermRequested) ?? false) return;
    await prefs.setBool(_kPrefsNotifPermRequested, true);

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// Replaces the entire pending queue: [tasks] should cover the next 7 wall days (Brain-built).
  Future<void> syncAlarms(List<PlanningTask> tasks) async {
    if (kIsWeb) return;
    try {
      await ensureInitialized();
    } catch (_) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final candidates = <_AlarmCandidate>[];

    for (final t in tasks) {
      if (t.isDone) continue;
      final off = t.reminderOffset;
      if (off == null || off < 0) continue;
      final st = t.startTime;
      if (st == null) continue;
      final key = t.recordIdForBackend.trim();
      if (key.isEmpty) continue;

      final fire = tz.TZDateTime(
        tz.local,
        st.year,
        st.month,
        st.day,
        st.hour,
        st.minute,
        st.second,
      ).subtract(Duration(minutes: off));

      if (!fire.isAfter(now)) continue;

      candidates.add(
        _AlarmCandidate(
          id: planAlarmNotificationIdFromStableKey(key),
          when: fire,
          title: t.title.trim().isEmpty ? 'Plan' : t.title.trim(),
          reminderMinutes: off,
        ),
      );
    }

    candidates.sort((a, b) => a.when.compareTo(b.when));
    final picked = candidates.take(kPlanAlarmNotificationLimit).toList();

    await _plugin.cancelAll();

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
    );

    for (final c in picked) {
      final body = c.reminderMinutes == 1
          ? 'Starting in 1 minute'
          : 'Starting in ${c.reminderMinutes} minutes';
      try {
        await _plugin.zonedSchedule(
          id: c.id,
          scheduledDate: c.when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: c.title,
          body: body,
        );
      } catch (_) {}
    }
  }
}
