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

  List<HealthDataType> get _types => Platform.isIOS
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

  List<HealthDataAccess> get _permissions => List<HealthDataAccess>.filled(
    _types.length,
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
    return await _health.hasPermissions(_types, permissions: _permissions) ??
        false;
  }

  Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    return _health.requestAuthorization(_types, permissions: _permissions);
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
      types: _types,
      startTime: startUtc.toLocal(),
      endTime: endUtc.toLocal(),
    );
    final points = _health.removeDuplicates(raw);
    if (Platform.isIOS) return _appleHealthSessions(points);
    return _androidHealthSessions(points);
  }

  List<HealthSleepSession> _androidHealthSessions(
    List<HealthDataPoint> points,
  ) {
    final stagePoints = _sleepStages(points);
    final sessions = points
        .where((point) => point.type == HealthDataType.SLEEP_SESSION)
        .map((point) => _sessionFromPoint(point, idPrefix: 'health-connect'))
        .whereType<HealthSleepSession>()
        .map((session) => _sessionWithStages(session, stagePoints))
        .toList(growable: true);

    if (sessions.isEmpty && stagePoints.isNotEmpty) {
      sessions.addAll(
        _sessionsRecoveredFromStages(
          stagePoints,
          idPrefix: 'health-connect-stages',
        ),
      );
    }
    sessions.sort((a, b) => a.endUtc.compareTo(b.endUtc));
    return sessions;
  }

  List<HealthSleepSession> _appleHealthSessions(List<HealthDataPoint> points) {
    final stagePoints = _sleepStages(points);
    final inBed = points
        .where((point) => point.type == HealthDataType.SLEEP_IN_BED)
        .map((point) => _sessionFromPoint(point, idPrefix: 'apple-health'))
        .whereType<HealthSleepSession>()
        .map((session) => _sessionWithStages(session, stagePoints))
        .toList(growable: false);
    if (inBed.isNotEmpty) {
      final out = List<HealthSleepSession>.of(inBed)
        ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
      return out;
    }

    return _sessionsRecoveredFromStages(
      stagePoints,
      idPrefix: 'apple-health-stages',
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
