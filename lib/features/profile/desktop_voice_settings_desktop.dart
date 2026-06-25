import 'dart:async';
import 'dart:io' show Platform;

import 'package:counter/core/diagnostics/desktop_voice_diag.dart';
import 'package:counter/core/services/desktop_stt_helper_service.dart';
import 'package:counter/core/services/desktop_voice_acceptance_bridge.dart';
import 'package:counter/core/services/desktop_tray_service.dart';
import 'package:counter/core/services/desktop_voice_hotkey.dart';
import 'package:counter/core/services/desktop_voice_settings.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/core/widgets/app_mic_level_bars.dart';
import 'package:counter/core/widgets/app_settings_layout.dart';
import 'package:counter/features/profile/desktop_voice_settings_section.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Desktop Voice tab — mockup-aligned layout (hero + 2×2 grid + tip + footer).
///
/// Diagnostics are hidden under a collapsed card at the bottom.
class DesktopVoiceSettingsDesktopGrid extends StatefulWidget {
  const DesktopVoiceSettingsDesktopGrid({
    super.key,
    this.onHotkeyChanged,
  });

  final Future<bool> Function(DesktopVoiceHotkeyConfig config)? onHotkeyChanged;

  @override
  State<DesktopVoiceSettingsDesktopGrid> createState() =>
      _DesktopVoiceSettingsDesktopGridState();
}

