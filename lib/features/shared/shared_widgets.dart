// ---------------------------------------------------------------------------
// SHARED UI — Sheets and tiles used by Timeline, Planning, Categories. UI_ISOLATION (§7).
// All strings via t(). Use Theme.of(context). No hardcoded colors.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:counter/core/app_snackbar.dart';
import 'package:counter/core/widgets/compact_nav_controls.dart';
import 'package:counter/core/widgets/omni_date_time_picker_dialog.dart';
import 'package:counter/core/picker_entry_modes.dart';
import 'package:counter/core/theme.dart';
import 'package:counter/features/categories/category_recursive_tree.dart';
import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/planning/smart_input_parser.dart';
import 'package:counter/features/profile/tag_settings_hub.dart';
import 'package:counter/features/shared/chip_component.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchUrlFromQuillEditor(String raw) async {
  final u = Uri.tryParse(raw.trim());
  if (u == null || !u.hasScheme) return;
  try {
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}

// --- Time helpers (Planetary: UTC + profile offset). Used by sheets. ---
/// Calendar date for UI (localized month/day per [currentLocale]).
String formatDate(DateTime date) =>
    DateFormat.yMMMd(currentLocale.value).format(date);
String formatTimeOfDay(DateTime dt) =>
    DateFormat.Hm(currentLocale.value).format(dt);
DateTime utcToDisplay(DateTime utc) =>
    DatabaseService.instance.applyUserOffset(utc);
DateTime displayToUtc(DateTime displayNaive) =>
    DatabaseService.instance.displayTimeToUtc(displayNaive);
DateTime displayNow() =>
    DatabaseService.instance.applyUserOffset(DatabaseService.getPlanetaryNow());

Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final defaultInitial = DatabaseService.instance.applyUserOffset(
    DatabaseService.getPlanetaryNow(),
  );
  final base = initial ?? defaultInitial;

  if (useKeyboardFriendlyMaterialPickers()) {
    final fd = firstDate ?? DateTime.utc(2020);
    final ld = lastDate ?? DateTime.utc(2030);
    final clampedDay = _clampDay(base, fd, ld);
    final initialCombined = DateTime(
      clampedDay.year,
      clampedDay.month,
      clampedDay.day,
      base.hour,
      base.minute,
    );
    return showOmniDateTimePickerDialog(
      context,
      initial: initialCombined,
      firstDate: DateTime(fd.year, fd.month, fd.day),
      lastDate: DateTime(ld.year, ld.month, ld.day),
    );
  }

  final theme = Theme.of(context);
  return showOmniDateTimePicker(
    context: context,
    initialDate: base,
    firstDate: firstDate ?? DateTime.utc(2020),
    lastDate: lastDate ?? DateTime.utc(2030),
    is24HourMode: true,
    theme: theme,
  );
}

DateTime _clampDay(DateTime value, DateTime first, DateTime last) {
  final d = DateTime(value.year, value.month, value.day);
  final f = DateTime(first.year, first.month, first.day);
  final l = DateTime(last.year, last.month, last.day);
  if (d.isBefore(f)) return f;
  if (d.isAfter(l)) return l;
  return d;
}

