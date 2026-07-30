import 'dart:async';
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

Future<NoteAudioData?> showNotesAudioRecorder({required BuildContext context}) {
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
    final status =
        _session.errorMessage ??
        switch (_session.state) {
          NotesRecorderState.ready => t(loc, 'notes_audio_ready'),
          NotesRecorderState.recording => t(loc, 'notes_audio_recording'),
          NotesRecorderState.paused => t(loc, 'notes_audio_paused'),
          NotesRecorderState.permissionBlocked => t(
            loc,
            'notes_audio_permission_blocked',
          ),
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
    final durationMs =
        (_pcm.length * 1000) ~/
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
