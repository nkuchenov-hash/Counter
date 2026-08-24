import 'dart:async';

import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/data/health/health_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// One user-facing sleep synchronization setting.
///
/// Android/iOS can read the device health store directly. Web uses the
/// server-owned Google Health connection, whose reconciled sleep stream can
/// include data uploaded from Health Connect and other supported sources.
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
    if (kIsWeb) {
      await CloudSleepSyncService.instance.loadStatus();
      return;
    }
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

  Future<void> _connectOrSyncWebCloud() async {
    final service = CloudSleepSyncService.instance;
    final current = service.state.value;
    if (!current.configured) {
      await service.connectGoogleFit();
      return;
    }
    if (!current.enabled) {
      final enabled = await service.setEnabled(true);
      if (!enabled) return;
    }
    await service.syncNow();
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
        'Confirm access in the opened Google window.',
        'Подтвердите доступ в открывшемся окне Google.',
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
              'Google Health access is required to continue.',
              'Для продолжения нужен доступ Google Health.',
            ),
      _ => state.configured && state.enabled
          ? _copy(
              locale,
              'Sleep is synchronized automatically through Google Health.',
              'Сон автоматически синхронизируется через Google Health.',
            )
          : _copy(
              locale,
              'Connect Google Health once and Life OS will keep sleep synchronized on the server.',
              'Один раз подключите Google Health — дальше сервер Life OS будет синхронизировать сон автоматически.',
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

  bool _requiresGoogleHealthSetup(CloudSleepSyncState state) {
    final raw = state.error?.toLowerCase() ?? '';
    return raw.contains('google_health_account_not_linked') ||
        raw.contains('account_not_linked') ||
        raw.contains('account is not linked to google health');
  }

  Widget _webStatus(String locale, ThemeData theme) {
    return ValueListenableBuilder<CloudSleepSyncState>(
      valueListenable: CloudSleepSyncService.instance.state,
      builder: (context, state, _) {
        final configured = state.configured;
        final syncing = state.phase == CloudSleepSyncPhase.syncing;
        final connecting = state.phase == CloudSleepSyncPhase.connecting;
        final setupRequired = _requiresGoogleHealthSetup(state);
        final status = setupRequired
            ? _copy(
                locale,
                'Google requires a one-time Google Health profile setup before LIFE OS can read Health Connect sleep. Open setup once; LIFE OS will retry automatically.',
                'Google требует один раз настроить профиль Google Health, прежде чем LIFE OS сможет читать сон из Health Connect. Откройте настройку один раз — LIFE OS будет повторять синхронизацию автоматически.',
              )
            : configured
            ? (syncing
                  ? _copy(
                      locale,
                      'Synchronizing sleep from Google Health…',
                      'Синхронизация сна из Google Health…',
                    )
                  : _copy(
                      locale,
                      'Google Health is connected. The LIFE OS server synchronizes sleep automatically and stores it in PocketBase for every client.',
                      'Google Health подключён. Сервер LIFE OS автоматически синхронизирует сон и сохраняет его в PocketBase для всех клиентов.',
                    ))
            : (connecting
                  ? _copy(
                      locale,
                      'Complete Google Health authorization in the opened Google page. LIFE OS will import sleep immediately after authorization.',
                      'Завершите авторизацию Google Health на открывшейся странице Google. LIFE OS сразу импортирует сон после авторизации.',
                    )
                  : _copy(
                      locale,
                      'Connect Google Health once. Its reconciled sleep stream can include data uploaded from Health Connect, without tying LIFE OS to a watch brand.',
                      'Один раз подключите Google Health. Его объединённый поток сна может включать данные из Health Connect без привязки LIFE OS к марке часов.',
                    ));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(
                _copy(locale, 'Sleep synchronization', 'Синхронизация сна'),
              ),
              subtitle: Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: syncing
                  ? null
                  : () => unawaited(
                      setupRequired
                          ? CloudSleepSyncService.instance.openGoogleHealthAccountSetup()
                          : _connectOrSyncWebCloud(),
                    ),
              icon: Icon(
                setupRequired
                    ? Icons.open_in_new
                    : (configured ? Icons.sync : Icons.cloud_outlined),
              ),
              label: Text(
                setupRequired
                    ? _copy(
                        locale,
                        'Set up Google Health',
                        'Настроить Google Health',
                      )
                    : configured
                    ? _copy(locale, 'Synchronize now', 'Синхронизировать сейчас')
                    : (connecting
                          ? _copy(
                              locale,
                              'Continue Google Health connection',
                              'Продолжить подключение Google Health',
                            )
                          : _copy(
                              locale,
                              'Connect Google Health',
                              'Подключить Google Health',
                            )),
              ),
            ),
          ],
        );
      },
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
