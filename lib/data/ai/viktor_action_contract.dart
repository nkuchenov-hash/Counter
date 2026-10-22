/// Viktor's model-independent, *proposal-only* action contract.
///
/// This file intentionally contains no HTTP, PocketBase, Flutter, credentials,
/// subscription checks, or mutation execution. A model can suggest an action;
/// an authenticated application executor must validate ownership, freshness,
/// time rules, conflicts, tier, confirmation and idempotency before any write.
library;

import 'viktor_agent_capabilities.dart';

class ViktorAction {
  ViktorAction._(this.name, Map<String, Object?> arguments)
      : arguments = Map<String, Object?>.unmodifiable(arguments);

  final String name;
  final Map<String, Object?> arguments;

  static final Set<String> names = ViktorAgentCapabilities.names;

  bool get isMutation =>
      ViktorAgentCapabilities.byName[name]?.requiresApproval ?? true;

  factory ViktorAction.fromJson(Map<String, dynamic> raw) {
    _onlyKeys(raw, const {'name', 'arguments'});
    final name = raw['name'];
    if (name is! String || !names.contains(name)) {
      throw const FormatException('Unknown Viktor action');
    }
    final rawArgs = raw['arguments'];
    if (rawArgs is! Map) {
      throw const FormatException('Action arguments must be an object');
    }
    final args = <String, Object?>{};
    for (final entry in rawArgs.entries) {
      if (entry.key is! String) {
        throw const FormatException('Argument keys must be strings');
      }
      args[entry.key as String] = entry.value;
    }
    try {
      switch (name) {
      case 'list_day_plans':
        _onlyKeys(args, const {'wall_day'});
        _day(args, 'wall_day');
      case 'create_plan':
        _onlyKeys(args, const {
          'title', 'wall_day', 'duration_minutes', 'start_time',
          'conflict_policy', 'timezone',
        });
        _title(args, 'title');
        _day(args, 'wall_day');
        _duration(args, 'duration_minutes');
        _clock(args, 'start_time');
        if (args.containsKey('timezone')) _text(args, 'timezone', maxLength: 64);
        if (args.containsKey('conflict_policy') &&
            !const {'reject', 'shift'}.contains(args['conflict_policy'])) {
          throw const FormatException('Unknown plan conflict policy');
        }
      case 'update_plan_duration':
        _onlyKeys(args, const {
          'plan_id', 'expected_duration_minutes', 'duration_minutes',
          'wall_day',
        });
        _id(args, 'plan_id');
        _duration(args, 'expected_duration_minutes');
        _duration(args, 'duration_minutes');
        if (args.containsKey('wall_day')) _day(args, 'wall_day');
      case 'move_plan_after':
        _onlyKeys(args, const {'plan_id', 'after_plan_id', 'wall_day'});
        final id = _id(args, 'plan_id');
        final afterId = _id(args, 'after_plan_id');
        if (id == afterId) {
          throw const FormatException('Cannot move an item after itself');
        }
        _day(args, 'wall_day');
      case 'swap_plan_positions':
        _onlyKeys(args, const {'first_plan_id', 'second_plan_id', 'wall_day'});
        final first = _id(args, 'first_plan_id');
        final second = _id(args, 'second_plan_id');
        if (first == second) {
          throw const FormatException('Cannot swap a plan with itself');
        }
        _day(args, 'wall_day');
      case 'bulk_replan':
        // A generic status-filtered schedule operation. The model describes
        // WHAT to change; the Brain resolves actual row IDs and previews all
        // resulting wall times before any write.
        _onlyKeys(args, const {'operations'});
        final raw = args['operations'];
        if (raw is! List || raw.isEmpty || raw.length > 8) {
          throw const FormatException('Expected 1–8 bulk planning operations');
        }
        final seen = <String>{};
        final canonicalOperations = <Map<String, Object?>>[];
        for (final item in raw) {
          if (item is! Map) {
            throw const FormatException('Invalid bulk planning operation');
          }
          final operation = Map<String, Object?>.from(item);
          _onlyKeys(operation, const {
            'kind', 'status', 'source_day', 'target_day',
            'start_time', 'timezone', 'category_name', 'tag_name',
            'title_contains', 'priority', 'max_count',
          });
          final kind = _text(operation, 'kind', maxLength: 16);
          if (!const {'move', 'compact'}.contains(kind)) {
            throw const FormatException('Invalid bulk operation kind');
          }
          // A model may use conventional completion labels instead of the
          // wire contract. Normalize only explicit, unambiguous synonyms;
          // never guess a status or change what an operation will select.
          final rawStatus = _text(operation, 'status', maxLength: 24)
              .toLowerCase().trim().replaceAll('-', '_')
              .replaceAll(' ', '_');
          final status = switch (rawStatus) {
            'complete' || 'completed' || 'done' || 'finished' ||
                'выполненные' => 'complete',
            'incomplete' || 'unfinished' || 'undone' ||
                'not_done' || 'not_completed' || 'невыполненные' =>
              'incomplete',
            'all' || 'все' => 'all',
            _ => throw const FormatException(
              'Invalid bulk status filter: use complete/incomplete/all'),
          };
          operation['status'] = status;
          final source = _day(operation, 'source_day');
          final selector = '$source|$status|' +
              (operation['category_name'] ?? '').toString() + '|' +
              (operation['tag_name'] ?? '').toString() + '|' +
              (operation['title_contains'] ?? '').toString();
          if (!seen.add(selector)) {
            throw const FormatException('Overlapping bulk plan filters');
          }
          if (kind == 'move') {
            final target = _day(operation, 'target_day');
            if (source == target) {
              throw const FormatException('Move target must differ from source');
            }
            _bulkClock(operation, 'start_time');
          } else if (operation.containsKey('target_day')) {
            throw const FormatException('Compaction is always same-day');
          } else if (operation.containsKey('start_time')) {
            _bulkClock(operation, 'start_time');
          }
          if (operation.containsKey('timezone')) {
            _text(operation, 'timezone', maxLength: 64);
          }
          for (final field in const ['category_name', 'tag_name',
              'title_contains']) {
            if (operation.containsKey(field)) {
              _text(operation, field, maxLength: 160);
              if ((operation[field] as String).trim().isEmpty) {
                throw FormatException('Empty filter: $field');
              }
            }
          }
          if (operation.containsKey('priority')) {
            final n = operation['priority'];
            if (n is! int || n < 1 || n > 100) {
              throw const FormatException('Invalid bulk priority');
            }
          }
          if (operation.containsKey('max_count')) {
            final n = operation['max_count'];
            if (n is! int || n < 1 || n > 100) {
              throw const FormatException('Invalid bulk max_count');
            }
          }
          canonicalOperations.add(operation);
        }
        // All downstream preview/Brain paths receive one canonical form.
        args['operations'] = canonicalOperations;
      case 'search_notes':
      case 'search_record_notes':
        _onlyKeys(args, const {'query', 'year', 'month', 'limit'});
        if (args.containsKey('query')) {
          _text(args, 'query', maxLength: 160);
        }
        if (args.containsKey('year')) {
          final year = args['year'];
          if (year is! int || year < 1970 || year > 2100) {
            throw const FormatException('Invalid note search year');
          }
        }
        if (args.containsKey('month')) {
          final month = args['month'];
          if (!args.containsKey('year') ||
              month is! int || month < 1 || month > 12) {
            throw const FormatException('Invalid note search month');
          }
        }
        if (args.containsKey('limit')) {
          final limit = args['limit'];
          if (limit is! int || limit < 1 || limit > 30) {
            throw const FormatException('Invalid note search limit');
          }
        }
        if ((args['query'] as String? ?? '').trim().isEmpty &&
            !args.containsKey('year')) {
          throw const FormatException('Note search requires text or year');
        }
      case 'read_note':
        _onlyKeys(args, const {'note_id'});
        _id(args, 'note_id');
      case 'read_record_note':
        _onlyKeys(args, const {'record_id'});
        _id(args, 'record_id');
      case 'list_categories':
      case 'list_backlog_items':
      case 'list_notes':
      case 'list_paths':
      case 'get_settings':
        _onlyKeys(args, const {});
      case 'list_tags':
        _onlyKeys(args, const {'domain'});
        if (!const {'plan', 'list'}.contains(args['domain'])) {
          throw const FormatException('Tag domain must be plan or list');
        }
      case 'set_list_item_done':
        _onlyKeys(args, const {
          'item_id', 'expected_title', 'expected_is_done', 'is_done',
        });
        _id(args, 'item_id');
        _title(args, 'expected_title');
        if (args['expected_is_done'] is! bool || args['is_done'] is! bool ||
            args['expected_is_done'] == args['is_done']) {
          throw const FormatException('Invalid list item completion change');
        }
      case 'rename_list_item':
        _onlyKeys(args, const {'item_id', 'expected_title', 'title'});
        _id(args, 'item_id');
        _title(args, 'expected_title');
        _title(args, 'title');
      case 'create_tag':
        _onlyKeys(args, const {'name', 'domain'});
        _title(args, 'name');
        if (!const {'plan', 'list'}.contains(args['domain'])) {
          throw const FormatException('Tag domain must be plan or list');
        }
      case 'rename_tag':
        _onlyKeys(args, const {'tag_id', 'expected_name', 'name'});
        _id(args, 'tag_id');
        _title(args, 'expected_name');
        _title(args, 'name');
      case 'create_category':
        _onlyKeys(args, const {'name', 'parent_category_id'});
        _title(args, 'name');
        if (args.containsKey('parent_category_id')) {
          _id(args, 'parent_category_id');
        }
      case 'create_note':
        _onlyKeys(args, const {'title', 'text', 'category_id'});
        _title(args, 'title');
        _longText(args, 'text', maxLength: 8000);
        if (args.containsKey('category_id')) _id(args, 'category_id');
      case 'edit_note_line':
        _onlyKeys(args, const {
          'note_id', 'expected_title', 'line_number', 'expected_text', 'text',
        });
        _id(args, 'note_id');
        _title(args, 'expected_title');
        final lineNumber = args['line_number'];
        if (lineNumber is! int || lineNumber < 1 || lineNumber > 10000) {
          throw const FormatException('Invalid note line_number');
        }
        _longText(args, 'expected_text', maxLength: 2000);
        _longText(args, 'text', maxLength: 2000);
        if ((args['text'] as String).contains('\n')) {
          throw const FormatException('Line replacement must not add lines');
        }
      case 'edit_note':
        _onlyKeys(args, const {'note_id', 'expected_title', 'text'});
        _id(args, 'note_id');
        _title(args, 'expected_title');
        _longText(args, 'text', maxLength: 8000);
      case 'create_path':
        _onlyKeys(args, const {'name', 'category_id', 'goal', 'stages'});
        _title(args, 'name');
        _id(args, 'category_id');
        _text(args, 'goal', maxLength: 2000);
        final stages = args['stages'];
        if (stages is! List || stages.isEmpty || stages.length > 16) {
          throw const FormatException('Path needs 1–16 stages');
        }
        for (final raw in stages) {
          if (raw is! Map) throw const FormatException('Invalid Path stage');
          final stage = Map<String, Object?>.from(raw);
          _onlyKeys(stage, const {'title', 'criteria', 'actions'});
          _title(stage, 'title');
          _text(stage, 'criteria', maxLength: 1000);
          final actions = stage['actions'];
          if (actions is! List || actions.isEmpty || actions.length > 24) {
            throw const FormatException('Path stage needs 1–24 actions');
          }
          for (final one in actions) {
            if (one is! Map) {
              throw const FormatException('Invalid Path action');
            }
            final task = Map<String, Object?>.from(one);
            _onlyKeys(task, const {'text', 'result', 'minutes'});
            _title(task, 'text');
            _text(task, 'result', maxLength: 1000);
            final minutes = task['minutes'];
            if (minutes is! int || minutes < 10 || minutes > 480) {
              throw const FormatException('Invalid Path action minutes');
            }
          }
        }
      case 'change_setting':
        _onlyKeys(args, const {'field', 'value'});
        final field = _text(args, 'field', maxLength: 40);
        if (!const {
          'theme_mode', 'preferred_timezone', 'primary_language',
          'list_completion_behavior', 'display_name',
        }.contains(field)) {
          throw const FormatException('Setting cannot be changed by AI');
        }
        final value = _text(args, 'value', maxLength: 120);
        if (field == 'theme_mode' &&
            !const {'light', 'dark', 'system'}.contains(value)) {
          throw const FormatException('Invalid theme mode');
        }
        if (field == 'list_completion_behavior' &&
            !const {'stay', 'bottom', 'hide', 'archive'}.contains(value)) {
          throw const FormatException('Invalid list completion behavior');
        }
      case 'start_record':
        _onlyKeys(args, const {'title', 'category_id'});
        _title(args, 'title');
        if (args.containsKey('category_id')) _id(args, 'category_id');
      case 'stop_record':
        _onlyKeys(args, const {'record_id'});
        _recordId(args, 'record_id');
      }
    } on FormatException catch (error) {
      throw FormatException('Tool $name: ${error.message}');
    }
    return ViktorAction._(name, args);
  }

