import 'package:flutter/foundation.dart';

@immutable
class HealthSleepStage {
  const HealthSleepStage({
    required this.startUtc,
    required this.endUtc,
    required this.stage,
    required this.sourceId,
    required this.sourceName,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final int stage;
  final String sourceId;
  final String sourceName;

  Duration get duration => endUtc.difference(startUtc);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start': startUtc.toIso8601String(),
        'end': endUtc.toIso8601String(),
        'stage': stage,
        'source': sourceId.isNotEmpty ? sourceId : sourceName,
      };
}

@immutable
class HealthSleepMetricPoint {
  const HealthSleepMetricPoint({
    required this.metric,
    required this.timeUtc,
    required this.value,
    required this.unit,
    required this.sourceId,
    required this.sourceName,
  });

  final String metric;
  final DateTime timeUtc;
  final num value;
  final String unit;
  final String sourceId;
  final String sourceName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'metric': metric,
        'time': timeUtc.toIso8601String(),
        'value': value,
        'unit': unit,
        'source': sourceId.isNotEmpty ? sourceId : sourceName,
      };
}

@immutable
class HealthSleepSession {
  const HealthSleepSession({
    required this.externalId,
    required this.startUtc,
    required this.endUtc,
    required this.sourceId,
    required this.sourceName,
    this.stages = const <HealthSleepStage>[],
    this.metrics = const <HealthSleepMetricPoint>[],
    this.recoveredFromStages = false,
  });

  final String externalId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String sourceId;
  final String sourceName;
  final List<HealthSleepStage> stages;
  final List<HealthSleepMetricPoint> metrics;
  final bool recoveredFromStages;

  Duration get duration => endUtc.difference(startUtc);
}
