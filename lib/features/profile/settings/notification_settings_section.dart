import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// OS notification permission and a real local-notification smoke test.
class ProfileNotificationsSection extends StatefulWidget {
  const ProfileNotificationsSection({this.embedded = false});

  final bool embedded;

  @override
  State<ProfileNotificationsSection> createState() =>
      ProfileNotificationsSectionState();
}

class ProfileNotificationsSectionState
    extends State<ProfileNotificationsSection> {
  Future<NotificationPermissionStatus>? _statusFuture;
  bool _requesting = false;
  String? _feedbackKey;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  void _refreshStatus() {
    _statusFuture = NotificationService.instance.permissionStatus();
  }

  Future<void> _requestAndTest() async {
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _feedbackKey = null;
    });

    final locale = currentLocale.value;
    final status = await NotificationService.instance.requestPermissions();
    var testShown = false;
    if (status == NotificationPermissionStatus.allowed) {
      testShown = await NotificationService.instance.showTestNotification(
        title: t(locale, 'notif_test_title'),
        body: t(locale, 'notif_test_body'),
      );
      await DatabaseService.instance.reschedulePlanAlarmsNow();
    }
    final refreshed = await NotificationService.instance.permissionStatus();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _statusFuture = Future.value(refreshed);
      _feedbackKey = switch (status) {
        NotificationPermissionStatus.allowed when testShown =>
          'notif_test_sent',
        NotificationPermissionStatus.allowed => 'notif_test_failed',
        NotificationPermissionStatus.denied => 'notif_permission_denied_hint',
        NotificationPermissionStatus.unavailable => 'notif_test_failed',
      };
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
        FutureBuilder<NotificationPermissionStatus>(
          future: _statusFuture,
          builder: (context, snapshot) {
            final status = snapshot.data;
            final key = status == NotificationPermissionStatus.allowed
                ? 'notif_status_allowed'
                : status == NotificationPermissionStatus.denied
                ? 'notif_status_denied'
                : 'notif_status_unknown';
            return Text(t(loc, key), style: theme.textTheme.bodyMedium);
          },
        ),
        if (_feedbackKey != null) ...[
          const SizedBox(height: 8),
          Text(
            t(loc, _feedbackKey!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppButton.secondary(
          label: t(loc, 'profile_notifications_request_button'),
          icon: Icons.notifications_active_outlined,
          loading: _requesting,
          onPressed: _requesting ? null : () => unawaited(_requestAndTest()),
        ),
      ],
    );
  }
}