  Map<String, Object?> toJson() =>
      {'name': name, 'arguments': Map<String, Object?>.from(arguments)};
}

/// A batch is a user-intent proposal, never a transaction or an execution
/// receipt. requestId is mandatory so a future executor can deduplicate retries.
class ViktorActionBatch {
  ViktorActionBatch._(this.requestId, List<ViktorAction> actions)
      : actions = List<ViktorAction>.unmodifiable(actions);

  static const version = 1;
  final String requestId;
  final List<ViktorAction> actions;

  bool get hasMutations => actions.any((a) => a.isMutation);

  /// A single reversible change may be applied without an extra confirmation
  /// dialog, but only after the normal fresh-state preview and Brain validation.
  /// Consequential changes and mixed batches never qualify.
  bool get isSingleReversibleWrite =>
      actions.length == 1 &&
      !(actions.single.name == 'create_plan' &&
        actions.single.arguments['conflict_policy'] == 'shift') &&
      ViktorAgentCapabilities.byName[actions.single.name]?.risk ==
          ViktorToolRisk.reversible;

  /// Previews are mandatory for multi-step edits and operations which may
  /// cascade scheduling. The executor can still require additional approval.
  bool get requiresPreview =>
      actions.where((a) => a.isMutation).length > 1 ||
      actions.any((a) =>
          a.name == 'move_plan_after' || a.name == 'bulk_replan' ||
          (a.name == 'create_plan' &&
           a.arguments['conflict_policy'] == 'shift') ||
          (ViktorAgentCapabilities.byName[a.name]?.requiresApproval == true &&
           !const {
             'create_plan', 'update_plan_duration', 'swap_plan_positions',
             'start_record', 'stop_record',
           }.contains(a.name)));

