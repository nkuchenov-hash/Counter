import 'dart:async';

import 'package:counter/core/app_build_info.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/timezone_quick_picker.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/features/profile/desktop_voice_settings_desktop.dart';
import 'package:counter/features/profile/desktop_voice_settings_section.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/features/profile/settings/account_settings_section.dart';
import 'package:counter/features/profile/settings/notification_settings_section.dart';
import 'package:counter/features/profile/settings/security_settings_section.dart';


// ---------------------------------------------------------------------------
// PROFILE FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------


/// Profile tab: Language and Timezone. Auto-saves on change.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.onSaved,
    this.onDesktopVoiceHotkeyChanged,
    this.onTestDesktopVoice,
  });

  final VoidCallback? onSaved;
  final Future<bool> Function(DesktopVoiceHotkeyConfig config)?
  onDesktopVoiceHotkeyChanged;
  final VoidCallback? onTestDesktopVoice;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _language;
  late String _timeZone;
  late String _themeMode;
  late final TextEditingController _displayNameController;
  late final FocusNode _displayNameFocus;

  Timer? _displayNameDebounce;
  String _lastSavedDisplayName = '';
  bool _savingDisplayName = false;
  bool _savingTheme = false;
  bool _savingLanguage = false;

  bool _savingTimeZone = false;
  AppSettingsTab _desktopSettingsTab = AppSettingsTab.desktopVoice;

  static const _nameDebounceDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    final s = DatabaseService.instance.settings;
    _language = resolvedUiLanguageCode(s.language);
    _timeZone = s.preferredTimeZone;
    _themeMode = s.themeMode;
    _lastSavedDisplayName = s.displayName?.trim() ?? '';
    _displayNameController = TextEditingController(text: s.displayName ?? '');
    _displayNameFocus = FocusNode();
    _displayNameFocus.addListener(_onDisplayNameFocusChange);
  }

  void _onDisplayNameFocusChange() {
    if (!_displayNameFocus.hasFocus) {
      _flushDisplayNameSave();
    }
  }

  @override
  void dispose() {
    _displayNameDebounce?.cancel();
    _displayNameFocus.removeListener(_onDisplayNameFocusChange);
    _displayNameFocus.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _scheduleDisplayNameSave() {
    _displayNameDebounce?.cancel();
    _displayNameDebounce = Timer(_nameDebounceDuration, () {
      unawaited(_persistDisplayNameIfNeeded());
    });
  }

  void _flushDisplayNameSave() {
    _displayNameDebounce?.cancel();
    _displayNameDebounce = null;
    unawaited(_persistDisplayNameIfNeeded());
  }

  Future<void> _persistDisplayNameIfNeeded() async {
    final trimmed = _displayNameController.text.trim();
    if (trimmed == _lastSavedDisplayName) return;
    if (_savingDisplayName) {
      _displayNameDebounce?.cancel();
      _displayNameDebounce = Timer(const Duration(milliseconds: 120), () {
        unawaited(_persistDisplayNameIfNeeded());
      });
      return;
    }
    if (!mounted) return;
    setState(() => _savingDisplayName = true);
    try {
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(
          displayName: trimmed.isEmpty ? null : trimmed,
        ),
      );
      if (!mounted) return;
      if (ok) {
        _lastSavedDisplayName = trimmed;
        widget.onSaved?.call();
        AppSnack.saved();
      } else {
        AppSnack.failed();
      }
    } catch (_) {
      if (mounted) AppSnack.failed();
    } finally {
      if (mounted) setState(() => _savingDisplayName = false);
      final again = _displayNameController.text.trim();
      if (mounted && again != _lastSavedDisplayName) {
        _scheduleDisplayNameSave();
      }
    }
  }

  Future<void> _saveTheme(String next) async {
    if (_savingTheme) return;
    setState(() {
      _themeMode = next;
      _savingTheme = true;
    });
    try {
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(themeMode: _themeMode),
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved?.call();
        AppSnack.saved();
      } else {
        setState(
          () => _themeMode = DatabaseService.instance.settings.themeMode,
        );
        AppSnack.failed();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _themeMode = DatabaseService.instance.settings.themeMode,
        );
        AppSnack.failed();
      }
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _saveLanguage(String next) async {
    if (_savingLanguage) return;
    setState(() {
      _language = resolvedUiLanguageCode(next);
      _savingLanguage = true;
    });
    try {
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(
          language: _language,
          primaryLanguage: _language,
        ),
      );
      if (!mounted) return;
      if (ok) {
        currentLocale.value = _language;
        widget.onSaved?.call();
        AppSnack.saved();
      } else {
        setState(() {
          final s = DatabaseService.instance.settings;
          _language = s.language;
        });
        AppSnack.failed();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final s = DatabaseService.instance.settings;
          _language = s.language;
        });
        AppSnack.failed();
      }
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _selectTimeZone(String v) async {
    if (_savingTimeZone) return;
    setState(() => _savingTimeZone = true);
    try {
      final ok = await DatabaseService.instance.updateTimeZone(v);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      if (ok) {
        setState(() => _timeZone = v);
        widget.onSaved?.call();
        AppSnack.saved();
      } else {
        setState(
          () => _timeZone = DatabaseService.instance.settings.preferredTimeZone,
        );
        AppSnack.failed();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _timeZone = DatabaseService.instance.settings.preferredTimeZone,
      );
      AppSnack.failed();
    } finally {
      if (mounted) setState(() => _savingTimeZone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validTimezones = tz_settings.kProfileTimezoneCatalog
        .map((e) => e.profileValue)
        .toList();
    final safeTimeZone =
        tz_settings.catalogEntryForStoredTimezone(_timeZone)?.profileValue ??
        (validTimezones.contains(_timeZone) ? _timeZone : 'UTC');
    final locale = currentLocale.value;
    final useDesktopLayout =
        settingsIsWideDesktop(context) &&
        shellUsesSideNavigation(MediaQuery.sizeOf(context).width);

    if (useDesktopLayout) {
      return Theme(
        data: settingsNeutralTheme(context),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: _buildDesktopSettings(context, locale, safeTimeZone),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(t(locale, 'settings'))),
      body: _buildMobileSettings(context, locale, safeTimeZone),
    );
  }

  Widget _buildDesktopSettings(
    BuildContext context,
    String locale,
    String safeTimeZone,
  ) {
    final tabLabels = {
      AppSettingsTab.account: t(locale, 'settings_tab_account'),
      AppSettingsTab.preferences: t(locale, 'settings_tab_preferences'),
      AppSettingsTab.desktopVoice: t(locale, 'settings_tab_desktop_voice'),
      AppSettingsTab.notifications: t(locale, 'settings_tab_notifications'),
      AppSettingsTab.appearance: t(locale, 'settings_tab_appearance'),
      AppSettingsTab.about: t(locale, 'settings_tab_about'),
    };

    return AppSettingsPageBody(
      children: [
        Text(
          t(locale, 'profile_page_title'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 32,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        AppSettingsCategoryTabs(
          selected: _desktopSettingsTab,
          labels: tabLabels,
          onSelected: (tab) => setState(() => _desktopSettingsTab = tab),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 0),
          color: const Color(0xFFE6E2DC),
        ),
        const SizedBox(height: 20),
        switch (_desktopSettingsTab) {
          AppSettingsTab.account => AppSettingsSectionCard(
            title: t(locale, 'account_security'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccountSecuritySection(),
                const SizedBox(height: 8),
                SecuritySection(onSaved: widget.onSaved, embedded: true),
              ],
            ),
          ),
          AppSettingsTab.preferences => AppSettingsSectionCard(
            title: t(locale, 'profile_time_locale_section'),
            child: _buildTimeLocaleFields(context, locale, safeTimeZone),
          ),
          AppSettingsTab.desktopVoice => DesktopVoiceSettingsDesktopGrid(
            onHotkeyChanged: widget.onDesktopVoiceHotkeyChanged,
          ),
          AppSettingsTab.notifications => AppSettingsSectionCard(
            title: t(locale, 'profile_notifications_section'),
            subtitle: t(locale, 'profile_notifications_subtitle'),
            child: ProfileNotificationsSection(embedded: true),
          ),
          AppSettingsTab.appearance => AppSettingsSectionCard(
            title: t(locale, 'appearance'),
            child: _buildAppearanceFields(context, locale),
          ),
          AppSettingsTab.about => AppSettingsSectionCard(
            title: t(locale, 'profile_about_section'),
            child: Text(
              '${t(locale, 'profile_build_label')} ${AppBuildInfo.gitCommit} · ${AppBuildInfo.builtAt}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        },
      ],
    );
  }

  Widget _buildMobileSettings(
    BuildContext context,
    String locale,
    String safeTimeZone,
  ) {
    return AppSettingsPageBody(
      children: [
        AppSettingsSectionCard(
          title: t(locale, 'account_security'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountSecuritySection(),
              const SizedBox(height: 8),
              SecuritySection(onSaved: widget.onSaved, embedded: true),
            ],
          ),
        ),
        AppSettingsSectionCard(
          title: t(locale, 'profile_notifications_section'),
          subtitle: kIsWeb ? null : t(locale, 'profile_notifications_subtitle'),
          child: ProfileNotificationsSection(embedded: true),
        ),
        DesktopVoiceSettingsSection(
          onHotkeyChanged: widget.onDesktopVoiceHotkeyChanged,
          onTestVoice: widget.onTestDesktopVoice,
        ),
        AppSettingsSectionCard(
          title: t(locale, 'appearance'),
          child: _buildAppearanceFields(context, locale),
        ),
        AppSettingsSectionCard(
          title: t(locale, 'profile_time_locale_section'),
          child: _buildTimeLocaleFields(context, locale, safeTimeZone),
        ),
        AppSettingsSectionCard(
          title: t(locale, 'profile_about_section'),
          child: Text(
            '${t(locale, 'profile_build_label')} ${AppBuildInfo.gitCommit} · ${AppBuildInfo.builtAt}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceFields(BuildContext context, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'light',
                  label: Text(t(locale, 'theme_light')),
                  icon: const Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: 'dark',
                  label: Text(t(locale, 'theme_dark')),
                  icon: const Icon(Icons.dark_mode_rounded),
                ),
                ButtonSegment(
                  value: 'system',
                  label: Text(t(locale, 'theme_system')),
                  icon: const Icon(Icons.settings_suggest_rounded),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (Set<String> next) {
                if (_savingTheme) return;
                if (next.isEmpty) return;
                final v = next.first;
                if (v == _themeMode) return;
                unawaited(_saveTheme(v));
              },
            ),
            if (_savingTheme)
              Positioned(
                right: 4,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _displayNameController,
          focusNode: _displayNameFocus,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: t(locale, 'display_name_label'),
            hintText: t(locale, 'display_name_hint'),
            border: const OutlineInputBorder(),
            suffixIcon: _savingDisplayName
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: AppLoading(size: AppLoadingSize.small),
                    ),
                  )
                : null,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _scheduleDisplayNameSave(),
          onEditingComplete: _flushDisplayNameSave,
        ),
      ],
    );
  }

  Widget _buildTimeLocaleFields(
    BuildContext context,
    String locale,
    String safeTimeZone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownMenu<String>(
                key: ValueKey(_language),
                initialSelection: _language,
                expandedInsets: EdgeInsets.zero,
                label: Text(t(locale, 'language_label')),
                dropdownMenuEntries: [
                  for (final code in supportedUiLanguageCodes())
                    DropdownMenuEntry<String>(
                      value: code,
                      label: nativeUiLanguageLabel(code),
                    ),
                ],
                onSelected: _savingLanguage
                    ? null
                    : (v) {
                        if (v == null || v == _language) return;
                        unawaited(_saveLanguage(v));
                      },
              ),
            ),
            if (_savingLanguage)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: AppLoading(size: AppLoadingSize.small),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AbsorbPointer(
          absorbing: _savingTimeZone,
          child: Opacity(
            opacity: _savingTimeZone ? 0.55 : 1,
            child: TimezonePickerField(
              currentTimezone: safeTimeZone,
              label: t(locale, 'search_timezones'),
              enabled: !_savingTimeZone,
              onSelected: (v) => unawaited(_selectTimeZone(v)),
            ),
          ),
        ),
        if (_savingTimeZone)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: AppLoading(size: AppLoadingSize.small),
            ),
          ),
      ],
    );
  }
}
