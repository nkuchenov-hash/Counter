
export 'package:counter/shared/voice/recognition/desktop_voice_recognizer.dart';
export 'package:counter/shared/voice/recognition/desktop_voice_recognizer_stub.dart'
    if (dart.library.io) 'package:counter/shared/voice/platforms/desktop/desktop_voice_recognizer_io.dart'
    show createDesktopVoiceRecognizer;
