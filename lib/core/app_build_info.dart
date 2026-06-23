/// Injected at build time via `--dart-define=GIT_COMMIT=...` and `BUILD_TIME=...`.
///
/// Boot marker `APP_BUILD` is allowed in release. Verbose P0* diagnostics are not.
/// Performance Kill Switch Law (P0V): release builds must not flood console/logcat.
abstract final class AppBuildInfo {
  static const String gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'dev',
  );
  static const String builtAt = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'unknown',
  );

  static String bootLogLine({String? route}) {
    final r = route?.trim();
    final routePart = (r != null && r.isNotEmpty) ? ' route=$r' : '';
    return 'APP_BUILD commit=$gitCommit builtAt=$builtAt$routePart';
  }

  /// Phone-test marker: pre-white-design PageView swipe restore.
  static String get swipeRestoreMarker =>
      'SWIPE_RESTORE build: $gitCommit $builtAt';

  /// Phone-test marker: P0N performance pass (cache + Plans physics/render).
  static String get p0nPerfMarker => 'P0N build: $gitCommit $builtAt';

  /// Phone-test marker: P0O rolling warm day window.
  static String get p0oWarmMarker => 'P0O build: $gitCommit $builtAt';

  /// Phone-test marker: P0P content-only date paging.
  static String get p0pContentMarker => 'P0P build: $gitCommit $builtAt';

  /// Phone-test marker: P0S eager mounted content pages ±10.
  static String get p0sMountMarker => 'P0S build: $gitCommit $builtAt';

  /// Marker: Performance Kill Switch Law documented (P0V); experimental preload default-off.
  static String get p0vPerfKillSwitchMarker =>
      'P0V_PERF_KILL_SWITCH build: $gitCommit $builtAt';
}
