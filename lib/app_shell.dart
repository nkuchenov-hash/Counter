// ---------------------------------------------------------------------------
// APP SHELL — Sovereign Vault Architecture. Dashboard, navigation, FAB, Sync.
// UI_ISOLATION (§7). All tab labels via t(). No UI in main.dart.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/database_service.dart';
import 'package:counter/models.dart';
import 'package:counter/features/calendar/calendar_view.dart';
import 'package:counter/features/categories/category_list_view.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/shared/voice_capture_config.dart';
import 'package:counter/features/shared/voice_input_sheet.dart';
import 'package:counter/features/timeline/timeline_view.dart' hide showAppDateTimePicker;
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// --- Shell-local time helpers (Planetary: UTC + profile offset). ---
DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _two(int n) => n.toString().padLeft(2, '0');

DateTime _localToday() => DatabaseService.instance.getTimelineDeviceLocalToday();

DateTime _utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);

DateTime _displayToUtc(DateTime displayNaive) =>
    DatabaseService.instance.displayTimeToUtc(displayNaive);

String _formatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);

/// Planning task opened from quick-add / draft: not yet on server (no PATCH id).
bool _shellIsNewPlanningDraft(PlanningTask t) {
  if (t.id != 0) return false;
  final p = t.planRowId?.trim() ?? '';
  return p.isEmpty;
}

/// Hides a plan on the current day in optimistic merge until DELETE completes (see [DatabaseService.applyOptimisticPlanningTask]).
const String _shellOptimisticPurgeDateKey = '2099-12-31';

