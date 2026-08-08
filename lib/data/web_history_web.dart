import 'dart:html' as html;

import 'package:counter/core/web_redirect.dart';

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
