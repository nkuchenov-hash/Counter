// ---------------------------------------------------------------------------
// APP SHELL — Sovereign Vault Architecture. Dashboard, navigation, FAB.
// UI_ISOLATION (§7). All tab labels via t(). No UI in main.dart.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:counter/database_service.dart';
import 'package:counter/models.dart';
import 'package:counter/features/categories/category_list_view.dart';
import 'package:counter/features/categories/category_visibility_prefs.dart';
import 'package:counter/features/calendar/calendar_view.dart';
import 'package:counter/features/dev/component_lab_view.dart';
import 'package:counter/features/lists/lists_view.dart';
import 'package:counter/features/planning/planning_view.dart';
import 'package:counter/features/profile/profile_view.dart';
import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/shell_adaptive.dart';
import 'package:counter/core/shell_layout_state.dart';
import 'package:counter/core/services/speech_engine_handle.dart';
import 'package:counter/core/widgets/global_app_header.dart';
import 'package:counter/features/shared/shared_widgets.dart';
import 'package:counter/features/shared/voice_capture_config.dart';
import 'package:counter/features/shared/voice_input_sheet.dart';
import 'package:counter/features/timeline/timeline_view.dart';
import 'package:counter/l10n/app_locales.dart';
import 'package:counter/l10n/category_db_display.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// --- Shell-local time helpers (Planetary: UTC + profile offset). ---
DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _two(int n) => n.toString().padLeft(2, '0');

DateTime _localToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

DateTime _displayToUtc(DateTime displayNaive) =>
    DatabaseService.instance.displayTimeToUtc(displayNaive);

/// Planning task opened from quick-add / draft: not yet on server (no PATCH id).
bool _shellIsNewPlanningDraft(PlanningTask t) {
  if (t.id != 0) return false;
  final p = t.planRowId?.trim() ?? '';
  return p.isEmpty;
}

/// Hides a plan on the current day in optimistic merge until DELETE completes (see [DatabaseService.applyOptimisticPlanningTask]).
const String _shellOptimisticPurgeDateKey = '2099-12-31';
const String _prefsRecordLinkSuggestionsEnabled =
    'plans_record_link_suggestions_enabled';
const String _prefsRecordLinkSuggestionMode =
    'plans_record_link_suggestion_mode';
const String _prefsRecordLinkSuggestionDismissed =
    'plans_record_link_suggestion_dismissed_record_ids';
const String _recordLinkSuggestionModeAsk = 'ask';
const String _recordLinkSuggestionModeAuto = 'auto';

// ---------------------------------------------------------------------------
// Global offline / sync indicator (O1).
// ---------------------------------------------------------------------------

class _OfflineSyncStatusBar extends StatefulWidget {
  const _OfflineSyncStatusBar({this.routeTab});

  final String? routeTab;

  @override
  State<_OfflineSyncStatusBar> createState() => _OfflineSyncStatusBarState();
}

class _OfflineSyncStatusBarState extends State<_OfflineSyncStatusBar> {
  bool _wasShowing = false;

