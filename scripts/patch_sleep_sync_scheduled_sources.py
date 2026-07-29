from __future__ import annotations

from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


service_path = Path("lib/data/health/health_sleep_sync_service.dart")
service = service_path.read_text(encoding="utf-8")
service = service.replace("HealthConnectSleepService", "DeviceHealthSleepService")
service = replace_once(
    service,
    "enum HealthSleepSyncPhase {",
    """enum SleepSyncSourceTransport {
  deviceHealth,
  cloudOAuth,
  webhook,
  fileImport,
  manual,
}

/// Stable adapter identifiers. New brands plug into one of the transports
/// above without changing Timeline persistence or the daily scheduler.
const Set<String> knownSleepSourceAdapterIds = <String>{
  'health_connect',
  'apple_health',
  'oura',
  'fitbit',
  'garmin',
  'whoop',
  'polar',
  'withings',
  'samsung_health',
  'huawei_health',
  'zepp',
  'mi_fitness',
};

enum HealthSleepSyncPhase {""",
    "source transport enum",
)
service = replace_once(
    service,
    "    required this.phase,\n",
    "    required this.phase,\n    this.dailySyncMinutes = 600,\n",
    "state constructor daily time",
)
service = replace_once(
    service,
    "      phase = HealthSleepSyncPhase.disabled,\n",
    "      phase = HealthSleepSyncPhase.disabled,\n      dailySyncMinutes = 600,\n",
    "initial daily time",
)
service = replace_once(
    service,
    "  final HealthSleepSyncPhase phase;\n",
    "  final HealthSleepSyncPhase phase;\n  final int dailySyncMinutes;\n",
    "daily time field",
)
service = replace_once(
    service,
    "    HealthSleepSyncPhase? phase,\n",
    "    HealthSleepSyncPhase? phase,\n    int? dailySyncMinutes,\n",
    "daily time copy arg",
)
service = replace_once(
    service,
    "      phase: phase ?? this.phase,\n",
    "      phase: phase ?? this.phase,\n      dailySyncMinutes: dailySyncMinutes ?? this.dailySyncMinutes,\n",
    "daily time copy value",
)
service = replace_once(
    service,
    "    if (taskName != HealthSleepSyncService.backgroundTaskName) return true;",
    """    if (taskName != HealthSleepSyncService.backgroundTaskName &&
        taskName != Workmanager.iOSBackgroundTask) {
      return true;
    }""",
    "background callback task filter",
)
service = replace_once(
    service,
    """      await HealthSleepSyncService.instance.start(
        observeLifecycle: false,
        manageBackgroundSchedule: false,
        triggerInitialSync: false,
      );""",
    """      await HealthSleepSyncService.instance.start(
        manageBackgroundSchedule: false,
      );""",
    "background start call",
)
service = replace_once(
    service,
    "class HealthSleepSyncService with WidgetsBindingObserver {",
    "class HealthSleepSyncService {",
    "remove lifecycle observer mixin",
)
service = replace_once(
    service,
    "  static const String _lastSyncKey = 'health_sleep_last_sync_utc_v1';\n",
    """  static const String _lastSyncKey = 'health_sleep_last_sync_utc_v1';
  static const String _dailySyncMinutesKey =
      'health_sleep_daily_sync_minutes_v1';
  static const int defaultDailySyncMinutes = 10 * 60;
  static const String iosBackgroundTaskIdentifier =
      'com.example.counter.sleep-sync';
""",
    "daily preference constants",
)
service = replace_once(
    service,
    """  static const String _backgroundTaskUniqueName =
      'health_sleep_background_periodic_v1';""",
    """  static const String _androidBackgroundTaskUniqueName =
      'health_sleep_background_periodic_v1';""",
    "background unique name",
)
service = replace_once(
    service,
    "  bool _observingLifecycle = false;\n",
    "",
    "remove lifecycle state",
)
service = replace_once(
    service,
    "  bool get isSupported => DeviceHealthSleepService.instance.isSupported;\n",
    """  bool get isSupported => DeviceHealthSleepService.instance.isSupported;

  String get activeDeviceSourceName =>
      DeviceHealthSleepService.instance.sourceName;

  String get _backgroundTaskUniqueName => Platform.isIOS
      ? iosBackgroundTaskIdentifier
      : _androidBackgroundTaskUniqueName;
""",
    "source and task getters",
)
start_pattern = re.compile(
    r"  Future<void> start\(\{.*?  Future<bool> requestAuthorizationAndEnable\(\) async \{",
    re.DOTALL,
)
start_replacement = """  Future<void> start({bool manageBackgroundSchedule = true}) async {
    if (!_started) {
      _started = true;
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(enabledPrefsKey) ?? false;
      final lastSyncRaw = prefs.getString(_lastSyncKey);
      final lastSync = lastSyncRaw == null
          ? null
          : DateTime.tryParse(lastSyncRaw)?.toUtc();
      final storedMinutes =
          prefs.getInt(_dailySyncMinutesKey) ?? defaultDailySyncMinutes;
      final dailySyncMinutes = storedMinutes.clamp(0, 1439);
      state.value = HealthSleepSyncState(
        enabled: enabled,
        phase: !isSupported
            ? HealthSleepSyncPhase.unsupported
            : enabled
            ? HealthSleepSyncPhase.idle
            : HealthSleepSyncPhase.disabled,
        dailySyncMinutes: dailySyncMinutes,
        lastSyncUtc: lastSync,
      );
    }

    if (manageBackgroundSchedule && isSupported) {
      await _ensureWorkmanagerInitialized();
      await _refreshBackgroundAccessAndSchedule();
    }
  }

  Future<bool> requestAuthorizationAndEnable() async {"""
