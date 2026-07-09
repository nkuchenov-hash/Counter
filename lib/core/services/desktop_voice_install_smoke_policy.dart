/// Pure rules for installed Desktop Voice smoke / identity checks (unit-tested).
abstract final class DesktopVoiceInstallSmokePolicy {
  /// Strict latency pass: useful candidate only when stopтЖТuseful &lt; 500ms.
  static const int usefulCandidateLatencyPassMaxMs = 499;

  static const List<String> requiredEndpointDiagKeys = [
    'endpoint_id',
    'endpoint_role',
    'endpoint_volume',
    'console_default_device',
    'communications_default_device',
    'selected_capture_endpoint',
    'capture_mix_format',
    'capture_backend',
    'capture_api',
    'raw_capture_rms',
    'raw_capture_peak',
    'processed_wav_rms',
    'processed_wav_peak',
    'capture_gain_mode',
  ];

  static bool isUsefulCandidateLatencyPass({
    required bool candidateUseful,
    required int? stopToUsefulCandidateMs,
  }) {
    if (!candidateUseful) return false;
    final ms = stopToUsefulCandidateMs;
    if (ms == null) return false;
    return ms <= usefulCandidateLatencyPassMaxMs;
  }

  static Map<String, String> parseDiagKeyValues(Iterable<String> lines) {
    final out = <String, String>{};
    for (final line in lines) {
      final i = line.indexOf('=');
      if (i <= 0) continue;
      out[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    return out;
  }

  static bool endpointDiagFieldsPresent(Iterable<String> lines) {
    final map = parseDiagKeyValues(lines);
    for (final key in requiredEndpointDiagKeys) {
      if (!map.containsKey(key)) return false;
      final v = map[key] ?? '';
      if (v.isEmpty || v == 'тАФ') {
        if (key == 'endpoint_id' || key == 'endpoint_role') return false;
      }
    }
    return true;
  }

  static bool endpointIdPresent(Iterable<String> lines) {
    final v = parseDiagKeyValues(lines)['endpoint_id'] ?? '';
    return v.isNotEmpty && v != 'тАФ';
  }

  static bool endpointRolePresent(Iterable<String> lines) {
    final v = parseDiagKeyValues(lines)['endpoint_role'] ?? '';
    return v.isNotEmpty && v != 'тАФ';
  }

  static bool endpointVolumePresent(Iterable<String> lines) {
    final v = parseDiagKeyValues(lines)['endpoint_volume'] ?? '';
    return v.isNotEmpty && v != 'тАФ';
  }

  /// Blocks mixed installs (new helper + old app) and stale build SHAs.
  static bool installIdentityPass({
    required String expectedBuildSha,
    required String runningBuildSha,
    required bool counterExeReplaced,
    required bool helperExeReplaced,
    required bool staleProcessAbsent,
    required bool runningPathMatchesInstalled,
    DateTime? appFileTime,
    DateTime? buildStartedAt,
  }) {
    if (expectedBuildSha.isEmpty || runningBuildSha.isEmpty) return false;
    if (runningBuildSha == 'dev' || runningBuildSha == 'unknown') return false;
    if (runningBuildSha != expectedBuildSha) return false;
    if (!counterExeReplaced || !helperExeReplaced) return false;
    if (!staleProcessAbsent) return false;
    if (!runningPathMatchesInstalled) return false;
    if (buildStartedAt != null && appFileTime != null) {
      if (appFileTime.isBefore(buildStartedAt)) return false;
    }
    return true;
  }

  static bool isStaleBuildSha(String sha) {
    const blocked = {'dev', 'unknown', 'df696fc'};
    return blocked.contains(sha);
  }
}
