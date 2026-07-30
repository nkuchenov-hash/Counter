from __future__ import annotations

from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one anchor, found {count}: {old[:120]!r}")
    write(path, content.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Pure audio value object. Stored inside the existing notes_delta envelope.
# ---------------------------------------------------------------------------
write(
    "lib/data/models/note_audio_types.dart",
    dedent(
        r'''// Part of lib/data/models.dart — persisted Notes audio value objects.
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
'''
    ),
)

replace_once(
    "lib/data/models.dart",
    "part 'models/note_rich_types.dart';\npart 'models/note_document.dart';",
    "part 'models/note_rich_types.dart';\npart 'models/note_audio_types.dart';\npart 'models/note_document.dart';",
)

# ---------------------------------------------------------------------------
# Extend the v2 document envelope without changing PocketBase schema/version.
# ---------------------------------------------------------------------------
replace_once(
    "lib/data/models/note_document.dart",
    "/// Guards against runaway base64 image/drawing payloads.\nconst int kLifeOsNotesMaxPayloadBytes = 4 * 1024 * 1024;\nconst int kLifeOsNotesMaxAssetBytes = 2 * 1024 * 1024;",
    "/// Guards against runaway base64 image/drawing/audio payloads.\nconst int kLifeOsNotesMaxPayloadBytes = 4 * 1024 * 1024;\nconst int kLifeOsNotesMaxAssetBytes = 2 * 1024 * 1024;\nconst int kLifeOsNotesMaxAudioBytes = kLifeOsNotesMaxAssetBytes;",
)
replace_once(
    "lib/data/models/note_document.dart",
    "  image,\n  drawing,\n  linkCard,",
    "  image,\n  drawing,\n  audio,\n  linkCard,",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      case 'drawing':\n        return NoteBlockType.drawing;\n      case 'linkCard':",
    "      case 'drawing':\n        return NoteBlockType.drawing;\n      case 'audio':\n      case 'audioRecording':\n      case 'audio_recording':\n        return NoteBlockType.audio;\n      case 'linkCard':",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      case NoteBlockType.image:\n      case NoteBlockType.drawing:\n      case NoteBlockType.linkCard:",
    "      case NoteBlockType.image:\n      case NoteBlockType.drawing:\n      case NoteBlockType.audio:\n      case NoteBlockType.linkCard:",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    this.drawingData,\n    this.caption,",
    "    this.drawingData,\n    this.audio,\n    this.caption,",
)
replace_once(
    "lib/data/models/note_document.dart",
    "  final String? imageData;\n  final String? drawingData;\n  final String? caption;",
    "  final String? imageData;\n  final String? drawingData;\n  final NoteAudioData? audio;\n  final String? caption;",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    Object? drawingData = _sentinel,\n    Object? caption = _sentinel,",
    "    Object? drawingData = _sentinel,\n    Object? audio = _sentinel,\n    Object? caption = _sentinel,",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      drawingData: identical(drawingData, _sentinel)\n          ? this.drawingData\n          : drawingData as String?,\n      caption:",
    "      drawingData: identical(drawingData, _sentinel)\n          ? this.drawingData\n          : drawingData as String?,\n      audio: identical(audio, _sentinel)\n          ? this.audio\n          : audio as NoteAudioData?,\n      caption:",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    if (type == NoteBlockType.drawing && drawingData != null) {\n      json['drawingData'] = drawingData;\n    }\n    if ((type == NoteBlockType.image || type == NoteBlockType.drawing) &&",
    "    if (type == NoteBlockType.drawing && drawingData != null) {\n      json['drawingData'] = drawingData;\n    }\n    if (type == NoteBlockType.audio && audio != null) {\n      json['audio'] = audio!.toJson();\n    }\n    if ((type == NoteBlockType.image || type == NoteBlockType.drawing) &&",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    final linkRaw = json['link'];\n    final referenceRaw = json['reference'];",
    "    final linkRaw = json['link'];\n    final audioRaw = json['audio'];\n    final referenceRaw = json['reference'];",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      drawingData: _cleanJsonString(json['drawingData']),\n      caption:",
    "      drawingData: _cleanJsonString(json['drawingData']),\n      audio: audioRaw is Map<String, dynamic>\n          ? NoteAudioData.fromJson(audioRaw)\n          : null,\n      caption:",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      case NoteBlockType.drawing:\n        return (block.drawingData ?? '').isEmpty;\n      case NoteBlockType.linkCard:",
    "      case NoteBlockType.drawing:\n        return (block.drawingData ?? '').isEmpty;\n      case NoteBlockType.audio:\n        return (block.audio?.dataUrl ?? '').isEmpty;\n      case NoteBlockType.linkCard:",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      } else if (block.type == NoteBlockType.linkCard) {",
    "      } else if (block.type == NoteBlockType.audio) {\n        text = block.audio?.transcript?.trim() ?? '';\n      } else if (block.type == NoteBlockType.linkCard) {",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    var hasDrawing = false;\n    for (final block in blocks) {",
    "    var hasDrawing = false;\n    var hasAudio = false;\n    for (final block in blocks) {",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      } else if (block.type == NoteBlockType.drawing) {\n        hasDrawing = true;\n      }\n    }",
    "      } else if (block.type == NoteBlockType.drawing) {\n        hasDrawing = true;\n      } else if (block.type == NoteBlockType.audio) {\n        hasAudio = true;\n      }\n    }",
)
replace_once(
    "lib/data/models/note_document.dart",
    "      hasDrawing: hasDrawing,\n      blockCount: blocks.length,",
    "      hasDrawing: hasDrawing,\n      hasAudio: hasAudio,\n      blockCount: blocks.length,",
)
replace_once(
    "lib/data/models/note_document.dart",
    "    required this.hasDrawing,\n    required this.blockCount,",
    "    required this.hasDrawing,\n    this.hasAudio = false,\n    required this.blockCount,",
)
replace_once(
    "lib/data/models/note_document.dart",
    "  final bool hasDrawing;\n  final int blockCount;",
    "  final bool hasDrawing;\n  final bool hasAudio;\n  final int blockCount;",
)

# ---------------------------------------------------------------------------
# Brain-owned freeform transcription through the existing app-owned endpoint.
# The route already accepts command_mode; Notes uses false and no glossary.
# ---------------------------------------------------------------------------
replace_once(
    "lib/data/plans/notes_brain_helpers.dart",
    "  /// Creates a new empty note (plan) and returns the row id for editing.",
    dedent(
        r'''  /// Sends a persisted WAV audio block to the app-owned transcription route.
  /// No client vendor SDK or secret is used. The original audio stays playable
  /// when this method throws or the server returns an empty transcript.
  Future<String> transcribeNoteAudio(NoteAudioData audio) async {
    final payload = audio.dataUrl.trim();
    final comma = payload.indexOf(',');
    final audioBase64 = payload.startsWith('data:') && comma >= 0
        ? payload.substring(comma + 1)
        : payload;
    if (audioBase64.isEmpty) throw StateError('audio_missing');

    await ensurePocketBaseReady();
    final token = pocketBase.authStore.token.trim();
    if (token.isEmpty) throw StateError('auth_required');

    final base = kPocketBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base${PbAppApiRoutes.aiTranscribeCommand}');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'audio_base64': audioBase64,
            'language_hint': currentLocale.value,
            'command_mode': false,
            'glossary_terms': const <String>[],
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('transcript_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('transcript_invalid_response');
    final map = Map<String, dynamic>.from(decoded);
    final serverError = map['error']?.toString().trim() ?? '';
    if (serverError.isNotEmpty) throw StateError(serverError);
    final transcript = (map['raw_transcript'] ?? map['transcript'] ?? '')
        .toString()
        .trim();
    if (transcript.isEmpty) throw StateError('empty_transcript');
    return transcript;
  }

  /// Creates a new empty note (plan) and returns the row id for editing.
'''
    ),
)

# ---------------------------------------------------------------------------
# Cross-platform Notes recorder/playback. PCM16 stream is wrapped into WAV and
# stored in the existing note document; audioplayers handles bytes playback.
# ---------------------------------------------------------------------------
write(
    "lib/features/notes/notes_audio_controller.dart",
    dedent(
        r'''import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:counter/core/widgets/app_button.dart';
import 'package:counter/data/models.dart';
import 'package:counter/features/notes/widgets/notes_canonical_components.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

const int _notesAudioSampleRate = 16000;
const int _notesAudioChannels = 1;
const int _notesAudioBytesPerSample = 2;

Future<NoteAudioData?> showNotesAudioRecorder({
  required BuildContext context,
}) {
  return showModalBottomSheet<NoteAudioData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _NotesAudioRecorderSheet(),
  );
}

class _NotesAudioRecorderSheet extends StatefulWidget {
  const _NotesAudioRecorderSheet();

  @override
  State<_NotesAudioRecorderSheet> createState() =>
      _NotesAudioRecorderSheetState();
}

class _NotesAudioRecorderSheetState extends State<_NotesAudioRecorderSheet> {
  late final NotesAudioRecorderSession _session;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _session = NotesAudioRecorderSession()..addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    if (_session.limitReached && !_finishing) {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    await _session.start();
  }

  Future<void> _stop() async {
    if (_finishing) return;
    _finishing = true;
    final audio = await _session.stop();
    if (!mounted) return;
    _finishing = false;
    if (audio == null) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(audio);
  }

  Future<void> _discard() async {
    await _session.discard();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = currentLocale.value;
    final status = _session.errorMessage ?? switch (_session.state) {
      NotesRecorderState.ready => t(loc, 'notes_audio_ready'),
      NotesRecorderState.recording => t(loc, 'notes_audio_recording'),
      NotesRecorderState.paused => t(loc, 'notes_audio_paused'),
      NotesRecorderState.permissionBlocked =>
        t(loc, 'notes_audio_permission_blocked'),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: NotesRecorderControls(
        state: _session.state,
        statusLabel: status,
        startLabel: t(loc, 'notes_audio_start'),
        pauseLabel: t(loc, 'notes_audio_pause'),
        resumeLabel: t(loc, 'notes_audio_resume'),
        stopLabel: t(loc, 'notes_audio_stop'),
        discardLabel: t(loc, 'notes_audio_discard'),
        openSettingsLabel: t(loc, 'notes_audio_open_settings'),
        durationLabel: formatNotesAudioDuration(_session.elapsedMs),
        levelIndicator: LinearProgressIndicator(value: _session.level),
        onStart: _finishing ? null : _start,
        onPause: _finishing ? null : _session.pause,
        onResume: _finishing ? null : _session.resume,
        onStop: _finishing ? null : _stop,
        onDiscard: _finishing ? null : _discard,
        onOpenSettings: openAppSettings,
      ),
    );
  }
}

class NotesAudioRecorderSession extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final List<int> _pcm = <int>[];
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _ticker;
  NotesRecorderState state = NotesRecorderState.ready;
  double level = 0;
  bool limitReached = false;
  String? errorMessage;
  bool _disposed = false;

  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  Future<void> start() async {
    errorMessage = null;
    limitReached = false;
    _pcm.clear();
    try {
      if (!await _recorder.hasPermission()) {
        state = NotesRecorderState.permissionBlocked;
        notifyListeners();
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _notesAudioSampleRate,
          numChannels: _notesAudioChannels,
        ),
      );
      _audioSubscription = stream.listen(
        _onAudio,
        onError: (Object error, StackTrace stackTrace) {
          errorMessage = error.toString();
          unawaited(discard(resetState: true));
        },
      );
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen((amplitude) {
            final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
            level = normalized.toDouble();
            notifyListeners();
          });
      _stopwatch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => notifyListeners(),
      );
      state = NotesRecorderState.recording;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      state = NotesRecorderState.ready;
      notifyListeners();
    }
  }

  void _onAudio(Uint8List bytes) {
    if (bytes.isEmpty || limitReached) return;
    if (_pcm.length + bytes.length + 44 > kLifeOsNotesMaxAudioBytes) {
      limitReached = true;
      notifyListeners();
      return;
    }
    _pcm.addAll(bytes);
  }

  Future<void> pause() async {
    if (state != NotesRecorderState.recording) return;
    try {
      await _recorder.pause();
      _stopwatch.stop();
      state = NotesRecorderState.paused;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (state != NotesRecorderState.paused) return;
    try {
      await _recorder.resume();
      _stopwatch.start();
      state = NotesRecorderState.recording;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<NoteAudioData?> stop() async {
    if (state != NotesRecorderState.recording &&
        state != NotesRecorderState.paused) {
      return null;
    }
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _audioSubscription = null;
    _amplitudeSubscription = null;
    level = 0;
    state = NotesRecorderState.ready;
    if (_pcm.isEmpty) {
      errorMessage = t(currentLocale.value, 'notes_audio_empty_recording');
      notifyListeners();
      return null;
    }
    final wav = buildNotesPcm16Wav(
      Uint8List.fromList(_pcm),
      sampleRate: _notesAudioSampleRate,
      channels: _notesAudioChannels,
    );
    if (wav.lengthInBytes > kLifeOsNotesMaxAudioBytes) {
      errorMessage = t(currentLocale.value, 'notes_audio_too_large');
      notifyListeners();
      return null;
    }
    final durationMs = (_pcm.length * 1000) ~/
        (_notesAudioSampleRate *
            _notesAudioChannels *
            _notesAudioBytesPerSample);
    notifyListeners();
    return NoteAudioData(
      dataUrl: 'data:audio/wav;base64,${base64Encode(wav)}',
      durationMs: durationMs,
    );
  }

  Future<void> discard({bool resetState = false}) async {
    _stopwatch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _audioSubscription = null;
    _amplitudeSubscription = null;
    _pcm.clear();
    level = 0;
    limitReached = false;
    if (!resetState) errorMessage = null;
    state = NotesRecorderState.ready;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    unawaited(_audioSubscription?.cancel());
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }
}

class NotesAudioPlaybackController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  String? playingBlockId;
  bool _paused = false;

  NotesAudioPlaybackController() {
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      playingBlockId = null;
      _paused = false;
      notifyListeners();
    });
  }

  bool isPlaying(String blockId) => playingBlockId == blockId && !_paused;

  Future<void> toggle(String blockId, NoteAudioData audio) async {
    if (playingBlockId == blockId) {
      if (_paused) {
        await _player.resume();
        _paused = false;
      } else {
        await _player.pause();
        _paused = true;
      }
      notifyListeners();
      return;
    }
    final bytes = decodeNotesDataUrl(audio.dataUrl);
    if (bytes == null || bytes.isEmpty) return;
    await _player.stop();
    playingBlockId = blockId;
    _paused = false;
    notifyListeners();
    try {
      await _player.play(BytesSource(bytes, mimeType: audio.mimeType));
    } catch (_) {
      playingBlockId = null;
      _paused = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    playingBlockId = null;
    _paused = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_completeSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}

Future<void> showNotesTranscriptDialog({
  required BuildContext context,
  required NoteAudioData audio,
  required NotesAudioState playbackState,
  required VoidCallback onPlayPause,
  VoidCallback? onRetry,
}) {
  final loc = currentLocale.value;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.24),
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: NotesTranscriptSurface(
        title: t(loc, 'notes_audio_transcript_title'),
        transcript: audio.transcript ?? '',
        emptyLabel: audio.transcriptStatus == NoteAudioTranscriptStatus.error
            ? t(loc, 'notes_audio_transcript_error')
            : t(loc, 'notes_audio_transcript_empty'),
        copyLabel: t(loc, 'notes_audio_copy_transcript'),
        doneLabel: t(loc, 'notes_v3_editor_done'),
        retryLabel: audio.transcriptStatus == NoteAudioTranscriptStatus.error
            ? t(loc, 'notes_audio_retry_transcript')
            : null,
        onRetry: onRetry,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: audio.transcript ?? ''));
        },
        onDone: () => Navigator.of(dialogContext).pop(),
        playbackContext: NotesAudioBlock(
          state: playbackState,
          title: t(loc, 'notes_audio_title'),
          statusLabel: t(loc, 'notes_audio_ready'),
          playTooltip: t(loc, 'notes_audio_play'),
          pauseTooltip: t(loc, 'notes_audio_pause'),
          transcriptTooltip: t(loc, 'notes_audio_transcript_title'),
          durationLabel: formatNotesAudioDuration(audio.durationMs),
          onPlayPause: onPlayPause,
        ),
      ),
    ),
  );
}

Uint8List? decodeNotesDataUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final comma = value.indexOf(',');
  final encoded = value.startsWith('data:') && comma >= 0
      ? value.substring(comma + 1)
      : value;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

Uint8List buildNotesPcm16Wav(
  Uint8List pcm, {
  required int sampleRate,
  required int channels,
}) {
  final byteRate = sampleRate * channels * _notesAudioBytesPerSample;
  final blockAlign = channels * _notesAudioBytesPerSample;
  final output = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(output);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      output[offset + index] = value.codeUnitAt(index);
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  output.setRange(44, output.length, pcm);
  return output;
}

String formatNotesAudioDuration(int durationMs) {
  final totalSeconds = (durationMs / 1000)
      .round()
      .clamp(0, 24 * 60 * 60)
      .toInt();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
'''
    ),
)

# Canonical transcript surface gets one optional retry action.
replace_once(
    "lib/features/notes/widgets/notes_component_media_blocks.dart",
    "    this.playbackContext,\n    this.emptyLabel,",
    "    this.playbackContext,\n    this.emptyLabel,\n    this.retryLabel,\n    this.onRetry,",
)
replace_once(
    "lib/features/notes/widgets/notes_component_media_blocks.dart",
    "  final Widget? playbackContext;\n  final String? emptyLabel;",
    "  final Widget? playbackContext;\n  final String? emptyLabel;\n  final String? retryLabel;\n  final VoidCallback? onRetry;",
)
replace_once(
    "lib/features/notes/widgets/notes_component_media_blocks.dart",
    "                children: [\n                  AppButton.secondary(",
    "                children: [\n                  if (retryLabel != null && onRetry != null)\n                    AppButton.outlined(\n                      label: retryLabel!,\n                      icon: Icons.refresh_rounded,\n                      size: AppButtonSize.s,\n                      onPressed: onRetry,\n                    ),\n                  AppButton.secondary(",
)

# Controller creates/updates audio as another visible production block.
replace_once(
    "lib/features/notes/notes_editor_document_controller.dart",
    "    String? drawingData,\n    String? caption,",
    "    String? drawingData,\n    NoteAudioData? audio,\n    String? caption,",
)
replace_once(
    "lib/features/notes/notes_editor_document_controller.dart",
    "      drawingData: type == NoteBlockType.drawing ? drawingData : null,\n      caption:",
    "      drawingData: type == NoteBlockType.drawing ? drawingData : null,\n      audio: type == NoteBlockType.audio ? audio : null,\n      caption:",
)
replace_once(
    "lib/features/notes/notes_editor_document_controller.dart",
    "  NotesEditorMutation deleteBlock(String id) {",
    dedent(
        r'''  NotesEditorMutation updateAudio(String id, NoteAudioData audio) {
    final block = blockById(id);
    if (block == null || block.type != NoteBlockType.audio) {
      return const NotesEditorMutation();
    }
    _replaceBlock(block.copyWith(audio: audio));
    activeBlockId = id;
    return const NotesEditorMutation(
      changed: true,
      requiresRebuild: true,
    );
  }

  NotesEditorMutation deleteBlock(String id) {
'''
    ),
)
replace_once(
    "lib/features/notes/notes_editor_document_controller.dart",
    "        type == NoteBlockType.image ||\n        type == NoteBlockType.drawing;",
    "        type == NoteBlockType.image ||\n        type == NoteBlockType.drawing ||\n        type == NoteBlockType.audio;",
)

# Production row composes the existing canonical NotesAudioBlock.
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "    this.onEmptyLongPress,\n  });",
    "    this.onEmptyLongPress,\n    this.audioState = NotesAudioState.ready,\n    this.onAudioPlayPause,\n    this.onOpenTranscript,\n  });",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "  final VoidCallback? onEmptyLongPress;",
    "  final VoidCallback? onEmptyLongPress;\n  final NotesAudioState audioState;\n  final VoidCallback? onAudioPlayPause;\n  final VoidCallback? onOpenTranscript;",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "      case NoteBlockType.image:\n      case NoteBlockType.drawing:",
    "      case NoteBlockType.image:\n      case NoteBlockType.drawing:",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "          onTap: onTap,\n        );\n      case NoteBlockType.callout:",
    dedent(
        r'''          onTap: onTap,
        );
      case NoteBlockType.audio:
        final loc = currentLocale.value;
        final audio = block.audio;
        final statusLabel = switch (audioState) {
          NotesAudioState.playing => t(loc, 'notes_audio_playing'),
          NotesAudioState.transcribing => t(loc, 'notes_audio_transcribing'),
          NotesAudioState.transcriptError =>
            t(loc, 'notes_audio_transcript_error'),
          NotesAudioState.ready => audio?.transcriptStatus ==
                  NoteAudioTranscriptStatus.ready
              ? t(loc, 'notes_audio_transcript_ready')
              : t(loc, 'notes_audio_ready'),
        };
        return NotesAudioBlock(
          state: audioState,
          title: t(loc, 'notes_audio_title'),
          statusLabel: statusLabel,
          playTooltip: t(loc, 'notes_audio_play'),
          pauseTooltip: t(loc, 'notes_audio_pause'),
          transcriptTooltip: t(loc, 'notes_audio_transcript_title'),
          durationLabel: formatNotesAudioDuration(audio?.durationMs ?? 0),
          onPlayPause: onAudioPlayPause,
          onOpenTranscript: onOpenTranscript,
        );
      case NoteBlockType.callout:
'''
    ),
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "import 'package:counter/features/notes/widgets/notes_canonical_components.dart';",
    "import 'package:counter/features/notes/notes_audio_controller.dart';\nimport 'package:counter/features/notes/widgets/notes_canonical_components.dart';\nimport 'package:counter/l10n/dictionary.dart';",
)
replace_once(
    "lib/features/notes/widgets/note_editor_block_widgets.dart",
    "      type == NoteBlockType.image ||\n      type == NoteBlockType.drawing;",
    "      type == NoteBlockType.image ||\n      type == NoteBlockType.drawing ||\n      type == NoteBlockType.audio;",
)

