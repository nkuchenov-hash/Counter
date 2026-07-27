import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/records/unfilled_time_gap_policy.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:counter/services/unfilled_time_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class UnfilledTimeGapSettings {
  const UnfilledTimeGapSettings({
    required this.notificationsEnabled,
    required this.minimumGapMinutes,
    required this.notificationDelayMinutes,
  });

  const UnfilledTimeGapSettings.defaults()
    : notificationsEnabled = false,
      minimumGapMinutes = 15,
      notificationDelayMinutes = 30;

  final bool notificationsEnabled;
  final int minimumGapMinutes;
  final int notificationDelayMinutes;

  UnfilledTimeGapSettings copyWith({
    bool? notificationsEnabled,
    int? minimumGapMinutes,
    int? notificationDelayMinutes,
  }) {
    return UnfilledTimeGapSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      minimumGapMinutes: minimumGapMinutes ?? this.minimumGapMinutes,
      notificationDelayMinutes:
          notificationDelayMinutes ?? this.notificationDelayMinutes,
    );
  }
}

class UnfilledTimeGapService with WidgetsBindingObserver {
  UnfilledTimeGapService._();

  static final UnfilledTimeGapService instance = UnfilledTimeGapService._();

  static const String _notificationsEnabledKey =
      'unfilled_time_notifications_enabled_v1';
  static const String _minimumGapMinutesKey =
      'unfilled_time_minimum_gap_minutes_v1';
  static const String _notificationDelayMinutesKey =
      'unfilled_time_notification_delay_minutes_v1';
  static const String _lastNotifiedGapKey =
      'unfilled_time_last_notified_gap_v1';

  final ValueNotifier<TimelineGap?> currentGap = ValueNotifier<TimelineGap?>(
    null,
  );
  final ValueNotifier<UnfilledTimeGapSettings> settings =
      ValueNotifier<UnfilledTimeGapSettings>(
        const UnfilledTimeGapSettings.defaults(),
      );

  bool _started = false;
  bool _refreshing = false;
  Timer? _timer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await _loadSettings();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    settings.value = UnfilledTimeGapSettings(
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? false,
      minimumGapMinutes: prefs.getInt(_minimumGapMinutesKey) ?? 15,
      notificationDelayMinutes:
          prefs.getInt(_notificationDelayMinutesKey) ?? 30,
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await start();
    if (enabled) {
      final permission = await NotificationService.instance
          .requestPermissions();
      if (permission != PlanAlarmPermissionStatus.allowed) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    settings.value = settings.value.copyWith(notificationsEnabled: enabled);
    if (enabled) unawaited(refresh());
  }

  Future<void> setMinimumGapMinutes(int minutes) async {
    await start();
    final safe = minutes.clamp(5, 180).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minimumGapMinutesKey, safe);
    settings.value = settings.value.copyWith(minimumGapMinutes: safe);
    unawaited(refresh());
  }

  Future<void> setNotificationDelayMinutes(int minutes) async {
    await start();
    final safe = minutes.clamp(0, 720).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationDelayMinutesKey, safe);
    settings.value = settings.value.copyWith(notificationDelayMinutes: safe);
    unawaited(refresh());
  }

  Future<void> refresh() async {
    await start();
    if (_refreshing) return;
    final db = DatabaseService.instance;
    if (!db.isInitialized || db.currentProfileId?.isNotEmpty != true) return;
    _refreshing = true;
    try {
      final now = DateTime.now().toUtc();
      final rows = await db.fetchRecords(forceNetwork: false);
      final gaps = findUnfilledTimeGaps(
        records: rows,
        windowStartUtc: now.subtract(const Duration(hours: 24)),
        windowEndUtc: now,
        minimumDuration: Duration(minutes: settings.value.minimumGapMinutes),
      );
      currentGap.value = gaps.isEmpty ? null : gaps.last;
      final gap = currentGap.value;
      if (gap != null) await _maybeNotify(gap, now);
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> fillGap(TimelineGap gap, String title) async {
    await start();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return false;
    final db = DatabaseService.instance;
    if (!db.isInitialized || db.currentProfileId?.isNotEmpty != true) {
      return false;
    }
    final wall = db.applyUserOffset(gap.startUtc);
    final dateKey =
        '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
    final createdId = await db.writeRecord(
      dateKey,
      cleanTitle,
      explicitStartTime: gap.startUtc,
      explicitEndTime: gap.endUtc,
    );
    if (createdId == null || createdId.isEmpty) return false;
    await refresh();
    return true;
  }

  Future<void> _maybeNotify(TimelineGap gap, DateTime nowUtc) async {
    final currentSettings = settings.value;
    if (!currentSettings.notificationsEnabled) return;
    final eligibleAt = gap.endUtc.add(
      Duration(minutes: currentSettings.notificationDelayMinutes),
    );
    if (nowUtc.isBefore(eligibleAt)) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastNotifiedGapKey) == gap.key) return;
    final locale = currentLocale.value;
    final minutes = gap.duration.inMinutes;
    final shown = await UnfilledTimeNotificationService.instance.show(
      gapKey: gap.key,
      title: t(locale, 'unfilled_time_notification_title'),
      body: t(
        locale,
        'unfilled_time_notification_body',
      ).replaceAll('%s', '$minutes'),
    );
    if (shown) await prefs.setString(_lastNotifiedGapKey, gap.key);
  }
}