class _DesktopVoiceSettingsDesktopGridState
    extends State<DesktopVoiceSettingsDesktopGrid> {
  final _settings = DesktopVoiceSettings.instance;
  final _stt = DesktopSttHelperService.instance;

  StreamSubscription<double>? _monitorSub;
  double _monitorLevel = 0;
  bool _monitorActive = false;
  List<InputDevice> _inputDevices = const [];
  String? _selectedMicId;

  List<String> _diagLines = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    _settings.addListener(_onSettingsChanged);
  }

  Future<void> _bootstrap() async {
    await _settings.loadIfNeeded();
    _selectedMicId = _settings.selectedMicDeviceId;
    try {
      _inputDevices = await _stt.listInputDevices();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    unawaited(_stopMicMonitor());
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshDiagnostics() async {
    await _stt.fetchDiagnostics();
    final lines = <String>[
      ..._stt.lastDiagnostics.toDiagLines(),
      ...DesktopVoiceDiag.instance.lines,
    ];
    if (!mounted) return;
    setState(() => _diagLines = lines);
  }

  Future<void> _startMicMonitor() async {
    if (_monitorActive) return;
    final label = _inputDevices
        .where((d) => d.id == _selectedMicId)
        .map((d) => d.label)
        .cast<String?>()
        .firstWhere((e) => e != null, orElse: () => null);
    final ok = await _stt.startListening(
      deviceId: _selectedMicId,
      deviceLabel: label,
    );
    if (!ok || !mounted) return;
    _monitorSub = _stt.amplitudeStream?.listen((level) {
      if (mounted) setState(() => _monitorLevel = level);
    });
    setState(() => _monitorActive = true);
  }

  Future<void> _stopMicMonitor() async {
    await _monitorSub?.cancel();
    _monitorSub = null;
    await _stt.cancelListening();
    if (mounted) {
      setState(() {
        _monitorActive = false;
        _monitorLevel = 0;
      });
    }
  }

  Future<void> _captureHotkey() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);

    if (kIsWeb ||
        !Platform.isWindows ||
        !DesktopVoiceHotkey.isSupportedPlatform) {
      return AppSettingsGridCard(
        title: t(loc, 'desktop_voice_settings_section'),
        subtitle: t(loc, 'desktop_voice_mobile_unavailable'),
        child: const SizedBox.shrink(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 100,
          width: double.infinity,
          child: AppSettingsGridCard(
            leading: _HeroIconTile(icon: Icons.mic_none_outlined),
            title: t(loc, 'desktop_voice_settings_section'),
            subtitle: t(loc, 'desktop_voice_settings_subtitle'),
            trailing: Switch(
              value: _settings.enabled,
              onChanged: (v) async {
                await _settings.setEnabled(v);
                await widget.onHotkeyChanged?.call(_settings.hotkey);
              },
            ),
            child: const SizedBox.shrink(),
          ),
        ),
        if ((_settings.hotkeyRegistrationError ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            t(loc, 'desktop_voice_hotkey_register_error')
                .replaceFirst('%s', _settings.hotkeyRegistrationError!.trim()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox(
                  height: 248,
                  child: _HotkeyCard(
                    onChange: _captureHotkey,
                    onReset: () async {
                      final previous = _settings.hotkey;
                      await _settings.resetHotkeyToDefault();
                      final ok = await widget.onHotkeyChanged?.call(
                            DesktopVoiceHotkeyConfig.defaultConfig,
                          ) ??
                          true;
                      if (!ok) await _settings.setHotkey(previous);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 248,
                  child: _BehaviorCard(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _VoiceWidgetCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MicrophoneCard(
                devices: _inputDevices,
                selectedId: _selectedMicId,
                monitorLevel: _monitorLevel,
                monitorActive: _monitorActive,
                onSelect: (id) async {
                  final label = _inputDevices
                      .where((d) => d.id == id)
                      .map((d) => d.label)
                      .cast<String?>()
                      .firstWhere((e) => e != null, orElse: () => null);
                  setState(() => _selectedMicId = id);
                  await _settings.setSelectedMicDevice(
                    id: id,
                    label: label,
                  );
                },
                onToggleMonitor: () {
                  if (_monitorActive) {
                    unawaited(_stopMicMonitor());
                  } else {
                    unawaited(_startMicMonitor());
                  }
                },
                showNoSignal: _monitorActive &&
                    _monitorLevel < 0.008 &&
                    !_stt.audioLevelSeen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 80,
          width: double.infinity,
          child: AppSettingsGridCard(
            title: t(loc, 'desktop_voice_card_tip'),
            trailing: Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: Text(
              t(loc, 'desktop_voice_tray_tip'),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: const Color(0xFF666666),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 22),
              childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              initiallyExpanded: false,
              title: Text(
                t(loc, 'desktop_voice_diagnostics_expand'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                AppSettingsActionRow(
                  children: [
                    AppButton.secondary(
                      label: t(loc, 'desktop_voice_simulate_hotkey'),
                      onPressed: () {
                        DesktopVoiceAcceptanceBridge.simulateHotkeyToggle?.call();
                      },
                    ),
                    AppButton.secondary(
                      label: t(loc, 'desktop_voice_acceptance_planning'),
                      onPressed: () => unawaited(
                        _runAcceptanceCommand(
                          'Price Reporter Planning',
                        ),
                      ),
                    ),
                    AppButton.secondary(
                      label: t(loc, 'desktop_voice_acceptance_age_mod'),
                      onPressed: () => unawaited(
                        _runAcceptanceCommand(
                          'Price Reporter AGE SOLUTIONS ADD MOD',
                        ),
                      ),
                    ),
                    AppButton.secondary(
                      label: t(loc, 'desktop_voice_refresh_diagnostics'),
                      onPressed: () => unawaited(_refreshDiagnostics()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._diagLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: SelectableText(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runAcceptanceCommand(String transcript) async {
    final runner = DesktopVoiceAcceptanceBridge.runCommand;
    if (runner == null) return;
    await _stopMicMonitor();
    await runner(transcript);
    await _refreshDiagnostics();
  }
}

class _HeroIconTile extends StatelessWidget {
  const _HeroIconTile({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: theme.colorScheme.onSurface, size: 26),
    );
  }
}

class _HotkeyCard extends StatelessWidget {
  const _HotkeyCard({required this.onChange, required this.onReset});

  final VoidCallback onChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    return AppSettingsGridCard(
      leading: Icon(Icons.keyboard_alt_outlined,
          color: theme.colorScheme.onSurface),
      title: t(loc, 'desktop_voice_card_hotkey'),
      subtitle: t(loc, 'desktop_voice_hotkey_press_keys'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppHotkeyKeycaps(
            label: DesktopVoiceSettings.instance.hotkey.displayLabel,
          ),
          const SizedBox(height: 16),
          AppSettingsActionRow(
            children: [
              AppButton.secondary(
                label: t(loc, 'desktop_voice_settings_change_hotkey'),
                onPressed: onChange,
              ),
              AppButton.secondary(
                label: t(loc, 'desktop_voice_settings_reset_hotkey'),
                onPressed: onReset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BehaviorCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    return AppSettingsGridCard(
      leading: const Icon(Icons.tune_rounded),
      title: t(loc, 'desktop_voice_card_behavior'),
      child: Column(
        children: [
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_autostart'),
            value: DesktopVoiceSettings.instance.autostart,
            onChanged: (v) async {
              await DesktopVoiceSettings.instance.setAutostart(v);
              await DesktopTrayService.applyAutostartRegistry();
            },
          ),
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_launch_hidden'),
            subtitle: t(loc, 'desktop_voice_settings_launch_hidden_hint'),
            value: DesktopVoiceSettings.instance.launchHidden,
            onChanged: (v) async {
              await DesktopVoiceSettings.instance.setLaunchHidden(v);
              await DesktopTrayService.applyAutostartRegistry();
            },
          ),
          AppSettingsSwitchRow(
            title: t(loc, 'desktop_voice_settings_show_on_hotkey'),
            value: DesktopVoiceSettings.instance.showWidgetOnHotkey,
            onChanged: (v) =>
                DesktopVoiceSettings.instance.setShowWidgetOnHotkey(v),
          ),
        ],
      ),
    );
  }
}

class _VoiceWidgetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final s = DesktopVoiceSettings.instance;
    return AppSettingsGridCard(
      leading: const Icon(Icons.widgets_outlined),
      title: t(loc, 'desktop_voice_card_widget'),
      child: Column(
        children: [
          _CheckboxRow(
            title: t(loc, 'desktop_voice_widget_play_sound'),
            value: s.playSoundOnStartFinish,
            onChanged: (v) => s.setPlaySoundOnStartFinish(v),
          ),
          _CheckboxRow(
            title: t(loc, 'desktop_voice_widget_auto_close'),
            value: s.autoCloseAfterApply,
            onChanged: (v) => s.setAutoCloseAfterApply(v),
          ),
          _CheckboxRow(
            title: t(loc, 'desktop_voice_widget_show_preview'),
            value: s.showPreviewBeforeConfirm,
            onChanged: (v) => s.setShowPreviewBeforeConfirm(v),
          ),
          _CheckboxRow(
            title: t(loc, 'desktop_voice_widget_show_undo'),
            value: s.showUndoAfterApply,
            onChanged: (v) => s.setShowUndoAfterApply(v),
          ),
        ],
      ),
    );
  }
}

class _MicrophoneCard extends StatelessWidget {
  const _MicrophoneCard({
    required this.devices,
    required this.selectedId,
    required this.monitorLevel,
    required this.monitorActive,
    required this.onSelect,
    required this.onToggleMonitor,
    required this.showNoSignal,
  });

  final List<InputDevice> devices;
  final String? selectedId;
  final double monitorLevel;
  final bool monitorActive;
  final ValueChanged<String?> onSelect;
  final VoidCallback onToggleMonitor;
  final bool showNoSignal;

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    return AppSettingsGridCard(
      leading: const Icon(Icons.settings_voice_outlined),
      title: t(loc, 'desktop_voice_card_microphone'),
      subtitle: t(loc, 'desktop_voice_mic_select_subtitle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownMenu<String?>(
            initialSelection: selectedId,
            expandedInsets: EdgeInsets.zero,
            label: Text(t(loc, 'desktop_voice_mic_select_label')),
            dropdownMenuEntries: [
              DropdownMenuEntry<String?>(
                value: null,
                label: t(loc, 'desktop_voice_mic_device_default'),
              ),
              for (final d in devices)
                DropdownMenuEntry<String?>(
                  value: d.id,
                  label: d.label,
                ),
            ],
            onSelected: onSelect,
          ),
          const SizedBox(height: 12),
          Text(
            t(loc, 'desktop_voice_mic_input_level'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          AppMicLevelBars(level: monitorLevel, height: 32),
          const SizedBox(height: 8),
          if (showNoSignal)
            Text(
              t(loc, 'desktop_voice_mic_no_signal'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 16),
          AppSettingsActionRow(
            children: [
              AppButton.secondary(
                label: monitorActive
                    ? t(loc, 'desktop_voice_mic_stop_monitor')
                    : t(loc, 'desktop_voice_mic_start_monitor'),
                onPressed: onToggleMonitor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: theme.colorScheme.onSurface,
                checkColor: theme.colorScheme.surface,
                side: const BorderSide(color: Color(0xFFDDD8D2)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14.5,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