// ---------------------------------------------------------------------------
// Settings page (Language, TimeZone). Persists to users/{uid}.
// ---------------------------------------------------------------------------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _language;
  late String _timeZone;

  static const List<String> _timezoneOptions = ['Local', 'UTC', 'GMT+3', 'GMT-5'];

  @override
  void initState() {
    super.initState();
    final s = DatabaseService.instance.settings;
    _language = s.language;
    _timeZone = s.preferredTimeZone;
    if (_timezoneOptions.isNotEmpty && !_timezoneOptions.contains(_timeZone)) {
      _timeZone = _timezoneOptions.first;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _save());
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
      appBar: AppBar(
        title: Text(t(locale, 'settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t(locale, 'settings'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _language,
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
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async => await _save(),
            child: Text(t(locale, 'save')),
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
      items: _timezoneOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (String? v) {
        if (v == null) return;
        setState(() => _timeZone = v);
        _save();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sync status icon: green = connected, red = offline.
// ---------------------------------------------------------------------------

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({
    required this.connected,
    required this.onTap,
  });

  final bool? connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = connected == null
        ? Colors.grey
        : connected!
            ? Colors.green
            : Colors.red;
    final tooltip = connected == null
        ? t(currentLocale.value, 'sync_checking')
        : connected!
            ? t(currentLocale.value, 'sync_connected')
            : t(currentLocale.value, 'sync_offline');
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.cloud_rounded,
              size: 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LifeOS Dashboard: 5 tabs (Timeline, Planning, Calendar, Categories, Profile).
// Active record live-timer in Timeline; Sync icon in shell.
// ---------------------------------------------------------------------------

class LifeOSDashboard extends StatefulWidget {
  const LifeOSDashboard({super.key});

  @override
  State<LifeOSDashboard> createState() => _LifeOSDashboardState();
}

class _LifeOSDashboardState extends State<LifeOSDashboard> {
  int _tabIndex = 0;

  late DateTime _selectedDate;
  late DateTime _focusedDay;

  final List<Task> _tasks = <Task>[];
  bool _tasksLoading = true;
  late List<CategoryRule> _rules;
  int? _selectedCategoryId;

  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();

  StreamSubscription<String?>? _notificationSub;
  StreamSubscription<List<CategoryRule>>? _categoryRulesSub;

  stt.SpeechToText? _speech;
  bool _speechReady = false;
  /// Last engine init failure (shown with [speech_unavailable] snackbar detail).
  String? _speechLastInitError;
  bool _isVoiceListening = false;
  void Function(String)? _speechStatusCallback;

  bool? _connected;
  StreamSubscription<bool>? _syncSub;

  /// Tracks device-local calendar day so an open session can follow midnight without restart.
  Timer? _deviceLocalMidnightWatchTimer;
  DateTime? _deviceTodayAtLastMidnightCheck;
  String? _deviceLocalDayKeyLast;

  /// Coalesce rapid Play / Start actions (500ms) to avoid double-running timers.
  DateTime? _lastPlayOrStartAction;
  static const Duration _playStartDebounce = Duration(milliseconds: 500);

  /// Stop button / callback: ignore duplicate taps within 300ms (double-dispatch guard).
  DateTime? _lastStopRecordAction;
  static const Duration _stopRecordDebounce = Duration(milliseconds: 300);

  /// Stops sync-failure SnackBars from stacking when rebuilds/errors repeat (e.g. page loop).
  DateTime? _lastSyncFailedSnackAt;
  static const Duration _syncFailedSnackThrottle = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _selectedDate = DatabaseService.instance.getTimelineDeviceLocalToday();
    _focusedDay = DatabaseService.instance.getTimelineDeviceLocalToday();
    _rules = List.from(DatabaseService.instance.rules);
    _selectedCategoryId = DatabaseService.instance.defaultCategoryId;
    unawaited(_loadTasksAndExtras());
    _syncSub = DatabaseService.instance.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() => _connected = connected);
    });

    _notificationSub = DatabaseService.instance.notifications.listen((msg) {
      if (!mounted || msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    });

    _categoryRulesSub =
        DatabaseService.instance.categoryStream.listen((rules) {
      if (!mounted) return;
      setState(() => _rules = List.from(rules));
    });
    _deviceTodayAtLastMidnightCheck =
        DatabaseService.instance.getTimelineDeviceLocalToday();
    _deviceLocalDayKeyLast =
        DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
    _deviceLocalMidnightWatchTimer =
        Timer.periodic(const Duration(minutes: 1), (_) {
      _onDeviceLocalCalendarDayWatchTick();
    });
  }

  void _onDeviceLocalCalendarDayWatchTick() {
    final key = DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
    if (key == _deviceLocalDayKeyLast) {
      _deviceTodayAtLastMidnightCheck =
          DatabaseService.instance.getTimelineDeviceLocalToday();
      return;
    }
    final oldToday = _deviceTodayAtLastMidnightCheck ??
        DatabaseService.instance.getTimelineDeviceLocalToday();
    _deviceLocalDayKeyLast = key;
    _deviceTodayAtLastMidnightCheck =
        DatabaseService.instance.getTimelineDeviceLocalToday();
    DatabaseService.instance.notifyTimelineDeviceLocalDayChanged();
    if (!mounted) return;
    final sel = _dateOnly(_selectedDate);
    final wasFollowingLiveToday = sel.year == oldToday.year &&
        sel.month == oldToday.month &&
        sel.day == oldToday.day;
    if (wasFollowingLiveToday && _tabIndex == 0) {
      final today = DatabaseService.instance.getTimelineDeviceLocalToday();
      setState(() {
        _selectedDate = today;
        _focusedDay = today;
      });
      unawaited(_loadTasksForDate(today));
    }
  }

  Future<void> _loadTasksAndExtras() async {
    await _loadTasksForDate(_selectedDate);
    await _ensureSpeechReady();
  }

  @override
  void dispose() {
    _deviceLocalMidnightWatchTimer?.cancel();
    _syncSub?.cancel();
    _notificationSub?.cancel();
    _categoryRulesSub?.cancel();
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _showSyncMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(currentLocale.value, 'sync')),
        content: Text(t(currentLocale.value, 'refresh_categories_server')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(currentLocale.value, 'close')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await DatabaseService.instance.forceRefreshFromServer();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t(currentLocale.value, 'refreshed_from_server'))),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t(currentLocale.value, 'refresh_failed'))),
                  );
                }
              }
            },
            child: Text(t(currentLocale.value, 'refresh_now')),
          ),
        ],
      ),
    );
  }

  String get _selectedDateString =>
      '${_selectedDate.year}-${_two(_selectedDate.month)}-${_two(_selectedDate.day)}';

  /// Calendar day key for **live** timeline voice (running record starts “now”).
  String get _timelineVoiceDateKey {
    final d = DatabaseService.instance.getTimelineDeviceLocalToday();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  bool get _isFutureDate => _selectedDate.isAfter(_localToday());

  Future<void> _loadTasksForDate(DateTime date) async {
    setState(() => _tasksLoading = true);
    try {
      final loaded = await DatabaseService.instance.loadTasksForDate(date);
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(loaded);
        _tasksLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _tasks.clear();
          _tasksLoading = false;
        });
      }
    }
  }

  Future<void> _saveTasks() async {
    try {
      await DatabaseService.instance.saveTasks(_selectedDate, _tasks);
    } catch (_) {}
  }

  int? get _effectiveCategoryId =>
      _selectedCategoryId ?? DatabaseService.instance.defaultCategoryId;

  void _showSyncFailedSnackBar({VoidCallback? onRetry}) {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastSyncFailedSnackAt != null &&
        now.difference(_lastSyncFailedSnackAt!) < _syncFailedSnackThrottle) {
      return;
    }
    _lastSyncFailedSnackAt = now;
    final loc = currentLocale.value;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t(loc, 'sync_failed_retry')),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 4),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: t(loc, 'try_again'),
                onPressed: onRetry,
              ),
      ),
    );
  }

  Future<void> _retryWriteNewTask(
    String title,
    int? cid,
    String pathTag, {
    String? sourcePlanPocketRecordId,
  }) async {
    try {
      final startTime = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: startTime,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: sourcePlanPocketRecordId,
          )),
        );
        return;
      }
      setState(() {
        _tasks.add(
          Task(
            title: title,
            startTime: startTime,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await _saveTasks();
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: sourcePlanPocketRecordId,
          )),
        );
      }
    }
  }

  /// Same as [writeRecord] from voice sheet: explicit planetary “now” + today’s device-local day key.
  Future<void> _retryVoiceWriteNewTask(
    String title,
    int? cid,
    String pathTag, {
    String? sourcePlanPocketRecordId,
  }) async {
    try {
      final now = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        _timelineVoiceDateKey,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: sourcePlanPocketRecordId,
          )),
        );
        return;
      }
      setState(() {
        _tasks.add(
          Task(
            title: title,
            startTime: now,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await _saveTasks();
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: sourcePlanPocketRecordId,
          )),
        );
      }
    }
  }

  Future<void> _retryVoicePlanningTask(String rawText) async {
    final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
      rawText: rawText,
      wallDay: _dateOnly(_selectedDate),
      categoryIdHint: _effectiveCategoryId,
    );
    if (!mounted) return;
    if (!ok) {
      _showSyncFailedSnackBar(
        onRetry: () => unawaited(_retryVoicePlanningTask(rawText)),
      );
    }
  }

  Future<bool> _voiceSubmitTimeline(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    await _stopAnyActiveTask();
    final now = DatabaseService.getPlanetaryNow();
    final alreadyExists = _tasks.any((t) =>
        t.title == title &&
        t.isActive &&
        t.startTime.difference(now).inSeconds.abs() <= 2);
    if (alreadyExists) return true;
    final fuzzyMatch = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    final cid = fuzzyMatch?.id ?? _effectiveCategoryId;
    final pathTag =
        cid != null ? DatabaseService.instance.getCategoryPath(cid) : 'Life';
    if (fuzzyMatch != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(currentLocale.value, 'mapped_to')
                .replaceFirst('%s', title)
                .replaceFirst('%s', fuzzyMatch.path),
          ),
        ),
      );
    }
    String? voiceSourcePlanId;
    if (mounted) {
      voiceSourcePlanId = await _promptSourcePlanLinkIfEligible(
        title: title,
        dateKey: _timelineVoiceDateKey,
      );
    }
    try {
      final serverId = await DatabaseService.instance.writeRecord(
        _timelineVoiceDateKey,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: voiceSourcePlanId,
      );
      if (!mounted) return false;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: voiceSourcePlanId,
          )),
        );
        return false;
      }
      setState(() {
        _tasks.add(
          Task(
            title: title,
            startTime: now,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await _saveTasks();
      return true;
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: voiceSourcePlanId,
          )),
        );
      }
      return false;
    }
  }

  Future<bool> _voiceSubmitPlanning(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    try {
      final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: recognized,
        wallDay: _dateOnly(_selectedDate),
        categoryIdHint: _effectiveCategoryId,
      );
      if (!mounted) return false;
      if (!ok) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoicePlanningTask(recognized)),
        );
      }
      return ok;
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoicePlanningTask(recognized)),
        );
      }
      return false;
    }
  }

  Future<void> _startTaskFromInput() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final tick = DateTime.now();
    if (_lastPlayOrStartAction != null &&
        tick.difference(_lastPlayOrStartAction!) < _playStartDebounce) {
      return;
    }
    _lastPlayOrStartAction = tick;

    await _stopAnyActiveTask();

    final now = DatabaseService.getPlanetaryNow();
    final cid = _effectiveCategoryId;
    final pathTag =
        cid != null ? DatabaseService.instance.getCategoryPath(cid) : 'Life';

    _titleController.clear();
    _titleFocus.requestFocus();

    String? chosenSourcePlanId;
    try {
      if (mounted) {
        chosenSourcePlanId = await _promptSourcePlanLinkIfEligible(
          title: title,
          dateKey: _selectedDateString,
        );
      }
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: chosenSourcePlanId,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: chosenSourcePlanId,
          )),
        );
        return;
      }
      setState(() {
        _tasks.add(
          Task(
            title: title,
            startTime: now,
            endTime: null,
            tags: [pathTag],
            isActive: true,
          ),
        );
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      await _saveTasks();
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(
            title,
            cid,
            pathTag,
            sourcePlanPocketRecordId: chosenSourcePlanId,
          )),
        );
      }
    }
  }

  Future<void> _planTaskFromInput() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DatabaseService.instance.addPlannedTask(
        _selectedDateString,
        title,
        categoryId: _effectiveCategoryId,
        isManual: false,
      );
    });
    _titleController.clear();
    _titleFocus.requestFocus();
  }

  Future<void> _stopTask(Task t) async {
    if (!t.isRunning) return;
    setState(() {
      t.endTime = DatabaseService.getPlanetaryNow();
      t.isActive = false;
    });
    await _saveTasks();
  }

  Future<void> _deleteRecordByDocId(String recordId) async {
    try {
      final ok = await DatabaseService.instance.deleteRecordByDocId(recordId);
      if (!mounted) return;
      if (!ok) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_deleteRecordByDocId(recordId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'failed_to_delete').replaceFirst('%s', e.toString()))),
        );
      }
    }
  }

  /// [systemRowId] must be PocketBase `records.id` (legacy `record_id` UUID is still accepted by [DatabaseService] but never preferred).
  Future<void> _stopRecordByDocId(String systemRowId) async {
    final tick = DateTime.now();
    if (_lastStopRecordAction != null &&
        tick.difference(_lastStopRecordAction!) < _stopRecordDebounce) {
      return;
    }
    _lastStopRecordAction = tick;
    try {
      final ok =
          await DatabaseService.instance.stopRecordByDocId(systemRowId);
      if (!mounted) return;
      if (!ok) {
        print(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=$systemRowId)',
        );
        // DatabaseService already showed error_stop_* / HTTP code — do not show sync_failed_retry.
        return;
      }
      await _stopAnyActiveTask();
    } catch (e) {
      print('UI ERROR: $e');
    }
  }

  Future<void> _stopAnyActiveTask() async {
    final running = _tasks.where((t) => t.isRunning).toList();
    for (final t in running) {
      await _stopTask(t);
    }
  }

  Future<void> _ensureSpeechReady() async {
    if (_speechReady) return;
    _speechLastInitError = null;
    _speech ??= stt.SpeechToText();
    try {
      final available = await _speech!.initialize(
        onStatus: (s) => _speechStatusCallback?.call(s),
        onError: (e) {
          final msg = e.errorMsg;
          debugPrint(
            '[STT] onError: $msg (permanent=${e.permanent})',
          );
          _speechStatusCallback?.call('error:$msg');
        },
      );
      if (!mounted) return;
      if (available) {
        try {
          final locales = await _speech!.locales();
          final ids = <String>[
            for (final l in locales) l.localeId.toString(),
          ];
          debugPrint(
            '[STT] initialize OK; locales (${locales.length}): ${ids.join(", ")}',
          );
        } catch (e, st) {
          debugPrint('[STT] locales() after init failed: $e\n$st');
        }
        setState(() {
          _speechReady = true;
          _speechLastInitError = null;
        });
      } else {
        const msg = 'initialize() returned false';
        _speechLastInitError = msg;
        debugPrint('[STT] $msg');
        setState(() => _speechReady = false);
      }
    } catch (e, st) {
      debugPrint('[STT] initialize exception: $e\n$st');
      _speechLastInitError = e.toString();
      if (!mounted) return;
      setState(() => _speechReady = false);
    }
  }

  /// Returns PB **plans** row id if the user confirms; `null` if no match or dismissed.
  Future<String?> _promptSourcePlanLinkIfEligible({
    required String title,
    required String dateKey,
  }) async {
    final sugg =
        await DatabaseService.instance.suggestSourcePlanForFreeStart(
      recordTitle: title,
      wallDateKey: dateKey,
    );
    if (!mounted || sugg == null) return null;
    final loc = currentLocale.value;
    var body = t(loc, 'link_to_plan_message');
    body = body.replaceFirst('%s', title);
    body = body.replaceFirst('%s', sugg.planTitle);
    body = body.replaceFirst('%s', '${(sugg.similarity * 100).round()}%');
    final link = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(loc, 'link_to_plan_title')),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(loc, 'skip_link_plan')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(loc, 'link_plan_confirm')),
          ),
        ],
      ),
    );
    if (link == true) return sugg.planPocketRecordId;
    return null;
  }

  Future<void> _startRecordFromPlanning(
    String title,
    int categoryId,
    String dateKey, {
    String? sourcePlanPocketRecordId,
  }) async {
    final tick = DateTime.now();
    if (_lastPlayOrStartAction != null &&
        tick.difference(_lastPlayOrStartAction!) < _playStartDebounce) {
      return;
    }
    _lastPlayOrStartAction = tick;
    try {
      final id = await DatabaseService.instance.startTimerWithCategory(
        title,
        categoryId: categoryId,
        dateKey: dateKey,
        sourcePlanPocketRecordId: sourcePlanPocketRecordId,
      );
      if (!mounted) return;
      if (id == null || id.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_startRecordFromPlanning(
                title,
                categoryId,
                dateKey,
                sourcePlanPocketRecordId: sourcePlanPocketRecordId,
              )),
        );
        return;
      }
      final loc = currentLocale.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(loc, 'record_started_message').replaceFirst('%s', title),
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      print('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _startRecordFromPlanning(
              title,
              categoryId,
              dateKey,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
        );
      }
    }
  }

  void _openNewTaskForPastDate() {
    final ctx = context;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => EditRecordSheet(
        serverRecordId: '',
        data: {'title': _titleController.text.trim()},
        dateKey: _selectedDateString,
        selectedDate: _selectedDate,
        onSaved: () => Navigator.of(sheetCtx).pop(),
        onJumpToConflict: (date, _) {
          Navigator.of(sheetCtx).pop();
          _jumpToConflictDate(date);
        },
      ),
    );
  }

  Future<void> _openManualAddDialog() async {
    final selectedDate = _selectedDate;
    final displayNow = _utcToDisplay(DatabaseService.getPlanetaryNow());
    final startDefault = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, displayNow.hour, displayNow.minute);
    final endDefault = startDefault.add(Duration.zero);
    if (!mounted) return;
    final result = await showDialog<_ManualEntryResult>(
      context: context,
      builder: (ctx) => _ManualEntryDialog(
        selectedDate: selectedDate,
        rules: _rules,
        initialStart: startDefault,
        initialEnd: endDefault,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final manualStart = result.start;
      final manualEnd = result.end;
      final running = _tasks.where((t) => t.isRunning).toList();
      final nowDisplay = _utcToDisplay(DatabaseService.getPlanetaryNow());
      bool overlaps(Task t) =>
          manualStart.isBefore(nowDisplay) && manualEnd.isAfter(_utcToDisplay(t.startTime));
      final toTruncate = running.where(overlaps).toList();
      for (final t in toTruncate) {
        if (!mounted) return;
        setState(() {
          t.endTime = _displayToUtc(DateTime(manualStart.year, manualStart.month, manualStart.day, manualStart.hour, manualStart.minute));
          t.isActive = false;
        });
      }
      if (running.isNotEmpty && toTruncate.isEmpty) {
        await _stopAnyActiveTask();
      }
      if (!mounted) return;
      final taskTitle = result.title.trim().isEmpty ? 'Manual entry' : result.title.trim();
      final startUtc = _displayToUtc(manualStart);
      final endUtc = _displayToUtc(manualEnd);
      setState(() {
        _tasks.add(
          Task(
            title: taskTitle,
            startTime: startUtc,
            endTime: endUtc,
            tags: result.tags,
            isActive: false,
          ),
        );
        _tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _saveTasks();
        if (!mounted) return;
        await DatabaseService.instance.writeCompletedRecord(
          taskTitle,
          startUtc,
          endUtc,
          categoryId: result.categoryId ?? _effectiveCategoryId,
        );
      });
    } catch (e) {
      print('UI ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'failed_to_save_manual'))),
      );
    }
  }

  Future<void> _startVoiceInput() async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final res = await Permission.microphone.request();
        if (!res.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t(currentLocale.value, 'microphone_permission'))),
          );
          return;
        }
      }
    }
    if (kIsWeb) {
      debugPrint(
        '[STT] Web: SpeechToText uses the browser Web Speech API (HTTPS + user gesture).',
      );
    }
    await _ensureSpeechReady();
    if (!_speechReady) {
      if (!mounted) return;
      final loc = currentLocale.value;
      final detail = _speechLastInitError?.trim();
      final text = detail != null && detail.isNotEmpty
          ? t(loc, 'speech_error_prefix').replaceFirst('%s', detail)
          : t(loc, 'speech_unavailable');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      return;
    }

    if (!mounted) return;
    final voiceSurfaceIsPlanning = _tabIndex == 1;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return VoiceInputSheet(
          speech: _speech!,
          setSpeechStatusCallback: (cb) {
            if (mounted) setState(() => _speechStatusCallback = cb);
          },
          onListeningChanged: (listening) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isVoiceListening = listening);
            });
          },
          config: VoiceCaptureConfig(
            submitIntent: voiceSurfaceIsPlanning
                ? _voiceSubmitPlanning
                : _voiceSubmitTimeline,
            successL10nKey: voiceSurfaceIsPlanning
                ? 'task_added_to_plan'
                : 'record_synced',
            primaryActionL10nKey:
                voiceSurfaceIsPlanning ? 'add_task' : 'start_task',
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _speechStatusCallback = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isVoiceListening = false);
    });
  }

  void _jumpToConflictDate(DateTime d) {
    setState(() {
      _selectedDate = DateTime(d.year, d.month, d.day);
      _tabIndex = 0;
    });
    _loadTasksForDate(_selectedDate);
  }

  void _showEditRecordSheetForTimeline(
      BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      builder: (sheetCtx) {
        final record = TimelineRecord.fromMap(data);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ActivityDetailSheet(
                kind: ActivityDetailKind.timelineRecord,
                timelineRecord: record,
                scrollController: scrollController,
                onSaved: (updated) {
                  if (sheetCtx.mounted) {
                    Navigator.of(sheetCtx).pop();
                  }
                },
                onDelete: () async {
                  final ok = await DatabaseService.instance
                      .deleteRecordByDocId(record.id);
                  if (!mounted) return;
                  if (!ok) {
                    _showSyncFailedSnackBar(
                      onRetry: () => unawaited(DatabaseService.instance
                          .deleteRecordByDocId(record.id)),
                    );
                  }
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                onStop: () async {
                  print(
                    'Attempting to stop record with systemRowId: ${record.id} (legacy record_id: ${record.recordId})',
                  );
                  final ok = await DatabaseService.instance
                      .stopRecordByDocId(record.id);
                  if (!mounted) return;
                  if (!ok) {
                    print(
                      'UI ERROR: stopRecordByDocId returned false (systemRowId=${record.id})',
                    );
                  }
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditDialog(PlanningTask task) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ActivityDetailSheet(
                kind: ActivityDetailKind.planningTask,
                planningTask: task,
                scrollController: scrollController,
                onSaved: (dynamic updatedRaw) {
                  final updated = updatedRaw as PlanningTask;
                  if (!_shellIsNewPlanningDraft(task)) {
                    DatabaseService.instance.applyOptimisticPlanningTask(updated);
                    DatabaseService.instance.notifyPlanningRefresh();
                  }
                  AppSnack.saved();
                  Navigator.of(ctx).pop(updated);
                },
                onDelete: _shellIsNewPlanningDraft(task)
                    ? null
                    : () {
                        final backup = PlanningTask(
                          id: 0,
                          title: task.title,
                          categoryId: task.categoryId,
                          isDone: task.isDone,
                          dateKey: task.dateKey,
                          order: task.order,
                          startTime: task.startTime,
                          date: task.date,
                          tags: task.tags,
                        );
                        DatabaseService.instance.applyOptimisticPlanningTask(
                          task.copyWith(dateKey: _shellOptimisticPurgeDateKey),
                        );
                        DatabaseService.instance.notifyPlanningRefresh();
                        unawaited(
                          _deletePlanningTaskOptimisticFollowUp(task, backup),
                        );
                      },
              );
            },
          ),
        );
      },
    );
    if (result is! PlanningTask || !mounted) return;
    final loc = currentLocale.value;
    try {
      if (_shellIsNewPlanningDraft(task)) {
        final day = planningDateFromKey(result.dateKey) ??
            DatabaseService.instance.getTimelineDeviceLocalToday();
        final nextOrder =
            await DatabaseService.instance.nextPlanningOrderForDate(day);
        final startUtc = result.startTime != null
            ? _displayToUtc(result.startTime!)
            : null;
        final toCreate = result.copyWith(
          order: nextOrder,
          startTime: startUtc,
        );
        final ok = await DatabaseService.instance.addPlanningTask(toCreate);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(loc, 'plan_save_failed')),
            ),
          );
          return;
        }
        HapticFeedback.heavyImpact();
      } else {
        unawaited(_persistPlanningEditFromSheet(task, result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'save_failed').replaceFirst('%s', e.toString()))),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistPlanningEditFromSheet(
    PlanningTask baseline,
    PlanningTask edited,
  ) async {
    final loc = currentLocale.value;
    try {
      final ok = await DatabaseService.instance.updatePlanningTask(
        edited.planRowIdForBackend,
        planBusinessId: edited.planRowId,
        title: edited.title,
        categoryId: edited.categoryId,
        isDone: edited.isDone,
        notes: edited.notes,
        checklist: edited.checklist,
        parentPlanId: edited.parentPlanId,
        startTimeDisplay: edited.startTime,
        endDateTimeDisplay: edited.endDateTime,
        clearEnd: edited.endDateTime == null,
        tags: edited.tags,
        suppressAppSnack: true,
      );
      if (!mounted) return;
      if (!ok) {
        DatabaseService.instance.applyOptimisticPlanningTask(baseline);
        DatabaseService.instance.notifyPlanningRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(loc, 'plan_save_failed'))),
        );
        return;
      }
      HapticFeedback.heavyImpact();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      DatabaseService.instance.applyOptimisticPlanningTask(baseline);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(t(loc, 'save_failed').replaceFirst('%s', e.toString())),
        ),
      );
    }
  }

  Future<void> _deletePlanningTaskOptimisticFollowUp(
    PlanningTask task,
    PlanningTask backup,
  ) async {
    final loc = currentLocale.value;
    final backendId = task.recordIdForBackend.trim();
    if (backendId.isEmpty) {
      if (!mounted) return;
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_save_failed'))),
      );
      return;
    }
    final ok =
        await DatabaseService.instance.deletePlanningTasksBulk([backendId]);
    if (!mounted) return;
    DatabaseService.instance
        .clearOptimisticPlanningForPlanRow(task.planRowIdForBackend);
    DatabaseService.instance.notifyPlanningRefresh();
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(loc, 'plan_save_failed'))),
      );
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(loc, 'task_deleted')),
        action: SnackBarAction(
          label: t(loc, 'undo'),
          onPressed: () async {
            await DatabaseService.instance.addPlanningTask(backup);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TimelineSwipeWrapper(
        selectedDate: _selectedDate,
        onDateChanged: (d) {
          final day = _dateOnly(d);
          setState(() => _selectedDate = day);
          _loadTasksForDate(day);
        },
        onJumpToConflict: _jumpToConflictDate,
        tasks: _tasks,
        tasksLoading: _tasksLoading,
        titleController: _titleController,
        titleFocus: _titleFocus,
        selectedCategoryId: _selectedCategoryId,
        onCategoryChanged: (id) => setState(() => _selectedCategoryId = id),
        onStart: _startTaskFromInput,
        onPlan: _planTaskFromInput,
        onNewTaskForPastDate: _openNewTaskForPastDate,
        onStopRecord: _stopRecordByDocId,
        onDeleteRecord: _deleteRecordByDocId,
        onManualAdd: _openManualAddDialog,
        rules: _rules,
        onShowEditRecordSheet: _showEditRecordSheetForTimeline,
      ),
      PlanningSwipeWrapper(
        selectedDate: _selectedDate,
        onDateChanged: (d) => setState(() => _selectedDate = d),
        selectedCategoryId: _selectedCategoryId,
        onCategoryChanged: (id) => setState(() => _selectedCategoryId = id),
        onStartRecordFromTask: _startRecordFromPlanning,
        onEditTask: (task) => _openEditDialog(task),
      ),
      CalendarView(
        selectedDate: _selectedDate,
        focusedDay: _focusedDay,
        onSelectDate: (d, f) async {
          setState(() {
            _selectedDate = _dateOnly(d);
            _focusedDay = _dateOnly(f);
          });
          await _loadTasksForDate(_selectedDate);
          if (!mounted) return;
        },
        onJumpToTimeline: () => setState(() => _tabIndex = 0),
      ),
      StreamBuilder<List<CategoryRule>>(
        stream: DatabaseService.instance.categoryStream,
        builder: (context, snapshot) {
          final rules = snapshot.data ?? DatabaseService.instance.rules;
          return CategoriesPage(
            rules: rules,
            onChanged: () async {
              if (mounted) {
                setState(() {
                  _rules = List.from(DatabaseService.instance.rules);
                });
              }
            },
          );
        },
      ),
      ProfilePage(onSaved: () => setState(() {})),
    ];

    final showVoiceFab = _tabIndex == 1 || !_isFutureDate;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ScaffoldMessenger.of(context).clearSnackBars();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            pages[_tabIndex],
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: _SyncStatusIcon(
                connected: _connected,
                onTap: () => _showSyncMenu(context),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        floatingActionButton: !showVoiceFab
            ? null
            : FloatingActionButton(
                onPressed: _startVoiceInput,
                tooltip: _isVoiceListening ? t(currentLocale.value, 'listening') : t(currentLocale.value, 'voice_input'),
                child: Icon(_isVoiceListening ? Icons.graphic_eq_rounded : Icons.mic_rounded),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) {
            setState(() {
              _tabIndex = i;
            });
            if (i == 0) {
              final target = DatabaseService.instance.getTimelineDeviceLocalToday();
              setState(() {
                _selectedDate = target;
                _focusedDay = target;
              });
              unawaited(_loadTasksForDate(target));
            } else if (i == 1) {
              final target = DatabaseService.instance.getTimelineDeviceLocalToday();
              setState(() {
                _selectedDate = target;
                _focusedDay = target;
              });
              unawaited(_loadTasksForDate(target));
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.timeline_outlined),
              selectedIcon: const Icon(Icons.timeline_rounded),
              label: t(currentLocale.value, 'tab_timeline'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.checklist_outlined),
              selectedIcon: const Icon(Icons.checklist_rounded),
              label: t(currentLocale.value, 'tab_planning'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: t(currentLocale.value, 'calendar'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category_rounded),
              label: t(currentLocale.value, 'categories'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: t(currentLocale.value, 'profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual add dialog (used from Calendar/Timeline).
// ---------------------------------------------------------------------------

class _ManualEntryResult {
  _ManualEntryResult({
    required this.title,
    required this.start,
    required this.end,
    required this.tags,
    required this.categoryId,
  });
  final String title;
  final DateTime start;
  final DateTime end;
  final List<String> tags;
  final int? categoryId;
}

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({
    required this.selectedDate,
    required this.rules,
    required this.initialStart,
    required this.initialEnd,
  });

  final DateTime selectedDate;
  final List<CategoryRule> rules;
  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  late TextEditingController _titleController;
  late DateTime _start;
  late DateTime _end;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    _selectedCategoryId = pairs.isNotEmpty ? pairs.first.id : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showAppDateTimePicker(
      context,
      initial: _start,
      firstDate: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day),
      lastDate: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked;
      if (_end.isBefore(_start) || _end.isAtSameMomentAs(_start)) {
        _end = _start.add(Duration.zero);
      }
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showAppDateTimePicker(
      context,
      initial: _end,
      firstDate: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day),
      lastDate: DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59),
    );
    if (picked == null || !mounted) return;
    setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final effectiveId = pairs.any((p) => p.id == _selectedCategoryId)
        ? _selectedCategoryId
        : (pairs.isNotEmpty ? pairs.first.id : null);

    return AlertDialog(
      title: Text(t(currentLocale.value, 'manual_add')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: t(currentLocale.value, 'title_label'),
                hintText: t(currentLocale.value, 'hint_meeting'),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: effectiveId,
              decoration: InputDecoration(labelText: t(currentLocale.value, 'category_label')),
              items: pairs
                  .map((p) => DropdownMenuItem<int>(value: p.id, child: Text(p.path)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v ?? effectiveId),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(t(currentLocale.value, 'start_time')),
              subtitle: Text(_formatTimeOfDay(_start)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: _pickStartTime,
            ),
            ListTile(
              title: Text(t(currentLocale.value, 'end_time')),
              subtitle: Text(_formatTimeOfDay(_end)),
              trailing: const Icon(Icons.access_time_rounded),
              onTap: _pickEndTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t(currentLocale.value, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_end.isBefore(_start) || _end.isAtSameMomentAs(_start)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(currentLocale.value, 'end_time_after_start'))),
              );
              return;
            }
            final path = effectiveId != null
                ? DatabaseService.instance.getCategoryPath(effectiveId)
                : 'Life';
            Navigator.of(context).pop(_ManualEntryResult(
              title: _titleController.text.trim(),
              start: _start,
              end: _end,
              tags: [path],
              categoryId: effectiveId,
            ));
          },
          child: Text(t(currentLocale.value, 'add')),
        ),
      ],
    );
  }
}
