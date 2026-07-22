import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Mutable holder so [AppShell] can replace [SpeechToText] after Web STT errors
/// while an open [VoiceInputSheet] still reads the current engine via [speech].
final class SpeechEngineHandle {
  SpeechEngineHandle(this.speech);

  stt.SpeechToText speech;
}
