import 'dart:html' as html;
import 'dart:math' as math;

import 'package:counter/core/web_redirect.dart';
import 'package:flutter/foundation.dart';

/// Clear OAuth query parameters (?code=, ?session_id=, etc.) from the browser URL after a successful redirect.
/// In production web mode uses OAuthSession.redirectUri so the cleaned URL matches GitHub Pages (/Counter/).
void clearOAuthParams() {
  final uri = Uri.base;
  if (uri.query.isEmpty) return;
  final redirect = webOAuthRedirectUri();
  final targetUrl = redirect.isNotEmpty ? redirect : uri.origin + uri.path;
  final clean = Uri.parse(targetUrl).replace(query: '');
  html.window.history.replaceState(null, html.document.title, clean.toString());
}

/// VisualViewport-based bottom occlusion for mobile browsers whose software
/// keyboard is not fully represented by Flutter's MediaQuery.viewInsets.
final ValueListenable<double> webVisualViewportBottomInset =
    _WebVisualViewportBottomInset();

class _WebVisualViewportBottomInset extends ValueNotifier<double> {
  _WebVisualViewportBottomInset() : super(0) {
    final viewport = html.window.visualViewport;
    viewport?.onResize.listen((_) => _update());
    viewport?.onScroll.listen((_) => _update());
    html.window.onResize.listen((_) => _update());
    _update();
  }

  double _baselineWidth = 0;
  double _baselineHeight = 0;

  void _update() {
    final viewport = html.window.visualViewport;
    final innerHeight = html.window.innerHeight?.toDouble();
    final innerWidth = html.window.innerWidth?.toDouble();
    final visualHeight = viewport?.height?.toDouble();
    final visualWidth = viewport?.width?.toDouble();

    if (viewport == null ||
        innerHeight == null ||
        innerWidth == null ||
        visualHeight == null ||
        visualWidth == null) {
      if (value != 0) value = 0;
      return;
    }

    final orientationChanged =
        _baselineWidth > 0 && (visualWidth - _baselineWidth).abs() >= 40;
    if (_baselineHeight == 0 ||
        orientationChanged ||
        visualHeight > _baselineHeight) {
      _baselineWidth = visualWidth;
      _baselineHeight = visualHeight;
    }

    final visualHeightLoss = math.max(0.0, _baselineHeight - visualHeight);
    final layoutOverlay = math.max(
      0.0,
      innerHeight - visualHeight - (viewport.offsetTop?.toDouble() ?? 0.0),
    );
    final hiddenBottom = math.max(visualHeightLoss, layoutOverlay);

    // Browser chrome motion is normally much smaller than a software keyboard.
    // Ignore small viewport changes so ordinary page scrolling cannot move the
    // Notes editor while a text field is focused.
    final next = hiddenBottom >= 120 ? hiddenBottom : 0.0;
    if ((next - value).abs() >= 0.5) value = next;
  }
}
