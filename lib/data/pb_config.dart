/// PocketBase backend — collection names and shared config.
library;

import 'package:counter/core/constants.dart';

/// Base URL of the PocketBase instance (no trailing slash).
/// Production: HTTPS via sslip.io (required for Flutter Web on GitHub Pages — avoids mixed content).
const String kPocketBaseUrl = 'https://217-114-0-201.sslip.io';

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
