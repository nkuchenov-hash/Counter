import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class HealthConnectSettingsSection extends StatefulWidget {
  const HealthConnectSettingsSection({super.key});

  @override
  State<HealthConnectSettingsSection> createState() =>
      _HealthConnectSettingsSectionState();
}

class _HealthConnectSettingsSectionState
    extends State<HealthConnectSettingsSection> {
  @override
  void initState() {
    super.initState();
    unawaited(HealthSleepSyncService.instance.start());
  }

  String _statusText(String locale, HealthSleepSyncState state) {
    final key = switch (state.phase) {
      HealthSleepSyncPhase.disabled => 'health_connect_status_disabled',
      HealthSleepSyncPhase.unsupported => 'health_connect_status_unavailable',
      HealthSleepSyncPhase.needsPermission =>
        'health_connect_status_permission',
      HealthSleepSyncPhase.idle => 'health_connect_status_idle',
      HealthSleepSyncPhase.syncing => 'health_connect_status_syncing',
      HealthSleepSyncPhase.synced => 'health_connect_status_synced',
      HealthSleepSyncPhase.error => 'health_connect_status_error',
    };
    var text = t(locale, key);
    final lastSync = state.lastSyncUtc?.toLocal();
    if (lastSync != null && state.phase == HealthSleepSyncPhase.synced) {
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      text = '$text · $hh:$mm';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return ValueListenableBuilder<HealthSleepSyncState>(
      valueListenable: HealthSleepSyncService.instance.state,
      builder: (context, state, _) {
        final busy = state.phase == HealthSleepSyncPhase.syncing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'health_connect_title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              t(locale, 'health_connect_subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t(locale, 'health_connect_enable')),
              subtitle: Text(_statusText(locale, state)),
              value: state.enabled,
              onChanged: busy || !HealthSleepSyncService.instance.isSupported
                  ? null
                  : (enabled) {
                      if (enabled) {
                        unawaited(
                          HealthSleepSyncService.instance
                              .requestAuthorizationAndEnable(),
                        );
                      } else {
                        unawaited(
                          HealthSleepSyncService.instance.setEnabled(false),
                        );
                      }
                    },
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              label: t(locale, 'health_connect_sync_now'),
              icon: Icons.sync_rounded,
              loading: busy,
              onPressed: state.enabled && !busy
                  ? () => unawaited(
                      HealthSleepSyncService.instance.sync(force: true),
                    )
                  : null,
            ),
            if (state.error?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
