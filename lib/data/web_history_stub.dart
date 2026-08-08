import 'package:flutter/foundation.dart';

void clearOAuthParams() {}

/// Browser-only keyboard occlusion fallback. Native platforms use
/// MediaQuery.viewInsets and therefore expose zero here.
final ValueListenable<double> webVisualViewportBottomInset =
    ValueNotifier<double>(0);
