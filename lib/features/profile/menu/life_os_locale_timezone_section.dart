import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/shared/time/profile_timezone_catalog.dart';
import 'package:counter/shared/time/timezone_quick_preferences.dart';
import 'package:flutter/material.dart';

/// Settings → Interface: searchable language, timezone mode, quick favorites.
/// Owns only on-demand UI state; profile wall-clock is still Brain-owned.
class LifeOsLocaleTimezoneControls extends StatefulWidget {
  const LifeOsLocaleTimezoneControls({super.key});

  @override
  State<LifeOsLocaleTimezoneControls> createState() =>
      _LifeOsLocaleTimezoneControlsState();
}

class _LifeOsLocaleTimezoneControlsState
    extends State<LifeOsLocaleTimezoneControls> {
  bool _savingLanguage = false;
  bool _savingTimezone = false;
  bool _timezonePreferencesLoaded = false;
  bool _timezoneLoadStarted = false;
  int _favoriteChangeRevision = 0;
  String? _deviceTimezone;
  TimezoneQuickPreferences _timezonePreferences =
      const TimezoneQuickPreferences(automatic: false, favorites: []);

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
  String tr(String ru, String en) => _ru ? ru : en;

  @override
  void initState() {
    super.initState();
    // Keep OS platform queries and preference reads off the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureTimezoneControlsLoaded();
    });
  }

  void _ensureTimezoneControlsLoaded() {
    if (_timezoneLoadStarted) return;
    _timezoneLoadStarted = true;
    unawaited(_loadTimezoneControls());
  }

  String get _timezoneProfileId {
    // Use the same stable key as the header quick switcher (UserSettings).
    final db = DatabaseService.instance;
    final settingsId = db.settings.userId.trim();
    return settingsId.isNotEmpty ? settingsId : (db.currentProfileId ?? '');
  }

  Future<void> _loadTimezoneControls() async {
    try {
      final db = DatabaseService.instance;
      final values = await Future.wait<Object?>([
        TimezoneQuickPreferenceStore.load(
          _timezoneProfileId,
          currentTimezone: db.settings.preferredTimeZone,
        ),
        TimezoneQuickPreferenceStore.deviceTimezone(),
      ]);
      if (!mounted) return;
      setState(() {
        _timezonePreferences = values[0] as TimezoneQuickPreferences;
        _deviceTimezone = values[1] as String?;
        _timezonePreferencesLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _timezonePreferencesLoaded = true);
    }
  }

  Future<void> _setLanguage(String code) async {
    if (_savingLanguage) return;
    final next = resolvedUiLanguageCode(code);
    final db = DatabaseService.instance;
    if (resolvedUiLanguageCode(db.settings.primaryLanguage) == next) return;
    setState(() => _savingLanguage = true);
    try {
      final ok = await db.saveSettings(db.settings.copyWith(
        language: next, primaryLanguage: next,
      ));
      if (!ok) AppSnack.failed();
    } catch (_) {
      AppSnack.failed();
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _setAutomaticTimezone(bool enabled) async {
    if (_savingTimezone || !_timezonePreferencesLoaded) return;
    final previous = _timezonePreferences;
    // Optimistic visual feedback before the platform channel / PocketBase.
    setState(() {
      _savingTimezone = true;
      _timezonePreferences = TimezoneQuickPreferences(
        automatic: enabled, favorites: previous.favorites,
      );
    });
    var committed = false;
    try {
      if (enabled) {
        final zone = _deviceTimezone ??
            await TimezoneQuickPreferenceStore.deviceTimezone();
        if (zone == null) {
          AppSnack.show(tr('Не удалось определить часовой пояс устройства',
              'Unable to detect the device time zone'), error: true);
          return;
        }
        final ok = await DatabaseService.instance.updateTimeZone(zone);
        if (!ok) {
          AppSnack.failed();
          return;
        }
        _deviceTimezone = zone;
      }
      await TimezoneQuickPreferenceStore.setAutomatic(
          _timezoneProfileId, enabled);
      committed = true;
    } catch (_) {
      AppSnack.failed();
    } finally {
      if (mounted) {
        setState(() {
          _savingTimezone = false;
          if (!committed) _timezonePreferences = previous;
        });
      }
    }
  }

  Future<void> _selectManualTimezone(String zone) async {
    if (_savingTimezone || !_timezonePreferencesLoaded) return;
    setState(() => _savingTimezone = true);
    try {
      final ok = await DatabaseService.instance.updateTimeZone(zone);
      if (!ok) {
        AppSnack.show(tr(
          'Не удалось сохранить часовой пояс в профиле',
          'Could not save the time zone in your profile'), error: true);
        return;
      }
      await TimezoneQuickPreferenceStore.setAutomatic(
          _timezoneProfileId, false);
      if (!mounted) return;
      setState(() => _timezonePreferences = TimezoneQuickPreferences(
        automatic: false, favorites: _timezonePreferences.favorites,
      ));
    } catch (_) {
      AppSnack.failed();
    } finally {
      if (mounted) setState(() => _savingTimezone = false);
    }
  }

  Future<void> _toggleFavoriteTimezone(String zone, bool selected) async {
    if (!_timezonePreferencesLoaded) return;
    final revision = ++_favoriteChangeRevision;
    final previous = _timezonePreferences;
    final canonical = catalogEntryForStoredTimezone(zone)?.profileValue ?? zone;
    final next = previous.favorites.toSet();
    if (selected) {
      next.add(canonical);
    } else {
      next.remove(canonical);
    }
    setState(() => _timezonePreferences = TimezoneQuickPreferences(
      automatic: previous.automatic, favorites: next.toList(),
    ));
    try {
      await TimezoneQuickPreferenceStore.setFavorites(
        _timezoneProfileId, next.toList(),
      );
    } catch (_) {
      // A failed earlier write must not erase a newer chip selection.
      if (mounted && revision == _favoriteChangeRevision) {
        setState(() => _timezonePreferences = previous);
      }
      AppSnack.show(tr('Не удалось сохранить быстрое переключение',
          'Could not save quick-switch time zones'), error: true);
    }
  }

  Widget _languageTimezoneControls() {
    final scheme = Theme.of(context).colorScheme;
    final db = DatabaseService.instance;
    return StreamBuilder<UserSettings>(
      stream: db.userSettingsStream,
      initialData: db.settings,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? db.settings;
        final current = settings.preferredTimeZone;
        final options = <String, String>{
          for (final zone in kProfileTimezoneCatalog)
            zone.profileValue: formatProfileTimezonePickerLabel(zone),
          if (catalogEntryForStoredTimezone(current) == null)
            current: current,
          if (_deviceTimezone != null &&
              catalogEntryForStoredTimezone(_deviceTimezone!) == null)
            _deviceTimezone!: _deviceTimezone!,
        };
        final selectedZone =
            catalogEntryForStoredTimezone(current)?.profileValue ?? current;
        final selectedOption = options.containsKey(selectedZone)
            ? selectedZone : current;
        final favoriteOptions = <String, String>{
          for (final zone in kProfileTimezoneCatalog)
            zone.profileValue: zone.cityName,
          if (_deviceTimezone != null &&
              catalogEntryForStoredTimezone(_deviceTimezone!) == null)
            _deviceTimezone!: _deviceTimezone!,
          for (final id in _timezonePreferences.favorites)
            if (catalogEntryForStoredTimezone(id) == null) id: id,
        };
        final language = resolvedUiLanguageCode(
          settings.primaryLanguage.trim().isNotEmpty
              ? settings.primaryLanguage : settings.language,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form fields are NOT navigation rows: no whole-panel mouse hover.
            // Each independent topic has its own canonical settings card.
            AppSettingsSectionCard(
              title: tr('Язык', 'Language'),
              child: DropdownMenu<String>(
                key: ValueKey('inline-language-$language'),
                initialSelection: language,
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                enableSearch: true,
                label: Text(tr('Язык приложения', 'Application language')),
                dropdownMenuEntries: [
                  for (final code in supportedUiLanguageCodes())
                    DropdownMenuEntry(
                      value: code, label: nativeUiLanguageLabel(code)),
                ],
                onSelected: _savingLanguage
                    ? null : (next) {
                        if (next != null) unawaited(_setLanguage(next));
                      },
              ),
            ),
            AppSettingsSectionCard(
              title: tr('Время', 'Time'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Часовой пояс', 'Time zone'),
                    style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true,
                        label: Text(tr('Автоматически', 'Automatic'))),
                      ButtonSegment(value: false,
                        label: Text(tr('Вручную', 'Manual'))),
                    ],
                    selected: {_timezonePreferences.automatic},
                    onSelectionChanged: !_timezonePreferencesLoaded ||
                            _savingTimezone
                        ? null : (values) => unawaited(
                            _setAutomaticTimezone(values.first)),
                  ),
                  const SizedBox(height: 12),
                  if (_timezonePreferences.automatic)
                    Text(
                      _deviceTimezone == null
                        ? tr('Определение по настройкам устройства — без IP и VPN',
                            'Uses device settings, not IP or VPN')
                        : tr('Часовой пояс устройства: $_deviceTimezone',
                            'Device time zone: $_deviceTimezone'),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  else
                    DropdownMenu<String>(
                      key: ValueKey('inline-timezone-$selectedOption'),
                      initialSelection: selectedOption,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      label: Text(tr('Выбрать часовой пояс', 'Select time zone')),
                      dropdownMenuEntries: [
                        for (final item in options.entries)
                          DropdownMenuEntry(value: item.key, label: item.value),
                      ],
                      onSelected: _savingTimezone
                          ? null : (next) {
                              if (next != null && next != current) {
                                unawaited(_selectManualTimezone(next));
                              }
                            },
                    ),
                  const SizedBox(height: 18),
                  Text(tr('Быстрое переключение', 'Quick switching'),
                    style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(tr('Отметьте пояса, которые должны быть в быстром меню.',
                          'Check zones to show in the quick menu.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (final entry in favoriteOptions.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _timezonePreferences.favorites
                              .contains(entry.key),
                          onSelected: !_timezonePreferencesLoaded ? null
                            : (selected) => unawaited(
                                _toggleFavoriteTimezone(entry.key, selected)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) => _languageTimezoneControls();
}