  factory ViktorActionBatch.fromJson(Map<String, dynamic> raw) {
    _onlyKeys(raw, const {'version', 'request_id', 'actions'});
    if (raw['version'] != version) {
      throw const FormatException('Unsupported Viktor action version');
    }
    final id = raw['request_id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{8,96}$').hasMatch(id)) {
      throw const FormatException('Invalid request_id');
    }
    final items = raw['actions'];
    if (items is! List || items.isEmpty || items.length > 16) {
      throw const FormatException('Expected 1–16 actions');
    }
    final parsed = <ViktorAction>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) {
        throw FormatException('Action ${i + 1}: expected an object');
      }
      try {
        parsed.add(ViktorAction.fromJson(Map<String, dynamic>.from(item)));
      } on FormatException catch (error) {
        throw FormatException('Action ${i + 1}: ${error.message}');
      }
    }
    // Brain reloads both affected dates for bulk_replan. Same-day list
    // reads included in the same proposal are redundant, never mutations.
    final bulkActions =
        parsed.where((action) => action.name == 'bulk_replan').toList();
    if (bulkActions.length == 1 && parsed.length > 1) {
      final bulk = bulkActions.single;
      final dates = <String>{};
      for (final item in bulk.arguments['operations'] as List) {
        final operation = item as Map;
        dates.add(operation['source_day'] as String);
        if (operation['kind'] == 'move') {
          dates.add(operation['target_day'] as String);
        }
      }
      final extras = parsed.where((action) => action != bulk).toList();
      if (extras.every((action) => action.name == 'list_day_plans')) {
        // Reads of source/target are redundant: Brain reloads them for
        // preview/apply. Preserve unrelated reads that the user may have
        // explicitly requested, and let the executor display them safely.
        final independentReads = extras.where((action) =>
            !dates.contains(action.arguments['wall_day'])).toList();
        return ViktorActionBatch._(id, [...independentReads, bulk]);
      }
    }
    return ViktorActionBatch._(id, parsed);
  }

  Map<String, Object?> toJson() => {
        'version': version,
        'request_id': requestId,
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

void _onlyKeys(Map<dynamic, dynamic> args, Set<String> allowed) {
  final invalid = args.keys.where(
      (key) => key is! String || !allowed.contains(key)).toList();
  if (invalid.isEmpty) return;
  // Only field names are included in the repair hint, never argument values.
  String safeField(dynamic key) {
    if (key is String && key.length <= 48) {
      final match = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*').firstMatch(key);
      if (match != null && match.start == 0 && match.end == key.length) {
        return key;
      }
    }
    return '[invalid field name]';
  }
  final rejected = invalid.take(4).map(safeField).join(', ');
  final expected =
      allowed.isEmpty ? '(none)' : (allowed.toList()..sort()).join(', ');
  throw FormatException(
      'Unexpected Viktor action field(s): ' + rejected +
      '. Allowed fields: ' + expected);
}

String _text(Map<String, Object?> args, String key, {int maxLength = 160}) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty ||
      value.length > maxLength || value.contains(RegExp(r'[\x00-\x1F]'))) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String _title(Map<String, Object?> args, String key) =>
    _text(args, key, maxLength: 160);

