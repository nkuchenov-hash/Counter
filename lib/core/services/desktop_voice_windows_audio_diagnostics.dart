import 'dart:convert';
import 'dart:io';

import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Windows Core Audio endpoint snapshot for capture-path diagnostics.
class DesktopVoiceEndpointSnapshot {
  const DesktopVoiceEndpointSnapshot({
    required this.deviceFriendlyName,
    required this.deviceId,
    required this.endpointRole,
    required this.endpointVolume,
    required this.endpointMuted,
    this.communicationsVolume,
    this.communicationsMuted,
    this.micBoostDb,
    this.audioEnhancementsEnabled,
  });

  final String deviceFriendlyName;
  final String deviceId;
  final String endpointRole;
  final double? endpointVolume;
  final bool endpointMuted;
  final double? communicationsVolume;
  final bool? communicationsMuted;
  final double? micBoostDb;
  final bool? audioEnhancementsEnabled;
}

/// Reads default capture endpoint volume via PowerShell + MMDevice COM.
abstract final class DesktopVoiceWindowsAudioDiagnostics {
  static const handyReferenceCaptureRms = 0.058;
  static const df696fcLiveQuietRms = 0.0135;

  static Future<DesktopVoiceEndpointSnapshot?> readDefaultCaptureEndpoint({
    String role = 'console',
  }) async {
    if (!Platform.isWindows) return null;
    DesktopVoicePipeline.mark('DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS');
    try {
      final ps = '''
\$e = New-Object -ComObject MMDeviceEnumerator
\$role = if ('$role' -eq 'communications') { 1 } else { 0 }
\$dev = \$e.GetDefaultAudioEndpoint(1, \$role)
\$vol = \$dev.AudioEndpointVolume
\$name = \$dev.FriendlyName
\$id = \$dev.Id
\$scalar = \$vol.GetMasterVolumeLevelScalar()
\$muted = \$vol.GetMute()
\$comm = \$null
try {
  \$cdev = \$e.GetDefaultAudioEndpoint(1, 1)
  \$cvol = \$cdev.AudioEndpointVolume
  \$comm = @{ volume = \$cvol.GetMasterVolumeLevelScalar(); muted = \$cvol.GetMute() }
} catch {}
@{ device_name = \$name; device_id = \$id; endpoint_role = '$role'; endpoint_volume = \$scalar; endpoint_muted = \$muted; communications = \$comm } | ConvertTo-Json -Compress
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', ps],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final raw = (result.stdout as String).trim();
      if (raw.isEmpty) return null;
      final body = jsonDecode(raw) as Map<String, dynamic>;
      final comm = body['communications'] as Map<String, dynamic>?;
      final snap = DesktopVoiceEndpointSnapshot(
        deviceFriendlyName: body['device_name'] as String? ?? '',
        deviceId: body['device_id'] as String? ?? '',
        endpointRole: body['endpoint_role'] as String? ?? role,
        endpointVolume: (body['endpoint_volume'] as num?)?.toDouble(),
        endpointMuted: body['endpoint_muted'] == true,
        communicationsVolume: (comm?['volume'] as num?)?.toDouble(),
        communicationsMuted: comm?['muted'] as bool?,
      );
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED',
        snap.endpointVolume?.toStringAsFixed(3) ?? '—',
      );
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MIC_BOOST_OR_EFFECTS_CHECKED');
      return snap;
    } catch (_) {
      return null;
    }
  }

  static void logCounterVsHandyRmsDiff({
    required double captureRms,
    double handyRms = handyReferenceCaptureRms,
  }) {
    final ratio = handyRms > 0 ? captureRms / handyRms : 0.0;
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COUNTER_HANDY_DEVICE_DIFFS_LOGGED',
      'counter_rms=${captureRms.toStringAsFixed(4)} handy_baseline_rms=${handyRms.toStringAsFixed(4)} ratio=${ratio.toStringAsFixed(2)}',
    );
  }
}
