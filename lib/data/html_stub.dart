// Stub for dart:html on non-web platforms. Only used when dart.library.html is not available.
// Provides window.location.origin so redirectTo can be compiled on all platforms.

dynamic get window => _HtmlWindowStub();

class _HtmlWindowStub {
  Object get location => _HtmlLocationStub();
}

class _HtmlLocationStub {
  String get origin => '';
}
