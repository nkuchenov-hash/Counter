import 'dart:async';

import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// One user-facing sleep synchronization setting.
///
/// Android/iOS own health permissions and ingestion. Web is a consumer of the
/// canonical PocketBase records produced by those device health bridges; it
/// must never pretend that a watch-vendor OAuth connection is required.
class SleepSyncSettingsSection extends StatefulWidget {
  const SleepSyncSettingsSection({super.key});

  @override
  State<SleepSyncSettingsSection> createState() =>
      _SleepSyncSettingsSectionState();
}

class _SleepSyncSettingsSectionState extends State<SleepSyncSettingsSection>
    with WidgetsBindingObserver {
  bool get _useDeviceSource =>
      !kIsWeb && HealthSleepSyncService.instance.isSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (kIsWeb) return;
    if (_useDeviceSource) {
      await HealthSleepSyncService.instance.start();
      return;
    }
    await CloudSleepSyncService.instance.loadStatus();
  }

  String _copy(String locale, String en, String ru) {
    return locale == 'ru' ? ru : en;
  }

  Future<void> _setDeviceEnabled(bool enabled) async {
    final service = HealthSleepSyncService.instance;
    if (enabled) {
      await service.requestAuthorizationAndEnable();
    } else {
      await service.setEnabled(false);
    }
  }

  Future<void> _setCloudEnabled(bool enabled) async {
    final service = CloudSleepSyncService.instance;
    final current = service.state.value;
    if (!enabled) {
      if (current.configured) await service.setEnabled(false);
      return;
    }
    if (!current.configured) {
      await service.connectGoogleFit();
      return;
    }
    await service.setEnabled(true);
  }

  String _deviceStatus(String locale, HealthSleepSyncState state) {
    return switch (state.phase) {
      HealthSleepSyncPhase.syncing =>
        _copy(locale, 'Synchronizing…', 'Синхронизация…'),
      HealthSleepSyncPhase.needsPermission => _copy(
        locale,
        'Permission is required to synchronize sleep.',
        'Для синхронизации нужен доступ к данным сна.',
      ),
      HealthSleepSyncPhase.error => _copy(
        locale,
        'Could not enable synchronization. Try again.',
        'Не удалось включить синхронизацию. Попробуйте ещё раз.',
      ),
      _ => state.enabled
          ? _copy(
              locale,
              'Sleep is synchronized automatically.',
              'Сон синхронизируется автоматически.',
            )
          : _copy(
              locale,
              'Turn on once and Life OS will keep sleep synchronized.',
              'Включите один раз — дальше Life OS будет синхронизировать сон автоматически.',
            ),
    };
  }

  String _cloudStatus(String locale, CloudSleepSyncState state) {
    return switch (state.phase) {
      CloudSleepSyncPhase.connecting => _copy(
        locale,
        'Confirm access in the opened window.',
        'Подтвердите доступ в открывшемся окне.',
      ),
      CloudSleepSyncPhase.syncing =>
        _copy(locale, 'Synchronizing…', 'Синхронизация…'),
      CloudSleepSyncPhase.error => state.configured && state.enabled
          ? _copy(
              locale,
              'Synchronization is on. Life OS will retry automatically.',
              'Синхронизация включена. Life OS повторит попытку автоматически.',
            )
          : _copy(
              locale,
              'Synchronization needs access. Turn it on to continue.',
              'Для синхронизации нужен доступ. Включите её, чтобы продолжить.',
            ),
      _ => state.configured && state.enabled
          ? _copy(
              locale,
              'Sleep is synchronized automatically.',
              'Сон синхронизируется автоматически.',
            )
          : _copy(
              locale,
              'Turn on once and Life OS will keep sleep synchronized.',
              'Включите один раз — дальше Life OS будет синхронизировать сон автоматически.',
            ),
    };
  }

  Widget _switch({
    required String locale,
    required bool value,
    required bool busy,
    required String status,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        _copy(locale, 'Synchronize sleep', 'Синхронизировать сон'),
      ),
      subtitle: Text(status),
      value: value,
      onChanged: busy ? null : onChanged,
    );
  }

  Widget _webStatus(String locale, ThemeData theme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.health_and_safety_outlined),
      title: Text(_copy(locale, 'Sleep synchronization', 'Синхронизация сна')),
      subtitle: Text(
        _copy(
          locale,
          'Sleep is received automatically from the health source connected on your phone and appears here on every client. Health permission is managed on the phone.',
          'Сон автоматически поступает из источника здоровья, подключённого на телефоне, и появляется здесь на всех устройствах. Доступ к данным здоровья управляется на телефоне.',
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(locale, 'health_connect_title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _copy(
            locale,
            'Automatically adds completed sleep to Timeline.',
            'Автоматически добавляет завершённый сон в Timeline.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (kIsWeb)
          _webStatus(locale, theme)
        else if (_useDeviceSource)
          ValueListenableBuilder<HealthSleepSyncState>(
            valueListenable: HealthSleepSyncService.instance.state,
            builder: (context, state, _) {
              final busy = state.phase == HealthSleepSyncPhase.syncing;
              return _switch(
                locale: locale,
                value: state.enabled,
                busy: busy,
                status: _deviceStatus(locale, state),
                onChanged: (enabled) =>
                    unawaited(_setDeviceEnabled(enabled)),
              );
            },
          )
        else
          ValueListenableBuilder<CloudSleepSyncState>(
            valueListenable: CloudSleepSyncService.instance.state,
            builder: (context, state, _) {
              final busy = state.phase == CloudSleepSyncPhase.syncing;
              return _switch(
                locale: locale,
                value: state.configured && state.enabled,
                busy: busy,
                status: _cloudStatus(locale, state),
                onChanged: (enabled) =>
                    unawaited(_setCloudEnabled(enabled)),
              );
            },
          ),
      ],
    );
  }
}

@Deprecated('Use SleepSyncSettingsSection')
typedef HealthConnectSettingsSection = SleepSyncSettingsSection;
