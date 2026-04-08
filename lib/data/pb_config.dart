/// PocketBase backend — collection names and shared config.
library;

import 'package:counter/core/constants.dart';
import 'package:flutter/foundation.dart';

/// Remote PocketBase (HTTPS). Used for release mobile builds and production web.
const String kPocketBaseProductionUrl = 'https://217-114-0-201.sslip.io';

String _pocketBaseUrlForWeb() {
  final host = Uri.base.host;
  final isLocalHost = host.isEmpty ||
      host == 'localhost' ||
      host == '127.0.0.1';
  if (isLocalHost) {
    return 'http://localhost:8090';
  }
  return kPocketBaseProductionUrl;
}

/// Resolves the PocketBase base URL (no trailing slash) for the current platform and build mode.
String resolvePocketBaseUrl() {
  if (kIsWeb) {
    return _pocketBaseUrlForWeb();
  }
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      kDebugMode) {
    return 'http://10.0.2.2:8090';
  }
  return kPocketBaseProductionUrl;
}

/// Effective API root — use this everywhere instead of a hard-coded host.
String get kPocketBaseUrl => resolvePocketBaseUrl();

/// Non-collection HTTP routes served by the same app backend (reverse proxy / edge).
/// Client code must stay **vendor-neutral** — no LLM provider names in Flutter.
abstract class PbAppApiRoutes {
  /// POST: natural-language task utterance → structured hints (title, optional clock).
  /// Body and schema are defined server-side; see POCKETBASE_MANIFEST / deployment docs.
  static const String aiParseTask = '/api/ai/parse-task';
}

/// PocketBase collection names (Admin → Collections). Must match server.
abstract class PbCollections {
  static const String profiles = TableNames.profiles;
  static const String records = TableNames.records;
  static const String categories = TableNames.categories;
  static const String plans = TableNames.plans;
  static const String tags = 'tags';
}

/// PocketBase Admin → OAuth2 provider **names** must match these strings exactly.
abstract class PbOauthProviderNames {
  static const String google = 'google';
  static const String yandex = 'yandex';
}

/// `records` → `categories` relation field (Timeline expand).
const String kPbRecordCategoryExpand = 'category_link';

/// `plans` → `tags` M2M (`database_service` `expand: tags_link`).
const String kPbPlanTagsExpand = 'tags_link';

/// `records` → `tags` M2M (optional; manifest also allows comma-separated `tags` text).
const String kPbRecordTagsExpand = 'tags_link';
