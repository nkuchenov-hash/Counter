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
}
