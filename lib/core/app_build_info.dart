/// Injected at build time via `--dart-define=GIT_COMMIT=...` and `BUILD_TIME=...`.
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
}
