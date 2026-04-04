import 'dart:async';

import 'package:counter/auth_service.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/auth_bridge.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/profile/timezone_settings.dart' as tz_settings;
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// PROFILE FEATURE — UI_ISOLATION (§7). All strings via t() from dictionary.
// No hardcoded UI text. No direct DB writes (use DatabaseService).
// ---------------------------------------------------------------------------

/// Security (Profile): Biometric lock toggle. Persists to profiles.biometric_enabled.
class _SecuritySection extends StatelessWidget {
  const _SecuritySection({this.onSaved});

  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    final s = DatabaseService.instance.settings;
    return SwitchListTile(
      value: s.biometricEnabled,
      onChanged: (bool value) async {
        try {
          final ok = await DatabaseService.instance
              .saveSettings(s.copyWith(biometricEnabled: value));
          if (ok) {
            onSaved?.call();
            AppSnack.saved();
          } else {
            AppSnack.failed();
          }
        } catch (_) {
          AppSnack.failed();
        }
      },
      title: Text(t(currentLocale.value, 'biometric_lock')),
      subtitle: Text(t(currentLocale.value, 'biometric_lock_subtitle')),
      secondary: const Icon(Icons.fingerprint_rounded),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Account: current user + Logout in one row (auth logic unchanged).
class _AccountSecuritySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email;
    final authDisplayName = user?.displayName;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
        final loc = currentLocale.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyLarge,
                    children: [
                      TextSpan(text: '${t(loc, 'signed_in_as')} '),
                      TextSpan(
                        text: subtitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _logout(context),
                icon: Icon(Icons.logout_rounded, color: scheme.error, size: 20),
                label: Text(
                  t(loc, 'log_out'),
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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
        messenger.showSnackBar(
            SnackBar(content: Text(t(currentLocale.value, 'logging_out'))));
      }
    });
    try {
      await AuthBridge.signOut();
      await AuthService.instance.signOut();
    } catch (_) {
      showSlowSnackBar = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(t(currentLocale.value, 'sign_out_failed'))),
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

/// Profile tab: Language and Timezone. Auto-saves on change.
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
  late String _themeMode;
  late final TextEditingController _displayNameController;
  late final FocusNode _displayNameFocus;

  Timer? _displayNameDebounce;
  String _lastSavedDisplayName = '';
  bool _savingDisplayName = false;
  bool _savingTheme = false;
  bool _savingLanguage = false;

  bool _savingTimeZone = false;

  static const _nameDebounceDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    final s = DatabaseService.instance.settings;
    _language = resolvedUiLanguageCode(s.language);
    _timeZone = s.preferredTimeZone;
    _activeLanguages = List.from(s.effectiveActiveLanguages);
    _themeMode = s.themeMode;
    _lastSavedDisplayName = s.displayName?.trim() ?? '';
    _displayNameController =
        TextEditingController(text: s.displayName ?? '');
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
        setState(() => _themeMode = DatabaseService.instance.settings.themeMode);
        AppSnack.failed();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _themeMode = DatabaseService.instance.settings.themeMode);
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
            () => _timeZone = DatabaseService.instance.settings.preferredTimeZone);
        AppSnack.failed();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _timeZone = DatabaseService.instance.settings.preferredTimeZone);
      AppSnack.failed();
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
          SnackBar(
            content: Text(
              t(currentLocale.value, 'added_language_categories')
                  .replaceFirst('%s', langCode),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _activeLanguages =
            List.from(DatabaseService.instance.settings.effectiveActiveLanguages));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validTimezones = tz_settings.kTimezoneOptions.map((e) => e.label).toList();
    final safeTimeZone = validTimezones.contains(_timeZone) ? _timeZone : 'UTC';
    final locale = currentLocale.value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(t(locale, 'profile')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          _AccountSecuritySection(),
          const Divider(),
          _SecuritySection(onSaved: widget.onSaved),
          const Divider(),
          Text(t(locale, 'appearance'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            focusNode: _displayNameFocus,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _scheduleDisplayNameSave(),
            onEditingComplete: _flushDisplayNameSave,
          ),
          const SizedBox(height: 16),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t(locale, 'active_primary')
                .replaceFirst('%s', _activeLanguages.join(', '))
                .replaceFirst(
                  '%s',
                  DatabaseService.instance.settings.primaryLanguage,
                ),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Builder(
            builder: (context) {
              final addable = supportedUiLanguageCodes()
                  .where((c) => !_activeLanguages.contains(c))
                  .toList();
              if (addable.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t(locale, 'all_supported_languages_active'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String?>(
                  key: ValueKey<String>('add_lang_${addable.join()}'),
                  initialValue: null,
                  decoration: InputDecoration(
                    labelText: t(locale, 'add_active_language'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final code in addable)
                      DropdownMenuItem<String?>(
                        value: code,
                        child: Text(nativeUiLanguageLabel(code)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) unawaited(_addLanguage(v));
                  },
                ),
              );
            },
          ),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    t(locale, 'time_zone'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _savingTimeZone,
                  child: Opacity(
                    opacity: _savingTimeZone ? 0.55 : 1,
                    child: DropdownMenu<String>(
                      initialSelection: safeTimeZone,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      label: Text(t(locale, 'search_timezones')),
                      dropdownMenuEntries: validTimezones
                          .map((z) =>
                              DropdownMenuEntry<String>(value: z, label: z))
                          .toList(),
                      onSelected: (v) {
                        if (v == null) return;
                        unawaited(_selectTimeZone(v));
                      },
                    ),
                  ),
                ),
              ),
              if (_savingTimeZone)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
