import 'package:flutter/foundation.dart';

@immutable
class HealthSleepSession {
  const HealthSleepSession({
    required this.externalId,
    required this.startUtc,
    required this.endUtc,
    required this.sourceId,
    required this.sourceName,
  });

  final String externalId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String sourceId;
  final String sourceName;

  Duration get duration => endUtc.difference(startUtc);
}