# Toolbar and empty-line insert menu expose audio, image, and drawing.
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "          tooltip: 'Record audio',\n          enabled: onAudio != null,",
    "          tooltip: type == NoteBlockType.audio\n              ? 'Record another audio'\n              : 'Record audio',\n          selected: type == NoteBlockType.audio,\n          enabled: onAudio != null,",
)
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "  required VoidCallback onTable,\n  required VoidCallback onDivider,\n}) {",
    "  required VoidCallback onTable,\n  required VoidCallback onDivider,\n  VoidCallback? onDrawing,\n  VoidCallback? onImage,\n  VoidCallback? onAudio,\n}) {",
)
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "            _menuAction(\n              dialogContext,\n              Icons.format_quote_rounded,",
    "            if (onDrawing != null)\n              _menuAction(\n                dialogContext,\n                Icons.draw_rounded,\n                'Drawing',\n                onDrawing,\n              ),\n            if (onImage != null)\n              _menuAction(\n                dialogContext,\n                Icons.image_rounded,\n                'Image',\n                onImage,\n              ),\n            _menuAction(\n              dialogContext,\n              Icons.format_quote_rounded,",
)
replace_once(
    "lib/features/notes/widgets/notes_editor_tools.dart",
    "            _menuAction(\n              dialogContext,\n              Icons.horizontal_rule_rounded,",
    "            if (onAudio != null)\n              _menuAction(\n                dialogContext,\n                Icons.mic_rounded,\n                'Audio record',\n                onAudio,\n              ),\n            _menuAction(\n              dialogContext,\n              Icons.horizontal_rule_rounded,",
)

