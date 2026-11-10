import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/context/context_awareness_coordinator.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opt-in Android-only settings: geofence/home, permissions, tracking, privacy.
class ContextAwarenessSettingsSection extends StatefulWidget {
  const ContextAwarenessSettingsSection({super.key});

  @override
  State<ContextAwarenessSettingsSection> createState() =>
      _ContextAwarenessSettingsSectionState();
}

class _ContextAwarenessSettingsSectionState
    extends State<ContextAwarenessSettingsSection> {
  Map<String, dynamic> _status = const {};
  bool _busy = false;
  String? _error;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  String _t(String ru, String en) => _ru ? ru : en;
  final _engine = ContextAwarenessCoordinator.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final state = await _engine.status();
      if (mounted) setState(() => _status = state);
    } catch (_) {
      if (mounted) setState(() => _error = _t(
        'Не удалось получить статус датчиков.',
        'Could not read sensor status.',
      ));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('PlatformException(', '')
            .replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveHome() async {
    var location = await Permission.locationWhenInUse.request();
    if (!location.isGranted) {
      throw StateError(_t('Разрешите точную геолокацию в настройках Android.',
          'Allow precise location in Android settings.'));
    }
    await _engine.setHomeHere();
  }

  Future<void> _enable() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      throw StateError(_t('Нужен доступ к точной геолокации.',
          'Precise location permission is required.'));
    }
    final activity = await Permission.activityRecognition.request();
    if (!activity.isGranted) {
      throw StateError(_t('Разрешите распознавание физической активности.',
          'Allow physical activity recognition.'));
    }
    final background = await Permission.locationAlways.request();
    if (!background.isGranted) {
      throw StateError(_t(
        'В настройках Android выберите «Местоположение → Разрешить всегда», '
        'затем вернитесь и повторите включение.',
        'In Android settings, choose Location → Allow all the time, '
        'then return and enable tracking again.',
      ));
    }
    final owner = DatabaseService.instance.currentProfileId;
    if (owner == null || owner.isEmpty) {
      throw StateError(_t('Сначала войдите в аккаунт.', 'Sign in first.'));
    }
    await _engine.enable(owner);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_engine.supported) {
      return Text(_t(
        'Фоновое распознавание доступно в приложении LIFE OS для Android. '
        'Веб-версия отображает синхронизированные записи.',
        'Background recognition currently requires LIFE OS for Android. '
        'The web version displays synchronized records.',
      ), style: theme.textTheme.bodyMedium);
    }
    final enabled = _status['enabled'] == true;
    final homeSet = _status['homeSet'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_t(
          'LIFE OS замечает выход из дома, ходьбу и поездки и может '
          'корректировать записи с явной привязкой к дому. '
          'Обычные записи приложение не прерывает по догадке.',
          'LIFE OS notices home departures, walking and vehicle trips. '
          'It can correct records explicitly tied to home. '
          'Other manual records are not interrupted on a guess.',
        ), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(
          enabled ? _t('Отслеживание включено', 'Tracking enabled')
              : _t('Отслеживание выключено', 'Tracking disabled'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          homeSet
              ? _t('Дом сохранён на этом устройстве', 'Home saved on this device')
              : _t('Дом ещё не указан', 'Home is not set'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        AppButton.secondary(
          label: _t('Запомнить дом здесь', 'Set home here'),
          icon: Icons.home_outlined,
          onPressed: _busy || enabled ? null : () => unawaited(_run(_saveHome)),
        ),
        const SizedBox(height: 12),
        if (enabled)
          AppButton.secondary(
            label: _t('Отключить и удалить события', 'Stop and clear events'),
            icon: Icons.location_off_outlined,
            onPressed: _busy ? null : () => unawaited(_run(_engine.disable)),
          )
        else
          AppButton.primary(
            label: _t('Включить распознавание', 'Enable recognition'),
            icon: Icons.location_on_outlined,
            onPressed: _busy || !homeSet
                ? null : () => unawaited(_run(_enable)),
          ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          )),
          const SizedBox(height: 8),
          AppButton.secondary(
            label: _t('Открыть настройки Android', 'Open Android settings'),
            icon: Icons.settings_outlined,
            onPressed: () => unawaited(openAppSettings()),
          ),
          const SizedBox(height: 8),
        ],
        Text(_t(
          'Требуется доступ к геолокации «всегда» и распознаванию активности. '
          'На устройстве сохраняются домашняя точка и короткая очередь событий, '
          'а не история координат. Автоматические записи появятся в Timeline '
          'при следующем запуске или возвращении в приложение. '
          'Время обнаружения может отличаться от фактического.',
          'Allow all-the-time location and activity recognition. '
          'The device stores the home point and a short event queue, '
          'not a GPS route. Timeline reconciles these events when '
          'LIFE OS is opened or resumed. Detection can be delayed.',
        ), style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }
}