service, count = start_pattern.subn(start_replacement, service, count=1)
if count != 1:
    raise RuntimeError(f"start function replacement: expected 1 match, found {count}")
service = replace_once(
    service,
    "Future<void> setEnabled(bool enabled, {bool syncNow = true})",
    "Future<void> setEnabled(bool enabled, {bool syncNow = false})",
    "disable lifecycle-style immediate sync",
)
service = replace_once(
    service,
    """    await start(
      manageBackgroundSchedule: false,
      triggerInitialSync: false,
    );""",
    "    await start(manageBackgroundSchedule: false);",
    "sync start call",
)
insert_before_workmanager = """  Future<void> setDailySyncMinutes(int minutes) async {
    await start(triggerInitialSync: false);
    final normalized = minutes.clamp(0, 1439);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailySyncMinutesKey, normalized);
    state.value = state.value.copyWith(dailySyncMinutes: normalized);
    await _applyBackgroundSchedule();
  }

  Duration _delayUntilNextDailyRun() {
    final now = DateTime.now();
    final minutes = state.value.dailySyncMinutes.clamp(0, 1439);
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    return target.difference(now);
  }

"""
service = replace_once(
    service,
    "  Future<void> _ensureWorkmanagerInitialized() async {",
    insert_before_workmanager + "  Future<void> _ensureWorkmanagerInitialized() async {",
    "daily schedule methods",
)
service = service.replace(
    "if (_workmanagerInitialized || kIsWeb || !Platform.isAndroid) return;",
    """if (_workmanagerInitialized ||
        kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }""",
)
service = service.replace(
    "if (!isSupported || kIsWeb || !Platform.isAndroid) return;",
    """if (!isSupported ||
        kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }""",
)
service = replace_once(
    service,
    "    if (kIsWeb || !Platform.isAndroid || !_workmanagerInitialized) return;",
    """    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS) ||
        !_workmanagerInitialized) {
      return;
    }""",
    "background schedule platform guard",
)
service = replace_once(
    service,
    "        frequency: _backgroundFrequency,\n",
    "        frequency: _backgroundFrequency,\n        initialDelay: _delayUntilNextDailyRun(),\n",
    "daily initial delay",
)
service = service.replace(
    "await start(triggerInitialSync: false);",
    "await start();",
)
service_path.write_text(service, encoding="utf-8")


