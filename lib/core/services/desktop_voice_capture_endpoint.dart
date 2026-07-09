import 'package:counter/core/diagnostics/desktop_voice_pipeline.dart';

/// Desktop Voice capture endpoint role selection (Windows WASAPI / MMDevice).
abstract final class DesktopVoiceCaptureEndpointPolicy {
  /// `auto` | `console` | `communications` | `multimedia`
  static const String defaultRole = 'auto';

  static const String markerEndpointSelected =
      'DESKTOP_VOICE_CAPTURE_ENDPOINT_SELECTED';
  static const String markerRoleSelected =
      'DESKTOP_VOICE_CAPTURE_ENDPOINT_ROLE_SELECTED';
  static const String markerFallbackReady =
      'DESKTOP_VOICE_CAPTURE_ENDPOINT_FALLBACK_READY';

  static Map<String, dynamic> startRequestBody({String? role}) {
    return {
      'endpoint_role': role ?? defaultRole,
    };
  }

  static void logFromHelperJson(Map<String, dynamic> body) {
    final id = body['endpoint_id'] as String? ?? '';
    final role = body['endpoint_role'] as String? ?? '';
    final vol = body['endpoint_volume'];
    final console = body['console_default_device'] as String? ?? '—';
    final comm = body['communications_default_device'] as String? ?? '—';
    if (id.isNotEmpty) {
      DesktopVoicePipeline.mark('DESKTOP_VOICE_ENDPOINT_ID_LOGGED', id);
    }
    if (role.isNotEmpty) {
      DesktopVoicePipeline.mark(markerRoleSelected, role);
      DesktopVoicePipeline.mark(markerEndpointSelected, role);
    }
    if (vol is num) {
      DesktopVoicePipeline.mark(
        'DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED',
        vol.toStringAsFixed(3),
      );
    }
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_DEFAULT_CONSOLE_DEVICE_LOGGED',
      console,
    );
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_DEFAULT_COMMUNICATIONS_DEVICE_LOGGED',
      comm,
    );
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_CAPTURE_MIX_FORMAT_LOGGED',
      '${body['mix_sample_rate'] ?? '—'}Hz '
      '${body['mix_channels'] ?? '—'}ch '
      '${body['mix_sample_format'] ?? '—'}',
    );
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_SELECTED_CAPTURE_ENDPOINT_LOGGED',
      '${body['device_name'] ?? body['selected_device_name'] ?? '—'}',
    );
    DesktopVoicePipeline.mark(
      'DESKTOP_VOICE_COUNTER_HANDY_DEVICE_DIFFS_LOGGED',
      'console=$console communications=$comm',
    );
  }
}

/// Parsed endpoint snapshot from helper `/capture/*` responses.
class DesktopVoiceCaptureEndpointSnapshot {
  const DesktopVoiceCaptureEndpointSnapshot({
    this.endpointId,
    this.endpointRole,
    this.endpointVolume,
    this.endpointMuted,
    this.sessionVolume,
    this.consoleDefaultDevice,
    this.communicationsDefaultDevice,
    this.mixSampleRate,
    this.mixChannels,
    this.mixSampleFormat,
    this.enhancementsNotes,
    this.rawCaptureLikelyBypassesEnhancements,
    this.captureGainMode,
    this.captureGainDb,
    this.agcEnabled,
    this.limiterEnabled,
    this.clippedSamples,
    this.selectedGainReason,
  });

  final String? endpointId;
  final String? endpointRole;
  final double? endpointVolume;
  final bool? endpointMuted;
  final double? sessionVolume;
  final String? consoleDefaultDevice;
  final String? communicationsDefaultDevice;
  final int? mixSampleRate;
  final int? mixChannels;
  final String? mixSampleFormat;
  final String? enhancementsNotes;
  final bool? rawCaptureLikelyBypassesEnhancements;
  final String? captureGainMode;
  final double? captureGainDb;
  final bool? agcEnabled;
  final bool? limiterEnabled;
  final int? clippedSamples;
  final String? selectedGainReason;

  static DesktopVoiceCaptureEndpointSnapshot? fromJson(Map<String, dynamic>? body) {
    if (body == null) return null;
    return DesktopVoiceCaptureEndpointSnapshot(
      endpointId: body['endpoint_id'] as String?,
      endpointRole: body['endpoint_role'] as String?,
      endpointVolume: (body['endpoint_volume'] as num?)?.toDouble(),
      endpointMuted: body['endpoint_muted'] as bool?,
      sessionVolume: (body['session_volume'] as num?)?.toDouble(),
      consoleDefaultDevice: body['console_default_device'] as String?,
      communicationsDefaultDevice:
          body['communications_default_device'] as String?,
      mixSampleRate: (body['mix_sample_rate'] as num?)?.toInt(),
      mixChannels: (body['mix_channels'] as num?)?.toInt(),
      mixSampleFormat: body['mix_sample_format'] as String?,
      enhancementsNotes: body['enhancements_notes'] as String?,
      rawCaptureLikelyBypassesEnhancements:
          body['raw_capture_likely_bypasses_enhancements'] as bool?,
      captureGainMode: body['capture_gain_mode'] as String?,
      captureGainDb: (body['capture_gain_db'] as num?)?.toDouble(),
      agcEnabled: body['agc_enabled'] as bool?,
      limiterEnabled: body['limiter_enabled'] as bool?,
      clippedSamples: (body['clipped_samples'] as num?)?.toInt(),
      selectedGainReason: body['selected_gain_reason'] as String?,
    );
  }
}