# Editor orchestration: recorder, playback, async transcription, transcript UI.
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "import 'package:counter/features/notes/drawing_canvas_page.dart';",
    "import 'package:counter/features/notes/drawing_canvas_page.dart';\nimport 'package:counter/features/notes/notes_audio_controller.dart';",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "  final Map<String, TextSelection> _lastSelections = {};\n  bool _dirty = false;",
    "  final Map<String, TextSelection> _lastSelections = {};\n  late final NotesAudioPlaybackController _audioPlayback;\n  final Set<String> _transcribingAudioIds = <String>{};\n  bool _dirty = false;",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "    _gate = EditSheetAutosaveGate();\n    _syncEditorsWithDocument();",
    "    _gate = EditSheetAutosaveGate();\n    _audioPlayback = NotesAudioPlaybackController()\n      ..addListener(_onAudioPlaybackChanged);\n    _syncEditorsWithDocument();",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "    _gate.dispose();\n    _titleController.dispose();",
    "    _gate.dispose();\n    _audioPlayback\n      ..removeListener(_onAudioPlaybackChanged)\n      ..dispose();\n    _titleController.dispose();",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "  void _scheduleSave([String? _]) {",
    "  void _onAudioPlaybackChanged() {\n    if (mounted) setState(() {});\n  }\n\n  void _scheduleSave([String? _]) {",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "      onDivider: () => _insertAfter(anchorId, NoteBlockType.divider),\n    );",
    "      onDivider: () => _insertAfter(anchorId, NoteBlockType.divider),\n      onDrawing: widget.parityPreview ? null : () => _openDrawing(),\n      onImage: widget.parityPreview ? null : () => _pickImage(),\n      onAudio: widget.parityPreview ? null : _recordAudio,\n    );",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "  Future<void> _showActiveBlockOptions() {",
    dedent(
        r'''  Future<void> _recordAudio() async {
    if (widget.parityPreview) return;
    final audio = await showNotesAudioRecorder(context: context);
    if (!mounted || audio == null) return;
    final mutation = _editor.insertAfter(
      _editor.activeBlockId,
      NoteBlockType.audio,
      audio: audio,
    );
    _applyMutation(mutation);
    final blockId = _editor.activeBlockId;
    if (blockId != null) unawaited(_transcribeAudio(blockId));
  }

  Future<void> _toggleAudio(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null) return;
    try {
      await _audioPlayback.toggle(blockId, audio);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLocale.value, 'notes_audio_play_failed'))),
      );
    }
  }

  NotesAudioState _audioState(String blockId) {
    if (_transcribingAudioIds.contains(blockId)) {
      return NotesAudioState.transcribing;
    }
    if (_audioPlayback.isPlaying(blockId)) return NotesAudioState.playing;
    final audio = _editor.blockById(blockId)?.audio;
    if (audio?.transcriptStatus == NoteAudioTranscriptStatus.error) {
      return NotesAudioState.transcriptError;
    }
    return NotesAudioState.ready;
  }

  Future<void> _transcribeAudio(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null || _transcribingAudioIds.contains(blockId)) return;
    setState(() => _transcribingAudioIds.add(blockId));
    try {
      final transcript = await DatabaseService.instance.transcribeNoteAudio(audio);
      if (!mounted) return;
      _applyMutation(
        _editor.updateAudio(
          blockId,
          audio.copyWith(
            transcript: transcript,
            transcriptStatus: NoteAudioTranscriptStatus.ready,
            transcriptError: null,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _applyMutation(
        _editor.updateAudio(
          blockId,
          audio.copyWith(
            transcriptStatus: NoteAudioTranscriptStatus.error,
            transcriptError: error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _transcribingAudioIds.remove(blockId));
    }
  }

  Future<void> _openAudioTranscript(String blockId) async {
    final audio = _editor.blockById(blockId)?.audio;
    if (audio == null) return;
    await showNotesTranscriptDialog(
      context: context,
      audio: audio,
      playbackState: _audioState(blockId),
      onPlayPause: () => _toggleAudio(blockId),
      onRetry: () {
        Navigator.of(context).pop();
        _transcribeAudio(blockId);
      },
    );
  }

  Future<void> _showActiveBlockOptions() {
'''
    ),
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "      onEmptyLongPress: editable && block.effectiveText.isEmpty\n          ? () => _showInsertMenu(block.id)\n          : null,",
    "      onEmptyLongPress: editable && block.effectiveText.isEmpty\n          ? () => _showInsertMenu(block.id)\n          : null,\n      audioState: block.type == NoteBlockType.audio\n          ? _audioState(block.id)\n          : NotesAudioState.ready,\n      onAudioPlayPause: block.type == NoteBlockType.audio\n          ? () => _toggleAudio(block.id)\n          : null,\n      onOpenTranscript: block.type == NoteBlockType.audio\n          ? () => _openAudioTranscript(block.id)\n          : null,",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "            onImage: widget.parityPreview\n                ? null",
    "            onAudio: widget.parityPreview ? null : _recordAudio,\n            onImage: widget.parityPreview\n                ? null",
)
replace_once(
    "lib/features/notes/note_editor_page.dart",
    "import 'dart:convert';",
    "import 'dart:async';\nimport 'dart:convert';",
)

