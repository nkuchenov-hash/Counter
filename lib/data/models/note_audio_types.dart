// Part of lib/data/models.dart — persisted Notes audio value objects.
// Pure data/serialization code. No UI, plugin, or PocketBase imports.

part of '../models.dart';

enum NoteAudioTranscriptStatus {
  none,
  ready,
  error;

  static NoteAudioTranscriptStatus fromString(String? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return NoteAudioTranscriptStatus.none;
  }
}

@immutable
class NoteAudioData {
  const NoteAudioData({
    required this.dataUrl,
    this.mimeType = 'audio/wav',
    this.durationMs = 0,
    this.transcript,
    this.transcriptStatus = NoteAudioTranscriptStatus.none,
    this.transcriptError,
  });

  final String dataUrl;
  final String mimeType;
  final int durationMs;
  final String? transcript;
  final NoteAudioTranscriptStatus transcriptStatus;
  final String? transcriptError;

  NoteAudioData copyWith({
    String? dataUrl,
    String? mimeType,
    int? durationMs,
    Object? transcript = _noteAudioUnset,
    NoteAudioTranscriptStatus? transcriptStatus,
    Object? transcriptError = _noteAudioUnset,
  }) {
    return NoteAudioData(
      dataUrl: dataUrl ?? this.dataUrl,
      mimeType: mimeType ?? this.mimeType,
      durationMs: durationMs ?? this.durationMs,
      transcript: identical(transcript, _noteAudioUnset)
          ? this.transcript
          : transcript as String?,
      transcriptStatus: transcriptStatus ?? this.transcriptStatus,
      transcriptError: identical(transcriptError, _noteAudioUnset)
          ? this.transcriptError
          : transcriptError as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'dataUrl': dataUrl,
    'mimeType': mimeType,
    'durationMs': durationMs,
    if (transcript != null) 'transcript': transcript,
    'transcriptStatus': transcriptStatus.name,
    if (transcriptError != null) 'transcriptError': transcriptError,
  };

  factory NoteAudioData.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['durationMs'];
    final duration = rawDuration is num
        ? rawDuration.toInt()
        : int.tryParse(rawDuration?.toString() ?? '') ?? 0;
    String? clean(Object? value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return NoteAudioData(
      dataUrl: clean(json['dataUrl'] ?? json['audioData']) ?? '',
      mimeType: clean(json['mimeType']) ?? 'audio/wav',
      durationMs: duration.clamp(0, 24 * 60 * 60 * 1000).toInt(),
      transcript: clean(json['transcript']),
      transcriptStatus: NoteAudioTranscriptStatus.fromString(
        json['transcriptStatus']?.toString(),
      ),
      transcriptError: clean(json['transcriptError']),
    );
  }
}

const Object _noteAudioUnset = Object();
