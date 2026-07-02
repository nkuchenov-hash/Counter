import 'dart:async';import 'package:counter/l10n/dictionary.dart';import 'package:flutter/material.dart';import 'package:shared_preferences/shared_preferences.dart';/// Record-to-plan suggestion prefs (Planning settings sheet only).
///
/// Owns UI state so toggles rebuild inside the modal; reads/writes
/// [plans_record_link_suggestions_enabled] and [plans_record_link_suggestion_mode].
class PlanRecordLinkSuggestionSettingsBlock extends StatefulWidget {
  const PlanRecordLinkSuggestionSettingsBlock();

  @override
  State<PlanRecordLinkSuggestionSettingsBlock> createState() =>
      PlanRecordLinkSuggestionSettingsBlockState();
}

class PlanRecordLinkSuggestionSettingsBlockState
    extends State<PlanRecordLinkSuggestionSettingsBlock> {
  static const String _prefsEnabled = 'plans_record_link_suggestions_enabled';
  static const String _prefsMode = 'plans_record_link_suggestion_mode';
  static const String _modeAsk = 'ask';
  static const String _modeAuto = 'auto';

  bool _enabled = true;
  String _mode = _modeAsk;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFromPrefs());
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsEnabled) ?? true;
      final raw = prefs.getString(_prefsMode);
      final mode = raw == _modeAuto ? _modeAuto : _modeAsk;
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _mode = mode;
      });
    } catch (_) {}
  }

  Future<void> _persist({bool? enabled, String? mode}) async {
    final nextEnabled = enabled ?? _enabled;
    final nextMode = mode != null
        ? (mode == _modeAuto ? _modeAuto : _modeAsk)
        : _mode;
    setState(() {
      _enabled = nextEnabled;
      _mode = nextMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsEnabled, nextEnabled);
      await prefs.setString(_prefsMode, nextMode);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          title: Text(t(loc, 'record_link_suggestions_title')),
          subtitle: Text(
            t(loc, 'record_link_suggestions_subtitle'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onChanged: (value) => unawaited(_persist(enabled: value)),
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: _modeAsk,
                label: Text(t(loc, 'record_link_suggestion_mode_ask')),
              ),
              ButtonSegment<String>(
                value: _modeAuto,
                label: Text(t(loc, 'record_link_suggestion_mode_auto')),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              unawaited(_persist(mode: next.first));
            },
          ),
        ],
      ],
    );
  }
}
