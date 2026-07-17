import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// OS notification permission + local plan reminders (Android / iOS / desktop).
class ProfileNotificationsSection extends StatefulWidget {
  const ProfileNotificationsSection({this.embedded = false});

  final bool embedded;

  @override
  State<ProfileNotificationsSection> createState() =>
      ProfileNotificationsSectionState();
}

class ProfileNotificationsSectionState
    extends State<ProfileNotificationsSection> {
  Future<PlanAlarmPermissionStatus>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = NotificationService.instance.permissionStatus();
  }

  void _refreshStatus() {
    setState(() {
      _statusFuture = NotificationService.instance.permissionStatus();
    });
  }

  String _statusLine(String loc, PlanAlarmPermissionStatus? v) {
    switch (v) {
      case PlanAlarmPermissionStatus.allowed:
        return t(loc, 'notif_status_allowed');
      case PlanAlarmPermissionStatus.denied:
      case PlanAlarmPermissionStatus.permanentlyDenied:
        return t(loc, 'notif_status_denied');
      case PlanAlarmPermissionStatus.unsupported:
        return t(loc, 'profile_notifications_web_hint');
      case PlanAlarmPermissionStatus.unknown:
      case null:
        return t(loc, 'notif_status_unknown');
    }
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
        FutureBuilder<PlanAlarmPermissionStatus>(
          future: _statusFuture,
          builder: (context, snap) {
            return Text(
              _statusLine(loc, snap.data),
              style: theme.textTheme.bodyMedium,
            );
          },
        ),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: t(loc, 'profile_notifications_request_button'),
          icon: Icons.notifications_active_outlined,
          onPressed: () {
            unawaited(() async {
              await NotificationService.instance.requestPermissions();
              if (mounted) _refreshStatus();
            }());
          },
        ),
      ],
    );
  }
}
