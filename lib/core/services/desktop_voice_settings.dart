import 'dart:convert';

import 'package:counter/core/performance/runtime_flags.dart';
import 'package:counter/core/services/desktop_stt_engine.dart';
import 'package:counter/core/services/desktop_voice_engine.dart';
import 'package:counter/core/services/desktop_hotkey_codec.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device Windows desktop voice + tray preferences (local only — not PocketBase).
class DesktopVoiceHotkeyConfig {
  const DesktopVoiceHotkeyConfig({
    required this.logicalKey,
    required this.physicalKey,
    this.control = true,
    this.shift = true,
    this.alt = false,
    this.meta = false,
  });

  final LogicalKeyboardKey logicalKey;
  final PhysicalKeyboardKey physicalKey;
  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;

  static final defaultConfig = DesktopVoiceHotkeyConfig(
    logicalKey: LogicalKeyboardKey.space,
    physicalKey: PhysicalKeyboardKey.space,
    control: true,
    shift: true,
  );

  bool get isValid => DesktopHotkeyCodec.isValidCombo(
        logicalKey: logicalKey,
        control: control,
        shift: shift,
        alt: alt,
        meta: meta,
      );

  String get displayLabel => DesktopHotkeyCodec.displayLabel(
        logicalKey: logicalKey,
        control: control,
        shift: shift,
        alt: alt,
        meta: meta,
      );

  Map<String, dynamic> toJson() => {
        'logicalKeyId': logicalKey.keyId,
        'physicalKeyId': physicalKey.usbHidUsage,
        'control': control,
        'shift': shift,
        'alt': alt,
        'meta': meta,
      };

  static DesktopVoiceHotkeyConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final logicalId = json['logicalKeyId'];
    final physicalId = json['physicalKeyId'];
    if (logicalId is! int || physicalId is! int) return null;
    final cfg = DesktopVoiceHotkeyConfig(
      logicalKey: LogicalKeyboardKey(logicalId),
      physicalKey: PhysicalKeyboardKey(physicalId),
      control: json['control'] == true,
      shift: json['shift'] == true,
      alt: json['alt'] == true,
      meta: json['meta'] == true,
    );
    return cfg.isValid ? cfg : null;
  }
}

/// Singleton local settings for desktop voice + tray (Windows device only).
class DesktopVoiceSettings extends ChangeNotifier {
  DesktopVoiceSettings._();

  static final DesktopVoiceSettings instance = DesktopVoiceSettings._();

  static const _kEnabled = 'desktop_voice_enabled_v1';
  static const _kAutostart = 'desktop_voice_autostart_v1';
  static const _kLaunchHidden = 'desktop_voice_launch_hidden_v1';
  static const _kShowWidgetOnHotkey = 'desktop_voice_show_widget_v1';
  static const _kHotkey = 'desktop_voice_hotkey_v1';
  static const _kPlaySound = 'desktop_voice_play_sound_v1';
  static const _kAutoClose = 'desktop_voice_auto_close_v1';
  static const _kShowPreview = 'desktop_voice_show_preview_v1';
  static const _kShowUndo = 'desktop_voice_show_undo_v1';
  static const _kProductionEngine = 'desktop_voice_production_engine_v1';
  static const _kSttMode = 'desktop_voice_stt_mode_v1';
  static const _kMicDeviceId = 'desktop_voice_mic_device_id_v1';
  static const _kMicDeviceLabel = 'desktop_voice_mic_device_label_v1';
  static const _kLastBenchmark = 'desktop_voice_last_benchmark_v1';

  bool _loaded = false;
  bool _enabled = false;
  bool _autostart = true;
  bool _launchHidden = true;
  bool _showWidgetOnHotkey = true;
  bool _playSoundOnStartFinish = true;
  bool _autoCloseAfterApply = true;
  bool _showPreviewBeforeConfirm = true;
  bool _showUndoAfterApply = true;
  DesktopVoiceEngineId? _productionEngine;
  DesktopSttMode? _sttMode;
  String? _selectedMicDeviceId;
  String? _selectedMicDeviceLabel;
  String? _lastBenchmarkSummary;
  DesktopVoiceHotkeyConfig _hotkey = DesktopVoiceHotkeyConfig.defaultConfig;
  String? _hotkeyRegistrationError;
  String? _voiceStatusLine;

  bool get isLoaded => _loaded;
  bool get enabled => _enabled;
  bool get autostart => _autostart;
  bool get launchHidden => _launchHidden;
  bool get showWidgetOnHotkey => _showWidgetOnHotkey;
  bool get playSoundOnStartFinish => _playSoundOnStartFinish;
  bool get autoCloseAfterApply => _autoCloseAfterApply;
  bool get showPreviewBeforeConfirm => _showPreviewBeforeConfirm;
  bool get showUndoAfterApply => _showUndoAfterApply;
  DesktopVoiceEngineId? get productionEngine => _productionEngine;
  DesktopSttMode get sttMode => _sttMode ?? DesktopSttMode.fastLocal;
  String? get selectedMicDeviceId => _selectedMicDeviceId;
  String? get selectedMicDeviceLabel => _selectedMicDeviceLabel;
  String? get lastBenchmarkSummary => _lastBenchmarkSummary;
  DesktopVoiceHotkeyConfig get hotkey => _hotkey;
  String? get hotkeyRegistrationError => _hotkeyRegistrationError;
  String? get voiceStatusLine => _voiceStatusLine;

