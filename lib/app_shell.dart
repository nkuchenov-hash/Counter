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
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/timeline/timeline_view.dart' hide showAppDateTimePicker;
import 'package:counter/l10n/dictionary.dart';
import 'package:counter/data/voice_audio_stub.dart' if (dart.library.html) 'package:counter/data/voice_audio_web.dart' as voice_audio;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// --- Shell-local time helpers (Planetary: UTC + profile offset). ---
DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _two(int n) => n.toString().padLeft(2, '0');

DateTime _localToday() => DatabaseService.instance.getProjectedToday();

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
      await DatabaseService.instance.saveSettings(UserSettings(
        userId: DatabaseService.instance.settings.userId,
        language: _language,
        preferredTimeZone: _timeZone,
        activeLanguages: DatabaseService.instance.settings.activeLanguages,
        primaryLanguage: _language,
        defaultCategoryId: DatabaseService.instance.settings.defaultCategoryId,
      ));
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
  bool _isVoiceListening = false;
  void Function(String)? _speechStatusCallback;

  bool? _connected;
  StreamSubscription<bool>? _syncSub;

  @override
  void initState() {
    super.initState();
    _selectedDate = DatabaseService.instance.getProjectedToday();
    _focusedDay = DatabaseService.instance.getProjectedToday();
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
  }

  Future<void> _loadTasksAndExtras() async {
    await _loadTasksForDate(_selectedDate);
    await _ensureSpeechReady();
  }

  @override
  void dispose() {
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
    final loc = currentLocale.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(loc, 'sync_failed_retry')),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: t(loc, 'try_again'),
                onPressed: onRetry,
              ),
      ),
    );
  }

  Future<void> _retryWriteNewTask(String title, int? cid, String pathTag) async {
    try {
      final startTime = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: startTime,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(title, cid, pathTag)),
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
    } catch (_) {
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(title, cid, pathTag)),
        );
      }
    }
  }

  /// Same as [writeRecord] from voice sheet (no [explicitStartTime] — Planetary “now” in Brain).
  Future<void> _retryVoiceWriteNewTask(String title, int? cid, String pathTag) async {
    try {
      final now = DatabaseService.getPlanetaryNow();
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(title, cid, pathTag)),
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
    } catch (_) {
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceWriteNewTask(title, cid, pathTag)),
        );
      }
    }
  }

  Future<void> _startTaskFromInput() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    await _stopAnyActiveTask();

    final now = DatabaseService.getPlanetaryNow();
    final cid = _effectiveCategoryId;
    final pathTag =
        cid != null ? DatabaseService.instance.getCategoryPath(cid) : 'Life';

    _titleController.clear();
    _titleFocus.requestFocus();

    try {
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: now,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(title, cid, pathTag)),
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
    } catch (_) {
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryWriteNewTask(title, cid, pathTag)),
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

  Future<void> _stopRecordByDocId(String recordId) async {
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(recordId);
      if (!mounted) return;
      if (!ok) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_stopRecordByDocId(recordId)),
        );
        return;
      }
      await _stopAnyActiveTask();
    } catch (e) {
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_stopRecordByDocId(recordId)),
        );
      }
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
    _speech ??= stt.SpeechToText();
    final available = await _speech!.initialize(
      onStatus: (s) => _speechStatusCallback?.call(s),
      onError: (e) => _speechStatusCallback?.call('error:${e.errorMsg}'),
    );
    if (!mounted) return;
    setState(() => _speechReady = available);
  }

  Future<void> _startRecordFromPlanning(
      String title, int categoryId, String dateKey) async {
    try {
      final id = await DatabaseService.instance.startTimerWithCategory(title,
          categoryId: categoryId, dateKey: dateKey);
      if (!mounted) return;
      if (id == null || id.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_startRecordFromPlanning(
              title, categoryId, dateKey)),
        );
        return;
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
              _startRecordFromPlanning(title, categoryId, dateKey)),
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
    } catch (_) {
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
    await _ensureSpeechReady();
    if (!_speechReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'speech_unavailable'))),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _VoiceTaskSheet(
          speech: _speech!,
          setSpeechStatusCallback: (cb) {
            if (mounted) setState(() => _speechStatusCallback = cb);
          },
          onListeningChanged: (listening) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isVoiceListening = listening);
            });
          },
          onTransferAndStart: (text) {
            _titleController.text = text;
            _startTaskFromInput();
          },
          onCreate: (recognized) async {
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
                SnackBar(content: Text(t(currentLocale.value, 'mapped_to').replaceFirst('%s', title).replaceFirst('%s', fuzzyMatch.path))),
              );
            }
            try {
              final serverId = await DatabaseService.instance.writeRecord(
                _selectedDateString,
                title,
                categoryId: cid,
              );
              if (!mounted) return false;
              if (serverId == null || serverId.trim().isEmpty) {
                _showSyncFailedSnackBar(
                  onRetry: () => unawaited(_retryVoiceWriteNewTask(title, cid, pathTag)),
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
            } catch (_) {
              if (mounted) {
                _showSyncFailedSnackBar(
                  onRetry: () => unawaited(_retryVoiceWriteNewTask(title, cid, pathTag)),
                );
              }
              return false;
            }
          },
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                onSaved: (updated) async {
                  if (sheetCtx.mounted) {
                    Navigator.of(sheetCtx).pop();
                  }
                },
                onDelete: () async {
                  final ok = await DatabaseService.instance
                      .deleteRecordByDocId(record.recordId);
                  if (!mounted) return;
                  if (!ok) {
                    _showSyncFailedSnackBar(
                      onRetry: () => unawaited(DatabaseService.instance
                          .deleteRecordByDocId(record.recordId)),
                    );
                  }
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                onStop: () async {
                  final ok = await DatabaseService.instance
                      .stopRecordByDocId(record.recordId);
                  if (!mounted) return;
                  if (!ok) {
                    _showSyncFailedSnackBar(
                      onRetry: () => unawaited(DatabaseService.instance
                          .stopRecordByDocId(record.recordId)),
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
                onSaved: (updated) => Navigator.of(ctx).pop(updated),
                onDelete: _shellIsNewPlanningDraft(task)
                    ? null
                    : () async {
                        await _deletePlanningTask(task);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
              );
            },
          ),
        );
      },
    );
    if (result is! PlanningTask || !mounted) return;
    try {
      if (_shellIsNewPlanningDraft(task)) {
        final day = planningDateFromKey(result.dateKey) ??
            _dateOnly(DateTime.now());
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
              content: Text(t(currentLocale.value, 'plan_save_failed')),
            ),
          );
          return;
        }
        HapticFeedback.heavyImpact();
      } else {
        await DatabaseService.instance.updatePlanningTask(
          result.planRowIdForNoco,
          planBusinessId: result.planRowId,
          title: result.title,
          categoryId: result.categoryId,
          isDone: result.isDone,
          notes: result.notes,
          checklist: result.checklist,
          parentPlanId: result.parentPlanId,
          startTimeDisplay: result.startTime,
          endDateTimeDisplay: result.endDateTime,
          clearEnd: result.endDateTime == null,
        );
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'save_failed').replaceFirst('%s', e.toString()))),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _deletePlanningTask(PlanningTask task) async {
    final backup = PlanningTask(
      id: 0,
      title: task.title,
      categoryId: task.categoryId,
      isDone: task.isDone,
      dateKey: task.dateKey,
      order: task.order,
      startTime: task.startTime,
      date: task.date,
    );
    await DatabaseService.instance.deletePlanningTask(task.planRowIdForNoco);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(currentLocale.value, 'task_deleted')),
        action: SnackBarAction(
          label: t(currentLocale.value, 'undo'),
          onPressed: () async {
            await DatabaseService.instance.addPlanningTask(backup);
          },
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TimelineSwipeWrapper(
        selectedDate: _selectedDate,
        onDateChanged: (d) {
          setState(() => _selectedDate = d);
          _loadTasksForDate(d);
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

    final isFutureDate = _isFutureDate;
    return Scaffold(
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
      floatingActionButton: isFutureDate
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
            debugPrint('NAV_TRACE: Reset to Today triggered: ${DateTime.now()}');
            final target = DatabaseService.instance.getProjectedToday();
            setState(() {
              _selectedDate = target;
              _focusedDay = target;
            });
            unawaited(_loadTasksForDate(target));
          } else if (i == 1) {
            // Keep the active day synchronized across tabs.
            _loadTasksForDate(_selectedDate);
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

// ---------------------------------------------------------------------------
// Voice task sheet (mic input → start task).
// ---------------------------------------------------------------------------

class _VoiceTaskSheet extends StatefulWidget {
  const _VoiceTaskSheet({
    required this.speech,
    required this.setSpeechStatusCallback,
    required this.onCreate,
    this.onListeningChanged,
    this.onTransferAndStart,
  });

  final stt.SpeechToText speech;
  final void Function(void Function(String)?) setSpeechStatusCallback;
  final Future<bool> Function(String text) onCreate;
  final void Function(bool listening)? onListeningChanged;
  final void Function(String text)? onTransferAndStart;

  @override
  State<_VoiceTaskSheet> createState() => _VoiceTaskSheetState();
}

class _VoiceTaskSheetState extends State<_VoiceTaskSheet> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  bool _isPulsing = false;
  String _statusText = 'Voice input';
  String? _error;
  bool _hadErrorInSession = false;
  bool _isSaving = false;
  final ValueNotifier<double> _soundLevel = ValueNotifier(0.0);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _textController = TextEditingController();

  void _playTone({required double freq, required double duration}) {
    voice_audio.playTone(freq: freq, duration: duration);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    unawaited(_start());
  }

  void _onSpeechResult(dynamic res) {
    if (!mounted || _isSaving) return;
    _textController.text = res.recognizedWords;
  }

  @override
  void dispose() {
    widget.speech.stop();
    widget.speech.cancel();
    _textController.dispose();
    _pulseController.dispose();
    _soundLevel.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.setSpeechStatusCallback(null);
      widget.onListeningChanged?.call(false);
    });
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _isPulsing = true;
      _statusText = 'Say your task now...';
      _isListening = true;
      _error = null;
      _hadErrorInSession = false;
    });
    _textController.clear();
    widget.onListeningChanged?.call(true);
    _playTone(freq: 660, duration: 0.1);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    try {
      if (!widget.speech.isAvailable) {
        await widget.speech.initialize();
      }
    } catch (e) {
      // ignore
    }
    if (!mounted) return;

    widget.setSpeechStatusCallback((status) {
      if (status.startsWith('error:')) {
        final msg = status.replaceFirst('error:', '').trim();
        final displayMsg = msg.toLowerCase().contains('network')
            ? 'Network error. Check your internet connection and try again.'
            : 'Speech error: $msg';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _error = displayMsg;
            _hadErrorInSession = true;
            _isPulsing = false;
          });
        });
        return;
      }
      if (status == 'listening') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _isPulsing = true);
        });
        return;
      }
      if (status == 'done' || status == 'notListening') {
        if (_hadErrorInSession) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isPulsing = false;
            _statusText = 'I heard you. Tap to confirm.';
            _isListening = false;
          });
          widget.onListeningChanged?.call(false);
        });
      }
    });
    try {
      await widget.speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) => _soundLevel.value = level,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
        localeId: 'en-US',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      );
    } catch (err) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = err.toString());
      });
      widget.setSpeechStatusCallback(null);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isListening = false);
        widget.onListeningChanged?.call(false);
      });
    }
  }

  Future<void> _stop() async {
    await widget.speech.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isPulsing = false;
        _statusText = 'I heard you. Tap to confirm.';
      });
      widget.onListeningChanged?.call(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canCreate = _textController.text.trim().isNotEmpty && !_isSaving;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _soundLevel,
                    builder: (context, level, _) {
                      final levelClamped = level.clamp(0.0, 1.0);
                      final pulse = _isPulsing ? 0.15 * _pulseAnimation.value : 0.0;
                      final soundScale = _isPulsing ? levelClamped * 0.35 : 0.0;
                      final scale = 1.0 + pulse + soundScale;
                      final scheme = Theme.of(context).colorScheme;
                      return Transform.scale(
                        scale: scale,
                        child: Icon(
                          _isPulsing ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                          color: _isPulsing ? scheme.primary : scheme.onSurface,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _error != null
                    ? Text(
                        _error!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.error),
                      )
                    : Text(
                        _statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
              if (_error != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _hadErrorInSession = false;
                    });
                    _start();
                  },
                  tooltip: t(currentLocale.value, 'try_again'),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              TextButton(
                onPressed: _isListening ? _stop : _start,
                child: Text(_isListening ? t(currentLocale.value, 'stop') : t(currentLocale.value, 'listen')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t(currentLocale.value, 'say_task_title'),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCreate
                      ? () async {
                          if (_isSaving || !mounted) return;
                          final text = _textController.text.trim();
                          if (text.isEmpty) return;
                          widget.speech.stop();
                          widget.speech.cancel();
                          setState(() => _isSaving = true);
                          var ok = false;
                          try {
                            ok = await widget.onCreate(text);
                          } finally {
                            if (mounted) {
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(currentLocale.value, 'record_synced'),
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _isSaving = false);
                              });
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t(currentLocale.value, 'start_task')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
