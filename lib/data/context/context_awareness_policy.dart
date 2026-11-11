import 'dart:convert';

/// Native Android emits discrete events, not a continuous GPS trail.
class ContextAwarenessEvent {
  const ContextAwarenessEvent({
    required this.id,
    required this.kind,
    required this.atUtc,
    this.mode = '',
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  final String id;
  final String kind;
  final DateTime atUtc;
  final String mode;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  factory ContextAwarenessEvent.fromJson(Map<String, dynamic> json) {
    final at = DateTime.parse(json['at'] as String).toUtc();
    return ContextAwarenessEvent(
      id: (json['id'] as String).trim(),
      kind: (json['kind'] as String).trim(),
      atUtc: at,
      mode: (json['mode'] as String? ?? '').trim(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
    );
  }

  static List<ContextAwarenessEvent> decode(String raw) {
    final parsed = jsonDecode(raw);
    if (parsed is! List) return const [];
    return [
      for (final item in parsed)
        if (item is Map<String, dynamic>)
          tryParse(item),
    ].whereType<ContextAwarenessEvent>().toList()
      ..sort((a, b) => a.atUtc.compareTo(b.atUtc));
  }

  static ContextAwarenessEvent? tryParse(Map<String, dynamic> item) {
    try {
      final event = ContextAwarenessEvent.fromJson(item);
      if (event.id.isEmpty || event.kind.isEmpty) return null;
      return event;
    } catch (_) {
      return null;
    }
  }
}

/// Deliberately conservative. Being away cannot prove what someone is doing.
/// Departures normally close the active record, with a user-correctable review.
class ContextTimelinePolicy {
  const ContextTimelinePolicy._();

  static bool isHomeBoundTitle(String title) {
    final normalized = title.toLowerCase().trim();
    return RegExp(r'(^|[^a-z])(at home|in my apartment|at my apartment)([^a-z]|$)')
            .hasMatch(normalized) ||
        RegExp(r'(^|[^а-яё])(дома|в квартире|у себя дома)([^а-яё]|$)')
            .hasMatch(normalized);
  }

  static bool isRunning(Map<String, dynamic> row) {
    final end = row['end_time'] ?? row['endTime'];
    return (row['status'] ?? '').toString().toLowerCase() == 'running' &&
        (end == null || end.toString().trim().isEmpty);
  }

  static DateTime? startedAt(Map<String, dynamic> row) {
    final raw = row['start_time'] ?? row['startTime'];
    return raw == null ? null : DateTime.tryParse(raw.toString())?.toUtc();
  }

  static bool canEndOnDeparture(
    Map<String, dynamic> row,
    DateTime departedAtUtc,
  ) {
    final start = startedAt(row);
    return isRunning(row) &&
        start != null &&
        start.isBefore(departedAtUtc.toUtc());
  }

  static String titleForTravel(String mode, {required bool russian}) {
    switch (mode) {
      case 'walking':
        return russian ? 'Пешком' : 'Walking';
      case 'vehicle':
        return russian ? 'Поездка на транспорте' : 'Vehicle trip';
      case 'bicycle':
        return russian ? 'На велосипеде' : 'Cycling';
      default:
        return russian ? 'В пути' : 'Travel';
    }
  }

  static String visitTitle({required bool russian}) =>
      russian ? 'Вне дома' : 'Away from home';

  static List<String> transportTitles({required bool russian}) => russian
      ? const ['Метро', 'Автобус', 'Автомобиль', 'Такси', 'Трамвай',
          'Электричка', 'Другой транспорт']
      : const ['Metro', 'Bus', 'Car', 'Taxi', 'Tram', 'Commuter train',
          'Other transport'];

  static bool isSpecificTransportTitle(String title) =>
      transportTitles(russian: true).contains(title.trim()) ||
      transportTitles(russian: false).contains(title.trim());

  static bool isAutoTravelTitle(String title) {
    return const {
      'В пути', 'Travel', 'Пешком', 'Walking',
      'Поездка на транспорте', 'Vehicle trip',
      'На велосипеде', 'Cycling',
    }.contains(title.trim()) || isSpecificTransportTitle(title);
  }
}
