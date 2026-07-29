import 'health_connect_sleep_models.dart';

class DeviceHealthSleepService {
  DeviceHealthSleepService._();

  static final DeviceHealthSleepService instance = DeviceHealthSleepService._();

  bool get isSupported => false;

  String get sourceName => 'Device health';

  Future<bool> hasAuthorization() async => false;

  Future<bool> requestAuthorization() async => false;

  Future<bool> isBackgroundReadAvailable() async => false;

  Future<bool> hasBackgroundAuthorization() async => false;

  Future<bool> requestBackgroundAuthorization() async => false;

  Future<List<HealthSleepSession>> readSessions({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async => const <HealthSleepSession>[];
}

@Deprecated('Use DeviceHealthSleepService')
typedef HealthConnectSleepService = DeviceHealthSleepService;
