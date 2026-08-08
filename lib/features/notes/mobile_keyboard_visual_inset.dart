import 'package:flutter/foundation.dart';

export 'mobile_keyboard_visual_inset_stub.dart'
    if (dart.library.js_interop) 'mobile_keyboard_visual_inset_web.dart';

/// Browser-reported part of the screen hidden by a soft keyboard.
///
/// Native platforms expose zero here and continue to use MediaQuery.viewInsets.
ValueListenable<double> get notesMobileKeyboardVisualInset =>
    mobileKeyboardVisualInset;
