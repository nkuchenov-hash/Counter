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
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
        ]
      : const <HealthDataType>[
          HealthDataType.SLEEP_SESSION,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_UNKNOWN,
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
    final sessions = points
        .where((point) => point.type == HealthDataType.SLEEP_SESSION)
        .map((point) => _sessionFromPoint(point, idPrefix: 'health-connect'))
        .whereType<HealthSleepSession>()
        .toList(growable: false);
    if (sessions.isNotEmpty) {
      final out = List<HealthSleepSession>.of(sessions)
        ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
      return out;
    }

    // Some producers expose the night's sleep through stage points even when
    // the package does not surface an overall SLEEP_SESSION point. Stages are
    // used only to recover one canonical start -> end interval; they are never
    // stored or displayed by LIFE OS.
    final sleepStagePoints = points
        .where((point) {
          return point.type == HealthDataType.SLEEP_ASLEEP ||
              point.type == HealthDataType.SLEEP_LIGHT ||
              point.type == HealthDataType.SLEEP_DEEP ||
              point.type == HealthDataType.SLEEP_REM ||
              point.type == HealthDataType.SLEEP_UNKNOWN;
        })
        .toList(growable: false)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    return _sessionsFromStagePoints(
      sleepStagePoints,
      idPrefix: 'health-connect-stages',
      maxGap: const Duration(minutes: 90),
    );
  }

  List<HealthSleepSession> _appleHealthSessions(List<HealthDataPoint> points) {
    final inBed = points
        .where((point) => point.type == HealthDataType.SLEEP_IN_BED)
        .map((point) => _sessionFromPoint(point, idPrefix: 'apple-health'))
        .whereType<HealthSleepSession>()
        .toList(growable: false);
    if (inBed.isNotEmpty) {
      final out = List<HealthSleepSession>.of(inBed)
        ..sort((a, b) => a.endUtc.compareTo(b.endUtc));
      return out;
    }

    final stages = points
        .where((point) {
          return point.type == HealthDataType.SLEEP_ASLEEP ||
              point.type == HealthDataType.SLEEP_DEEP ||
              point.type == HealthDataType.SLEEP_REM;
        })
        .toList(growable: false)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    return _sessionsFromStagePoints(
      stages,
      idPrefix: 'apple-health',
      maxGap: const Duration(minutes: 30),
    );
  }

  List<HealthSleepSession> _sessionsFromStagePoints(
    List<HealthDataPoint> points, {
    required String idPrefix,
    required Duration maxGap,
  }) {
    final out = <HealthSleepSession>[];
    DateTime? currentStart;
    DateTime? currentEnd;
    String currentSourceId = '';
    String currentSourceName = '';

    void flush() {
      final from = currentStart;
      final to = currentEnd;
      if (from == null || to == null || !to.isAfter(from)) return;
      if (to.difference(from) < const Duration(minutes: 20)) return;
      final sourceKey = currentSourceId.isNotEmpty
          ? currentSourceId
          : currentSourceName;
      out.add(
        HealthSleepSession(
          externalId:
              '$idPrefix|$sourceKey|${from.toIso8601String()}|${to.toIso8601String()}',
          startUtc: from,
          endUtc: to,
          sourceId: currentSourceId,
          sourceName: currentSourceName,
        ),
      );
    }

    for (final point in points) {
      final from = point.dateFrom.toUtc();
      final to = point.dateTo.toUtc();
      if (!to.isAfter(from)) continue;
      final sourceId = point.sourceId.trim();
      final sourceName = point.sourceName.trim();
      final sameSource =
          currentStart != null &&
          sourceId == currentSourceId &&
          sourceName == currentSourceName;
      final joinsCurrent =
          sameSource &&
          currentEnd != null &&
          !from.isAfter(currentEnd!.add(maxGap));
      if (!joinsCurrent) {
        flush();
        currentStart = from;
        currentEnd = to;
        currentSourceId = sourceId;
        currentSourceName = sourceName;
        continue;
      }
      if (from.isBefore(currentStart!)) currentStart = from;
      if (to.isAfter(currentEnd!)) currentEnd = to;
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