# Dependency. pub get in CI regenerates pubspec.lock.
replace_once(
    "pubspec.yaml",
    "  record: ^6.0.0\n  tray_manager:",
    "  record: ^6.0.0\n  audioplayers: ^6.8.1\n  tray_manager:",
)

# App-owned route contract: command_mode=false is freeform Notes transcription.
replace_once(
    "docs/POCKETBASE_MANIFEST.md",
    "- `POST /api/ai/parse-task` — optional structured parsing for voice/plan text; implemented behind the reverse proxy. Client calls `DatabaseService.parseTaskViaAiBackend` only (no vendor-specific SDKs).",
    "- `POST /api/ai/parse-task` — optional structured parsing for voice/plan text; implemented behind the reverse proxy. Client calls `DatabaseService.parseTaskViaAiBackend` only (no vendor-specific SDKs).\n- `POST /api/ai/transcribe-command` — authenticated audio transcription. `command_mode: true` serves Desktop Voice; `command_mode: false` serves freeform Notes audio and returns `raw_transcript` or `transcript`. Audio remains stored/playable if transcription fails.",
)

# Localization. Keep the existing test count; no new test file.
en_audio = dedent(
    r'''  'notes_audio_title': 'Audio recording',
  'notes_audio_ready': 'Ready',
  'notes_audio_recording': 'Recording…',
  'notes_audio_paused': 'Paused',
  'notes_audio_playing': 'Playing',
  'notes_audio_permission_blocked': 'Microphone permission is blocked',
  'notes_audio_start': 'Start',
  'notes_audio_pause': 'Pause',
  'notes_audio_resume': 'Resume',
  'notes_audio_stop': 'Stop',
  'notes_audio_discard': 'Discard',
  'notes_audio_open_settings': 'Open settings',
  'notes_audio_play': 'Play audio',
  'notes_audio_play_failed': 'Could not play this recording.',
  'notes_audio_transcribing': 'Transcribing…',
  'notes_audio_transcript_title': 'Transcript',
  'notes_audio_transcript_ready': 'Transcript ready',
  'notes_audio_transcript_error': 'Transcript failed. Audio is still available.',
  'notes_audio_transcript_empty': 'No transcript yet.',
  'notes_audio_copy_transcript': 'Copy transcript',
  'notes_audio_retry_transcript': 'Retry transcription',
  'notes_audio_empty_recording': 'No audio was captured.',
  'notes_audio_too_large': 'Recording reached the 2 MB note limit.',
'''
)
ru_audio = dedent(
    r'''  'notes_audio_title': 'Аудиозапись',
  'notes_audio_ready': 'Готово',
  'notes_audio_recording': 'Идёт запись…',
  'notes_audio_paused': 'Пауза',
  'notes_audio_playing': 'Воспроизведение',
  'notes_audio_permission_blocked': 'Доступ к микрофону заблокирован',
  'notes_audio_start': 'Начать',
  'notes_audio_pause': 'Пауза',
  'notes_audio_resume': 'Продолжить',
  'notes_audio_stop': 'Остановить',
  'notes_audio_discard': 'Удалить запись',
  'notes_audio_open_settings': 'Открыть настройки',
  'notes_audio_play': 'Воспроизвести аудио',
  'notes_audio_play_failed': 'Не удалось воспроизвести запись.',
  'notes_audio_transcribing': 'Расшифровка…',
  'notes_audio_transcript_title': 'Расшифровка',
  'notes_audio_transcript_ready': 'Расшифровка готова',
  'notes_audio_transcript_error': 'Расшифровка не удалась. Аудио сохранено.',
  'notes_audio_transcript_empty': 'Расшифровки пока нет.',
  'notes_audio_copy_transcript': 'Копировать текст',
  'notes_audio_retry_transcript': 'Повторить расшифровку',
  'notes_audio_empty_recording': 'Звук не был записан.',
  'notes_audio_too_large': 'Запись достигла лимита заметки 2 МБ.',
'''
)
replace_once(
    "lib/l10n/langs/en.dart",
    "  // Drawing\n  'notes_drawing_title': 'Drawing',",
    en_audio + "\n  // Drawing\n  'notes_drawing_title': 'Drawing',",
)
replace_once(
    "lib/l10n/langs/ru.dart",
    "  // Drawing\n  'notes_drawing_title': 'Рисунок',",
    ru_audio + "\n  // Drawing\n  'notes_drawing_title': 'Рисунок',",
)

