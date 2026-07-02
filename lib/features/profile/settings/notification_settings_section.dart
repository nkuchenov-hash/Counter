import 'dart:async';import 'package:counter/core/widgets/app_button.dart';import 'package:counter/l10n/dictionary.dart';import 'package:counter/services/notification_service.dart';import 'package:flutter/foundation.dart' show kIsWeb;import 'package:flutter/material.dart';import 'package:flutter_local_notifications/flutter_local_notifications.dart';/// OS notification permission + local plan reminders (Android / iOS).
class ProfileNotificationsSection extends StatefulWidget {
  const ProfileNotificationsSection({this.embedded = false});

  final bool embedded;

  @override
  State<ProfileNotificationsSection> createState() =>
      ProfileNotificationsSectionState();
}

class ProfileNotificationsSectionState
    extends State<ProfileNotificationsSection> {
  Future<bool?>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadAndroidNotificationEnabled();
  }

  Future<bool?> _loadAndroidNotificationEnabled() async {
    if (kIsWeb) return null;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  void _refreshStatus() {
    setState(() {
      _statusFuture = _loadAndroidNotificationEnabled();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    if (kIsWeb) {
      return Text(
        t(loc, 'profile_notifications_web_hint'),
        style: theme.textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Text(
            t(loc, 'profile_notifications_section'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            t(loc, 'profile_notifications_subtitle'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FutureBuilder<bool?>(
          future: _statusFuture,
          builder: (context, snap) {
            final v = snap.data;
            final line = v == null
                ? t(loc, 'notif_status_unknown')
                : (v
                      ? t(loc, 'notif_status_allowed')
                      : t(loc, 'notif_status_denied'));
            return Text(line, style: theme.textTheme.bodyMedium);
          },
        ),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: t(loc, 'profile_notifications_request_button'),
          icon: Icons.notifications_active_outlined,
          onPressed: () {
            unawaited(
              NotificationService.instance.requestPermissionsIfNeeded(),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _refreshStatus();
            });
          },
        ),
      ],
    );
  }
}
