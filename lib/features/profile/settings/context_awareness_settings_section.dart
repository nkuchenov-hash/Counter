import 'dart:async';

import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_text_field.dart';
import 'package:counter/data/context/context_awareness_coordinator.dart';
import 'package:counter/data/context/context_awareness_policy.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  List<Map<String, dynamic>> _reviews = const [];
  List<Map<String, dynamic>> _transportReviews = const [];
  List<Map<String, dynamic>> _departureReviews = const [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _addresses = {};
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
      final reviews = await _engine.pendingVisitReviews();
      final transportReviews = await _engine.pendingTransportReviews();
      final departureReviews = await _engine.pendingDepartureReviews();
      if (mounted) setState(() {
        _status = state;
        _reviews = reviews;
        _transportReviews = transportReviews;
        _departureReviews = departureReviews;
      });
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

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String eventId) =>
      _controllers.putIfAbsent(eventId, () => TextEditingController());

  Future<void> _applyVisitReview(String eventId) async {
    final title = _controllerFor(eventId).text.trim();
    if (title.isEmpty) {
      throw StateError(_t('Укажите название места или занятия.',
          'Enter a place or activity name.'));
    }
    if (!await _engine.labelVisit(eventId, title)) {
      throw StateError(_t('Не удалось обновить запись. Повторите.',
          'Could not update the record. Retry.'));
    }
  }

  Future<void> _loadAddresses(Map<String, dynamic> review) async {
    final id = review['eventId']?.toString() ?? '';
    final found = await _engine.suggestVisitAddresses(review);
    if (mounted) setState(() => _addresses[id] = found);
  }

  Widget _buildVisitReview(Map<String, dynamic> review, ThemeData theme) {
    final id = review['eventId']?.toString() ?? '';
    final at = DateTime.tryParse(review['atUtc']?.toString() ?? '');
    final wall = at == null ? '' : DateFormat('dd.MM HH:mm')
        .format(DatabaseService.instance.applyUserOffset(at));
    final controller = _controllerFor(id);
    final choices = _addresses[id] ?? const <String>[];
    final hasPoint = review['latitude'] is num &&
        review['longitude'] is num;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('Остановка · $wall', 'Stop · $wall'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller,
            inputFormatters: [LengthLimitingTextInputFormatter(160)],
            textCapitalization: TextCapitalization.sentences,
            labelText: _t('Где вы были?', 'Where were you?'),
            hintText: _t('Например: кафе, магазин, у друзей',
                'For example: cafe, store, visiting friends'),
          ),
          if (choices.isNotEmpty) ...[
            Text(_t('Адресные подсказки (не названия заведений):',
                'Address hints (not verified venue names):'),
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                for (final candidate in choices)
                  ChoiceChip(
                    label: Text(candidate),
                    selected: controller.text == candidate,
                    onSelected: _busy ? null : (_) => setState(() {
                      controller.text = candidate;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (hasPoint)
            AppButton.secondary(
              label: _t('Предложить адрес', 'Suggest address'),
              icon: Icons.place_outlined,
              onPressed: _busy ? null
                  : () => unawaited(_run(() => _loadAddresses(review))),
            ),
          const SizedBox(height: 6),
          AppButton.primary(
            label: _t('Сохранить название', 'Save place'),
            icon: Icons.check,
            onPressed: _busy ? null
                : () => unawaited(_run(() => _applyVisitReview(id))),
          ),
          const SizedBox(height: 6),
          AppButton.secondary(
            label: _t('Оставить «Вне дома»', 'Keep generic label'),
            icon: Icons.close,
            onPressed: _busy ? null
                : () => unawaited(_run(() => _engine.dismissVisitReview(id))),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Future<void> _chooseTransport(String eventId, String title) async {
    if (!await _engine.labelTransport(eventId, title)) {
      throw StateError(_t(
        'Не удалось уточнить транспорт. Повторите попытку.',
        'Could not update the transport mode. Retry.',
      ));
    }
  }

  Widget _buildTransportReview(Map<String, dynamic> review, ThemeData theme) {
    final id = review['eventId']?.toString() ?? '';
    final at = DateTime.tryParse(review['atUtc']?.toString() ?? '');
    final wall = at == null ? '' : DateFormat('dd.MM HH:mm')
        .format(DatabaseService.instance.applyUserOffset(at));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('Поездка · $wall', 'Trip · $wall'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(_t(
            'Какой транспорт вы использовали?',
            'Which type of transport did you use?',
          ), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final mode in ContextTimelinePolicy.transportTitles(
                  russian: _ru))
                ChoiceChip(
                  label: Text(mode),
                  selected: false,
                  onSelected: _busy ? null : (_) => unawaited(
                    _run(() => _chooseTransport(id, mode)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton.secondary(
            label: _t('Не уточнять', 'Leave as generic transport'),
            icon: Icons.close,
            onPressed: _busy ? null : () => unawaited(
              _run(() => _engine.dismissTransportReview(id)),
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }


  Future<void> _correctDeparture(String eventId) async {
    if (!await _engine.correctDeparture(eventId)) {
      throw StateError(_t(
        'Не удалось исправить автоматическую запись.',
        'Could not correct the inferred record.',
      ));
    }
  }

  Widget _buildDepartureReview(Map<String, dynamic> review, ThemeData theme) {
    final id = review['eventId']?.toString() ?? '';
    final title = (review['priorTitle'] ?? '').toString().trim();
    final at = DateTime.tryParse(review['atUtc']?.toString() ?? '');
    final wall = at == null ? '' : DateFormat('dd.MM HH:mm')
        .format(DatabaseService.instance.applyUserOffset(at));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('Выход из дома · $wall', 'Left home · $wall'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(_t('Запись «$title» завершена автоматически. '
              'Продолжалось ли занятие в дороге?',
              'The "$title" record ended automatically. '
              'Did the activity continue while travelling?'),
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          AppButton.secondary(
            label: _t('Завершение верное', 'End time is correct'),
            icon: Icons.check,
            onPressed: _busy ? null : () => unawaited(
              _run(() => _engine.dismissDepartureReview(id)),
            ),
          ),
          const SizedBox(height: 6),
          AppButton.primary(
            label: _t('Продолжал это занятие', 'Continued the activity'),
            icon: Icons.edit_outlined,
            onPressed: _busy ? null : () => unawaited(
              _run(() => _correctDeparture(id)),
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
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
          'завершать активную запись при выходе из домашней зоны. '
          'Остановки можно уточнять вручную.',
          'LIFE OS notices departures, walking and vehicle trips. '
          'It ends the active record when you leave your home zone. '
          'You can label detected stops.',
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
        if (_departureReviews.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t('Уточнить завершение записей', 'Review ended records'),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final review in _departureReviews)
            _buildDepartureReview(review, theme),
        ],
        if (_transportReviews.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t('Уточнить транспорт', 'Review transport trips'),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final review in _transportReviews)
            _buildTransportReview(review, theme),
        ],
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t('Уточнить обнаруженные места', 'Review detected places'),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_t('Названия ещё неизвестны. Выберите адресную подсказку '
              'или впишите, где вы были.',
              'Place names are uncertain. Choose an address hint '
              'or enter where you were.'), style: theme.textTheme.bodySmall),
          for (final review in _reviews) _buildVisitReview(review, theme),
        ],
        Text(_t(
          'Требуется доступ к геолокации «всегда» и распознаванию активности. '
          'На устройстве сохраняются домашняя точка, короткая очередь событий '
          'и отдельные координаты остановок (когда доступны), но не маршрут. Автоматические записи появятся в Timeline '
          'при следующем запуске или возвращении в приложение. '
          'Время обнаружения может отличаться от фактического.',
          'Allow all-the-time location and activity recognition. '
          'The device stores a home point, a short event queue and '
          'individual stop coordinates when available, not a GPS route. Timeline reconciles these events when '
          'LIFE OS is opened or resumed. Detection can be delayed.',
        ), style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }
}
