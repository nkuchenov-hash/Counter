import 'package:counter/core/services/desktop_voice_recognizer_stub.dart'
    if (dart.library.io) 'package:counter/core/services/desktop_voice_recognizer_io.dart';

export 'package:counter/core/services/desktop_voice_recognizer.dart';
export 'package:counter/core/services/desktop_voice_recognizer_stub.dart'
    if (dart.library.io) 'package:counter/core/services/desktop_voice_recognizer_io.dart'
    show createDesktopVoiceRecognizer;