  @override
  Widget build(BuildContext context) {
    final sync = DatabaseService.instance.offlineSync;
    final brain = DatabaseService.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        sync.ensureBannerInvariant();
        final showing = sync.shouldShowBanner;
        if (showing && !_wasShowing) {
          _wasShowing = true;
          final kind = sync.bannerKindLabel;
          unawaited(
            sync.logVisibleBannerState(
              bannerKind: kind,
              routeTab: widget.routeTab,
              pbBackoffActive: brain.pbHttpBackoffActive,
            ),
          );
        } else if (!showing) {
          _wasShowing = false;
        }
        if (!showing) {
          return const SizedBox.shrink();
        }
        final locale = currentLocale.value;
        final scheme = Theme.of(context).colorScheme;
        String label;
        Color fg;
        Color bg;
        if (sync.isSyncing) {
          label = t(locale, 'offline_sync_syncing');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else if (sync.authPaused) {
          label = t(locale, 'offline_sync_auth_paused');
          fg = scheme.onErrorContainer;
          bg = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.hasBlockingSyncError) {
          label = t(locale, 'offline_sync_error');
          fg = scheme.onErrorContainer;
          bg = scheme.errorContainer.withValues(alpha: 0.85);
        } else if (sync.isOffline) {
          label = t(
            locale,
            'offline_sync_pending',
          ).replaceAll('%s', '${sync.pendingCount}');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        } else {
          label = t(
            locale,
            'offline_sync_pending_online',
          ).replaceAll('%s', '${sync.pendingCount}');
          fg = scheme.onSurfaceVariant;
          bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
        }
        return Material(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () {
                unawaited(() async {
                  sync.logTapRetry(phase: 'TAP_RETRY');
                  await DatabaseService.instance.flushPendingLocalMutations();
                  sync.logTapRetry(phase: 'AFTER_RETRY');
                }());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sync.isSyncing)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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

class LifeOSDashboard extends StatefulWidget {
  const LifeOSDashboard({super.key});

  @override
  State<LifeOSDashboard> createState() => _LifeOSDashboardState();
}

class _LifeOSDashboardState extends State<LifeOSDashboard> {
  /// 0 Timeline, 1 Planning, 2 Calendar, 3 Lists, 4 Categories, 5 Profile.
  int _shellPageIndex = 0;

  int get _navBarSelectedIndex => _shellPageIndex <= 3 ? _shellPageIndex : 4;

  static String _shellTabDiagnosticLabel(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 => 'timeline',
      1 => 'plan',
      2 => 'calendar',
      3 => 'lists',
      4 => 'more',
      5 => 'settings',
      _ => 'tab$shellPageIndex',
    };
  }

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

  final ShellLayoutController _shellLayout = ShellLayoutController();

  stt.SpeechToText? _speech;
  SpeechEngineHandle? _speechHandle;
  bool _speechReady = false;

  /// Last engine init failure (shown with [speech_unavailable] snackbar detail).
  String? _speechLastInitError;
  bool _isVoiceListening = false;
  void Function(String)? _speechStatusCallback;

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

  void _categoryVisibilityShellListener() {
    if (!mounted) return;
    final id = _selectedCategoryId;
    if (id != null && CategoryVisibilityPrefs.isHiddenOrAncestor(id)) {
      int? firstVisible;
      for (final p in DatabaseService.instance.allCategoryIdPathPairs) {
        if (!CategoryVisibilityPrefs.isHiddenOrAncestor(p.id)) {
          firstVisible = p.id;
          break;
        }
      }
      setState(() => _selectedCategoryId = firstVisible);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(CategoryVisibilityPrefs.ensureLoaded());
    CategoryVisibilityPrefs.hiddenIds.addListener(
      _categoryVisibilityShellListener,
    );
    _selectedDate = DatabaseService.instance.getTimelineDeviceLocalToday();
    _focusedDay = DatabaseService.instance.getTimelineDeviceLocalToday();
    _rules = List.from(DatabaseService.instance.rules);
    _selectedCategoryId = DatabaseService.instance.defaultCategoryId;
    unawaited(_loadTasksAndExtras());
    unawaited(() async {
      await DatabaseService.instance.offlineSync.bootstrapFromOutboxes(
        pbBackoffActive: DatabaseService.instance.pbHttpBackoffActive,
      );
    }());

    _notificationSub = DatabaseService.instance.notifications.listen((msg) {
      if (!mounted || msg == null || msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });

    _categoryRulesSub = DatabaseService.instance.categoryStream.listen((rules) {
      if (!mounted) return;
      setState(() => _rules = List.from(rules));
    });
    _deviceTodayAtLastMidnightCheck = DatabaseService.instance
        .getTimelineDeviceLocalToday();
    _deviceLocalDayKeyLast = DatabaseService.instance
        .getTimelineDeviceLocalTodayDateKey();
    _deviceLocalMidnightWatchTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        _onDeviceLocalCalendarDayWatchTick();
      },
    );
    unawaited(_ensureSpeechReady());
  }

  void _onDeviceLocalCalendarDayWatchTick() {
    final key = DatabaseService.instance.getTimelineDeviceLocalTodayDateKey();
    if (key == _deviceLocalDayKeyLast) {
      _deviceTodayAtLastMidnightCheck = DatabaseService.instance
          .getTimelineDeviceLocalToday();
      return;
    }
    final oldToday =
        _deviceTodayAtLastMidnightCheck ??
        DatabaseService.instance.getTimelineDeviceLocalToday();
    _deviceLocalDayKeyLast = key;
    _deviceTodayAtLastMidnightCheck = DatabaseService.instance
        .getTimelineDeviceLocalToday();
    DatabaseService.instance.notifyTimelineDeviceLocalDayChanged();
    if (!mounted) return;
    final sel = _dateOnly(_selectedDate);
    final wasFollowingLiveToday =
        sel.year == oldToday.year &&
        sel.month == oldToday.month &&
        sel.day == oldToday.day;
    if (wasFollowingLiveToday && _shellPageIndex == 0) {
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
  }

  void _selectShellHeaderDate(DateTime date) {
    final day = _dateOnly(date);
    setState(() {
      _selectedDate = day;
      _focusedDay = day;
    });
    unawaited(_loadTasksForDate(day));
  }

  @override
  void dispose() {
    CategoryVisibilityPrefs.hiddenIds.removeListener(
      _categoryVisibilityShellListener,
    );
    _deviceLocalMidnightWatchTimer?.cancel();
    _notificationSub?.cancel();
    _categoryRulesSub?.cancel();
    _titleController.dispose();
    _titleFocus.dispose();
    _shellLayout.dispose();
    super.dispose();
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
            : SnackBarAction(label: t(loc, 'try_again'), onPressed: onRetry),
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
          onRetry: () => unawaited(
            _retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
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
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
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
          onRetry: () => unawaited(
            _retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
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
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
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

  Future<void> _retryVoiceBacklogTask(String rawText) async {
    final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
      rawText: rawText,
      wallDay: _dateOnly(_selectedDate),
      categoryIdHint: _effectiveCategoryId,
      isBacklog: true,
    );
    if (!mounted) return;
    if (!ok) {
      _showSyncFailedSnackBar(
        onRetry: () => unawaited(_retryVoiceBacklogTask(rawText)),
      );
    }
  }

  Future<bool> _voiceSubmitTimeline(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    unawaited(_stopAnyActiveTask());
    final now = DatabaseService.getPlanetaryNow();
    final alreadyExists = _tasks.any(
      (t) =>
          t.title == title &&
          t.isActive &&
          t.startTime.difference(now).inSeconds.abs() <= 2,
    );
    if (alreadyExists) return true;
    final fuzzyMatch = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    final cid = fuzzyMatch?.id ?? _effectiveCategoryId;
    final pathTag = cid != null
        ? DatabaseService.instance.getCategoryPath(cid)
        : 'Life';
    if (fuzzyMatch != null && mounted) {
      final loc = currentLocale.value;
      final pathUi = localizeCategoryBreadcrumbPath(fuzzyMatch.path, loc);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              loc,
              'mapped_to',
            ).replaceFirst('%s', title).replaceFirst('%s', pathUi),
          ),
        ),
      );
    }
    try {
      final serverId = await DatabaseService.instance.writeRecord(
        _timelineVoiceDateKey,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: null,
      );
      if (!mounted) return false;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
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
      unawaited(_saveTasks());
      if (mounted) {
        unawaited(
          _deferSourcePlanLinkAfterFreeStart(
            title: title,
            dateKey: _timelineVoiceDateKey,
            recordBusinessId: serverId,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryVoiceWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
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
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoicePlanningTask(recognized)),
        );
      }
      return false;
    }
  }

  Future<bool> _voiceSubmitBacklog(String recognized) async {
    final title = recognized.trim();
    if (title.isEmpty) return false;
    try {
      final ok = await DatabaseService.instance.addPlanningTaskFromVoiceText(
        rawText: recognized,
        wallDay: _dateOnly(_selectedDate),
        categoryIdHint: _effectiveCategoryId,
        isBacklog: true,
      );
      if (!mounted) return false;
      if (!ok) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceBacklogTask(recognized)),
        );
      }
      return ok;
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(_retryVoiceBacklogTask(recognized)),
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

    unawaited(_stopAnyActiveTask());

    final now = DatabaseService.getPlanetaryNow();
    final cid = _effectiveCategoryId;
    final pathTag = cid != null
        ? DatabaseService.instance.getCategoryPath(cid)
        : 'Life';

    _titleController.clear();
    _titleFocus.requestFocus();

    try {
      final serverId = await DatabaseService.instance.writeRecord(
        _selectedDateString,
        title,
        categoryId: cid,
        explicitStartTime: now,
        sourcePlanPocketRecordId: null,
      );
      if (!mounted) return;
      if (serverId == null || serverId.trim().isEmpty) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
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
      unawaited(_saveTasks());
      if (mounted) {
        unawaited(
          _deferSourcePlanLinkAfterFreeStart(
            title: title,
            dateKey: _selectedDateString,
            recordBusinessId: serverId,
          ),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        _showSyncFailedSnackBar(
          onRetry: () => unawaited(
            _retryWriteNewTask(
              title,
              cid,
              pathTag,
              sourcePlanPocketRecordId: null,
            ),
          ),
        );
      }
    }
  }

  Future<void> _planTaskFromInput() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final dateKey = _selectedDateString;
    final cat = _effectiveCategoryId;
    _titleController.clear();
    _titleFocus.requestFocus();
    unawaited(() async {
      try {
        await DatabaseService.instance.addPlannedTask(
          dateKey,
          title,
          categoryId: cat,
          isManual: false,
        );
      } catch (_) {}
    }());
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
          SnackBar(
            content: Text(
              t(
                currentLocale.value,
                'failed_to_delete',
              ).replaceFirst('%s', e.toString()),
            ),
          ),
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
      final ok = await DatabaseService.instance.stopRecordByDocId(systemRowId);
      if (!mounted) return;
      if (!ok) {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=$systemRowId)',
        );
        // DatabaseService already showed error_stop_* / HTTP code — do not show sync_failed_retry.
        return;
      }
      await _stopAnyActiveTask();
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  Future<void> _stopAnyActiveTask() async {
    final running = _tasks.where((t) => t.isRunning).toList();
    for (final t in running) {
      await _stopTask(t);
    }
  }

  /// Initializes the global [SpeechToText] instance. Actual [listen] [localeId] is chosen
  /// per session in [VoiceInputSheet] via [SpeechListenLocale.resolveListenLocaleId]
  /// (app UI language first; device/system locale when that pack is missing; then
  /// null / en_US retries). One locale per listen — no plugin API for bilingual
  /// recognition in a single pass (see [SpeechListenLocale] class doc).
  Future<void> _ensureSpeechReady() async {
    if (_speechReady) return;
    _speech ??= stt.SpeechToText();
    await _initializeSpeechInstance();
  }

  /// New [SpeechToText] instance + [initialize] after Web errors (`no_speech`, network).
  Future<void> _speechEngineHardReset() async {
    if (!mounted) return;
    try {
      await _speech?.stop();
    } catch (_) {}
    try {
      await _speech?.cancel();
    } catch (_) {}
    _speech = stt.SpeechToText();
    _speechHandle?.speech = _speech!;
    _speechReady = false;
    _speechLastInitError = null;
    if (!mounted) return;
    await _initializeSpeechInstance();
  }

  Future<void> _initializeSpeechInstance() async {
    _speechLastInitError = null;
    try {
      final available = await _speech!.initialize(
        onStatus: (s) => _speechStatusCallback?.call(s),
        onError: (e) {
          final msg = e.errorMsg;
          debugPrint('[STT] onError: $msg (permanent=${e.permanent})');
          _speechStatusCallback?.call('error:$msg');
        },
        debugLogging: false,
      );
      if (!mounted) return;
      if (available) {
        if (kIsWeb) {
          // Web: never block ready state on [locales] (often 0 or 1 synthetic tag until post-listen).
          unawaited(_logSttLocalesBestEffortWeb());
        } else {
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

  Future<void> _logSttLocalesBestEffortWeb() async {
    try {
      final locales = await _speech!.locales();
      final ids = <String>[for (final l in locales) l.localeId.toString()];
      debugPrint(
        '[STT] Web init OK; locales async (${locales.length}): ${ids.join(", ")}',
      );
    } catch (e, st) {
      debugPrint('[STT] Web locales() log failed: $e\n$st');
    }
  }

  Future<SharedPreferences> _recordLinkPrefs() =>
      SharedPreferences.getInstance();

  Future<bool> _recordLinkSuggestionsEnabled() async {
    final prefs = await _recordLinkPrefs();
    return prefs.getBool(_prefsRecordLinkSuggestionsEnabled) ?? true;
  }

  Future<String> _recordLinkSuggestionMode() async {
    final prefs = await _recordLinkPrefs();
    final raw = prefs.getString(_prefsRecordLinkSuggestionMode);
    return raw == _recordLinkSuggestionModeAuto
        ? _recordLinkSuggestionModeAuto
        : _recordLinkSuggestionModeAsk;
  }

  Future<bool> _recordLinkSuggestionDismissed(String recordBusinessId) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return true;
    final prefs = await _recordLinkPrefs();
    return (prefs.getStringList(_prefsRecordLinkSuggestionDismissed) ??
            const [])
        .contains(rid);
  }

  Future<void> _markRecordLinkSuggestionDismissed(
    String recordBusinessId,
  ) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return;
    final prefs = await _recordLinkPrefs();
    final existing =
        prefs.getStringList(_prefsRecordLinkSuggestionDismissed) ?? [];
    if (existing.contains(rid)) return;
    existing.add(rid);
    if (existing.length > 300) {
      existing.removeRange(0, existing.length - 300);
    }
    await prefs.setStringList(_prefsRecordLinkSuggestionDismissed, existing);
  }

  Future<void> _disableRecordLinkSuggestions() async {
    final prefs = await _recordLinkPrefs();
    await prefs.setBool(_prefsRecordLinkSuggestionsEnabled, false);
  }

  void _showSourcePlanSuggestionSnack({
    required String title,
    required String recordBusinessId,
    required SourcePlanLinkSuggestion suggestion,
  }) {
    if (!mounted) return;
    final loc = currentLocale.value;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                loc,
                'record_link_suggestion_message',
              ).replaceFirst('%s', suggestion.planTitle),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      _markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                    unawaited(
                      _patchSuggestedSourcePlanLink(
                        recordBusinessId: recordBusinessId,
                        planPocketRecordId: suggestion.planPocketRecordId,
                      ),
                    );
                  },
                  child: Text(t(loc, 'link_plan_confirm')),
                ),
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      _markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                  },
                  child: Text(t(loc, 'skip_link_plan')),
                ),
                TextButton(
                  onPressed: () {
                    messenger.clearSnackBars();
                    unawaited(
                      _markRecordLinkSuggestionDismissed(recordBusinessId),
                    );
                    unawaited(_disableRecordLinkSuggestions());
                  },
                  child: Text(t(loc, 'record_link_suggestion_turn_off')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _patchSuggestedSourcePlanLink({
    required String recordBusinessId,
    required String planPocketRecordId,
  }) async {
    try {
      await DatabaseService.instance.primaryRecordWriteNetworkChain;
    } catch (_) {}
    if (!mounted) return;
    try {
      await DatabaseService.instance.patchRecordSourcePlanLink(
        recordId: recordBusinessId,
        sourcePlanPocketRecordId: planPocketRecordId,
      );
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  /// Plan-link suggestion + optional PATCH run **after** [writeRecord] shadow.
  Future<void> _deferSourcePlanLinkAfterFreeStart({
    required String title,
    required String dateKey,
    required String recordBusinessId,
  }) async {
    final rid = recordBusinessId.trim();
    if (rid.isEmpty) return;
    if (!mounted) return;
    if (!await _recordLinkSuggestionsEnabled()) return;
    if (await _recordLinkSuggestionDismissed(rid)) return;
    final mode = await _recordLinkSuggestionMode();
    final minSimilarity = mode == _recordLinkSuggestionModeAuto ? 0.92 : 0.72;
    final suggestion = await DatabaseService.instance
        .suggestSourcePlanForFreeStart(
          recordTitle: title,
          wallDateKey: dateKey,
          minSimilarity: minSimilarity,
        );
    if (!mounted || suggestion == null) return;
    if (mode == _recordLinkSuggestionModeAuto) {
      await _markRecordLinkSuggestionDismissed(rid);
      await _patchSuggestedSourcePlanLink(
        recordBusinessId: rid,
        planPocketRecordId: suggestion.planPocketRecordId,
      );
      return;
    }
    _showSourcePlanSuggestionSnack(
      title: title,
      recordBusinessId: rid,
      suggestion: suggestion,
    );
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
          onRetry: () => unawaited(
            _startRecordFromPlanning(
              title,
              categoryId,
              dateKey,
              sourcePlanPocketRecordId: sourcePlanPocketRecordId,
            ),
          ),
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
      debugPrint('UI ERROR: $e');
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
    // Synthetic empty record signals "create" to _TimelineRecordSheetContent
    // (id == '' triggers the create branch in _save). Single shared edit sheet.
    final tzHours = DatabaseService.instance.settings.timezoneOffsetHours;
    final defaultStartDisplay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9,
    );
    final defaultEndDisplay = defaultStartDisplay.add(const Duration(hours: 1));
    final placeholder = TimelineRecord(
      id: '',
      title: _titleController.text.trim(),
      startTime: displayToUtc(defaultStartDisplay),
      endTime: displayToUtc(defaultEndDisplay),
      status: 'completed',
      timezoneOffsetHours: tzHours,
    );
    showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.42,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ActivityDetailSheet(
                kind: ActivityDetailKind.timelineRecord,
                timelineRecord: placeholder,
                scrollController: scrollController,
                onSaved: (_) {
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startVoiceInput() async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final res = await Permission.microphone.request();
        if (!res.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(currentLocale.value, 'microphone_permission')),
            ),
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
    final Future<bool> Function(String) voiceSubmitIntent = _shellPageIndex == 1
        ? _voiceSubmitPlanning
        : _shellPageIndex == 3
        ? _voiceSubmitBacklog
        : _voiceSubmitTimeline;
    final voiceSuccessKey = _shellPageIndex == 1 || _shellPageIndex == 3
        ? 'task_added_to_plan'
        : 'record_synced';
    final voicePrimaryKey = _shellPageIndex == 1 || _shellPageIndex == 3
        ? 'add_task'
        : 'start_task';
    _speechHandle ??= SpeechEngineHandle(_speech!);
    _speechHandle!.speech = _speech!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return VoiceInputSheet(
          speechHandle: _speechHandle!,
          setSpeechStatusCallback: (cb) {
            if (mounted) setState(() => _speechStatusCallback = cb);
          },
          onSpeechEngineHardReset: _speechEngineHardReset,
          onListeningChanged: (listening) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isVoiceListening = listening);
            });
          },
          config: VoiceCaptureConfig(
            submitIntent: voiceSubmitIntent,
            successL10nKey: voiceSuccessKey,
            primaryActionL10nKey: voicePrimaryKey,
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
      _shellPageIndex = 0;
    });
    _loadTasksForDate(_selectedDate);
  }

  void _onShellTabSelected(int i) {
    if (i == 4) {
      _openMoreMenu(secondaryOnly: false);
      return;
    }
    setState(() {
      _shellPageIndex = i;
    });
    if (i == 0 || i == 1) {
      final target = DatabaseService.instance.getTimelineDeviceLocalToday();
      setState(() {
        _selectedDate = target;
        _focusedDay = target;
      });
      unawaited(_loadTasksForDate(target));
    }
  }

  void _onDesktopSideNavSelected(int navIndex) {
    // 0–3 primary tabs, 4 Categories, 5 Profile, 6 More (secondary overflow).
    if (navIndex == 6) {
      _openMoreMenu(secondaryOnly: true);
      return;
    }
    if (navIndex <= 5) {
      setState(() => _shellPageIndex = navIndex);
      if (navIndex == 0 || navIndex == 1) {
        final target = DatabaseService.instance.getTimelineDeviceLocalToday();
        setState(() {
          _selectedDate = target;
          _focusedDay = target;
        });
        unawaited(_loadTasksForDate(target));
      }
    }
  }

  int _desktopSideNavSelectedIndex(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 || 1 || 2 || 3 || 4 || 5 => shellPageIndex,
      _ => 6,
    };
  }

  void _openMoreMenu({bool secondaryOnly = false}) {
    final loc = currentLocale.value;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, snapshot) {
          final isAdmin =
              snapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;
          debugPrint(
            '[ADMIN_FLAG] More bottom sheet settings.isAdmin=$isAdmin renderDevLab=$isAdmin',
          );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!secondaryOnly) ...[
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(t(loc, 'more_menu_profile')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => _shellPageIndex = 5);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_rounded),
                    title: Text(t(loc, 'more_menu_categories')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => _shellPageIndex = 4);
                    },
                  ),
                ],
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.design_services_rounded),
                    title: const Text('Dev / Design Lab'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComponentLabPage(),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Admin flag: $isAdmin',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditRecordSheetForTimeline(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      builder: (sheetCtx) {
        final record = TimelineRecord.fromMap(
          data,
          timezoneOffsetHours:
              DatabaseService.instance.settings.timezoneOffsetHours,
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.42,
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
                  final ok = await DatabaseService.instance.deleteRecordByDocId(
                    record.id,
                  );
                  if (!mounted) return;
                  if (!ok) {
                    _showSyncFailedSnackBar(
                      onRetry: () => unawaited(
                        DatabaseService.instance.deleteRecordByDocId(record.id),
                      ),
                    );
                  }
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                onStop: () async {
                  await DatabaseService.instance.stopRecordByDocId(record.id);
                  if (!mounted) return;
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.42,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ActivityDetailSheet(
                kind: ActivityDetailKind.planningTask,
                planningTask: task,
                scrollController: scrollController,
                onSaved: (dynamic updatedRaw) {
                  final updated = updatedRaw as PlanningTask;
                  if (!_shellIsNewPlanningDraft(task)) {
                    DatabaseService.instance.applyOptimisticPlanningTask(
                      updated,
                    );
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
        final day =
            planningDateFromKey(result.dateKey) ??
            DatabaseService.instance.getTimelineDeviceLocalToday();
        final nextOrder = await DatabaseService.instance
            .nextPlanningOrderForDate(day);
        final startUtc = result.startTime != null
            ? _displayToUtc(result.startTime!)
            : null;
        final toCreate = result.copyWith(order: nextOrder, startTime: startUtc);
        final ok = await DatabaseService.instance.addPlanningTask(toCreate);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
          return;
        }
        HapticFeedback.heavyImpact();
      } else {
        unawaited(_persistPlanningEditFromSheet(task, result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(loc, 'save_failed').replaceFirst('%s', e.toString()),
            ),
          ),
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
      final anchorShort = DatabaseService.instance.planningAuditAnchorDateKey(
        baseline,
      );
      const minKeyLen = 10;
      final persistInitial = anchorShort.length >= minKeyLen
          ? anchorShort
          : DatabaseService.instance.planningWallScheduleDateKey(baseline);
      final newSk = DatabaseService.instance.planningWallScheduleDateKey(
        edited,
      );
      final initForPatch = persistInitial.length >= minKeyLen
          ? persistInitial
          : (newSk.length >= minKeyLen ? newSk : '');
      final postponed =
          !edited.isDone &&
          initForPatch.length >= minKeyLen &&
          DatabaseService.instance.planningShouldMarkPostponed(
            anchorKey: initForPatch,
            newScheduleKey: newSk.length >= minKeyLen ? newSk : initForPatch,
          );
      final ok = await DatabaseService.instance.updatePlanningTask(
        edited.planRowIdForBackend,
        planBusinessId: edited.planRowId,
        title: edited.title,
        categoryId: edited.categoryId,
        isDone: edited.isDone,
        notesPlain: edited.notesPlain,
        notesDeltaJson: edited.notesDeltaJson,
        checklist: edited.checklist,
        parentPlanId: edited.parentPlanId,
        startTimeDisplay: edited.startTime,
        endDateTimeDisplay: edited.endDateTime,
        clearEnd: edited.endDateTime == null,
        tags: edited.tags,
        suppressAppSnack: true,
        planInitialDateKey: initForPatch.length >= minKeyLen
            ? initForPatch
            : null,
        planIsPostponed: postponed,
        patchPlanAlarmRecurrence: true,
        planRrule: edited.rrule,
        planReminderOffset: edited.reminderOffset,
        planExceptionDates:
            (edited.rrule != null && edited.rrule!.trim().isNotEmpty)
            ? edited.exceptionDates
            : const <String>[],
      );
      if (!mounted) return;
      if (!ok) {
        DatabaseService.instance.applyOptimisticPlanningTask(baseline);
        DatabaseService.instance.notifyPlanningRefresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
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
          content: Text(t(loc, 'save_failed').replaceFirst('%s', e.toString())),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
      return;
    }
    final ok = await DatabaseService.instance.deletePlanningTasksBulk([
      backendId,
    ]);
    if (!mounted) return;
    DatabaseService.instance.clearOptimisticPlanningForPlanRow(
      task.planRowIdForBackend,
    );
    DatabaseService.instance.notifyPlanningRefresh();
    if (!ok) {
      DatabaseService.instance.applyOptimisticPlanningTask(task);
      DatabaseService.instance.notifyPlanningRefresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(loc, 'plan_save_failed'))));
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
        },
        onEditTask: _openEditDialog,
        onStartRecordFromTask: _startRecordFromPlanning,
      ),
      ListsPage(
        selectedDate: _selectedDate,
        onDateChanged: (d) => setState(() => _selectedDate = _dateOnly(d)),
        onEditTask: _openEditDialog,
      ),
      StreamBuilder<List<CategoryRule>>(
        stream: DatabaseService.instance.categoryStream,
        initialData: _rules,
        builder: (context, snapshot) {
          final r = snapshot.data ?? _rules;
          return CategoriesPage(
            rules: r,
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
      ProfilePage(
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    ];

    final showVoiceFab =
        _shellPageIndex == 1 || _shellPageIndex == 3 || !_isFutureDate;
    return AnimatedBuilder(
      animation: currentLocale,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        _shellLayout.applyShellFrame(_shellPageIndex);
        final loc = currentLocale.value;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: scheme.surface,
          ),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              ScaffoldMessenger.of(context).clearSnackBars();
            },
            child: ShellLayoutScope(
              controller: _shellLayout,
              child: Scaffold(
                backgroundColor: scheme.surface,
                resizeToAvoidBottomInset: true,
                appBar: _shellPageIndex <= 3
                    ? AppBar(
                        toolbarHeight: kGlobalCompactHeaderHeight,
                        backgroundColor: kGlobalCompactHeaderColor,
                        foregroundColor: kGlobalCompactHeaderForeground,
                        surfaceTintColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        titleSpacing: 16,
                        title: Row(
                          children: [
                            Text(
                              t(loc, 'app_title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: kGlobalCompactHeaderForeground,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: GlobalAppHeader(
                                  selectedDate: _selectedDate,
                                  onDateSelected: _selectShellHeaderDate,
                                  compact: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final useSideNav = shellUsesSideNavigation(
                      constraints.maxWidth,
                    );
                    final mainColumn = Column(
                      children: [
                        _OfflineSyncStatusBar(
                          routeTab: _shellTabDiagnosticLabel(_shellPageIndex),
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _shellPageIndex,
                            sizing: StackFit.expand,
                            children: pages,
                          ),
                        ),
                      ],
                    );
                    if (!useSideNav) return mainColumn;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ShellSideNavigation(
                          width: kShellSideNavWidth,
                          selectedIndex:
                              _desktopSideNavSelectedIndex(_shellPageIndex),
                          onTabSelected: _onDesktopSideNavSelected,
                        ),
                        Expanded(child: mainColumn),
                      ],
                    );
                  },
                ),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
                floatingActionButton: !showVoiceFab
                    ? null
                    : ListenableBuilder(
                        listenable: _shellLayout,
                        builder: (context, child) {
                          final bulkReservePx = _shellLayout.fabBottomReservePx;
                          return AnimatedPadding(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.paddingOf(context).bottom +
                                  bulkReservePx,
                            ),
                            child: child,
                          );
                        },
                        child: FloatingActionButton(
                          onPressed: _startVoiceInput,
                          tooltip: _isVoiceListening
                              ? t(currentLocale.value, 'listening')
                              : t(currentLocale.value, 'voice_input'),
                          child: Icon(
                            _isVoiceListening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_rounded,
                          ),
                        ),
                      ),
                bottomNavigationBar: LayoutBuilder(
                  builder: (context, constraints) {
                    if (shellUsesSideNavigation(constraints.maxWidth)) {
                      return const SizedBox.shrink();
                    }
                    return NavigationBar(
                      selectedIndex: _navBarSelectedIndex,
                      onDestinationSelected: _onShellTabSelected,
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
                          icon: const Icon(Icons.format_list_bulleted_outlined),
                          selectedIcon: const Icon(
                            Icons.format_list_bulleted_rounded,
                          ),
                          label: t(currentLocale.value, 'tab_lists'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.menu_rounded),
                          selectedIcon: const Icon(Icons.menu_rounded),
                          label: t(currentLocale.value, 'tab_more'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desktop/web left navigation rail (replaces bottom nav at wide breakpoints).
class _ShellSideNavigation extends StatelessWidget {
  const _ShellSideNavigation({
    required this.width,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final double width;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = currentLocale.value;
    final items = <({IconData icon, IconData selectedIcon, String label, int index})>[
      (
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        label: t(loc, 'tab_timeline'),
        index: 0,
      ),
      (
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist_rounded,
        label: t(loc, 'tab_planning'),
        index: 1,
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: t(loc, 'calendar'),
        index: 2,
      ),
      (
        icon: Icons.format_list_bulleted_outlined,
        selectedIcon: Icons.format_list_bulleted_rounded,
        label: t(loc, 'tab_lists'),
        index: 3,
      ),
      (
        icon: Icons.label_outlined,
        selectedIcon: Icons.label_rounded,
        label: t(loc, 'more_menu_categories'),
        index: 4,
      ),
      (
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: t(loc, 'more_menu_profile'),
        index: 5,
      ),
      (
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_horiz_rounded,
        label: t(loc, 'tab_more'),
        index: 6,
      ),
    ];
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
      child: SizedBox(
        width: width,
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _ShellSideNavItem(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: item.label,
                      selected: selectedIndex == item.index,
                      onTap: () => onTabSelected(item.index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellSideNavItem extends StatelessWidget {
  const _ShellSideNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primaryContainer.withValues(alpha: 0.72)
        : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(selected ? selectedIcon : icon, size: 22, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
