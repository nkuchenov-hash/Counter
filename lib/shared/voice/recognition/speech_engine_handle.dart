import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Mutable holder so the recognition owner can replace [SpeechToText] after
/// recoverable STT failures while an open VoiceInputSheet keeps reading the
/// current engine through [speech].
final class SpeechEngineHandle {
  SpeechEngineHandle(this.speech);

  stt.SpeechToText speech;
}
