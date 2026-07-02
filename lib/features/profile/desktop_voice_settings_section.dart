import 'dart:async';
import 'dart:io' show Platform;

import 'package:counter/core/diagnostics/desktop_voice_log.dart';
import 'package:counter/core/services/desktop_hotkey_codec.dart';
import 'package:counter/core/services/desktop_voice_hotkey.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/services/desktop_tray_service.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/voice_command_parser.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Profile → Desktop Voice settings (Windows desktop full; mobile info only).
class DesktopVoiceSettingsSection extends StatefulWidget {
  const DesktopVoiceSettingsSection({
    super.key,
    this.onHotkeyChanged,
    this.onTestVoice,
  });

  final Future<bool> Function(DesktopVoiceHotkeyConfig config)? onHotkeyChanged;
  final VoidCallback? onTestVoice;

  @override
  State<DesktopVoiceSettingsSection> createState() =>
      _DesktopVoiceSettingsSectionState();
}

class _DesktopVoiceSettingsSectionState extends State<DesktopVoiceSettingsSection> {
  final _settings = DesktopVoiceSettings.instance;
  final _parserTestController = TextEditingController(
    text: 'Price Reporter AGE SOLUTIONS ADD MOD',
  );
  String? _parserTestOutput;

  bool get _isWindowsDesktop =>
      !kIsWeb && Platform.isWindows && DesktopVoiceHotkey.isSupportedPlatform;

