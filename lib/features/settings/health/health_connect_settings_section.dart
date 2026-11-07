import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/health/cloud_sleep_sync_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

/// One server-owned sleep connection on Android, iOS and Web.
///
/// Xiaomi Cloud (Mi Fitness) imports completed nights into PocketBase. Device
/// Health Connect permission is not a prerequisite for this settings flow.
class SleepSyncSettingsSection extends StatefulWidget {
  const SleepSyncSettingsSection({super.key});

  @override
  State<SleepSyncSettingsSection> createState() =>
      _SleepSyncSettingsSectionState();
}

class _SleepSyncSettingsSectionState extends State<SleepSyncSettingsSection>
    with WidgetsBindingObserver {
  final CloudSleepSyncService _cloud = CloudSleepSyncService.instance;
  bool _firstLoad = true;
  bool _actionRunning = false;

  String _copy(String en, String ru) =>
      currentLocale.value == 'ru' ? ru : en;

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
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _cloud.loadStatus();
    } finally {
      if (mounted && _firstLoad) setState(() => _firstLoad = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_actionRunning) return;
    setState(() => _actionRunning = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  Future<void> _connect() => _perform(() async {
    final connected = await _cloud.connectXiaomi();
    // An existing Xiaomi session returns connected immediately (no login URL).
    // The server already starts an import for that path; refresh its status.
    if (connected && _cloud.state.value.configured) {
      await _cloud.loadStatus();
    }
  });

  Future<void> _toggle(bool enabled) => _perform(() async {
    if (!_cloud.state.value.configured) {
      if (enabled) await _cloud.connectXiaomi();
      return;
    }
    final updated = await _cloud.setEnabled(enabled);
    if (updated && enabled) await _cloud.syncNow();
  });

  Future<void> _syncNow() => _perform(() async {
    final current = _cloud.state.value;
    if (!current.configured) {
      await _cloud.connectXiaomi();
      return;
    }
    if (!current.enabled) {
      if (!await _cloud.setEnabled(true)) return;
    }
    await _cloud.syncNow();
  });

  Future<void> _confirmDisconnect() async {
    if (_actionRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_copy('Disconnect Xiaomi?', 'Отключить Xiaomi?')),
        content: Text(_copy(
          'Automatic sleep imports will stop. Existing sleep records in Timeline will remain.',
          'Автоматический импорт сна прекратится. Уже сохранённые записи в Timeline останутся.',
        )),
        actions: [
          AppButton.ghost(
            label: _copy('Cancel', 'Отмена'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.destructive(
            label: _copy('Disconnect', 'Отключить'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      await _cloud.disconnect();
    });
  }

  String _status(CloudSleepSyncState state) {
    if (state.phase == CloudSleepSyncPhase.connecting) {
      return _copy(
        'Complete Xiaomi sign-in in the opened browser.',
        'Завершите вход в Xiaomi в открывшемся браузере.',
      );
    }
    if (!state.configured) {
      return _copy(
        'Not connected. Sign in to the Xiaomi account used by Mi Fitness.',
        'Не подключено. Войдите в аккаунт Xiaomi, используемый в Mi Fitness.',
      );
    }
    if (!state.enabled) {
      return _copy('Paused', 'Приостановлено');
    }
    if (state.phase == CloudSleepSyncPhase.syncing) {
      return _copy('Importing sleep…', 'Импортируем сон…');
    }
    if (state.error != null || state.phase == CloudSleepSyncPhase.error) {
      return _copy('Needs attention', 'Требуется внимание');
    }
    if (state.lastSyncUtc == null) {
      return _copy('Connected. Waiting for first import.', 'Подключено. Ожидаем первый импорт.');
    }
    return _copy('Connected · automatic sync on', 'Подключено · автосинхронизация включена');
  }

  String _errorText(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('xiaomi_sleep_not_available_today')) {
      return _copy(
        'Xiaomi has not published today\'s sleep yet. LIFE OS will check again automatically.',
        'Xiaomi ещё не передал сон за сегодня. LIFE OS проверит данные повторно автоматически.',
      );
    }
    if (normalized.contains('server_sleep_sync_not_deployed')) {
      return _copy(
        'Sleep synchronization is not installed on the server.',
        'Синхронизация сна не установлена на сервере.',
      );
    }
    if (normalized.contains('xiaomi_authorization_start_failed')) {
      return _copy(
        'Could not start Xiaomi sign-in. Try connecting again.',
        'Не удалось начать вход в Xiaomi. Повторите подключение.',
      );
    }
    if (normalized.contains('not_connected')) {
      return _copy(
        'Xiaomi authorization has expired. Connect the account again.',
        'Авторизация Xiaomi недействительна. Подключите аккаунт повторно.',
      );
    }
    if (normalized.contains('(401') || normalized.contains('(403')) {
      return _copy(
        'Your LIFE OS session has expired. Sign in again.',
        'Сессия LIFE OS истекла. Войдите в аккаунт повторно.',
      );
    }
    return _copy(
      'Sleep sync failed. Retry now or check Xiaomi/Mi Fitness and the server connection.',
      'Не удалось синхронизировать сон. Повторите попытку и проверьте Mi Fitness и соединение с сервером.',
    );
  }

  String _lastSyncLabel(DateTime instant) {
    final local = instant.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return _copy('Last check (device time): ', 'Последняя проверка (время телефона): ') +
        date + ' · ' + time;
  }

  String _counts(CloudSleepSyncState state) {
    if (state.lastSessionCount == 0) {
      return _copy(
        'No sleep sessions returned in the last check.',
        'При последней проверке записей сна не получено.',
      );
    }
    return _copy('Sleep sessions found: ', 'Найдено периодов сна: ') +
        state.lastSessionCount.toString() +
        _copy(' · imported/updated: ', ' · добавлено/обновлено: ') +
        state.lastImportedCount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(currentLocale.value, 'health_connect_title'),
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _copy(
            'Source: Xiaomi Cloud / Mi Fitness. Completed sleep is saved to PocketBase and appears in Timeline on all devices. No Health Connect permission required.',
            'Источник: Xiaomi Cloud / Mi Fitness. Завершённый сон сохраняется в PocketBase и появляется в Timeline на всех устройствах. Доступ к Health Connect не требуется.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (_firstLoad)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _copy('Checking connection…', 'Проверяем подключение…'),
                  style: theme.textTheme.bodyMedium,
                )),
              ],
            ),
          )
        else
          ValueListenableBuilder<CloudSleepSyncState>(
            valueListenable: _cloud.state,
            builder: (context, state, _) {
              final isSyncing = state.phase == CloudSleepSyncPhase.syncing;
              final busy = _actionRunning || isSyncing;
              final connected = state.configured;
              final error = state.error?.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_status(state), style: theme.textTheme.bodyMedium),
                  if (error != null && error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: theme.colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorText(error),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error))),
                      ],
                    ),
                  ],
                  if (connected) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_copy(
                        'Automatic sleep synchronization',
                        'Автоматическая синхронизация сна',
                      )),
                      subtitle: Text(_copy(
                        'The server checks Xiaomi and adds completed nights.',
                        'Сервер проверяет Xiaomi и добавляет завершённый сон.',
                      )),
                      value: state.enabled,
                      onChanged: busy
                          ? null
                          : (value) => unawaited(_toggle(value)),
                    ),
                    if (state.lastSyncUtc != null) ...[
                      const SizedBox(height: 4),
                      Text(_lastSyncLabel(state.lastSyncUtc!),
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(_counts(state), style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 16),
                    AppButton.secondary(
                      label: _copy('Synchronize now', 'Синхронизировать сейчас'),
                      icon: Icons.sync_rounded,
                      loading: busy,
                      fullWidth: true,
                      onPressed: busy ? null : () => unawaited(_syncNow()),
                    ),
                    const SizedBox(height: 8),
                    AppButton.ghost(
                      label: _copy('Disconnect Xiaomi account', 'Отключить аккаунт Xiaomi'),
                      onPressed: busy ? null : () => unawaited(_confirmDisconnect()),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    AppButton.primary(
                      label: state.phase == CloudSleepSyncPhase.connecting
                          ? _copy('Continue Xiaomi sign-in', 'Продолжить вход в Xiaomi')
                          : _copy('Connect Xiaomi / Mi Fitness', 'Подключить Xiaomi / Mi Fitness'),
                      icon: Icons.cloud_outlined,
                      loading: busy,
                      fullWidth: true,
                      onPressed: busy ? null : () => unawaited(_connect()),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

@Deprecated('Use SleepSyncSettingsSection')
typedef HealthConnectSettingsSection = SleepSyncSettingsSection;
