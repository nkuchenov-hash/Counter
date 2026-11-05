import 'dart:async';

import 'package:counter/core/app_build_info.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/core/widgets/timezone_quick_picker.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/shared/voice/platforms/desktop/desktop_voice_settings.dart';
import 'package:counter/features/settings/timezone_settings.dart'
    as tz_settings;
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:counter/core/widgets/app_loading.dart';
import 'package:counter/features/profile/settings/account_settings_section.dart';
import 'package:counter/features/profile/calendar_integrations/calendar_integrations_section.dart';
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
    this.onOpenViktor,
  });

  final VoidCallback? onSaved;
  final Future<bool> Function(DesktopVoiceHotkeyConfig config)?
  onDesktopVoiceHotkeyChanged;
  final VoidCallback? onTestDesktopVoice;
  final VoidCallback? onOpenViktor;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _MobileSettingsSection {
  account,
  calendars,
  timeLocale,
  appearance,
  notifications,
  morning,
  viktor,
  about,
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
  AppSettingsTab _desktopSettingsTab = AppSettingsTab.account;
  _MobileSettingsSection? _mobileSection;

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

    final section = _mobileSection;
    return PopScope(
      canPop: section == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mobileSection != null && mounted) {
          setState(() => _mobileSection = null);
        }
      },
      child: Theme(
        data: settingsNeutralTheme(context),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: section == null
                ? null
                : IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _mobileSection = null),
                  ),
            toolbarHeight: section == null ? 80 : 60,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              section == null
                  ? t(locale, 'settings')
                  : _mobileSectionTitle(locale, section),
              style: (section == null
                      ? Theme.of(context).textTheme.headlineLarge
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          body: section == null
              ? _buildMobileSettings(context, locale, safeTimeZone)
              : _buildMobileSettingsDetail(context, locale, safeTimeZone, section),
        ),
      ),
    );
  }

  Widget _buildDesktopSettings(
    BuildContext context,
    String locale,
    String safeTimeZone,
  ) {
    final tabLabels = {
      AppSettingsTab.account: t(locale, 'settings_tab_account'),
      AppSettingsTab.calendars: t(locale, 'calendar_integrations_title'),
      AppSettingsTab.preferences: t(locale, 'settings_tab_preferences'),
      AppSettingsTab.desktopVoice: locale.startsWith('ru') ? 'Виктор · ИИ' : 'Viktor · AI',
      AppSettingsTab.notifications: t(locale, 'settings_tab_notifications'),
      AppSettingsTab.appearance: t(locale, 'settings_tab_appearance'),
      AppSettingsTab.about: t(locale, 'settings_tab_about'),
    };

    return AppSettingsPageBody(
      children: [
        Text(
          t(locale, 'settings'),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        AppSettingsCategoryTabs(
          selected: _desktopSettingsTab,
          labels: tabLabels,
          onSelected: (tab) => setState(() => _desktopSettingsTab = tab),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 0),
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 20),
        switch (_desktopSettingsTab) {
          AppSettingsTab.account => AppSettingsSectionCard(
            title: t(locale, 'account_security'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDisplayNameField(context, locale),
                const SizedBox(height: 16),
                AccountSecuritySection(),
                const SizedBox(height: 8),
                SecuritySection(onSaved: widget.onSaved, embedded: true),
              ],
            ),
          ),
          AppSettingsTab.calendars => AppSettingsSectionCard(
            title: t(locale, 'calendar_integrations_title'),
            child: const CalendarIntegrationsSection(),
          ),
          AppSettingsTab.preferences => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSettingsSectionCard(
                title: t(locale, 'profile_time_locale_section'),
                child: _buildTimeLocaleFields(context, locale, safeTimeZone),
              ),
              const SizedBox(height: 16),
              AppSettingsSectionCard(
                title: t(locale, 'morning_prompt_section'),
                child: const MorningStartSettingsSection(),
              ),
            ],
          ),
          AppSettingsTab.desktopVoice => AppSettingsSectionCard(
            title: 'Виктор · ИИ',
            child: AppButton.primary(
              label: 'Открыть Виктора',
              icon: Icons.auto_awesome_rounded,
              onPressed: widget.onOpenViktor,
            ),
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

  String _mobileSectionTitle(String locale, _MobileSettingsSection section) {
    return switch (section) {
      _MobileSettingsSection.account => t(locale, 'account_security'),
      _MobileSettingsSection.calendars => t(locale, 'calendar_integrations_title'),
      _MobileSettingsSection.timeLocale => t(locale, 'profile_time_locale_section'),
      _MobileSettingsSection.appearance => t(locale, 'appearance'),
      _MobileSettingsSection.notifications => t(locale, 'profile_notifications_section'),
      _MobileSettingsSection.morning => t(locale, 'morning_prompt_section'),
      _MobileSettingsSection.viktor => locale.startsWith('ru') ? 'Виктор · ИИ' : 'Viktor · AI',
      _MobileSettingsSection.about => t(locale, 'profile_about_section'),
    };
  }

  Widget _buildMobileSettings(
    BuildContext context,
    String locale,
    String safeTimeZone,
  ) {
    AppSettingsNavigationRow destination(
      _MobileSettingsSection section,
      IconData icon, {
      String? subtitle,
    }) {
      return AppSettingsNavigationRow(
        title: _mobileSectionTitle(locale, section),
        subtitle: subtitle,
        leading: AppSettingsMenuIcon(icon: icon),
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _mobileSection = section);
        },
      );
    }

    return AppSettingsPageBody(
      children: [
        AppSettingsNavigationGroup(
          children: [
            destination(_MobileSettingsSection.account, Icons.person_outline_rounded),
            destination(_MobileSettingsSection.calendars, Icons.calendar_month_outlined),
          ],
        ),
        AppSettingsNavigationGroup(
          children: [
            destination(_MobileSettingsSection.appearance, Icons.palette_outlined),
            destination(_MobileSettingsSection.timeLocale, Icons.language_rounded),
            destination(_MobileSettingsSection.notifications, Icons.notifications_none_rounded),
            destination(_MobileSettingsSection.morning, Icons.wb_sunny_outlined),
          ],
        ),
        AppSettingsNavigationGroup(
          children: [
            destination(_MobileSettingsSection.viktor, Icons.auto_awesome_outlined),
            destination(_MobileSettingsSection.about, Icons.info_outline_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileSettingsDetail(
    BuildContext context,
    String locale,
    String safeTimeZone,
    _MobileSettingsSection section,
  ) {
    final title = _mobileSectionTitle(locale, section);
    final content = switch (section) {
      _MobileSettingsSection.account => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDisplayNameField(context, locale),
          const SizedBox(height: 16),
          AccountSecuritySection(),
          const SizedBox(height: 8),
          SecuritySection(onSaved: widget.onSaved, embedded: true),
        ],
      ),
      _MobileSettingsSection.calendars => const CalendarIntegrationsSection(),
      _MobileSettingsSection.timeLocale =>
          _buildTimeLocaleFields(context, locale, safeTimeZone),
      _MobileSettingsSection.appearance => _buildAppearanceFields(context, locale),
      _MobileSettingsSection.notifications =>
          ProfileNotificationsSection(embedded: true),
      _MobileSettingsSection.morning => const MorningStartSettingsSection(),
      _MobileSettingsSection.viktor => AppButton.primary(
        label: locale.startsWith('ru') ? 'Открыть Виктора' : 'Open Viktor',
        icon: Icons.auto_awesome_rounded,
        onPressed: widget.onOpenViktor,
      ),
      _MobileSettingsSection.about => Text(
        '${t(locale, 'profile_build_label')} ${AppBuildInfo.gitCommit} · ${AppBuildInfo.builtAt}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    };
    return AppSettingsPageBody(
      children: [
        AppSettingsSectionCard(
          title: title,
          subtitle: section == _MobileSettingsSection.notifications && !kIsWeb
              ? t(locale, 'profile_notifications_subtitle')
              : null,
          child: content,
        ),
      ],
    );
  }

  Widget _buildDisplayNameField(BuildContext context, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

  Widget _buildAppearanceFields(BuildContext context, String locale) {
    return AppSettingsThemeModePicker(
      value: _themeMode,
      lightLabel: t(locale, 'theme_light'),
      darkLabel: t(locale, 'theme_dark'),
      systemLabel: t(locale, 'theme_system'),
      saving: _savingTheme,
      onChanged: (next) {
        if (next == _themeMode || _savingTheme) return;
        unawaited(_saveTheme(next));
      },
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

/// Device-local setting; does not disable sleep synchronization or records.
class MorningStartSettingsSection extends StatefulWidget {
  const MorningStartSettingsSection({super.key});

  @override
  State<MorningStartSettingsSection> createState() =>
      _MorningStartSettingsSectionState();
}

class _MorningStartSettingsSectionState
    extends State<MorningStartSettingsSection> {
  bool _enabled = true;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final enabled = await MorningStartPreference.isEnabled(
        DatabaseService.instance.currentProfileId,
      );
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
      AppSnack.failed();
    }
  }

  Future<void> _save(bool enabled) async {
    if (!_loaded || _saving) return;
    final previous = _enabled;
    setState(() {
      _enabled = enabled;
      _saving = true;
    });
    try {
      await MorningStartPreference.setEnabled(
        DatabaseService.instance.currentProfileId,
        enabled,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _enabled = previous);
        AppSnack.failed();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    if (!_loaded) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(t(locale, 'morning_prompt_toggle')),
        subtitle: Text(
          t(locale, 'morning_prompt_description'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: _loadFailed
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                onPressed: () => unawaited(_load()),
                icon: const Icon(Icons.refresh),
              )
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      );
    }
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(t(locale, 'morning_prompt_toggle')),
      subtitle: Text(
        t(locale, 'morning_prompt_description'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: _enabled,
      onChanged: !_saving ? (next) => unawaited(_save(next)) : null,
    );
  }
}
