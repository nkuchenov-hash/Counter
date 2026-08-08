import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

final ValueListenable<double> mobileKeyboardVisualInset =
    _MobileKeyboardVisualInset();

class _MobileKeyboardVisualInset extends ValueNotifier<double> {
  _MobileKeyboardVisualInset() : super(0) {
    _listener = _handleViewportEvent.toJS;
    final viewport = web.window.visualViewport;
    viewport?.addEventListener('resize', _listener);
    viewport?.addEventListener('scroll', _listener);
    web.window.addEventListener('resize', _listener);
    _update();
  }

  late final web.EventListener _listener;
  double _baselineWidth = 0;
  double _baselineHeight = 0;

  void _handleViewportEvent(web.Event _) => _update();

  void _update() {
    final viewport = web.window.visualViewport;
    if (viewport == null) {
      if (value != 0) value = 0;
      return;
    }

    final width = viewport.width;
    final height = viewport.height;
    final orientationChanged =
        _baselineWidth > 0 && (width - _baselineWidth).abs() >= 40;

    if (_baselineHeight == 0 ||
        orientationChanged ||
        height > _baselineHeight) {
      _baselineWidth = width;
      _baselineHeight = height;
    }

    final visualHeightLoss = math.max(0.0, _baselineHeight - height);
    final layoutOverlay = math.max(
      0.0,
      web.window.innerHeight.toDouble() - height - viewport.offsetTop,
    );
    final hiddenBottom = math.max(visualHeightLoss, layoutOverlay);

    // Browser address-bar motion is normally much smaller than a software
    // keyboard. Ignore small viewport changes so normal scrolling cannot move
    // the Notes editor.
    final next = hiddenBottom >= 120 ? hiddenBottom : 0.0;
    if ((next - value).abs() >= 0.5) value = next;
  }
}