# Structure law exact-file inventory.
replace_once(
    "docs/APP_STRUCTURE.md",
    "| `models/note_rich_types.dart` | Notes v2 inline marks, text runs, table/callout/link/reference value objects (pure data) *(part)* |\n| `models/note_document.dart`",
    "| `models/note_rich_types.dart` | Notes v2 inline marks, text runs, table/callout/link/reference value objects (pure data) *(part)* |\n| `models/note_audio_types.dart` | Persisted Notes audio payload, duration, transcript status/error value object *(part)* |\n| `models/note_document.dart`",
)
replace_once(
    "docs/APP_STRUCTURE.md",
    "| `notes/drawing_canvas_page.dart` | Full-screen drawing canvas for image/drawing blocks (PNG data URL in/out) |\n| `notes/notes_editor_document_controller.dart`",
    "| `notes/drawing_canvas_page.dart` | Full-screen drawing canvas for image/drawing blocks (PNG data URL in/out) |\n| `notes/notes_audio_controller.dart` | Cross-platform in-memory PCM recorder, WAV codec, byte playback, recorder/transcript modal orchestration |\n| `notes/notes_editor_document_controller.dart`",
)
replace_once(
    "docs/APP_STRUCTURE.md",
    "| `notes/` | `drawing_canvas_page.dart`, `notes_editor_document_controller.dart`,",
    "| `notes/` | `drawing_canvas_page.dart`, `notes_audio_controller.dart`, `notes_editor_document_controller.dart`,",
)

