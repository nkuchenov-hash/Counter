import 'dart:async';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/services/morning_start_preference.dart';
import 'package:flutter/material.dart';

/// Device-local setting; does not disable sleep synchronization or records.
class MorningStartSettingsSection extends StatefulWidget {
  const MorningStartSettingsSection({super.key});

  @override
  State<MorningStartSettingsSection> createState() =>
      _MorningStartSettingsSectionState();
}

class _MorningStartSettingsSectionState
    extends State<MorningStartSettingsSection> {
  String? _profileId;
  bool _enabled = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileId = DatabaseService.instance.currentProfileId;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final enabled = await MorningStartPreference.isEnabled(_profileId);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) AppSnack.failed();
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
      await MorningStartPreference.setEnabled(_profileId, enabled);
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
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(t(locale, 'morning_prompt_toggle')),
      subtitle: Text(
        t(locale, 'morning_prompt_description'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: _enabled,
      onChanged: _loaded && !_saving
          ? (next) => unawaited(_save(next))
          : null,
    );
  }
}
