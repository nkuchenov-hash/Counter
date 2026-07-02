import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late String _language;
  late String _timeZone;

  static const List<String> _timezoneOptions = [
    'Local',
    'UTC',
    'GMT+3',
    'GMT-5',
  ];

  @override
  void initState() {
    super.initState();
    final s = DatabaseService.instance.settings;
    _language = resolvedUiLanguageCode(s.language);
    final validTz = DatabaseService.instance.profileTimezoneOptions;
    final storedTz = s.preferredTimeZone.trim();
    if (validTz.contains(storedTz)) {
      _timeZone = storedTz;
    } else if (validTz.contains('UTC')) {
      _timeZone = 'UTC';
    } else if (validTz.isNotEmpty) {
      _timeZone = validTz.first;
    } else {
      _timeZone = storedTz.isEmpty ? 'UTC' : storedTz;
    }
  }

  Future<void> _save() async {
    try {
      await DatabaseService.instance.saveSettings(
        DatabaseService.instance.settings.copyWith(
          language: _language,
          preferredTimeZone: _timeZone,
          primaryLanguage: _language,
        ),
      );
      currentLocale.value = _language;
      widget.onSaved?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = currentLocale.value;
    return Scaffold(
      appBar: AppBar(title: Text(t(locale, 'settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t(locale, 'settings'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_language),
            initialValue: _language,
            decoration: InputDecoration(
              labelText: t(locale, 'language_label'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final code in supportedUiLanguageCodes())
                DropdownMenuItem<String>(
                  value: code,
                  child: Text(nativeUiLanguageLabel(code)),
                ),
            ],
            onChanged: (String? v) {
              if (v == null) return;
              setState(() => _language = v);
              unawaited(_save());
            },
          ),
          const Divider(),
          ListTile(
            title: Text(t(locale, 'time_zone')),
            subtitle: Text(_timeZone),
            trailing: _buildTimezoneDropdown(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneDropdown(BuildContext context) {
    if (_timezoneOptions.isEmpty) {
      return Text(t(currentLocale.value, 'loading_settings'));
    }
    if (!_timezoneOptions.contains(_timeZone)) {
      return Text(t(currentLocale.value, 'loading_settings'));
    }
    return DropdownButton<String>(
      value: _timeZone,
      items: _timezoneOptions
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (String? v) {
        if (v == null) return;
        setState(() => _timeZone = v);
        _save();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// LifeOS Dashboard: 5 nav destinations; stack index 4–5 = Categories / Profile (More menu).
// Active record live-timer in Timeline.
// ---------------------------------------------------------------------------
