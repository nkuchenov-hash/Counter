part of '../notification_service.dart';

const int _kDesktopVoiceNotificationId = 0x7f00d001;
const int _kDesktopVoiceStopNotificationId = 0x7f00d002;
const int _kDesktopVoiceOverlayUnavailableId = 0x7f00d003;

const NotificationDetails _desktopVoiceNotificationDetails =
    NotificationDetails(
      android: AndroidNotificationDetails(
        'desktop_voice',
        'Desktop voice',
        channelDescription: 'Desktop voice command status',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

extension DesktopVoiceNotifications on NotificationService {
  Future<bool> showDesktopVoiceRecordStarted({required String message}) =>
      _showImmediate(
        id: _kDesktopVoiceNotificationId,
        title: message,
        details: _desktopVoiceNotificationDetails,
      );

  Future<bool> showDesktopVoiceRecordStopped({required String message}) =>
      _showImmediate(
        id: _kDesktopVoiceStopNotificationId,
        title: message,
        details: _desktopVoiceNotificationDetails,
      );

  Future<bool> showDesktopVoiceOverlayUnavailable({required String message}) =>
      _showImmediate(
        id: _kDesktopVoiceOverlayUnavailableId,
        title: message,
        details: _desktopVoiceNotificationDetails,
      );
}
