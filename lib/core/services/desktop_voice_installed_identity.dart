import 'dart:io';

import 'package:counter/core/app_build_info.dart';
import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Installed-app identity for Desktop Voice diagnostics and smoke scripts.
abstract final class DesktopVoiceInstalledIdentity {
  static String get runningExePath => Platform.resolvedExecutable;

  static String get installFolder {
    try {
      return File(runningExePath).parent.path;
    } catch (_) {
      return '';
    }
  }

  static String get expectedInstalledExe {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    if (local.isEmpty) return '';
    return '$local${Platform.pathSeparator}Programs${Platform.pathSeparator}Counter'
        '${Platform.pathSeparator}counter.exe';
  }

  static String get expectedHelperPath {
    final local = Platform.environment['LOCALAPPDATA'] ?? '';
    if (local.isEmpty) return '';
    return '$local${Platform.pathSeparator}Programs${Platform.pathSeparator}Counter'
        '${Platform.pathSeparator}stt_helper${Platform.pathSeparator}counter_stt_helper.exe';
  }

  static bool get isInstalledApp {
    final expected = expectedInstalledExe;
    if (expected.isEmpty) return false;
    return runningExePath.toLowerCase() == expected.toLowerCase();
  }

  static bool get isDevBuild {
    if (isInstalledApp) return false;
    final lower = runningExePath.toLowerCase();
    return lower.contains('${Platform.pathSeparator}build${Platform.pathSeparator}') ||
        lower.contains('${Platform.pathSeparator}runner${Platform.pathSeparator}');
  }

  static bool get staleBuildWarning => isDevBuild;

  static String? get devBuildWarningMessage {
    if (!isDevBuild) return null;
    return 'Запущена dev-сборка, установите CounterSetup.exe';
  }

  static String? get devBuildWarningMessageEn {
    if (!isDevBuild) return null;
    return 'Running a dev build — install CounterSetup.exe';
  }

  static void logBootMarkers() {
    DesktopVoicePipeline.mark('DESKTOP_VOICE_RUNNING_EXE_PATH', runningExePath);
    DesktopVoicePipeline.mark('DESKTOP_VOICE_BUILD_SHA', AppBuildInfo.gitCommit);
    if (isInstalledApp) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_INSTALLED_APP_CONFIRMED');
      if (AppBuildInfo.gitCommit != 'dev' &&
          AppBuildInfo.gitCommit != 'unknown') {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_BUILD_SHA_MATCHES_RUNNING_APP');
      }
    }
    if (staleBuildWarning) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_STALE_BUILD_WARNING',
        runningExePath,
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_STALE_APP_BUILD_BLOCKED');
    }
  }

  static Map<String, Object?> toDiagnosticMap() {
    final helper = expectedHelperPath;
    return {
      'running_exe_path': runningExePath,
      'build_sha': AppBuildInfo.gitCommit,
      'build_time': AppBuildInfo.builtAt,
      'is_installed_app': isInstalledApp,
      'install_folder': installFolder,
      'stale_build_warning': staleBuildWarning,
      'helper_expected_path': helper,
      'helper_exists':
          helper.isNotEmpty && File(helper).existsSync(),
    };
  }

  static List<String> toDiagLines() {
    final map = toDiagnosticMap();
    return map.entries
        .map((e) => '${e.key}=${e.value}')
        .toList(growable: false);
  }
}
