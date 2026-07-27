import 'health_connect_sleep_models.dart';

class HealthConnectSleepService {
  HealthConnectSleepService._();

  static final HealthConnectSleepService instance =
      HealthConnectSleepService._();

  bool get isSupported => false;

  Future<bool> hasAuthorization() async => false;

  Future<bool> requestAuthorization() async => false;

  Future<List<HealthSleepSession>> readSessions({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async => const <HealthSleepSession>[];
}
