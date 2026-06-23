import 'package:flutter/foundation.dart' show kIsWeb;

/// Production web app URL (GitHub Pages). OAuth redirect target in production web mode.
const String kProductionWebUrl = 'https://nkuchenov-hash.github.io/Counter/';

bool _isProductionWeb() =>
    kIsWeb &&
    (Uri.base.origin.contains('nkuchenov-hash.github.io') ||
        Uri.base.toString().startsWith(kProductionWebUrl));

/// OAuth / post-login URL cleanup target for web history helpers.
String webOAuthRedirectUri() {
  if (_isProductionWeb()) return kProductionWebUrl;
  if (kIsWeb) return '${Uri.base.origin}${Uri.base.path}';
  return '';
}
