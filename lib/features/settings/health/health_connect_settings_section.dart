import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class SleepSyncSettingsSection extends StatefulWidget {
  const SleepSyncSettingsSection({super.key});

  @override
  State<SleepSyncSettingsSection> createState() =>
      _SleepSyncSettingsSectionState();
}

class _SleepSyncSettingsSectionState extends State<SleepSyncSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Loading settings registers schedules but does not import sleep merely
    // because the Settings page was opened.
    unawaited(HealthSleepSyncService.instance.start());
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
      // Refresh OAuth status after the external browser returns. The server,
      // not this lifecycle callback, performs the actual sleep import.
      unawaited(CloudSleepSyncService.instance.loadStatus());
    }
  }

  String _withValues(String template, Object first, Object second) {
    return template.replaceFirst('%s', '$first').replaceFirst('%s', '$second');
  }

  String _localStatusText(String locale, HealthSleepSyncState state) {
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

  String _cloudStatusText(String locale, CloudSleepSyncState state) {
    final key = switch (state.phase) {
      CloudSleepSyncPhase.disconnected => 'sleep_cloud_status_disconnected',
      CloudSleepSyncPhase.connecting => 'sleep_cloud_status_connecting',
      CloudSleepSyncPhase.connected =>
        state.enabled
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

  Future<void> _pickLocalDailyTime(
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

  Widget _buildCloudSection(BuildContext context, String locale) {
    return ValueListenableBuilder<CloudSleepSyncState>(
      valueListenable: CloudSleepSyncService.instance.state,
      builder: (context, state, _) {
        final busy =
            state.phase == CloudSleepSyncPhase.connecting ||
            state.phase == CloudSleepSyncPhase.syncing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'sleep_cloud_title'),
              style: Theme.of(context).textTheme.titleSmall,
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

  Widget _buildLocalSection(BuildContext context, String locale) {
    return ValueListenableBuilder<HealthSleepSyncState>(
      valueListenable: HealthSleepSyncService.instance.state,
      builder: (context, state, _) {
        final busy = state.phase == HealthSleepSyncPhase.syncing;
        final source = state.lastSourceSummary?.trim() ?? '';
        final deviceSource =
            HealthSleepSyncService.instance.activeDeviceSourceName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(locale, 'sleep_local_title'),
              style: Theme.of(context).textTheme.titleSmall,
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
              subtitle: Text(_localStatusText(locale, state)),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: state.enabled && !busy,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(t(locale, 'sleep_sync_daily_time')),
              subtitle: Text(t(locale, 'sleep_sync_daily_time_hint')),
              trailing: Text(
                _formattedDailyTime(context, state.dailySyncMinutes),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              onTap: state.enabled && !busy
                  ? () => unawaited(_pickLocalDailyTime(context, state))
                  : null,
            ),
            Text(
              t(
                locale,
                'sleep_sync_device_source',
              ).replaceFirst('%s', deviceSource),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(locale, 'health_connect_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          t(locale, 'health_connect_subtitle'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildCloudSection(context, locale),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        _buildLocalSection(context, locale),
      ],
    );
  }
}

@Deprecated('Use SleepSyncSettingsSection')
typedef HealthConnectSettingsSection = SleepSyncSettingsSection;
