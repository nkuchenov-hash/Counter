import 'dart:html' as html;

import 'package:counter/auth_service.dart';

/// Clear OAuth query parameters (?code=, ?session_id=, etc.) from the browser URL after a successful redirect.
/// In production web mode uses AuthService.redirectUri so the cleaned URL matches GitHub Pages (/Counter/).
void clearOAuthParams() {
  final uri = Uri.base;
  if (uri.query.isEmpty) return;
  final targetUrl = AuthService.redirectUri.isNotEmpty ? AuthService.redirectUri : uri.origin + uri.path;
  final clean = Uri.parse(targetUrl).replace(query: '');
  html.window.history.replaceState(null, html.document.title, clean.toString());
}