dictionary_path = Path("lib/l10n/dictionary.dart")
dictionary = dictionary_path.read_text(encoding="utf-8")
replacements = {
    "'health_connect_title': 'Health Connect'":
        "'health_connect_title': 'Sleep synchronization'",
    "'health_connect_subtitle':\n      'Import completed sleep sessions into the Life OS timeline.'":
        "'health_connect_subtitle':\n      'Import sleep from connected device and cloud sources on a daily schedule.'",
    "'health_connect_enable_background': 'Enable background sync'":
        "'health_connect_enable_background': 'Enable scheduled sync'",
    "'health_connect_status_unavailable': 'Available on Android only'":
        "'health_connect_status_unavailable': 'No supported local sleep source on this device'",
    "'No completed sleep sessions found in Health Connect'":
        "'No completed sleep sessions found in connected sources'",
    "'health_connect_background_active': 'Background sync active'":
        "'health_connect_background_active': 'Daily scheduled sync active'",
    "'Background access has not been granted'":
        "'Scheduled background access has not been granted'",
    "'health_connect_title': 'Health Connect',":
        "'health_connect_title': 'Синхронизация сна',",
    "'health_connect_subtitle':\n      'Импорт завершённых сессий сна в Timeline Life OS.'":
        "'health_connect_subtitle':\n      'Импорт сна из подключённых локальных и облачных источников по ежедневному расписанию.'",
    "'health_connect_enable_background': 'Включить фоновую синхронизацию'":
        "'health_connect_enable_background': 'Включить синхронизацию по расписанию'",
    "'health_connect_status_unavailable': 'Доступно только на Android'":
        "'health_connect_status_unavailable': 'На этом устройстве нет поддерживаемого локального источника сна'",
    "'В Health Connect нет завершённых сессий сна'":
        "'В подключённых источниках нет завершённых сессий сна'",
    "'health_connect_background_active': 'Фоновая синхронизация включена'":
        "'health_connect_background_active': 'Ежедневная синхронизация по расписанию включена'",
    "'Нет разрешения на фоновый доступ'":
        "'Нет разрешения на синхронизацию по расписанию'",
}
for old, new in replacements.items():
    if old not in dictionary:
        raise RuntimeError(f"dictionary replacement missing: {old}")
    dictionary = dictionary.replace(old, new, 1)
dictionary = replace_once(
    dictionary,
    "  'health_connect_enable_background': 'Enable scheduled sync',\n",
    """  'health_connect_enable_background': 'Enable scheduled sync',
  'sleep_sync_daily_time': 'Daily synchronization time',
  'sleep_sync_daily_time_hint':
      'Runs without opening the app. The operating system may delay it to save battery.',
  'sleep_sync_device_source': 'Device source: %s',
  'sleep_sync_cloud_note':
      'Cloud sources are synchronized by the server scheduler.',
""",
    "english schedule strings",
)
dictionary = replace_once(
    dictionary,
    "  'health_connect_enable_background': 'Включить синхронизацию по расписанию',\n",
    """  'health_connect_enable_background': 'Включить синхронизацию по расписанию',
  'sleep_sync_daily_time': 'Время ежедневной синхронизации',
  'sleep_sync_daily_time_hint':
      'Запускается без открытия приложения. ОС может выполнить задачу позже для экономии батареи.',
  'sleep_sync_device_source': 'Локальный источник: %s',
  'sleep_sync_cloud_note':
      'Облачные источники синхронизируются серверным планировщиком.',
""",
    "russian schedule strings",
)
dictionary_path.write_text(dictionary, encoding="utf-8")


info_path = Path("ios/Runner/Info.plist")
info = info_path.read_text(encoding="utf-8")
info_insert = """\t<key>NSHealthShareUsageDescription</key>
\t<string>Import your sleep sessions into the Life OS timeline.</string>
\t<key>NSHealthUpdateUsageDescription</key>
\t<string>Life OS requests Health access only to synchronize your sleep timeline.</string>
\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>processing</string>
\t</array>
\t<key>BGTaskSchedulerPermittedIdentifiers</key>
\t<array>
\t\t<string>com.example.counter.sleep-sync</string>
\t</array>
"""
info = replace_once(info, "</dict>\n</plist>", info_insert + "</dict>\n</plist>", "Info.plist health config")
info_path.write_text(info, encoding="utf-8")


app_delegate_path = Path("ios/Runner/AppDelegate.swift")
app_delegate = app_delegate_path.read_text(encoding="utf-8")
app_delegate = replace_once(
    app_delegate,
    "import UIKit\n",
    "import UIKit\nimport workmanager_apple\n",
    "workmanager import",
)
app_delegate = replace_once(
    app_delegate,
    """  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }""",
    """  ) -> Bool {
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.example.counter.sleep-sync",
      frequency: NSNumber(value: 24 * 60 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }""",
    "iOS periodic task registration",
)
app_delegate_path.write_text(app_delegate, encoding="utf-8")


project_path = Path("ios/Runner.xcodeproj/project.pbxproj")
project = project_path.read_text(encoding="utf-8")
project = project.replace("IPHONEOS_DEPLOYMENT_TARGET = 13.0;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;")
needle = '\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n\t\t\t\tENABLE_BITCODE = NO;'
replacement = '\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tENABLE_BITCODE = NO;'
count = project.count(needle)
if count != 3:
    raise RuntimeError(f"project entitlements: expected 3 matches, found {count}")
project = project.replace(needle, replacement)
project_path.write_text(project, encoding="utf-8")
