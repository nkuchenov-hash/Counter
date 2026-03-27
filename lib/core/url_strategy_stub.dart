/// No-op on non-web. On web, usePathUrlStrategy() is used from flutter_web_plugins so OAuth redirect to /?code=... is served correctly (avoids 404).
void usePathUrlStrategy() {}