  @override
  void initState() {
    super.initState();
    unawaited(_settings.loadIfNeeded().then((_) {
      if (mounted) setState(() {});
    }));
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _parserTestController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _captureHotkey() async {
    final loc = currentLocale.value;
    final captured = await showDialog<DesktopVoiceHotkeyConfig>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const HotkeyCaptureDialog(),
    );
    if (captured == null || !captured.isValid) return;

    final previous = _settings.hotkey;
    await _settings.setHotkey(captured);
    final ok = await widget.onHotkeyChanged?.call(captured) ?? true;
    if (!ok) {
      await _settings.setHotkey(previous);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(loc, 'desktop_voice_hotkey_error')
                .replaceFirst('%s', _settings.hotkeyRegistrationError ?? '')),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(loc, 'desktop_voice_hotkey_saved')
              .replaceFirst('%s', captured.displayLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;

    if (!_isWindowsDesktop) {
      if (kIsWeb) return const SizedBox.shrink();
      return AppSettingsSectionCard(
        title: t(loc, 'desktop_voice_settings_section'),
        subtitle: t(loc, 'desktop_voice_mobile_unavailable'),
        child: const SizedBox.shrink(),
      );
    }

    final err = _settings.hotkeyRegistrationError;
    final status = _settings.voiceStatusLine;
    final diag = DesktopVoiceLog.instance.lines;

    return AppSettingsSectionCard(
      title: t(loc, 'desktop_voice_settings_section'),
      subtitle: t(loc, 'desktop_voice_settings_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_enable'),
            value: _settings.enabled,
            onChanged: (v) async {
              await _settings.setEnabled(v);
              await widget.onHotkeyChanged?.call(_settings.hotkey);
            },
          ),
          AppSettingsInfoRow(
            label: t(loc, 'desktop_voice_settings_hotkey'),
            value: _settings.hotkey.displayLabel,
          ),
          AppSettingsActionRow(
            children: [
              AppButton.secondary(
                label: t(loc, 'desktop_voice_settings_change_hotkey'),
                onPressed: _captureHotkey,
              ),
              AppButton.secondary(
                label: t(loc, 'desktop_voice_settings_reset_hotkey'),
                onPressed: () async {
                  final previous = _settings.hotkey;
                  await _settings.resetHotkeyToDefault();
                  final ok = await widget.onHotkeyChanged
                          ?.call(DesktopVoiceHotkeyConfig.defaultConfig) ??
                      true;
                  if (!ok) await _settings.setHotkey(previous);
                },
              ),
              if (widget.onTestVoice != null)
                AppButton.secondary(
                  label: t(loc, 'desktop_voice_test_command'),
                  onPressed: widget.onTestVoice,
                ),
            ],
          ),
          if (err != null && err.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t(loc, 'desktop_voice_hotkey_error').replaceFirst('%s', err),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_autostart'),
            value: _settings.autostart,
            onChanged: (v) async {
              await _settings.setAutostart(v);
              await DesktopTrayService.applyAutostartRegistry();
            },
          ),
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_launch_hidden'),
            subtitle: t(loc, 'desktop_voice_settings_launch_hidden_hint'),
            value: _settings.launchHidden,
            onChanged: (v) async {
              await _settings.setLaunchHidden(v);
              await DesktopTrayService.applyAutostartRegistry();
            },
          ),
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_show_on_hotkey'),
            value: _settings.showWidgetOnHotkey,
            onChanged: (v) => _settings.setShowWidgetOnHotkey(v),
          ),
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              status,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t(loc, 'desktop_voice_parser_test_label'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _parserTestController,
            decoration: InputDecoration(
              hintText: t(loc, 'desktop_voice_parser_test_hint'),
              border: const OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          AppSettingsActionRow(
            children: [
              AppButton.secondary(
                label: t(loc, 'desktop_voice_parser_test_run'),
                onPressed: () {
                  final parsed = parseVoiceCommand(
                    rules: DatabaseService.instance.rules,
                    transcript: _parserTestController.text,
                  );
                  final path = parsed.matchedCategoryDisplayPath ?? '—';
                  final line =
                      '${parsed.confidence.name} · $path · ${parsed.recordTitle}';
                  setState(() {
                    _parserTestOutput = t(loc, 'desktop_voice_parser_test_result')
                        .replaceFirst('%s', line);
                  });
                },
              ),
            ],
          ),
          if (_parserTestOutput != null) ...[
            const SizedBox(height: 6),
            Text(
              _parserTestOutput!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (diag.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t(loc, 'desktop_voice_diag_title'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            ...diag.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HotkeyCaptureDialog extends StatefulWidget {
  const HotkeyCaptureDialog({super.key});

  @override
  State<HotkeyCaptureDialog> createState() => _HotkeyCaptureDialogState();
}

class _HotkeyCaptureDialogState extends State<HotkeyCaptureDialog> {
  LogicalKeyboardKey? _pendingKey;
  PhysicalKeyboardKey? _pendingPhysical;
  late bool _control;
  late bool _shift;
  late bool _alt;
  late bool _meta;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final m = DesktopHotkeyCodec.readModifiers();
    _control = m.control;
    _shift = m.shift;
    _alt = m.alt;
    _meta = m.meta;
  }

  String get _preview {
    if (_pendingKey == null) return '—';
    return DesktopHotkeyCodec.displayLabel(
      logicalKey: _pendingKey!,
      control: _control,
      shift: _shift,
      alt: _alt,
      meta: _meta,
    );
  }

  bool get _canSave {
    if (_pendingKey == null || _pendingPhysical == null) return false;
    return DesktopHotkeyCodec.isValidCombo(
      logicalKey: _pendingKey!,
      control: _control,
      shift: _shift,
      alt: _alt,
      meta: _meta,
    );
  }

  void _validate() {
    if (_pendingKey == null) {
      _validationMessage = null;
      return;
    }
    if (DesktopHotkeyCodec.isModifierKey(_pendingKey!)) {
      _validationMessage =
          t(currentLocale.value, 'desktop_voice_hotkey_invalid_modifier');
      return;
    }
    if (!_control && !_shift && !_alt && !_meta) {
      _validationMessage =
          t(currentLocale.value, 'desktop_voice_hotkey_need_modifier');
      return;
    }
    _validationMessage = null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return AlertDialog(
      title: Text(t(loc, 'desktop_voice_settings_change_hotkey')),
      content: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          final mods = DesktopHotkeyCodec.readModifiers();
          setState(() {
            _control = mods.control;
            _shift = mods.shift;
            _alt = mods.alt;
            _meta = mods.meta;
            if (!DesktopHotkeyCodec.isModifierKey(event.logicalKey)) {
              _pendingKey = event.logicalKey;
              _pendingPhysical = event.physicalKey;
            }
            _validate();
          });
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(loc, 'desktop_voice_hotkey_press_keys')),
            const SizedBox(height: 12),
            Text(
              _preview,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton.ghost(
          label: t(loc, 'cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: t(loc, 'save'),
          onPressed: _canSave
              ? () {
                  Navigator.of(context).pop(
                    DesktopVoiceHotkeyConfig(
                      logicalKey: _pendingKey!,
                      physicalKey: _pendingPhysical!,
                      control: _control,
                      shift: _shift,
                      alt: _alt,
                      meta: _meta,
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}
