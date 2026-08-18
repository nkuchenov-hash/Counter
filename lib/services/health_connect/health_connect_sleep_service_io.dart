import 'dart:io';

import 'package:health/health.dart';

import 'health_connect_sleep_models.dart';

/// Device-local health source.
///
/// Android reads Health Connect. iOS reads Apple Health / HealthKit.
class DeviceHealthSleepService {
  DeviceHealthSleepService._();

  static final DeviceHealthSleepService instance = DeviceHealthSleepService._();

  final Health _health = Health();
  bool _configured = false;

  List<HealthDataType> get _sleepTypes => Platform.isIOS
      ? const <HealthDataType>[
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
        ]
      : const <HealthDataType>[
          HealthDataType.SLEEP_SESSION,
          HealthDataType.SLEEP_UNKNOWN,
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_OUT_OF_BED,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_AWAKE_IN_BED,
        ];

  static const List<HealthDataType> _metricTypes = <HealthDataType>[
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
  ];

  List<HealthDataAccess> _readPermissions(List<HealthDataType> types) =>
      List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
        growable: false,
      );

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  String get sourceName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  Future<void> _ensureConfigured() async {
    if (_configured || !isSupported) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> hasAuthorization() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    if (Platform.isIOS) {
      // HealthKit intentionally does not reveal whether read access was denied.
      // Once the user has enabled the source, scheduled reads are attempted and
      // HealthKit returns only the samples the user allowed.
      return true;
    }
    return await _health.hasPermissions(
          _sleepTypes,
          permissions: _readPermissions(_sleepTypes),
        ) ??
        false;
  }

  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    final sleepGranted = await _health.requestAuthorization(
      _sleepTypes,
      permissions: _readPermissions(_sleepTypes),
    );
    if (!sleepGranted) return false;

    // Vitals enrich sleep but are deliberately optional. A user can decline
    // heart-rate/SpO2/respiratory access without disabling base sleep import.
    try {
      await _health.requestAuthorization(
        _metricTypes,
        permissions: _readPermissions(_metricTypes),
      );
    } catch (_) {}
    return true;
  }

  Future<bool> isBackgroundReadAvailable() async {
    if (!isSupported) return false;
    if (Platform.isIOS) return true;
    await _ensureConfigured();
    return _health.isHealthDataInBackgroundAvailable();
  }

  Future<bool> hasBackgroundAuthorization() async {
    if (!isSupported) return false;
    if (Platform.isIOS) return true;
    await _ensureConfigured();
    return _health.isHealthDataInBackgroundAuthorized();
  }

  Future<bool> requestBackgroundAuthorization() async {
    if (!isSupported) return false;
    if (Platform.isIOS) return true;
    await _ensureConfigured();
    return _health.requestHealthDataInBackgroundAuthorization();
  }

  Future<List<HealthSleepSession>> readSessions({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    if (!isSupported || !endUtc.isAfter(startUtc)) {
      return const <HealthSleepSession>[];
    }
    await _ensureConfigured();
    final raw = await _health.getHealthDataFromTypes(
      types: _sleepTypes,
      startTime: startUtc.toLocal(),
      endTime: endUtc.toLocal(),
    );
    final sleepPoints = _health.removeDuplicates(raw);
    final metricPoints = await _readOptionalMetrics(
      startUtc: startUtc,
      endUtc: endUtc,
    );
    if (Platform.isIOS) {
      return _appleHealthSessions(sleepPoints, metricPoints);
    }
    return _androidHealthSessions(sleepPoints, metricPoints);
  }

  Future<List<HealthSleepMetricPoint>> _readOptionalMetrics({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final raw = <HealthDataPoint>[];
    for (final type in _metricTypes) {
      try {
        if (Platform.isAndroid) {
          final authorized = await _health.hasPermissions(
                <HealthDataType>[type],
                permissions: const <HealthDataAccess>[HealthDataAccess.READ],
              ) ??
              false;
          if (!authorized) continue;
        }
        raw.addAll(
          await _health.getHealthDataFromTypes(
            types: <HealthDataType>[type],
            startTime: startUtc.toLocal(),
            endTime: endUtc.toLocal(),
          ),
        );
      } catch (_) {
        // Each vital is optional and independent from the others.
      }
    }
    final points = _health.removeDuplicates(raw);
    final out = <HealthSleepMetricPoint>[];
    for (final point in points) {
      final metric = _metricForType(point.type);
      final value = point.value;
      if (metric == null || value is! NumericHealthValue) continue;
      out.add(
        HealthSleepMetricPoint(
          metric: metric,
          timeUtc: point.dateFrom.toUtc(),
          value: value.numericValue,
          unit: point.unit.name,
          sourceId: point.sourceId.trim(),
          sourceName: point.sourceName.trim(),
        ),
      );
    }
    out.sort((a, b) => a.timeUtc.compareTo(b.timeUtc));
    return out;
  }

  String? _metricForType(HealthDataType type) {
    if (type == HealthDataType.HEART_RATE) return 'heart_rate';
    if (type == HealthDataType.BLOOD_OXYGEN) return 'blood_oxygen';
    if (type == HealthDataType.RESPIRATORY_RATE) return 'respiratory_rate';
    return null;
  }

  List<HealthSleepSession> _androidHealthSessions(
    List<HealthDataPoint> points,
    List<HealthSleepMetricPoint> metrics,
  ) {
    final stagePoints = _sleepStages(points);
    final sessions = points
        .where((point) => point.type == HealthDataType.SLEEP_SESSION)
        .map((point) => _sessionFromPoint(point, idPrefix: 'health-connect'))
        .whereType<HealthSleepSession>()
        .map((session) => _sessionWithStages(session, stagePoints))
        .map((session) => _sessionWithMetrics(session, metrics))
        .toList(growable: true);

    if (sessions.isEmpty && stagePoints.isNotEmpty) {
      sessions.addAll(
        _sessionsRecoveredFromStages(
          stagePoints,
          idPrefix: 'health-connect-stages',
        ).map((session) => _sessionWithMetrics(session, metrics)),
      );
    }
    sessions.sort((a, b) => a.endUtc.compareTo(b.endUtc));
    return sessions;
  }

  List<HealthSleepSession> _appleHealthSessions(
    List<HealthDataPoint> points,
    List<HealthSleepMetricPoint> metrics,
  ) {
    final stagePoints = _sleepStages(points);
    final inBed = points
        .where((point) => point.type == HealthDataType.SLEEP_IN_BED)
        .map((point) => _sessionFromPoint(point, idPrefix: 'apple-health'))
        .whereType<HealthSleepSession>()
        .map((session) => _sessionWithStages(session, stagePoints))
        .map((session) => _sessionWithMetrics(session, metrics))
        .toList(growable: false);
    if (inBed.isNotEmpty) {
      final out = List<HealthSleepSession>.of(inBed)
        ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
      return out;
    }

    return _sessionsRecoveredFromStages(
      stagePoints,
      idPrefix: 'apple-health-stages',
    ).map((session) => _sessionWithMetrics(session, metrics)).toList(
          growable: false,
        );
  }

  int? _stageForType(HealthDataType type) {
    if (type == HealthDataType.SLEEP_UNKNOWN) return 0;
    if (type == HealthDataType.SLEEP_AWAKE) return 1;
    if (type == HealthDataType.SLEEP_ASLEEP) return 2;
    if (type == HealthDataType.SLEEP_OUT_OF_BED) return 3;
    if (type == HealthDataType.SLEEP_LIGHT) return 4;
    if (type == HealthDataType.SLEEP_DEEP) return 5;
    if (type == HealthDataType.SLEEP_REM) return 6;
    if (type == HealthDataType.SLEEP_AWAKE_IN_BED) return 7;
    return null;
  }

  List<HealthSleepStage> _sleepStages(List<HealthDataPoint> points) {
    final out = <HealthSleepStage>[];
    for (final point in points) {
      final stage = _stageForType(point.type);
      if (stage == null) continue;
      final from = point.dateFrom.toUtc();
      final to = point.dateTo.toUtc();
      if (!to.isAfter(from)) continue;
      out.add(
        HealthSleepStage(
          startUtc: from,
          endUtc: to,
          stage: stage,
          sourceId: point.sourceId.trim(),
          sourceName: point.sourceName.trim(),
        ),
      );
    }
    out.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return out;
  }

  HealthSleepSession _sessionWithStages(
    HealthSleepSession session,
    List<HealthSleepStage> stages,
  ) {
    final matching = <HealthSleepStage>[];
    for (final stage in stages) {
      final from = stage.startUtc.isAfter(session.startUtc)
          ? stage.startUtc
          : session.startUtc;
      final to = stage.endUtc.isBefore(session.endUtc)
          ? stage.endUtc
          : session.endUtc;
      if (!to.isAfter(from)) continue;
      matching.add(
        HealthSleepStage(
          startUtc: from,
          endUtc: to,
          stage: stage.stage,
          sourceId: stage.sourceId,
          sourceName: stage.sourceName,
        ),
      );
    }
    return HealthSleepSession(
      externalId: session.externalId,
      startUtc: session.startUtc,
      endUtc: session.endUtc,
      sourceId: session.sourceId,
      sourceName: session.sourceName,
      stages: matching,
      metrics: session.metrics,
      recoveredFromStages: session.recoveredFromStages,
    );
  }

  HealthSleepSession _sessionWithMetrics(
    HealthSleepSession session,
    List<HealthSleepMetricPoint> metrics,
  ) {
    final matching = <HealthSleepMetricPoint>[];
    for (final metric in metrics) {
      if (metric.timeUtc.isBefore(session.startUtc) ||
          metric.timeUtc.isAfter(session.endUtc)) {
        continue;
      }
      matching.add(metric);
    }
    return HealthSleepSession(
      externalId: session.externalId,
      startUtc: session.startUtc,
      endUtc: session.endUtc,
      sourceId: session.sourceId,
      sourceName: session.sourceName,
      stages: session.stages,
      metrics: matching,
      recoveredFromStages: session.recoveredFromStages,
    );
  }

  List<HealthSleepSession> _sessionsRecoveredFromStages(
    List<HealthSleepStage> stages, {
    required String idPrefix,
  }) {
    if (stages.isEmpty) return const <HealthSleepSession>[];
    const maxGap = Duration(minutes: 90);
    const minDuration = Duration(minutes: 20);
    final out = <HealthSleepSession>[];
    var current = <HealthSleepStage>[];

    void flush() {
      if (current.isEmpty) return;
      final start = current.first.startUtc;
      final end = current
          .map((stage) => stage.endUtc)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final hasSleepingStage = current.any(
        (stage) => stage.stage == 2 ||
            stage.stage == 4 ||
            stage.stage == 5 ||
            stage.stage == 6,
      );
      if (end.difference(start) >= minDuration && hasSleepingStage) {
        final sourceId = current.first.sourceId;
        final sourceName = current.first.sourceName;
        final sourceKey = sourceId.isNotEmpty ? sourceId : sourceName;
        out.add(
          HealthSleepSession(
            externalId:
                '$idPrefix|$sourceKey|${start.toIso8601String()}|${end.toIso8601String()}',
            startUtc: start,
            endUtc: end,
            sourceId: sourceId,
            sourceName: sourceName,
            stages: List<HealthSleepStage>.of(current),
            recoveredFromStages: true,
          ),
        );
      }
      current = <HealthSleepStage>[];
    }

    for (final stage in stages) {
      if (current.isEmpty) {
        current.add(stage);
        continue;
      }
      final previous = current.last;
      final sameSource = previous.sourceId == stage.sourceId &&
          previous.sourceName == stage.sourceName;
      final gap = stage.startUtc.difference(previous.endUtc);
      if (!sameSource || gap > maxGap) {
        flush();
      }
      current.add(stage);
    }
    flush();
    out.sort((a, b) => a.endUtc.compareTo(b.endUtc));
    return out;
  }

  HealthSleepSession? _sessionFromPoint(
    HealthDataPoint point, {
    required String idPrefix,
  }) {
    final from = point.dateFrom.toUtc();
    final to = point.dateTo.toUtc();
    if (!to.isAfter(from)) return null;
    final uuid = point.uuid.trim();
    final sourceId = point.sourceId.trim();
    final externalId = uuid.isNotEmpty
        ? '$idPrefix|$uuid'
        : '$idPrefix|$sourceId|${from.toIso8601String()}|${to.toIso8601String()}';
    return HealthSleepSession(
      externalId: externalId,
      startUtc: from,
      endUtc: to,
      sourceId: sourceId,
      sourceName: point.sourceName.trim(),
    );
  }
}

@Deprecated('Use DeviceHealthSleepService')
typedef HealthConnectSleepService = DeviceHealthSleepService;