String _id(Map<String, Object?> args, String key) {
  final value = _text(args, key, maxLength: 15);
  if (!RegExp(r'^[a-z0-9]{15}$').hasMatch(value)) {
    throw FormatException('Invalid PocketBase id: $key');
  }
  return value;
}

/// Timeline record IDs can be PocketBase row ids or stable business UUIDs.
String _recordId(Map<String, Object?> args, String key) {
  final value = _text(args, key, maxLength: 36);
  if (!RegExp(r'^[a-z0-9]{15}$').hasMatch(value) &&
      !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(value)) {
    throw FormatException('Invalid record id: $key');
  }
  return value;
}

int _duration(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! int || value < 10 || value > 1440) {
    throw FormatException('Invalid duration: $key');
  }
  return value;
}

String _day(Map<String, Object?> args, String key) {
  final value = _text(args, key, maxLength: 10);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Invalid wall day: $key');
  }
  final parts = value.split('-').map(int.parse).toList();
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parsed.year != parts[0] || parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    throw FormatException('Invalid calendar day: $key');
  }
  return value;
}

/// Normalize only unambiguous model clock variants. Never invent a missing
/// time or overwrite a conflicting timezone.
String _bulkClock(Map<String, Object?> operation, String key) {
  final raw = operation[key];
  if (raw is! String || raw.isEmpty || raw.length > 48) {
    throw FormatException('Invalid $key');
  }
  var text = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  // Normalize explicit clock notations only. Unclear times still fail.
  text = text.replaceFirst(RegExp(r'^в\s+'), '');
  text = text.replaceAll('a.m.', 'am').replaceAll('p.m.', 'pm');
  final ny = RegExp(
    r'\s*(?:\(?\s*(?:по\s+)?(?:ny|new york|нью[\s-]?йорку|нью[\s-]?йорк)\s*\)?)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (ny != null) {
    final specified = (operation['timezone'] as String?)?.trim();
    if (specified != null && specified.isNotEmpty &&
        !const {'NY', 'ny', 'New York', 'new york',
                'America/New_York'}.contains(specified)) {
      throw const FormatException('Conflicting bulk timezone');
    }
    operation['timezone'] = 'America/New_York';
    text = text.substring(0, ny.start).trim();
  }
  text = text.replaceFirst(RegExp(r'\s+(?:часов|часа|час)$'), '');
  final parsed = RegExp(
    r'^(\d{1,2})(?:(?::|\.)(\d{1,2}))?(?::00)?(?:\s*(am|pm|утра|вечера))?$',
  ).firstMatch(text);
  if (parsed == null) throw FormatException('Invalid $key');
  var hour = int.parse(parsed.group(1)!);
  final minute = int.parse(parsed.group(2) ?? '0');
  final suffix = parsed.group(3);
  if (minute > 59) throw FormatException('Invalid $key');
  if (suffix == 'am' || suffix == 'pm') {
    if (hour < 1 || hour > 12) throw FormatException('Invalid $key');
    hour = hour % 12 + (suffix == 'pm' ? 12 : 0);
  } else if (suffix == 'утра' || suffix == 'вечера') {
    if (hour < 1 || hour > 11) throw FormatException('Invalid $key');
    if (suffix == 'вечера') hour += 12;
  }
  if (hour > 23) throw FormatException('Invalid $key');
  final canonical = '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
  operation[key] = canonical;
  return _clock(operation, key);
}

String _clock(Map<String, Object?> args, String key) {
  final value = _text(args, key, maxLength: 5);
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
    throw FormatException('Invalid wall clock: $key');
  }
  final p = value.split(':').map(int.parse).toList();
  if (p[0] > 23 || p[1] > 59) {
    throw FormatException('Invalid wall clock: $key');
  }
  return value;
}

String _longText(Map<String, Object?> args, String key,
    {int maxLength = 8000}) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength ||
      value.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
    throw FormatException('Invalid $key');
  }
  return value;
}