  bool get isDesktopVoiceActive =>
      kDesktopVoiceCommandEnabled && _enabled;

  Future<void> loadIfNeeded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? kDesktopVoiceCommandEnabled;
    _autostart = prefs.getBool(_kAutostart) ?? true;
    _launchHidden = prefs.getBool(_kLaunchHidden) ?? true;
    _showWidgetOnHotkey = prefs.getBool(_kShowWidgetOnHotkey) ?? true;
    _playSoundOnStartFinish = prefs.getBool(_kPlaySound) ?? true;
    _autoCloseAfterApply = prefs.getBool(_kAutoClose) ?? true;
    _showPreviewBeforeConfirm = prefs.getBool(_kShowPreview) ?? false;
    _showUndoAfterApply = prefs.getBool(_kShowUndo) ?? true;
    _productionEngine = DesktopVoiceEngineId.tryParse(
      prefs.getString(_kProductionEngine),
    );
    _sttMode = _parseSttMode(prefs.getString(_kSttMode));
    _selectedMicDeviceId = prefs.getString(_kMicDeviceId);
    _selectedMicDeviceLabel = prefs.getString(_kMicDeviceLabel);
    _lastBenchmarkSummary = prefs.getString(_kLastBenchmark);
    final hotkeyRaw = prefs.getString(_kHotkey);
    if (hotkeyRaw != null && hotkeyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(hotkeyRaw);
        if (decoded is Map<String, dynamic>) {
          final parsed = DesktopVoiceHotkeyConfig.fromJson(decoded);
          if (parsed != null) _hotkey = parsed;
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  Future<void> setAutostart(bool value) async {
    _autostart = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutostart, value);
  }

  Future<void> setLaunchHidden(bool value) async {
    _launchHidden = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLaunchHidden, value);
  }

  Future<void> setShowWidgetOnHotkey(bool value) async {
    _showWidgetOnHotkey = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowWidgetOnHotkey, value);
  }

  Future<void> setPlaySoundOnStartFinish(bool value) async {
    _playSoundOnStartFinish = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPlaySound, value);
  }

  Future<void> setAutoCloseAfterApply(bool value) async {
    _autoCloseAfterApply = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoClose, value);
  }

  Future<void> setShowPreviewBeforeConfirm(bool value) async {
    _showPreviewBeforeConfirm = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowPreview, value);
  }

  /// Production recognizer — parakeet default; whisper-tiny never auto-selected.
  DesktopVoiceEngineId resolveProductionEngine() {
    if (_productionEngine != null) return _productionEngine!;
    return DesktopVoiceEngineId.parakeet;
  }

  DesktopSttMode resolveSttMode() => _sttMode ?? DesktopSttMode.fastLocal;

  static DesktopSttMode? _parseSttMode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final m in DesktopSttMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  Future<void> setSttMode(DesktopSttMode mode) async {
    _sttMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSttMode, mode.name);
  }

  Future<void> setProductionEngine(DesktopVoiceEngineId engine) async {
    _productionEngine = engine;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProductionEngine, engine.helperEngineId);
  }

  Future<void> setSelectedMicDevice({String? id, String? label}) async {
    _selectedMicDeviceId = id;
    _selectedMicDeviceLabel = label;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kMicDeviceId);
    } else {
      await prefs.setString(_kMicDeviceId, id);
    }
    if (label == null) {
      await prefs.remove(_kMicDeviceLabel);
    } else {
      await prefs.setString(_kMicDeviceLabel, label);
    }
  }

  Future<void> setLastBenchmarkSummary(String? summary) async {
    _lastBenchmarkSummary = summary;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (summary == null || summary.isEmpty) {
      await prefs.remove(_kLastBenchmark);
    } else {
      await prefs.setString(_kLastBenchmark, summary);
    }
  }

  Future<void> setShowUndoAfterApply(bool value) async {
    _showUndoAfterApply = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowUndo, value);
  }

  Future<void> setHotkey(DesktopVoiceHotkeyConfig config) async {
    if (!config.isValid) return;
    _hotkey = config;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHotkey, jsonEncode(config.toJson()));
  }

  Future<void> resetHotkeyToDefault() =>
      setHotkey(DesktopVoiceHotkeyConfig.defaultConfig);

  void setHotkeyRegistrationError(String? message) {
    if (_hotkeyRegistrationError == message) return;
    _hotkeyRegistrationError = message;
    notifyListeners();
  }

  void setVoiceStatusLine(String? message) {
    if (_voiceStatusLine == message) return;
    _voiceStatusLine = message;
    notifyListeners();
  }
}
