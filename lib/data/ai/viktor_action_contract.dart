/// Viktor's model-independent, *proposal-only* action contract.
///
/// This file intentionally contains no HTTP, PocketBase, Flutter, credentials,
/// subscription checks, or mutation execution. A model can suggest an action;
/// an authenticated application executor must validate ownership, freshness,
/// time rules, conflicts, tier, confirmation and idempotency before any write.
library;

class ViktorAction {
  ViktorAction._(this.name, Map<String, Object?> arguments)
      : arguments = Map<String, Object?>.unmodifiable(arguments);

  final String name;
  final Map<String, Object?> arguments;

  static const names = <String>{
    'list_day_plans',
    'create_plan',
    'update_plan_duration',
    'move_plan_after',
    'swap_plan_positions',
    'start_record',
    'stop_record',
  };

  bool get isMutation => name != 'list_day_plans';

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
    switch (name) {
      case 'list_day_plans':
        _onlyKeys(args, const {'wall_day'});
        _day(args, 'wall_day');
      case 'create_plan':
        _onlyKeys(args, const {
          'title', 'wall_day', 'duration_minutes', 'start_time',
        });
        _title(args, 'title');
        _day(args, 'wall_day');
        _duration(args, 'duration_minutes');
        _clock(args, 'start_time');
      case 'update_plan_duration':
        _onlyKeys(args, const {
          'plan_id', 'expected_duration_minutes', 'duration_minutes',
        });
        _id(args, 'plan_id');
        _duration(args, 'expected_duration_minutes');
        _duration(args, 'duration_minutes');
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
      case 'start_record':
        _onlyKeys(args, const {'title', 'category_id'});
        _title(args, 'title');
        if (args.containsKey('category_id')) _id(args, 'category_id');
      case 'stop_record':
        _onlyKeys(args, const {'record_id'});
        _recordId(args, 'record_id');
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

  /// Previews are mandatory for multi-step edits and operations which may
  /// cascade scheduling. The executor can still require additional approval.
  bool get requiresPreview => actions.where((a) => a.isMutation).length > 1 ||
      actions.any((a) => a.name == 'move_plan_after');

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
    for (final item in items) {
      if (item is! Map) {
        throw const FormatException('Each action must be an object');
      }
      parsed.add(ViktorAction.fromJson(Map<String, dynamic>.from(item)));
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
  if (args.keys.any((key) => key is! String || !allowed.contains(key))) {
    throw const FormatException('Unexpected Viktor action field');
  }
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
