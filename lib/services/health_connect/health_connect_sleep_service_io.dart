import 'dart:io';

import 'package:health/health.dart';

import 'health_connect_sleep_models.dart';

class HealthConnectSleepService {
  HealthConnectSleepService._();

  static final HealthConnectSleepService instance =
      HealthConnectSleepService._();

  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.SLEEP_SESSION,
  ];
  static const List<HealthDataAccess> _permissions = <HealthDataAccess>[
    HealthDataAccess.READ,
  ];

  bool get isSupported => Platform.isAndroid;

  Future<void> _ensureConfigured() async {
    if (_configured || !isSupported) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> hasAuthorization() async {
    if (!isSupported) return false;
    await _ensureConfigured();
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
    await _ensureConfigured();
    return _health.isHealthDataInBackgroundAvailable();
  }

  Future<bool> hasBackgroundAuthorization() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    return _health.isHealthDataInBackgroundAuthorized();
  }

  Future<bool> requestBackgroundAuthorization() async {
    if (!isSupported) return false;
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
    final out = <HealthSleepSession>[];
    for (final point in points) {
      if (point.type != HealthDataType.SLEEP_SESSION) continue;
      final from = point.dateFrom.toUtc();
      final to = point.dateTo.toUtc();
      if (!to.isAfter(from)) continue;
      final uuid = point.uuid.trim();
      final sourceId = point.sourceId.trim();
      final externalId = uuid.isNotEmpty
          ? uuid
          : '$sourceId|${from.toIso8601String()}|${to.toIso8601String()}';
      out.add(
        HealthSleepSession(
          externalId: externalId,
          startUtc: from,
          endUtc: to,
          sourceId: sourceId,
          sourceName: point.sourceName.trim(),
        ),
      );
    }
    out.sort((a, b) => a.endUtc.compareTo(b.endUtc));
    return out;
  }
}
