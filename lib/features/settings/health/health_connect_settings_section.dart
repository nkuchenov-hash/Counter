import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// Canonical sleep-sync settings surface.
///
/// Device Health Connect / Apple Health and server Google Fit are deliberately
/// shown as separate sources so enabling one never hides or replaces the other.
class SleepSyncSettingsSection extends StatelessWidget {
  const SleepSyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeviceHealthSleepSettingsSection(),
        SizedBox(height: 20),
        Divider(),
        SizedBox(height: 16),
        _CloudSleepSettingsSection(),
      ],
    );
  }
}

class _DeviceHealthSleepSettingsSection extends StatefulWidget {
  const _DeviceHealthSleepSettingsSection();

  @override
  State<_DeviceHealthSleepSettingsSection> createState() =>
      _DeviceHealthSleepSettingsSectionState();
}

class _DeviceHealthSleepSettingsSectionState
    extends State<_DeviceHealthSleepSettingsSection> {
  @override
  void initState() {
    super.initState();
    unawaited(HealthSleepSyncService.instance.start());
  }

  String _withValues(String template, Object first, Object second) {
    return template.replaceFirst('%s', '$first').replaceFirst('%s', '$second');
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
    if (lastSync != null) {
      final yyyy = lastSync.year.toString().padLeft(4, '0');
      final month = lastSync.month.toString().padLeft(2, '0');
      final day = lastSync.day.toString().padLeft(2, '0');
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      text = '$text · $yyyy-$month-$day $hh:$mm';
    }
    if (state.lastReadSessionCount != null &&
        state.lastImportedSessionCount != null) {
      text =
          '$text\n${_withValues(t(locale, 'health_connect_result'), state.lastReadSessionCount!, state.lastImportedSessionCount!)}';
    }
    if (state.enabled && state.backgroundReadAvailable) {
      final backgroundKey = state.backgroundReadAuthorized
          ? 'health_connect_background_active'
          : 'health_connect_background_permission';
      text = '$text\n${t(locale, backgroundKey)}';
    }
    return text;
  }

  String _formattedDailyTime(BuildContext context, int minutes) {
    final normalized = minutes.clamp(0, 1439).toInt();
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Future<void> _pickDailyTime(
    BuildContext context,
    HealthSleepSyncState state,
  ) async {
    final normalized = state.dailySyncMinutes.clamp(0, 1439).toInt();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
    );
    if (selected == null) return;
    await HealthSleepSyncService.instance.setDailySyncMinutes(
      selected.hour * 60 + selected.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return ValueListenableBuilder<HealthSleepSyncState>(
      valueListenable: HealthSleepSyncService.instance.state,
      builder: (context, state, _) {
        final service = HealthSleepSyncService.instance;
        final busy = state.phase == HealthSleepSyncPhase.syncing;
        final source = state.lastSourceSummary?.trim() ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'sleep_local_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              t(locale, 'sleep_local_subtitle'),
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
              onChanged: busy || !service.isSupported
                  ? null
                  : (enabled) {
                      if (enabled) {
                        unawaited(service.requestAuthorizationAndEnable());
                      } else {
                        unawaited(service.setEnabled(false));
                      }
                    },
            ),
            Text(
              t(locale, 'sleep_sync_device_source').replaceFirst(
                '%s',
                service.activeDeviceSourceName,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (state.enabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(t(locale, 'sleep_sync_daily_time')),
                subtitle: Text(t(locale, 'sleep_sync_daily_time_hint')),
                trailing: Text(
                  _formattedDailyTime(context, state.dailySyncMinutes),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                onTap: busy
                    ? null
                    : () => unawaited(_pickDailyTime(context, state)),
              ),
              if (state.backgroundReadAvailable &&
                  !state.backgroundReadAuthorized) ...[
                AppButton.secondary(
                  label: t(locale, 'health_connect_enable_background'),
                  icon: Icons.sync_lock_rounded,
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          service.requestBackgroundAuthorizationAndSchedule(),
                        ),
                ),
                const SizedBox(height: 8),
              ],
              AppButton.secondary(
                label: t(locale, 'health_connect_sync_now'),
                icon: Icons.sync_rounded,
                loading: busy,
                onPressed: busy
                    ? null
                    : () => unawaited(service.sync(force: true)),
              ),
            ],
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

class _CloudSleepSettingsSection extends StatefulWidget {
  const _CloudSleepSettingsSection();

  @override
  State<_CloudSleepSettingsSection> createState() =>
      _CloudSleepSettingsSectionState();
}

class _CloudSleepSettingsSectionState extends State<_CloudSleepSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(CloudSleepSyncService.instance.loadStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(CloudSleepSyncService.instance.loadStatus());
    }
  }

  String _withValues(String template, Object first, Object second) {
    return template.replaceFirst('%s', '$first').replaceFirst('%s', '$second');
  }

  String _cloudStatusText(String locale, CloudSleepSyncState state) {
    final key = switch (state.phase) {
      CloudSleepSyncPhase.disconnected => 'sleep_cloud_status_disconnected',
      CloudSleepSyncPhase.connecting => 'sleep_cloud_status_connecting',
      CloudSleepSyncPhase.connected => state.enabled
          ? 'sleep_cloud_status_active'
          : 'sleep_cloud_status_paused',
      CloudSleepSyncPhase.syncing => 'sleep_cloud_status_syncing',
      CloudSleepSyncPhase.error => 'sleep_cloud_status_error',
    };
    var text = t(locale, key);
    final lastSync = state.lastSyncUtc?.toLocal();
    if (lastSync != null) {
      final yyyy = lastSync.year.toString().padLeft(4, '0');
      final month = lastSync.month.toString().padLeft(2, '0');
      final day = lastSync.day.toString().padLeft(2, '0');
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      text = '$text · $yyyy-$month-$day $hh:$mm';
      text =
          '$text\n${_withValues(t(locale, 'health_connect_result'), state.lastSessionCount, state.lastImportedCount)}';
    }
    return text;
  }

  String _cloudErrorText(String locale, String raw) {
    if (raw == 'server_sleep_sync_not_deployed') {
      return t(locale, 'sleep_cloud_server_not_deployed');
    }
    return raw;
  }

  String _formattedDailyTime(BuildContext context, int minutes) {
    final normalized = minutes.clamp(0, 1439).toInt();
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Future<void> _pickCloudDailyTime(
    BuildContext context,
    CloudSleepSyncState state,
  ) async {
    final normalized = state.dailySyncMinutes.clamp(0, 1439).toInt();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
    );
    if (selected == null) return;
    await CloudSleepSyncService.instance.setDailySyncMinutes(
      selected.hour * 60 + selected.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return ValueListenableBuilder<CloudSleepSyncState>(
      valueListenable: CloudSleepSyncService.instance.state,
      builder: (context, state, _) {
        final busy = state.phase == CloudSleepSyncPhase.connecting ||
            state.phase == CloudSleepSyncPhase.syncing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'sleep_cloud_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              t(locale, 'sleep_cloud_subtitle'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_sync_rounded),
              title: Text(t(locale, 'sleep_cloud_google_fit')),
              subtitle: Text(_cloudStatusText(locale, state)),
              trailing: state.configured
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            if (!state.configured) ...[
              AppButton.secondary(
                label: t(locale, 'sleep_cloud_connect_google'),
                icon: Icons.link_rounded,
                loading: state.phase == CloudSleepSyncPhase.connecting,
                onPressed: busy
                    ? null
                    : () => unawaited(
                          CloudSleepSyncService.instance.connectGoogleFit(),
                        ),
              ),
            ] else ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t(locale, 'sleep_cloud_enable')),
                subtitle: Text(t(locale, 'sleep_cloud_enable_hint')),
                value: state.enabled,
                onChanged: busy
                    ? null
                    : (enabled) => unawaited(
                          CloudSleepSyncService.instance.setEnabled(enabled),
                        ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(t(locale, 'sleep_sync_daily_time')),
                subtitle: Text(t(locale, 'sleep_cloud_daily_time_hint')),
                trailing: Text(
                  _formattedDailyTime(context, state.dailySyncMinutes),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                onTap: busy
                    ? null
                    : () => unawaited(_pickCloudDailyTime(context, state)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton.secondary(
                    label: t(locale, 'health_connect_sync_now'),
                    icon: Icons.sync_rounded,
                    loading: state.phase == CloudSleepSyncPhase.syncing,
                    onPressed: busy || !state.enabled
                        ? null
                        : () => unawaited(
                              CloudSleepSyncService.instance.syncNow(),
                            ),
                  ),
                  AppButton.secondary(
                    label: t(locale, 'sleep_cloud_disconnect'),
                    icon: Icons.link_off_rounded,
                    onPressed: busy
                        ? null
                        : () => unawaited(
                              CloudSleepSyncService.instance.disconnect(),
                            ),
                  ),
                ],
              ),
            ],
            if (state.error?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                _cloudErrorText(locale, state.error!),
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

@Deprecated('Use SleepSyncSettingsSection')
typedef HealthConnectSettingsSection = SleepSyncSettingsSection;
