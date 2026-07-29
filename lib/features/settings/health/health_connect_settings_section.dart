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

  String _withValues(String template, Object first, Object second) {
    return template
        .replaceFirst('%s', '$first')
        .replaceFirst('%s', '$second');
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
      HealthSleepSyncPhase.noData => 'health_connect_status_no_data',
      HealthSleepSyncPhase.error => 'health_connect_status_error',
    };
    var text = t(locale, key);
    final lastSync = state.lastSyncUtc?.toLocal();
    if (lastSync != null &&
        (state.phase == HealthSleepSyncPhase.synced ||
            state.phase == HealthSleepSyncPhase.noData)) {
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      text = '$text · $hh:$mm';
    }
    if (state.lastReadSessionCount != null &&
        state.lastImportedSessionCount != null) {
      text = '$text\n${_withValues(
        t(locale, 'health_connect_result'),
        state.lastReadSessionCount!,
        state.lastImportedSessionCount!,
      )}';
    }
    if (state.enabled && state.backgroundReadAvailable) {
      final backgroundKey = state.backgroundReadAuthorized
          ? 'health_connect_background_active'
          : 'health_connect_background_permission';
      text = '$text\n${t(locale, backgroundKey)}';
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
        final source = state.lastSourceSummary?.trim() ?? '';
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
            if (state.enabled &&
                state.backgroundReadAvailable &&
                !state.backgroundReadAuthorized) ...[
              const SizedBox(height: 8),
              AppButton.secondary(
                label: t(locale, 'health_connect_enable_background'),
                icon: Icons.sync_lock_rounded,
                onPressed: busy
                    ? null
                    : () => unawaited(
                        HealthSleepSyncService.instance
                            .requestBackgroundAuthorizationAndSchedule(),
                      ),
              ),
            ],
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
            if (source.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t(locale, 'health_connect_source').replaceFirst('%s', source),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
