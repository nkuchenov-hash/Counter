import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/features/settings/health/health_connect_settings_section.dart';
import 'package:counter/features/settings/notifications/unfilled_time_notifications_section.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// OS notification permission, Health Connect sleep sync, and reminder settings.
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
        if (kIsWeb)
          Text(
            t(loc, 'profile_notifications_web_hint'),
            style: theme.textTheme.bodyMedium,
          )
        else ...[
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
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        const HealthConnectSettingsSection(),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        const UnfilledTimeNotificationsSection(),
      ],
    );
  }
}
