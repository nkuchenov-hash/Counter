import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UnfilledTimeNotificationService {
  UnfilledTimeNotificationService._();

  static final UnfilledTimeNotificationService instance =
      UnfilledTimeNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> ensureInitialized() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (_initialized) return true;
    await NotificationService.instance.ensureInitialized();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    final ok = await _plugin.initialize(settings: settings);
    _initialized = ok != false;
    return _initialized;
  }

  Future<bool> show({
    required String gapKey,
    required String title,
    required String body,
  }) async {
    if (!await ensureInitialized()) return false;
    final permission = await NotificationService.instance.permissionStatus();
    if (permission != PlanAlarmPermissionStatus.allowed) return false;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'unfilled_time',
        'Unfilled time',
        channelDescription: 'Reminders about gaps in the Life OS timeline',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: _stableNotificationId(gapKey),
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'unfilled_time|$gapKey',
    );
    return true;
  }

  int _stableNotificationId(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
