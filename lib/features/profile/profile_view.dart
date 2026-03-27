import 'package:counter/auth_service.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// PROFILE FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------

/// Security (Profile): Biometric lock toggle. Persists to profiles.biometric_enabled. No biometric data in cloud.
class _SecuritySection extends StatelessWidget {
  const _SecuritySection({this.onSaved});

  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = DatabaseService.instance.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(currentLocale.value, 'security_section'), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        SwitchListTile(
          value: s.biometricEnabled,
          onChanged: (bool value) async {
            try {
              await DatabaseService.instance.saveSettings(s.copyWith(biometricEnabled: value));
              onSaved?.call();
            } catch (_) {}
          },
          title: Text(t(currentLocale.value, 'biometric_lock')),
          subtitle: Text(t(currentLocale.value, 'biometric_lock_subtitle')),
          secondary: const Icon(Icons.fingerprint_rounded),
        ),
      ],
    );
  }
}

/// Account Security (Profile): show current user (email/displayName from AuthService), Logout.
class _AccountSecuritySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email;
    final authDisplayName = user?.displayName;
    final theme = Theme.of(context);

    return StreamBuilder<UserSettings>(
      stream: DatabaseService.instance.userSettingsStream,
      initialData: DatabaseService.instance.settings,
      builder: (context, snap) {
        final profileName = snap.data?.displayName;
        final subtitle = (profileName != null && profileName.trim().isNotEmpty)
            ? profileName.trim()
            : (authDisplayName != null && authDisplayName.isNotEmpty
                ? authDisplayName
                : (email ?? user?.uid ?? '—'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(currentLocale.value, 'account_security'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            ListTile(
              title: Text(t(currentLocale.value, 'signed_in_as')),
              subtitle: Text(subtitle),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text(t(currentLocale.value, 'log_out'),
                  style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500)),
              onTap: () => _logout(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(context);
    var showSlowSnackBar = true;
    Future.delayed(const Duration(seconds: 1), () {
      if (showSlowSnackBar) {
        messenger.showSnackBar(SnackBar(content: Text(t(currentLocale.value, 'logging_out'))));
      }
    });
    try {
      await AuthBridge.signOut();
      await AuthService.instance.signOut();
    } catch (_) {
      showSlowSnackBar = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'sign_out_failed'))),
        );
      }
    } finally {
      showSlowSnackBar = false;
      try {
        DatabaseService.instance.clearLocalStateOnSignOut();
        DatabaseService.instance.onSignOut?.call();
      } catch (_) {}
    }
  }
}

/// Profile tab: Language and Timezone. Zero-trust dropdown to prevent assertion crash.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _language;
  late String _timeZone;
  late List<String> _activeLanguages;
  late String _primaryLanguage;
  late String _themeMode;
  late final TextEditingController _displayNameController;
  bool _savingTimeZone = false;
  bool _timeZoneDirty = false;

  @override
  void initState() {
    super.initState();
    final s = DatabaseService.instance.settings;
    _language = s.language;
    _timeZone = s.preferredTimeZone;
    _activeLanguages = List.from(s.effectiveActiveLanguages);
    _primaryLanguage = s.primaryLanguage;
    _themeMode = s.themeMode;
    _displayNameController =
        TextEditingController(text: s.displayName ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveTheme() async {
    try {
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(themeMode: _themeMode),
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    }
  }

  Future<void> _saveLanguage() async {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    }
  }

  Future<void> _saveDisplayName() async {
    try {
      final trimmed = _displayNameController.text.trim();
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(
          displayName: trimmed.isEmpty ? null : trimmed,
        ),
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
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
      } else {
        setState(() => _timeZone = DatabaseService.instance.settings.preferredTimeZone);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _timeZone = DatabaseService.instance.settings.preferredTimeZone);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'timezone_save_failed'))),
      );
    } finally {
      if (mounted) setState(() => _savingTimeZone = false);
    }
  }

  Future<void> _addLanguage(String langCode) async {
    if (_activeLanguages.contains(langCode)) return;
    setState(() => _activeLanguages = [..._activeLanguages, langCode]);
    try {
      await DatabaseService.instance.addLanguageToAllCategories(langCode);
      final ok = await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(activeLanguages: _activeLanguages),
      );
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'added_language_categories').replaceFirst('%s', langCode))),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _activeLanguages = List.from(DatabaseService.instance.settings.effectiveActiveLanguages));
    }
  }

  @override
  Widget build(BuildContext context) {
    final validTimezones = tz_settings.kTimezoneOptions.map((e) => e.label).toList();
    final safeTimeZone = validTimezones.contains(_timeZone) ? _timeZone : 'UTC';
    final locale = currentLocale.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(locale, 'profile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t(locale, 'profile'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _AccountSecuritySection(),
          const Divider(),
          _SecuritySection(onSaved: widget.onSaved),
          const Divider(),
          Text(t(locale, 'appearance'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
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
              if (next.isEmpty) return;
              setState(() => _themeMode = next.first);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _saveTheme,
            child: Text(t(locale, 'save_theme')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: t(locale, 'display_name_label'),
              hintText: t(locale, 'display_name_hint'),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _saveDisplayName,
            child: Text(t(locale, 'save_display_name')),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: InputDecoration(
              labelText: t(locale, 'language_label'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: 'en', child: Text(t(locale, 'language_english'))),
              DropdownMenuItem(value: 'ru', child: Text(t(locale, 'language_russian'))),
            ],
            onChanged: (String? v) {
              if (v != null) setState(() => _language = v);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _saveLanguage,
            child: Text(t(locale, 'save_language')),
          ),
          const Divider(),
          ListTile(
            title: Text(t(locale, 'manage_languages')),
            subtitle: Text(t(locale, 'active_primary').replaceFirst('%s', _activeLanguages.join(', ')).replaceFirst('%s', _primaryLanguage)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                if (!_activeLanguages.contains('ru'))
                  FilledButton.tonal(
                    onPressed: () => _addLanguage('ru'),
                    child: Text(t(currentLocale.value, 'add_russian_ru')),
                  ),
                if (!_activeLanguages.contains('en'))
                  FilledButton.tonal(
                    onPressed: () => _addLanguage('en'),
                    child: Text(t(currentLocale.value, 'add_english_en')),
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(t(locale, 'time_zone')),
            subtitle: Text(safeTimeZone),
            trailing: _savingTimeZone
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownMenu<String>(
              initialSelection: safeTimeZone,
              expandedInsets: EdgeInsets.zero,
              enableFilter: true,
              enableSearch: true,
              label: Text(t(locale, 'search_timezones')),
              dropdownMenuEntries: validTimezones
                  .map((z) => DropdownMenuEntry<String>(value: z, label: z))
                  .toList(),
              onSelected: _savingTimeZone ? null : (v) {
                if (v == null) return;
                setState(() {
                  _timeZone = v;
                  _timeZoneDirty = true;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: FilledButton(
              onPressed: (_savingTimeZone || !_timeZoneDirty) ? null : () async {
                await _selectTimeZone(_timeZone);
                if (mounted) setState(() => _timeZoneDirty = false);
              },
              child: Text(t(locale, 'save_timezone')),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t(locale, 'diagnostic_uid').replaceFirst('%s', DatabaseService.instance.currentProfileId?.toString() ?? '—'),
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