DateTime? planningDateFromKey(String key) {
  if (key.length < 10) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(5, 7));
  final d = int.tryParse(key.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Strike 23: one horizontal row ([multiRowsDisplay]: false → arrow-indicated list, no [Wrap]).
QuillSimpleToolbarConfig _planningTaskEditQuillToolbarConfig(
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  return QuillSimpleToolbarConfig(
    multiRowsDisplay: false,
    showDividers: false,
    toolbarSize: kPlanningEditQuillToolbarRowSize,
    toolbarRunSpacing: 0,
    buttonOptions: const QuillSimpleToolbarButtonOptions(
      base: QuillToolbarBaseButtonOptions(
        iconSize: kPlanningEditQuillToolbarIconSize,
        iconButtonFactor: 1.42,
      ),
    ),
    showFontFamily: false,
    showFontSize: false,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showAlignmentButtons: false,
    showHeaderStyle: false,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: true,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false,
    showLink: false,
    showUndo: false,
    showRedo: false,
    showSearchButton: false,
    showSubscript: false,
    showSuperscript: false,
    showSmallButton: false,
    showLineHeightButton: false,
    showDirection: false,
    color: scheme.surfaceContainerHighest,
  );
}

// --- Checklist editors (_PlanningTaskEditSheet + _TimelineRecordSheetContent) ---
void _syncChecklistDoneLength(
  List<TextEditingController> controllers,
  List<bool> done,
) {
  while (done.length < controllers.length) {
    done.add(false);
  }
  if (done.length > controllers.length) {
    done.removeRange(controllers.length, done.length);
  }
}

/// Unchecked rows first (stable order), then checked (stable order). Mutates lists in place.
void _partitionChecklistRowsByDone({
  required List<TextEditingController> controllers,
  required List<bool> done,
}) {
  if (controllers.isEmpty) return;
  _syncChecklistDoneLength(controllers, done);
  final n = controllers.length;
  final order = List<int>.generate(n, (i) => i);
  order.sort((a, b) {
    final da = done[a] ? 1 : 0;
    final db = done[b] ? 1 : 0;
    if (da != db) return da.compareTo(db);
    return a.compareTo(b);
  });
  var identity = true;
  for (var k = 0; k < n; k++) {
    if (order[k] != k) {
      identity = false;
      break;
    }
  }
  if (identity) return;
  final newControllers = order.map(controllers.elementAt).toList();
  final newDone = order.map(done.elementAt).toList();
  controllers
    ..clear()
    ..addAll(newControllers);
  done
    ..clear()
    ..addAll(newDone);
}

void _removeChecklistRowAt(
  int index, {
  required List<TextEditingController> controllers,
  required List<bool> done,
}) {
  if (index < 0 || index >= controllers.length) return;
  controllers[index].dispose();
  controllers.removeAt(index);
  if (index < done.length) {
    done.removeAt(index);
  }
  _syncChecklistDoneLength(controllers, done);
  if (controllers.isEmpty) {
    controllers.add(TextEditingController());
    done
      ..clear()
      ..add(false);
  }
}

// ---------------------------------------------------------------------------
// Empty states — first-run / empty collection (grayscale, minimal).
// ---------------------------------------------------------------------------

/// Full-width centered cue: large faded icon, title, subtitle, optional action.
class EmptyStatePlaceholder extends StatelessWidget {
  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.titleL10nKey,
    required this.subtitleL10nKey,
    this.actionLabelL10nKey,
    this.onAction,
    this.iconSize = 96,
    this.iconOpacity = 0.26,
    this.useFilledAction = false,
  });

  final IconData icon;
  final String titleL10nKey;
  final String subtitleL10nKey;
  final String? actionLabelL10nKey;
  final VoidCallback? onAction;
  final double iconSize;
  final double iconOpacity;

  /// When true, primary-style button (e.g. “create first” flows).
  final bool useFilledAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final loc = currentLocale.value;
    final hasAction = actionLabelL10nKey != null && onAction != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: scheme.onSurface.withValues(alpha: iconOpacity),
            ),
            const SizedBox(height: 20),
            Text(
              t(loc, titleL10nKey),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t(loc, subtitleL10nKey),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 22),
              useFilledAction
                  ? FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(t(loc, actionLabelL10nKey!)),
                    )
                  : OutlinedButton.icon(
                      onPressed: onAction,
                      icon: Icon(
                        Icons.north_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                      label: Text(t(loc, actionLabelL10nKey!)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ActivityDetailSheet & related
// ---------------------------------------------------------------------------

enum ActivityDetailKind { timelineRecord, planningTask }

/// Local repeat presets for plan edit sheet (maps to @DATA_MAP `plans.rrule`).
enum _PlanRepeatUi { none, daily, weekdays, weekly, monthly, yearly, custom }

String _planRruleForUiParse(String? raw) {
  var s = (raw ?? '').trim();
  if (s.isEmpty) return s;
  if (s.toUpperCase().startsWith('RRULE:')) {
    s = s.substring(6).trim();
  }
  return s;
}

bool _rruleHasFreqWeekly(String r) {
  return RegExp(r'FREQ\s*=\s*WEEKLY', caseSensitive: false).hasMatch(r);
}

bool _rruleHasBydayClause(String r) {
  return RegExp(r'\bBYDAY\s*=', caseSensitive: false).hasMatch(r);
}

String? _bydayClauseValue(String raw) {
  final m = RegExp(
    r'BYDAY\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(raw);
  return m?.group(1)?.trim();
}

/// RFC 5545: Mon–Fri bundle (office weekdays), distinct from plain `FREQ=WEEKLY`.
bool _isWeekdaysMoToFrRrule(String r) {
  if (!_rruleHasFreqWeekly(r)) return false;
  final val = _bydayClauseValue(r);
  if (val == null || val.isEmpty) return false;
  final tokens = val
      .split(',')
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  const want = {'MO', 'TU', 'WE', 'TH', 'FR'};
  return tokens.length == 5 && tokens.containsAll(want);
}

_PlanRepeatUi _planRepeatUiFromTask(PlanningTask t) {
  final r = _planRruleForUiParse(t.rrule);
  if (r.isEmpty) return _PlanRepeatUi.none;
  if (RegExp(r'FREQ\s*=\s*YEARLY', caseSensitive: false).hasMatch(r)) {
    return _PlanRepeatUi.yearly;
  }
  if (RegExp(r'FREQ\s*=\s*DAILY', caseSensitive: false).hasMatch(r)) {
    return _PlanRepeatUi.daily;
  }
  if (_isWeekdaysMoToFrRrule(r)) {
    return _PlanRepeatUi.weekdays;
  }
  if (RegExp(r'FREQ\s*=\s*MONTHLY', caseSensitive: false).hasMatch(r)) {
    return _PlanRepeatUi.monthly;
  }
  if (_rruleHasFreqWeekly(r)) {
    if (_rruleHasBydayClause(r) && !_isWeekdaysMoToFrRrule(r)) {
      return _PlanRepeatUi.custom;
    }
    return _PlanRepeatUi.weekly;
  }
  return _PlanRepeatUi.custom;
}

String? _rruleWireFromRepeatUi(_PlanRepeatUi choice, String? customRaw) {
  switch (choice) {
    case _PlanRepeatUi.none:
      return null;
    case _PlanRepeatUi.daily:
      return 'FREQ=DAILY';
    case _PlanRepeatUi.weekdays:
      return 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
    case _PlanRepeatUi.weekly:
      return 'FREQ=WEEKLY';
    case _PlanRepeatUi.monthly:
      return 'FREQ=MONTHLY';
    case _PlanRepeatUi.yearly:
      return 'FREQ=YEARLY';
    case _PlanRepeatUi.custom:
      final s = customRaw?.trim() ?? '';
      return s.isEmpty ? null : s;
  }
}

class ActivityDetailSheet extends StatelessWidget {
  const ActivityDetailSheet({
    super.key,
    required this.kind,
    this.timelineRecord,
    this.planningTask,
    required this.scrollController,
    required this.onSaved,
    this.onDelete,
    this.onStop,
  });

  final ActivityDetailKind kind;
  final TimelineRecord? timelineRecord;
  final PlanningTask? planningTask;
  final ScrollController scrollController;
  final void Function(dynamic updated) onSaved;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (kind == ActivityDetailKind.planningTask && planningTask != null) {
      return _PlanningTaskEditSheet(
        task: planningTask!,
        dateKey: planningTask!.dateKey,
        scrollController: scrollController,
        onDelete: onDelete != null ? (_) => onDelete!() : null,
        onSaved: onSaved,
      );
    }
    if (kind == ActivityDetailKind.timelineRecord && timelineRecord != null) {
      return _TimelineRecordSheetContent(
        record: timelineRecord!,
        scrollController: scrollController,
        onSaved: onSaved,
        onDelete: onDelete ?? () {},
        onStop: onStop ?? () {},
      );
    }
    return const SizedBox.shrink();
  }
}

class _PlanningTaskEditSheet extends StatefulWidget {
  const _PlanningTaskEditSheet({
    required this.task,
    required this.dateKey,
    required this.scrollController,
    this.onDelete,
    this.onSaved,
  });

  final PlanningTask task;
  final String dateKey;
  final ScrollController scrollController;
  final void Function(PlanningTask task)? onDelete;
  final void Function(dynamic updated)? onSaved;

  @override
  State<_PlanningTaskEditSheet> createState() => _PlanningTaskEditSheetState();
}

class _PlanningTaskEditSheetState extends State<_PlanningTaskEditSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _quillFocusNode;

  /// Separate from [scrollController] so plan-mode outer [ListView] does not fight Quill.
  late final ScrollController _quillScrollController;
  late int _categoryId;
  DateTime? _scheduledTime;
  DateTime? _endTime;
  late DateTime _date;

  /// Undated backlog / list item before any schedule is set (no wall date in [dateKey]).
  late final bool _startedAsUndatedBacklog;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];

  /// Non-null only for list-item / Idea mode (3-tab Strike 19 layout).
  TabController? _tabController;

  /// Dated plan mode: Notes / Checklist / schedule & recurrence (Strike 24).
  TabController? _planTabController;
  List<Tag> _availableTags = [];

  /// True until [DatabaseService.fetchTagsForCurrentUser] completes (strip stays visible).
  bool _tagsLoading = true;
  late List<Tag> _selectedTags;
  int? _reminderMinutes;
  late _PlanRepeatUi _repeatUi;
  String? _rruleCustomRaw;
  late final TextEditingController _rruleCustomController;

  @override
  void initState() {
    super.initState();
    _startedAsUndatedBacklog =
        widget.task.startTime == null && widget.task.dateKey.trim().length < 10;
    if (_startedAsUndatedBacklog) {
      _tabController = TabController(length: 4, vsync: this);
    } else {
      _planTabController = TabController(length: 4, vsync: this);
    }
    _titleController = TextEditingController(text: widget.task.title);
    final parsedNotes = _parseStoredNotesForLink(widget.task.notesPlain);
    _quillController = QuillController(
      document: _documentForPlanningNotes(
        parsedNotes.body,
        legacyUrl: parsedNotes.link,
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillFocusNode = FocusNode();
    _quillScrollController = ScrollController();
    _categoryId = widget.task.categoryId;
    _selectedTags = List<Tag>.from(widget.task.tags);
    _reminderMinutes = widget.task.reminderOffset;
    _repeatUi = _planRepeatUiFromTask(widget.task);
    _rruleCustomRaw = _repeatUi == _PlanRepeatUi.custom
        ? widget.task.rrule?.trim()
        : null;
    _rruleCustomController = TextEditingController(
      text: _repeatUi == _PlanRepeatUi.custom
          ? (widget.task.rrule?.trim() ?? '')
          : '',
    );
    if (!_startedAsUndatedBacklog) {
      DatabaseService.instance
          .fetchTagsForCurrentUser(scope: TagCatalogScope.plan)
          .then((List<Tag> result) {
            if (!mounted) return;
            setState(() {
              _availableTags = result;
              _tagsLoading = false;
            });
          });
    } else {
      DatabaseService.instance
          .fetchTagsForCurrentUser(scope: TagCatalogScope.list)
          .then((List<Tag> result) {
            if (!mounted) return;
            setState(() {
              _availableTags = result;
              _tagsLoading = false;
            });
          });
    }
    // [PlanningTask.startTime] / [endDateTime] from Brain are profile wall components, not UTC.
    _scheduledTime = widget.task.startTime;
    _endTime = widget.task.endDateTime;
    _date =
        planningDateFromKey(widget.task.dateKey) ??
        widget.task.date ??
        DateTime.now();
    _date = DateTime(_date.year, _date.month, _date.day);
    for (final item in widget.task.checklist) {
      final text = (item['text'] ?? '').toString();
      final done = item['isDone'] == true;
      _checklistControllers.add(TextEditingController(text: text));
      _checklistDone.add(done);
    }
    if (_checklistControllers.isEmpty) {
      _checklistControllers.add(TextEditingController());
      _checklistDone.add(false);
    }
    _partitionChecklistRowsByDone(
      controllers: _checklistControllers,
      done: _checklistDone,
    );
  }

  bool get _shouldShowGraduateUi =>
      _startedAsUndatedBacklog && _scheduledTime != null;

  @override
  void dispose() {
    _tabController?.dispose();
    _planTabController?.dispose();
    _titleController.dispose();
    _quillController.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    _rruleCustomController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyFuzzyCategoryFromTitle(String title) {
    final fuzzy = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    if (fuzzy != null && fuzzy.id != _categoryId && mounted) {
      setState(() => _categoryId = fuzzy.id);
    }
  }

  void _onTitleChangedForSmartTime(String raw) {
    _applyFuzzyCategoryFromTitle(
      raw.trim().isEmpty ? _titleController.text : raw,
    );
    if (_startedAsUndatedBacklog) return;
    final v = _titleController.value;
    if (!v.composing.isCollapsed) return;

    final parsed = SmartInputParser.parseTitleForScheduledTime(raw);
    if (parsed == null) return;

    final cleaned = parsed.cleanedTitle;
    final newOffset = cleaned.length;
    if (_titleController.text != cleaned) {
      _titleController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(
          offset: newOffset.clamp(0, cleaned.length),
        ),
        composing: TextRange.empty,
      );
    } else {
      _titleController.selection = TextSelection.collapsed(
        offset: newOffset.clamp(0, cleaned.length),
      );
    }
    if (!mounted) return;
    setState(() {
      _scheduledTime = parsed.wallDateTimeOn(_date);
    });
  }

  Future<void> _openTagManagerAndReload() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => TagSettingsHub(
          tagCreateDomain: _startedAsUndatedBacklog ? 'list' : 'plan',
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _tagsLoading = true);
    final list = await DatabaseService.instance.fetchTagsForCurrentUser(
      scope: _startedAsUndatedBacklog
          ? TagCatalogScope.list
          : TagCatalogScope.plan,
    );
    if (!mounted) return;
    setState(() {
      _availableTags = list;
      _tagsLoading = false;
    });
  }

  void _toggleTag(Tag t) {
    setState(() {
      final next = List<Tag>.from(_selectedTags);
      final i = next.indexWhere((x) => x.tagId == t.tagId);
      if (i >= 0) {
        next.removeAt(i);
      } else {
        next.add(t);
      }
      _selectedTags = next;
    });
  }

  /// Optional URL line prefix in [notesPlain] for backlog ideas (no separate PB field).
  static const String _kLifeOsLinkPrefix = 'LIFEOS_LINK::';

  ({String link, String body}) _parseStoredNotesForLink(String? raw) {
    final s = raw?.trim() ?? '';
    if (!s.startsWith(_kLifeOsLinkPrefix)) {
      return (link: '', body: s);
    }
    final rest = s.substring(_kLifeOsLinkPrefix.length);
    final nl = rest.indexOf('\n');
    if (nl < 0) {
      return (link: rest.trim(), body: '');
    }
    return (
      link: rest.substring(0, nl).trim(),
      body: rest.substring(nl + 1).trimRight(),
    );
  }

  /// Builds initial Quill [Document] from stored delta or legacy plain-only [legacyPlainBody].
  /// [legacyUrl] migrates old `LIFEOS_LINK::` first line into an inline Quill link op.
  Document _documentForPlanningNotes(
    String legacyPlainBody, {
    String? legacyUrl,
  }) {
    final deltaRaw = widget.task.notesDeltaJson?.trim() ?? '';
    if (deltaRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(deltaRaw);
        if (decoded is List) {
          return Document.fromJson(decoded);
        }
      } catch (_) {}
    }
    final url = legacyUrl?.trim() ?? '';
    final b = legacyPlainBody.trim();
    if (url.isNotEmpty) {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': url,
          'attributes': LinkAttribute(url).toJson(),
        },
        <String, dynamic>{'insert': '\n'},
      ];
      if (b.isNotEmpty) {
        ops.add(<String, dynamic>{'insert': '$b\n'});
      }
      return Document.fromJson(ops);
    }
    if (b.isNotEmpty) {
      return Document.fromJson([
        <String, dynamic>{'insert': '$b\n'},
      ]);
    }
    return Document();
  }

  bool _isTrivialEmptyNotes(String deltaJson, String plainTrimmed) {
    if (plainTrimmed.isNotEmpty) return false;
    try {
      final d = jsonDecode(deltaJson);
      if (d is! List) return true;
      if (d.isEmpty) return true;
      if (d.length == 1 && d[0] is Map) {
        final m = Map<String, dynamic>.from(d[0] as Map);
        if (m['insert'] == '\n' && m['attributes'] == null) return true;
      }
    } catch (_) {}
    return false;
  }

  String _dateKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _shortMonth(int month) =>
      month >= 1 && month <= 12 ? _shortMonths[month - 1] : '';

  void _commitSave() {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final catId = pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : _categoryId);
    final newDateKey = _dateKeyFromDate(_date);
    _syncChecklistDoneLength(_checklistControllers, _checklistDone);
    final List<Map<String, dynamic>> checklist = [];
    for (var i = 0; i < _checklistControllers.length; i++) {
      final text = _checklistControllers[i].text.trim();
      if (text.isEmpty) continue;
      checklist.add(<String, dynamic>{
        'text': text,
        'isDone': i < _checklistDone.length ? _checklistDone[i] : false,
      });
    }
    if (_repeatUi == _PlanRepeatUi.custom) {
      _rruleCustomRaw = _rruleCustomController.text.trim();
    }
    final rruleWire = _rruleWireFromRepeatUi(_repeatUi, _rruleCustomRaw);
    final clearR = rruleWire == null;
    final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());
    final plainTrimmed = _quillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    String? notesPlainOut;
    String? notesDeltaJsonOut;
    if (_startedAsUndatedBacklog) {
      notesPlainOut = plainTrimmed.isEmpty ? null : plainTrimmed;
      notesDeltaJsonOut = deltaJson;
    } else {
      notesPlainOut = plainTrimmed.isEmpty ? null : plainTrimmed;
      notesDeltaJsonOut = deltaJson;
    }
    final shouldClear =
        notesPlainOut == null && _isTrivialEmptyNotes(deltaJson, plainTrimmed);
    final updated = shouldClear
        ? widget.task.copyWith(
            title: title,
            categoryId: catId,
            startTime: _scheduledTime,
            date: _date,
            dateKey: newDateKey,
            endDateTime: _endTime != null
                ? DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    _endTime!.hour,
                    _endTime!.minute,
                  )
                : null,
            endDateKey: _endTime != null ? newDateKey : null,
            checklist: checklist,
            clearNotes: true,
            tags: List<Tag>.from(_selectedTags),
            rrule: rruleWire,
            clearRrule: clearR,
            exceptionDates: clearR
                ? const <String>[]
                : List<String>.from(widget.task.exceptionDates),
            reminderOffset: _reminderMinutes,
            clearReminderOffset: _reminderMinutes == null,
          )
        : widget.task.copyWith(
            title: title,
            categoryId: catId,
            startTime: _scheduledTime,
            date: _date,
            dateKey: newDateKey,
            endDateTime: _endTime != null
                ? DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    _endTime!.hour,
                    _endTime!.minute,
                  )
                : null,
            endDateKey: _endTime != null ? newDateKey : null,
            checklist: checklist,
            notesPlain: notesPlainOut,
            notesDeltaJson: notesDeltaJsonOut,
            tags: List<Tag>.from(_selectedTags),
            rrule: rruleWire,
            clearRrule: clearR,
            exceptionDates: clearR
                ? const <String>[]
                : List<String>.from(widget.task.exceptionDates),
            reminderOffset: _reminderMinutes,
            clearReminderOffset: _reminderMinutes == null,
          );
    if (widget.onSaved != null) {
      widget.onSaved!(updated);
    } else {
      Navigator.of(context).pop<PlanningTask?>(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final dropdownValue = pairs.any((p) => p.id == _categoryId)
        ? _categoryId
        : (pairs.isNotEmpty ? pairs.first.id : _categoryId);
    final kbBottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kbBottom > 0;
    final compactChrome = keyboardOpen;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              compactChrome ? 6 : 12,
              16,
              compactChrome ? 4 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    autofocus: _startedAsUndatedBacklog,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    minLines: 1,
                    maxLines: compactChrome ? 2 : 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t(currentLocale.value, 'title_label'),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onTitleChangedForSmartTime,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () =>
                      Navigator.of(context).pop<PlanningTask?>(null),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              compactChrome ? 4 : 8,
              16,
              compactChrome ? 2 : 4,
            ),
            child: CategoryTreeFormField(
              value: pairs.any((p) => p.id == dropdownValue)
                  ? dropdownValue
                  : (pairs.isNotEmpty ? pairs.first.id : null),
              decoration: InputDecoration(
                labelText: t(currentLocale.value, 'category_label'),
              ),
              onChanged: (id) =>
                  setState(() => _categoryId = id ?? _categoryId),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (_startedAsUndatedBacklog) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: kAppCompactControlHeight,
                      child: TabBar(
                        controller: _tabController!,
                        isScrollable: true,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        tabs: [
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'notes_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'checklist_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(currentLocale.value, 'lists_subitems_tab'),
                          ),
                          AppCompactTextTab(
                            text: t(
                              currentLocale.value,
                              'plan_idea_tab_schedule',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController!,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 4 : 8,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: kPlanningEditQuillToolbarMinHeight,
                                ),
                                child: QuillSimpleToolbar(
                                  controller: _quillController,
                                  config: _planningTaskEditQuillToolbarConfig(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: QuillEditor.basic(
                                    controller: _quillController,
                                    focusNode: _quillFocusNode,
                                    scrollController: _quillScrollController,
                                    config: QuillEditorConfig(
                                      expands: true,
                                      padding: const EdgeInsets.all(12),
                                      placeholder: t(
                                        currentLocale.value,
                                        'notes_hint_flat',
                                      ),
                                      onLaunchUrl: _launchUrlFromQuillEditor,
                                      customStyles: DefaultStyles.getInstance(
                                        context,
                                      ),
                                      keyboardAppearance:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Brightness.dark
                                          : Brightness.light,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 8 : 12,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          children: [
                            ...List.generate(_checklistControllers.length, (i) {
                              final scheme = Theme.of(context).colorScheme;
                              final rowDone =
                                  i < _checklistDone.length &&
                                  _checklistDone[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                horizontalTitleGap: 4,
                                leading: Checkbox(
                                  value: rowDone,
                                  onChanged: (v) => setState(() {
                                    _syncChecklistDoneLength(
                                      _checklistControllers,
                                      _checklistDone,
                                    );
                                    _checklistDone[i] = v ?? false;
                                    _partitionChecklistRowsByDone(
                                      controllers: _checklistControllers,
                                      done: _checklistDone,
                                    );
                                  }),
                                ),
                                title: TextField(
                                  controller: _checklistControllers[i],
                                  style: TextStyle(
                                    decoration: rowDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    color: rowDone
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.5,
                                          )
                                        : scheme.onSurface,
                                    decorationColor: rowDone
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.5,
                                          )
                                        : null,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: t(
                                      currentLocale.value,
                                      'checklist_item',
                                    ),
                                    hintStyle: TextStyle(
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: rowDone ? 0.35 : 0.5,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: scheme.error,
                                  ),
                                  tooltip: t(currentLocale.value, 'delete'),
                                  onPressed: () => setState(() {
                                    _removeChecklistRowAt(
                                      i,
                                      controllers: _checklistControllers,
                                      done: _checklistDone,
                                    );
                                  }),
                                ),
                              );
                            }),
                            ListTile(
                              leading: Icon(
                                Icons.add_circle_outline_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                t(currentLocale.value, 'add_checklist_item'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => setState(() {
                                _checklistControllers.add(
                                  TextEditingController(),
                                );
                                _checklistDone.add(false);
                              }),
                            ),
                          ],
                        ),
                        _BacklogSubItemsPanel(
                          parentTask: widget.task,
                          categoryId: _categoryId,
                        ),
                        ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            compactChrome ? 8 : 12,
                            16,
                            compactChrome ? 12 : 24,
                          ),
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _scheduledTime == null
                                    ? t(currentLocale.value, 'scheduled')
                                    : '${_date.day} ${_shortMonth(_date.month)} ${_date.year}, ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                              ),
                              trailing: const Icon(Icons.schedule_rounded),
                              onTap: () async {
                                final initial = DateTime(
                                  _date.year,
                                  _date.month,
                                  _date.day,
                                  _scheduledTime?.hour ?? 9,
                                  _scheduledTime?.minute ?? 0,
                                );
                                final picked = await showAppDateTimePicker(
                                  context,
                                  initial: initial,
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _date = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                    );
                                    _scheduledTime = picked;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _endTime == null
                                    ? t(currentLocale.value, 'no_end_time')
                                    : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                              ),
                              trailing: const Icon(Icons.schedule_rounded),
                              onTap: () async {
                                final initial = DateTime(
                                  _date.year,
                                  _date.month,
                                  _date.day,
                                  _endTime?.hour ?? 10,
                                  _endTime?.minute ?? 0,
                                );
                                final picked = await showAppDateTimePicker(
                                  context,
                                  initial: initial,
                                );
                                if (picked != null && mounted) {
                                  setState(
                                    () => _endTime = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      picked.hour,
                                      picked.minute,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              initialValue: _reminderMinutes,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: t(
                                  currentLocale.value,
                                  'plan_reminder_label',
                                ),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_reminder_none',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 5,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_5m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 15,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_15m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 30,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_30m'),
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 60,
                                  child: Text(
                                    t(currentLocale.value, 'plan_reminder_1h'),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _reminderMinutes = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<_PlanRepeatUi>(
                              initialValue: _repeatUi,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: t(
                                  currentLocale.value,
                                  'plan_repeat_label',
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.none,
                                  child: Text(
                                    t(currentLocale.value, 'plan_repeat_none'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.daily,
                                  child: Text(
                                    t(currentLocale.value, 'plan_repeat_daily'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.weekdays,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_weekdays',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.weekly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_weekly',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.monthly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_monthly',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: _PlanRepeatUi.yearly,
                                  child: Text(
                                    t(
                                      currentLocale.value,
                                      'plan_repeat_yearly',
                                    ),
                                  ),
                                ),
                                if (_repeatUi == _PlanRepeatUi.custom)
                                  DropdownMenuItem(
                                    value: _PlanRepeatUi.custom,
                                    child: Text(
                                      t(
                                        currentLocale.value,
                                        'plan_repeat_custom',
                                      ),
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _repeatUi = v;
                                  if (v != _PlanRepeatUi.custom) {
                                    _rruleCustomRaw = null;
                                    _rruleCustomController.clear();
                                  } else {
                                    _rruleCustomRaw = widget.task.rrule?.trim();
                                    _rruleCustomController.text =
                                        _rruleCustomRaw ?? '';
                                  }
                                });
                              },
                            ),
                            if (_repeatUi == _PlanRepeatUi.custom) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _rruleCustomController,
                                minLines: 2,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  labelText: t(
                                    currentLocale.value,
                                    'plan_repeat_custom',
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final initial = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      _scheduledTime?.hour ?? 9,
                                      _scheduledTime?.minute ?? 0,
                                    );
                                    final picked = await showAppDateTimePicker(
                                      context,
                                      initial: initial,
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _date = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                        );
                                        _scheduledTime = picked;
                                      });
                                    }
                                  },
                                  child: SizedBox(
                                    height: 56,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                t(
                                                  currentLocale.value,
                                                  'plan_start_time_full',
                                                ),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelMedium,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _scheduledTime == null
                                              ? t(
                                                  currentLocale.value,
                                                  'scheduled',
                                                )
                                              : '${_date.day} ${_shortMonth(_date.month)} ${_date.year}, ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final initial = DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      _endTime?.hour ?? 10,
                                      _endTime?.minute ?? 0,
                                    );
                                    final picked = await showAppDateTimePicker(
                                      context,
                                      initial: initial,
                                    );
                                    if (picked != null && mounted) {
                                      setState(
                                        () => _endTime = DateTime(
                                          _date.year,
                                          _date.month,
                                          _date.day,
                                          picked.hour,
                                          picked.minute,
                                        ),
                                      );
                                    }
                                  },
                                  child: SizedBox(
                                    height: 56,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.event_available_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                t(
                                                  currentLocale.value,
                                                  'plan_end_time_full',
                                                ),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelMedium,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _endTime == null
                                              ? t(
                                                  currentLocale.value,
                                                  'no_end_time',
                                                )
                                              : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SizedBox(
                            height: 64,
                            child: _tagsLoading
                                ? Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : _availableTags.isEmpty
                                ? Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: OutlinedButton.icon(
                                      onPressed: _openTagManagerAndReload,
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 20,
                                      ),
                                      label: Text(
                                        t(
                                          currentLocale.value,
                                          'tags_empty_create_first',
                                        ),
                                      ),
                                    ),
                                  )
                                : TagQuickPickStrip(
                                    tags: _availableTags,
                                    selected: _selectedTags,
                                    onToggle: _toggleTag,
                                    variant: CategoryChipVariant.largePicker,
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: kAppCompactControlHeight,
                            child: TabBar(
                              controller: _planTabController!,
                              isScrollable: true,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              tabAlignment: TabAlignment.start,
                              padding: EdgeInsets.zero,
                              tabs: [
                                AppCompactTextTab(
                                  text: t(currentLocale.value, 'notes_tab'),
                                ),
                                AppCompactTextTab(
                                  text: t(currentLocale.value, 'checklist_tab'),
                                ),
                                AppCompactTextTab(
                                  text: t(
                                    currentLocale.value,
                                    'plan_repeat_label',
                                  ),
                                ),
                                AppCompactTextTab(
                                  text: t(
                                    currentLocale.value,
                                    'plan_parallel_plans_tab',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _planTabController!,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  compactChrome ? 4 : 8,
                                  16,
                                  compactChrome ? 12 : 24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight:
                                            kPlanningEditQuillToolbarMinHeight,
                                      ),
                                      child: QuillSimpleToolbar(
                                        controller: _quillController,
                                        config:
                                            _planningTaskEditQuillToolbarConfig(
                                              context,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: QuillEditor.basic(
                                          controller: _quillController,
                                          focusNode: _quillFocusNode,
                                          scrollController:
                                              _quillScrollController,
                                          config: QuillEditorConfig(
                                            expands: true,
                                            padding: const EdgeInsets.all(12),
                                            placeholder: t(
                                              currentLocale.value,
                                              'notes_hint_flat',
                                            ),
                                            onLaunchUrl:
                                                _launchUrlFromQuillEditor,
                                            customStyles:
                                                DefaultStyles.getInstance(
                                                  context,
                                                ),
                                            keyboardAppearance:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Brightness.dark
                                                : Brightness.light,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                children: [
                                  ...List.generate(
                                    _checklistControllers.length,
                                    (i) {
                                      final scheme = Theme.of(
                                        context,
                                      ).colorScheme;
                                      final rowDone =
                                          i < _checklistDone.length &&
                                          _checklistDone[i];
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                        horizontalTitleGap: 4,
                                        leading: Checkbox(
                                          value: rowDone,
                                          onChanged: (v) => setState(() {
                                            _syncChecklistDoneLength(
                                              _checklistControllers,
                                              _checklistDone,
                                            );
                                            _checklistDone[i] = v ?? false;
                                            _partitionChecklistRowsByDone(
                                              controllers:
                                                  _checklistControllers,
                                              done: _checklistDone,
                                            );
                                          }),
                                        ),
                                        title: TextField(
                                          controller: _checklistControllers[i],
                                          style: TextStyle(
                                            decoration: rowDone
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            color: rowDone
                                                ? scheme.onSurface.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : scheme.onSurface,
                                            decorationColor: rowDone
                                                ? scheme.onSurface.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: t(
                                              currentLocale.value,
                                              'checklist_item',
                                            ),
                                            hintStyle: TextStyle(
                                              color: scheme.onSurfaceVariant
                                                  .withValues(
                                                    alpha: rowDone ? 0.35 : 0.5,
                                                  ),
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            filled: true,
                                            fillColor: scheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.35),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: scheme.error,
                                          ),
                                          tooltip: t(
                                            currentLocale.value,
                                            'delete',
                                          ),
                                          onPressed: () => setState(() {
                                            _removeChecklistRowAt(
                                              i,
                                              controllers:
                                                  _checklistControllers,
                                              done: _checklistDone,
                                            );
                                          }),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    title: Text(
                                      t(
                                        currentLocale.value,
                                        'add_checklist_item',
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () => setState(() {
                                      _checklistControllers.add(
                                        TextEditingController(),
                                      );
                                      _checklistDone.add(false);
                                    }),
                                  ),
                                ],
                              ),
                              ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  24,
                                ),
                                children: [
                                  DropdownButtonFormField<int?>(
                                    initialValue: _reminderMinutes,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: t(
                                        currentLocale.value,
                                        'plan_reminder_label',
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_none',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 5,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_5m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 15,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_15m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 30,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_30m',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<int?>(
                                        value: 60,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_reminder_1h',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _reminderMinutes = v),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<_PlanRepeatUi>(
                                    initialValue: _repeatUi,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: t(
                                        currentLocale.value,
                                        'plan_repeat_label',
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.none,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_none',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.daily,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_daily',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.weekdays,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_weekdays',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.weekly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_weekly',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.monthly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_monthly',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: _PlanRepeatUi.yearly,
                                        child: Text(
                                          t(
                                            currentLocale.value,
                                            'plan_repeat_yearly',
                                          ),
                                        ),
                                      ),
                                      if (_repeatUi == _PlanRepeatUi.custom)
                                        DropdownMenuItem(
                                          value: _PlanRepeatUi.custom,
                                          child: Text(
                                            t(
                                              currentLocale.value,
                                              'plan_repeat_custom',
                                            ),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _repeatUi = v;
                                        if (v != _PlanRepeatUi.custom) {
                                          _rruleCustomRaw = null;
                                          _rruleCustomController.clear();
                                        } else {
                                          _rruleCustomRaw = widget.task.rrule
                                              ?.trim();
                                          _rruleCustomController.text =
                                              _rruleCustomRaw ?? '';
                                        }
                                      });
                                    },
                                  ),
                                  if (_repeatUi == _PlanRepeatUi.custom) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _rruleCustomController,
                                      minLines: 2,
                                      maxLines: 5,
                                      decoration: InputDecoration(
                                        labelText: t(
                                          currentLocale.value,
                                          'plan_repeat_custom',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              _BacklogSubItemsPanel(
                                parentTask: widget.task,
                                categoryId: _categoryId,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_shouldShowGraduateUi)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      keyboardOpen ? 4 : 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t(currentLocale.value, 'plan_graduate_warning'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kPlanningEditActionBarPadH,
                    keyboardOpen
                        ? kPlanningEditActionBarPadVKeyboard
                        : kPlanningEditActionBarPadV,
                    kPlanningEditActionBarPadH,
                    keyboardOpen
                        ? kPlanningEditActionBarBottomPadKeyboard
                        : kPlanningEditActionBarBottomPad,
                  ),
                  child: Row(
                    children: [
                      if (widget.onDelete != null)
                        TextButton(
                          onPressed: () {
                            widget.onDelete!(widget.task);
                            Navigator.of(context).pop<PlanningTask?>(null);
                          },
                          child: Text(
                            t(currentLocale.value, 'delete'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop<PlanningTask?>(null),
                        child: Text(t(currentLocale.value, 'cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _commitSave,
                        child: Text(
                          t(
                            currentLocale.value,
                            _shouldShowGraduateUi
                                ? 'plan_graduate_from_idea'
                                : 'save',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRecordSheetContent extends StatefulWidget {
  const _TimelineRecordSheetContent({
    required this.record,
    required this.scrollController,
    required this.onSaved,
    required this.onDelete,
    required this.onStop,
  });

  final TimelineRecord record;
  final ScrollController scrollController;
  final void Function(dynamic updated) onSaved;
  final VoidCallback onDelete;
  final VoidCallback onStop;

  @override
  State<_TimelineRecordSheetContent> createState() =>
      _TimelineRecordSheetContentState();
}

class _TimelineRecordSheetContentState
    extends State<_TimelineRecordSheetContent>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late QuillController _recordQuillController;
  late FocusNode _recordQuillFocus;
  late ScrollController _recordQuillScroll;
  int? _categoryId;
  DateTime? _startDisplay;
  DateTime? _endDisplay;
  final List<TextEditingController> _checklistControllers = [];
  final List<bool> _checklistDone = [];
  late TabController _tabController;

  /// PocketBase **plans** row id; empty = no link.
  late String _sourcePlanPbId;
  List<PlanningTask> _plansForLink = [];
  bool _plansLoading = true;

  List<Map<String, dynamic>> _checklistForApi() {
    _syncChecklistDoneLength(_checklistControllers, _checklistDone);
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _checklistControllers.length; i++) {
      final text = _checklistControllers[i].text.trim();
      if (text.isEmpty) continue;
      out.add(<String, dynamic>{
        'text': text,
        'isDone': i < _checklistDone.length ? _checklistDone[i] : false,
      });
    }
    return out;
  }

  void _applyFuzzyCategoryFromRecordTitle(String title) {
    final fuzzy = DatabaseService.instance.findCategoryByFuzzyMatch(title);
    if (fuzzy != null && fuzzy.id != _categoryId && mounted) {
      setState(() => _categoryId = fuzzy.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController(text: widget.record.title);
    _recordQuillController = QuillController(
      document: _documentForRecordPlain(widget.record.note),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _recordQuillFocus = FocusNode();
    _recordQuillScroll = ScrollController();
    _categoryId = widget.record.categoryId;
    _startDisplay = widget.record.startTime != null
        ? utcToDisplay(widget.record.startTime!)
        : null;
    _endDisplay = widget.record.endTime != null
        ? utcToDisplay(widget.record.endTime!)
        : null;
    for (final item in widget.record.checklist ?? []) {
      _checklistControllers.add(
        TextEditingController(text: (item['text'] ?? '').toString()),
      );
      _checklistDone.add(item['isDone'] == true);
    }
    if (_checklistControllers.isEmpty) {
      _checklistControllers.add(TextEditingController());
      _checklistDone.add(false);
    }
    _partitionChecklistRowsByDone(
      controllers: _checklistControllers,
      done: _checklistDone,
    );
    _sourcePlanPbId =
        DatabaseService.pocketRelationIdOrNull(widget.record.sourcePlanId) ??
        '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPlansForLink());
    });
  }

  /// Same wall-calendar day as [DatabaseService._profileWallFromUtc] / planning fetch —
  /// never [DateTime.toLocal] on raw UTC (that shifted links to the wrong day vs profile).
  DateTime _wallDayForRecord() {
    if (_startDisplay != null) {
      final d = _startDisplay!;
      return DateTime(d.year, d.month, d.day);
    }
    final st = widget.record.startTime;
    if (st != null) {
      final wall = utcToDisplay(st);
      return DateTime(wall.year, wall.month, wall.day);
    }
    final dk = widget.record.dateKey;
    if (dk.length >= 10) {
      final y = int.tryParse(dk.substring(0, 4));
      final m = int.tryParse(dk.substring(5, 7));
      final d = int.tryParse(dk.substring(8, 10));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    final now = displayNow();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadPlansForLink() async {
    if (mounted) setState(() => _plansLoading = true);
    final list = await DatabaseService.instance.getPlanningTasksForWallDate(
      _wallDayForRecord(),
    );
    if (!mounted) return;
    setState(() {
      _plansForLink = list;
      _plansLoading = false;
    });
  }

  Future<void> _showPlanLinkPickerSheet(
    BuildContext context, {
    required List<MapEntry<String, String>> options,
    required String selectedKey,
  }) async {
    final loc = currentLocale.value;
    final theme = Theme.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetCtx).bottom;
        final h = (MediaQuery.sizeOf(sheetCtx).height * 0.55).clamp(
          240.0,
          520.0,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: SizedBox(
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    t(loc, 'record_link_plan_label'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      bottom: 16,
                    ),
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final o = options[i];
                      return ListTile(
                        title: Text(
                          o.value,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: o.key == selectedKey,
                        onTap: () => Navigator.of(sheetCtx).pop(o.key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _sourcePlanPbId = picked);
    }
  }

  /// Full-screen-width tap target; list opens in a sheet with a real [ListView] (always scrolls).
  Widget _buildPlanLinkDropdown(BuildContext context) {
    final loc = currentLocale.value;
    final options = <MapEntry<String, String>>[
      MapEntry('', t(loc, 'record_no_plan_link')),
    ];
    final seen = <String>{''};
    for (final p in _plansForLink) {
      final pid = DatabaseService.pocketRelationIdOrNull(p.pocketRecordId);
      if (pid == null || seen.contains(pid)) continue;
      seen.add(pid);
      options.add(MapEntry(pid, p.title));
    }
    var value = _sourcePlanPbId;
    if (value.isNotEmpty &&
        !seen.contains(value) &&
        DatabaseService.pocketRelationIdOrNull(value) != null) {
      final v = DatabaseService.pocketRelationIdOrNull(value)!;
      options.insert(1, MapEntry(v, '—'));
      seen.add(v);
      value = v;
    }
    if (value.isNotEmpty && !seen.contains(value)) {
      value = '';
    }
    final desired = value.isEmpty ? '' : value;
    final initial = options.any((e) => e.key == desired) ? desired : '';
    var displayLabel = t(loc, 'record_no_plan_link');
    for (final o in options) {
      if (o.key == initial) {
        displayLabel = o.value;
        break;
      }
    }
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        labelText: t(loc, 'record_link_plan_label'),
        helperText: _plansLoading ? t(loc, 'record_link_plan_loading') : null,
        suffixIcon: Icon(
          Icons.arrow_drop_down_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: InkWell(
        onTap: _plansLoading
            ? null
            : () => unawaited(
                _showPlanLinkPickerSheet(
                  context,
                  options: options,
                  selectedKey: initial,
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({bool sync, bool clear, String? id}) _sourcePlanPatchArgs() {
    final initial =
        DatabaseService.pocketRelationIdOrNull(widget.record.sourcePlanId) ??
        '';
    final sel = _sourcePlanPbId.isEmpty
        ? ''
        : (DatabaseService.pocketRelationIdOrNull(_sourcePlanPbId) ?? '');
    if (initial == sel) {
      return (sync: false, clear: false, id: null);
    }
    if (sel.isEmpty) {
      return (sync: true, clear: true, id: null);
    }
    return (sync: true, clear: false, id: sel);
  }

  Document _documentForRecordPlain(String? plain) {
    final b = plain?.trim() ?? '';
    if (b.isEmpty) return Document();
    return Document.fromJson([
      <String, dynamic>{'insert': '$b\n'},
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _recordQuillController.dispose();
    _recordQuillFocus.dispose();
    _recordQuillScroll.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final initial = _startDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) {
      setState(() => _startDisplay = picked);
      unawaited(_loadPlansForLink());
    }
  }

  Future<void> _pickEnd() async {
    final initial = _endDisplay ?? displayNow();
    final picked = await showAppDateTimePicker(context, initial: initial);
    if (picked != null && mounted) setState(() => _endDisplay = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final noteText = _recordQuillController.document
        .toPlainText()
        .replaceAll('\u200b', '')
        .trim();
    final checklistPayload = _checklistForApi();
    final isRunning = widget.record.endTime == null;
    final isCreate = widget.record.id.isEmpty;
    final planPatch = _sourcePlanPatchArgs();

    // CREATE path (past-date "New Record" entry): no existing row id.
    // Single shared edit sheet — no separate EditRecordSheet for past dates.
    if (isCreate) {
      if (_startDisplay == null || _endDisplay == null) return;
      final startUtc = displayToUtc(_startDisplay!);
      final endUtc = displayToUtc(_endDisplay!);
      if (endUtc.isBefore(startUtc) || endUtc.isAtSameMomentAs(startUtc)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t(currentLocale.value, 'end_time_after_start')),
            ),
          );
        }
        return;
      }
      final overlap = await DatabaseService.instance
          .checkOverlapWithExistingRecords(startUtc, endUtc);
      if (overlap && mounted) {
        final conflict = await DatabaseService.instance
            .findFirstOverlappingRecord(startUtc, endUtc);
        if (!mounted) return;
        final loc = currentLocale.value;
        final rawTitle = (conflict?['title'] ?? '').toString().trim();
        final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
        final msg = t(
          loc,
          'time_conflict_with_title',
        ).replaceFirst('%s', otherLabel);
        final sm = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sm?.showSnackBar(SnackBar(content: Text(msg)));
        });
        return;
      }
      final ok = await DatabaseService.instance.writeCompletedRecord(
        title,
        startUtc,
        endUtc,
        categoryId: _categoryId,
      );
      if (!mounted) return;
      if (ok) {
        AppSnack.saved();
        widget.onSaved(null);
      } else {
        AppSnack.failed();
      }
      return;
    }

    if (isRunning) {
      final startUtc = _startDisplay != null
          ? displayToUtc(_startDisplay!)
          : null;
      DatabaseService.instance.applyOptimisticRecordRowEdit(
        recordId: widget.record.id,
        title: title,
        startTime: startUtc,
        categoryId: _categoryId,
        note: noteText,
        checklist: checklistPayload,
        syncSourcePlan: planPatch.sync,
        clearSourcePlan: planPatch.clear,
        sourcePlanPocketRecordId: planPatch.id,
      );
      final optimistic = widget.record.copyWith(
        title: title,
        startTime: startUtc,
        categoryId: _categoryId,
        note: noteText.isEmpty ? null : noteText,
        checklist: checklistPayload.isEmpty ? null : checklistPayload,
        sourcePlanId: planPatch.sync
            ? (planPatch.clear ? null : planPatch.id)
            : widget.record.sourcePlanId,
      );
      AppSnack.saved();
      widget.onSaved(optimistic);
      unawaited(
        DatabaseService.instance
            .updateRecord(
              recordId: widget.record.id,
              title: title,
              startTime: startUtc,
              categoryId: _categoryId,
              note: noteText,
              checklist: checklistPayload,
              syncSourcePlan: planPatch.sync,
              clearSourcePlan: planPatch.clear,
              sourcePlanPocketRecordId: planPatch.id,
            )
            .then((TimelineRecord? server) {
              if (!mounted) return;
              if (server == null) {
                AppSnack.failed();
              }
            }),
      );
      return;
    }

    if (_startDisplay == null || _endDisplay == null) return;
    final startUtc = displayToUtc(_startDisplay!);
    final endUtc = displayToUtc(_endDisplay!);
    if (endUtc.isBefore(startUtc) || endUtc.isAtSameMomentAs(startUtc)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(currentLocale.value, 'end_time_after_start')),
          ),
        );
      }
      return;
    }
    final overlap = await DatabaseService.instance
        .checkOverlapWithExistingRecords(
          startUtc,
          endUtc,
          excludeRecordId: widget.record.id.isNotEmpty
              ? widget.record.id
              : null,
        );
    if (overlap && mounted) {
      final conflict = await DatabaseService.instance
          .findFirstOverlappingRecord(
            startUtc,
            endUtc,
            excludeRecordId: widget.record.id.isNotEmpty
                ? widget.record.id
                : null,
          );
      if (!mounted) return;
      final loc = currentLocale.value;
      final rawTitle = (conflict?['title'] ?? '').toString().trim();
      final otherLabel = rawTitle.isNotEmpty ? rawTitle : t(loc, 'untitled');
      final msg = t(
        loc,
        'time_conflict_with_title',
      ).replaceFirst('%s', otherLabel);
      final sm = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sm?.showSnackBar(SnackBar(content: Text(msg)));
      });
      return;
    }
    final planPatchStopped = _sourcePlanPatchArgs();
    DatabaseService.instance.applyOptimisticRecordRowEdit(
      recordId: widget.record.id,
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: _categoryId,
      note: noteText,
      checklist: checklistPayload,
      syncSourcePlan: planPatchStopped.sync,
      clearSourcePlan: planPatchStopped.clear,
      sourcePlanPocketRecordId: planPatchStopped.id,
    );
    final optimisticStopped = widget.record.copyWith(
      title: title,
      startTime: startUtc,
      endTime: endUtc,
      categoryId: _categoryId,
      note: noteText.isEmpty ? null : noteText,
      checklist: checklistPayload.isEmpty ? null : checklistPayload,
      sourcePlanId: planPatchStopped.sync
          ? (planPatchStopped.clear ? null : planPatchStopped.id)
          : widget.record.sourcePlanId,
    );
    AppSnack.saved();
    widget.onSaved(optimisticStopped);
    unawaited(
      DatabaseService.instance
          .updateRecord(
            recordId: widget.record.id,
            title: title,
            startTime: startUtc,
            endTime: endUtc,
            categoryId: _categoryId,
            note: noteText,
            checklist: checklistPayload,
            syncSourcePlan: planPatchStopped.sync,
            clearSourcePlan: planPatchStopped.clear,
            sourcePlanPocketRecordId: planPatchStopped.id,
          )
          .then((TimelineRecord? server) {
            if (!mounted) return;
            if (server == null) {
              AppSnack.failed();
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairs = DatabaseService.instance.allCategoryIdPathPairs;
    final isRunning = widget.record.endTime == null;
    final int catVal;
    if (_categoryId != null && pairs.any((p) => p.id == _categoryId)) {
      catVal = _categoryId!;
    } else if (pairs.isNotEmpty) {
      catVal = pairs.first.id;
    } else {
      catVal = CategoryRule.uncategorizedSyntheticId;
    }

    Widget startEndCaption(bool isEnd) {
      if (isEnd && isRunning) {
        return Text(
          t(currentLocale.value, 'running_label'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      }
      final dt = isEnd ? _endDisplay : _startDisplay;
      if (dt == null) return const Text('–');
      return Text(
        '${formatDate(dt)} ${formatTimeOfDay(dt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Material(
      clipBehavior: Clip.none,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t(currentLocale.value, 'edit_record'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: t(currentLocale.value, 'title_label'),
                              hintText: t(
                                currentLocale.value,
                                'hint_record_example',
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: _applyFuzzyCategoryFromRecordTitle,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CategoryTreeFormField(
                              value: catVal,
                              enabled: pairs.isNotEmpty,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: t(
                                  currentLocale.value,
                                  'category_label',
                                ),
                              ),
                              onChanged: pairs.isEmpty
                                  ? (_) {}
                                  : (id) => setState(
                                      () => _categoryId = id ?? catVal,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPlanLinkDropdown(context),
                          ),
                          if (_plansLoading)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickStart,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          t(currentLocale.value, 'start_time'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    DefaultTextStyle.merge(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall!,
                                      child: startEndCaption(false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isRunning ? null : _pickEnd,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.event_available_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          t(currentLocale.value, 'end_time'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    DefaultTextStyle.merge(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall!,
                                      child: startEndCaption(true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: kAppCompactControlHeight,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: EdgeInsets.zero,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: [
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'notes_tab'),
                      ),
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'checklist_tab'),
                      ),
                      AppCompactTextTab(
                        text: t(currentLocale.value, 'parallel_activities_tab'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: kPlanningEditQuillToolbarMinHeight,
                              ),
                              child: QuillSimpleToolbar(
                                controller: _recordQuillController,
                                config: _planningTaskEditQuillToolbarConfig(
                                  context,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: QuillEditor.basic(
                                  controller: _recordQuillController,
                                  focusNode: _recordQuillFocus,
                                  scrollController: _recordQuillScroll,
                                  config: QuillEditorConfig(
                                    expands: true,
                                    padding: const EdgeInsets.all(12),
                                    placeholder: t(
                                      currentLocale.value,
                                      'notes_hint_flat',
                                    ),
                                    onLaunchUrl: _launchUrlFromQuillEditor,
                                    customStyles: DefaultStyles.getInstance(
                                      context,
                                    ),
                                    keyboardAppearance:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Brightness.dark
                                        : Brightness.light,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          ...List.generate(_checklistControllers.length, (i) {
                            final scheme = Theme.of(context).colorScheme;
                            final rowDone =
                                i < _checklistDone.length && _checklistDone[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              horizontalTitleGap: 4,
                              leading: Checkbox(
                                value: rowDone,
                                onChanged: (v) => setState(() {
                                  _syncChecklistDoneLength(
                                    _checklistControllers,
                                    _checklistDone,
                                  );
                                  _checklistDone[i] = v ?? false;
                                  _partitionChecklistRowsByDone(
                                    controllers: _checklistControllers,
                                    done: _checklistDone,
                                  );
                                }),
                              ),
                              title: TextField(
                                controller: _checklistControllers[i],
                                style: TextStyle(
                                  decoration: rowDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: rowDone
                                      ? scheme.onSurface.withValues(alpha: 0.5)
                                      : scheme.onSurface,
                                  decorationColor: rowDone
                                      ? scheme.onSurface.withValues(alpha: 0.5)
                                      : null,
                                ),
                                decoration: InputDecoration(
                                  hintText: t(
                                    currentLocale.value,
                                    'checklist_item',
                                  ),
                                  hintStyle: TextStyle(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: rowDone ? 0.35 : 0.5,
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  filled: true,
                                  fillColor: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: scheme.error,
                                ),
                                tooltip: t(currentLocale.value, 'delete'),
                                onPressed: () => setState(() {
                                  _removeChecklistRowAt(
                                    i,
                                    controllers: _checklistControllers,
                                    done: _checklistDone,
                                  );
                                }),
                              ),
                            );
                          }),
                          ListTile(
                            leading: Icon(
                              Icons.add_circle_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              t(currentLocale.value, 'add_checklist_item'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => setState(() {
                              _checklistControllers.add(
                                TextEditingController(),
                              );
                              _checklistDone.add(false);
                            }),
                          ),
                        ],
                      ),
                      _ParallelActivitiesTab(
                        parentRecord: widget.record,
                        scrollController: widget.scrollController,
                        categoryId: catVal,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (isRunning)
                        TextButton.icon(
                          onPressed: widget.onStop,
                          icon: const Icon(Icons.stop_rounded),
                          label: Text(t(currentLocale.value, 'stop')),
                        ),
                      TextButton(
                        onPressed: widget.onDelete,
                        child: Text(
                          t(currentLocale.value, 'delete'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _save,
                        child: Text(t(currentLocale.value, 'save')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Child backlog plans linked via [PlanningTask.parentPlanPocketId] (lists sub-items).
class _BacklogSubItemsPanel extends StatefulWidget {
  const _BacklogSubItemsPanel({
    required this.parentTask,
    required this.categoryId,
  });

  final PlanningTask parentTask;
  final int categoryId;

  @override
  State<_BacklogSubItemsPanel> createState() => _BacklogSubItemsPanelState();
}

class _BacklogSubItemsPanelState extends State<_BacklogSubItemsPanel> {
  final TextEditingController _newTitleController = TextEditingController();
  StreamSubscription<void>? _planRefreshSub;

  @override
  void initState() {
    super.initState();
    _planRefreshSub = DatabaseService.instance.planningRefreshNotifications
        .listen((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _planRefreshSub?.cancel();
    _newTitleController.dispose();
    super.dispose();
  }

  bool get _parentPersisted {
    final id = widget.parentTask.planRowIdForBackend.trim();
    return id.isNotEmpty && !id.startsWith('optimistic-');
  }

  List<PlanningTask> get _children {
    if (!_parentPersisted) return const [];
    return DatabaseService.instance.backlogChildPlansForParent(
      widget.parentTask.planRowIdForBackend.trim(),
    );
  }

  Future<void> _addSubItem() async {
    final title = _newTitleController.text.trim();
    if (title.isEmpty) return;
    if (!_parentPersisted) {
      AppSnack.show(
        t(currentLocale.value, 'lists_subitems_save_parent_first'),
        error: true,
      );
      return;
    }
    final ok = await DatabaseService.instance.addBacklogChildPlan(
      parentPocketPlanId: widget.parentTask.planRowIdForBackend.trim(),
      title: title,
      categoryId: widget.categoryId,
    );
    if (!mounted) return;
    if (ok) {
      _newTitleController.clear();
      setState(() {});
    } else {
      AppSnack.failed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final scheme = Theme.of(context).colorScheme;
    final children = _children;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!_parentPersisted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              t(loc, 'lists_subitems_save_parent_first'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _newTitleController,
                enabled: _parentPersisted,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t(loc, 'lists_subitems_add_hint'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => unawaited(_addSubItem()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _parentPersisted
                  ? () => unawaited(_addSubItem())
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(t(loc, 'add')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Text(
            '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          for (final child in children)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: child.isDone,
                onChanged: child.planRowIdForBackend.startsWith('optimistic-')
                    ? null
                    : (v) {
                        if (v == null) return;
                        final db = DatabaseService.instance;
                        db.applyOptimisticPlanningTask(
                          child.copyWith(isDone: v),
                        );
                        db.notifyPlanningRefresh(scheduleNetworkRefresh: false);
                        setState(() {});
                        unawaited(
                          db.updatePlanningTask(
                            child.planRowIdForBackend,
                            planBusinessId: child.planRowId,
                            isDone: v,
                            suppressAppSnack: true,
                          ),
                        );
                      },
              ),
              title: Text(
                child.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: child.isDone
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
      ],
    );
  }
}

/// Parallel sub-records for an open record sheet: add / list / stop / edit (@DATA_MAP.md parent_id).
class _ParallelActivitiesTab extends StatefulWidget {
  const _ParallelActivitiesTab({
    required this.parentRecord,
    required this.scrollController,
    required this.categoryId,
  });

  final TimelineRecord parentRecord;
  final ScrollController scrollController;
  final int? categoryId;

  @override
  State<_ParallelActivitiesTab> createState() => _ParallelActivitiesTabState();
}

class _ParallelActivitiesTabState extends State<_ParallelActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _newTitleController;

  /// Parent link key for which [_runningChildrenStream] / [_completedChildrenStream] were built.
  /// [runningChildrenStream] / [completedChildrenStream] return new streams per call — must not
  /// pass a freshly created stream from [build] each rebuild.
  String? _childStreamsLink;
  late Stream<List<TimelineRecord>> _runningChildrenStream;
  late Stream<List<TimelineRecord>> _completedChildrenStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _newTitleController = TextEditingController();
  }

  void _ensureChildStreams(String link) {
    if (_childStreamsLink == link) return;
    _childStreamsLink = link;
    _runningChildrenStream = DatabaseService.instance.runningChildrenStream(
      link,
    );
    _completedChildrenStream = DatabaseService.instance.completedChildrenStream(
      link,
    );
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    super.dispose();
  }

  String _parentWallDateKey() {
    final st = widget.parentRecord.startTime;
    if (st != null) {
      final wall = utcToDisplay(st);
      return formatDate(wall);
    }
    return formatDate(displayNow());
  }

  Future<void> _addParallel() async {
    final title = _newTitleController.text.trim();
    if (title.isEmpty) return;
    final link = DatabaseService.instance.resolveParentLinkForChildren(
      widget.parentRecord.id,
    );
    if (link.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(currentLocale.value, 'parallel_activities_info')),
          ),
        );
      }
      return;
    }
    try {
      final id = await DatabaseService.instance.writeRecord(
        _parentWallDateKey(),
        title,
        categoryId: widget.categoryId ?? widget.parentRecord.categoryId,
        explicitStartTime: DatabaseService.getPlanetaryNow(),
        parentRecordId: link,
      );
      if (!mounted) return;
      if (id != null) {
        _newTitleController.clear();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stopChild(TimelineRecord child) async {
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(child.id);
      if (!mounted) return;
      if (!ok) {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=${child.id})',
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  void _openChildEditor(TimelineRecord child) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return _ChildParallelEditBar(
          child: child,
          onSaved: () {
            Navigator.pop(ctx);
            setState(() {});
          },
        );
      },
    );
  }

  Widget _childTile(
    BuildContext context,
    TimelineRecord c, {
    required bool running,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        running
            ? (c.startTime != null
                  ? '${formatDate(utcToDisplay(c.startTime!))} ${formatTimeOfDay(utcToDisplay(c.startTime!))}'
                  : '—')
            : (c.startTime != null && c.endTime != null
                  ? '${formatDate(utcToDisplay(c.startTime!))} ${formatTimeOfDay(utcToDisplay(c.startTime!))} — ${formatTimeOfDay(utcToDisplay(c.endTime!))}'
                  : '—'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (running)
            IconButton(
              icon: const Icon(Icons.stop_rounded),
              onPressed: () => _stopChild(c),
              tooltip: t(currentLocale.value, 'stop'),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _openChildEditor(c),
            tooltip: t(currentLocale.value, 'edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.parentRecord.id.isEmpty) {
      return ListView(
        primary: false,
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            t(currentLocale.value, 'parallel_activities_info'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }
    final link = DatabaseService.instance.resolveParentLinkForChildren(
      widget.parentRecord.id,
    );
    _ensureChildStreams(link);
    return ListView(
      primary: false,
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          controller: _newTitleController,
          decoration: InputDecoration(
            labelText: t(currentLocale.value, 'title_label'),
            hintText: t(currentLocale.value, 'hint_record_example'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _addParallel,
          icon: const Icon(Icons.add_rounded),
          label: Text(t(currentLocale.value, 'parallel_add_activity')),
        ),
        const SizedBox(height: 16),
        Text(
          t(currentLocale.value, 'child_records_running'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<List<TimelineRecord>>(
          stream: _runningChildrenStream,
          builder: (context, snap) {
            final list = snap.data ?? const <TimelineRecord>[];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  t(currentLocale.value, 'no_parallel_activities'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: list
                  .map((c) => _childTile(context, c, running: true))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          t(currentLocale.value, 'child_records_completed'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        StreamBuilder<List<TimelineRecord>>(
          stream: _completedChildrenStream,
          builder: (context, snap) {
            final list = snap.data ?? const <TimelineRecord>[];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('—', style: Theme.of(context).textTheme.bodySmall),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: list
                  .map((c) => _childTile(context, c, running: false))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ChildParallelEditBar extends StatefulWidget {
  const _ChildParallelEditBar({required this.child, required this.onSaved});

  final TimelineRecord child;
  final VoidCallback onSaved;

  @override
  State<_ChildParallelEditBar> createState() => _ChildParallelEditBarState();
}

class _ChildParallelEditBarState extends State<_ChildParallelEditBar> {
  late final TextEditingController _title;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.child.title);
    _note = TextEditingController(text: widget.child.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    try {
      final u = await DatabaseService.instance.updateRecord(
        recordId: widget.child.id,
        title: title,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      if (u != null) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLocale.value, 'plan_save_failed'))),
        );
      }
    }
  }

  Future<void> _stop() async {
    try {
      final ok = await DatabaseService.instance.stopRecordByDocId(
        widget.child.id,
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved();
      } else {
        debugPrint(
          'UI ERROR: stopRecordByDocId returned false (systemRowId=${widget.child.id})',
        );
      }
    } catch (e) {
      debugPrint('UI ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.child.endTime == null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: t(currentLocale.value, 'title_label'),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: t(currentLocale.value, 'notes_label'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (running)
                TextButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(t(currentLocale.value, 'stop')),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: Text(t(currentLocale.value, 'save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