# Extend the existing editor/model test, preserving exactly three tests total.
replace_once(
    "test/notes_canonical_components_test.dart",
    "    final legacy = NoteBlock(\n      id: 'legacy-reference',",
    dedent(
        r'''    const audio = NoteAudioData(
      dataUrl: 'data:audio/wav;base64,UklGRg==',
      durationMs: 1250,
      transcript: 'Recorded thought',
      transcriptStatus: NoteAudioTranscriptStatus.ready,
    );
    empty.insertAfter(
      empty.blocks.last.id,
      NoteBlockType.audio,
      audio: audio,
    );
    final audioBlock = empty.blocks.singleWhere(
      (block) => block.type == NoteBlockType.audio,
    );
    expect(audioBlock.audio?.durationMs, 1250);

    final legacy = NoteBlock(
      id: 'legacy-reference',
'''
    ),
)
replace_once(
    "test/notes_canonical_components_test.dart",
    "    expect(\n      saved.blocks\n          .singleWhere((block) => block.id == legacy.id)",
    "    expect(\n      saved.blocks\n          .singleWhere((block) => block.type == NoteBlockType.audio)\n          .audio\n          ?.transcript,\n      'Recorded thought',\n    );\n    expect(\n      saved.blocks\n          .singleWhere((block) => block.id == legacy.id)",
)

print('Notes audio phase patched successfully.')
