// ---------------------------------------------------------------------------
// CORE — Table names and hard limits. Single source for data layer.
// ---------------------------------------------------------------------------

/// **Web application** OAuth Client ID from Google Cloud Console (not the Android client).
/// Required for Android/iOS `GoogleSignIn` → `signInWithIdToken` with Supabase: the ID token
/// must be issued for this client. Must match Supabase Auth → Google provider setup.
/// Same value as `web/index.html` meta `google-signin-client_id`.
const String kGoogleWebClientId =
    '647328834111-9v6vqhi9p1bl1fg6cbc1huvdcvmc89tr.apps.googleusercontent.com';

/// Android `applicationId` / package name. Must match Google Cloud → Android OAuth client
/// (SHA-1, package name). See `android/app/build.gradle.kts` → `defaultConfig.applicationId`.
const String kAndroidApplicationId = 'com.example.counter';

/// Supabase/backend table names. Used by providers to avoid magic strings.
abstract class TableNames {
  static const String records = 'records';
  static const String categories = 'categories';
  static const String profiles = 'profiles';
  static const String plans = 'plans';
}

/// NocoDB v3 table segments: `baseUrl` = `.../api/v3/data/{baseId}` then `/{segment}` (@DATA_MAP.md §0).
///
/// **Row PATCH/DELETE (no 404s)**: `.../api/v3/data/{baseId}/{tableUid}/records/{Id}` — integer [Id] in URL;
/// UUID `record_id` only in `fields`. (Do not insert `/noco/` unless your server docs require it.)
///
/// **Collection** (list GET / create POST): `.../{tableUid}/records`.
/// **Single row** (PATCH / DELETE): `.../{tableUid}/records/{rowId}` (integer system Id for `records` / `plans`).
abstract class NocoV3TablePaths {
  static const String profiles = 'mkiyat3508jooui/records';

  /// @DATA_MAP.md §0 — **categories** table. Never use for timeline record REST.
  static const String categoriesTableUid = 'mhg7mv6dfsgq9i0';
  static const String categories = '$categoriesTableUid/records';

  /// @DATA_MAP.md §0 — **records** table (timeline / Sacred Law). Exclusive for record GET/POST/PATCH/DELETE.
  static const String recordsTableUid = 'mjchwhned7zsvj0';

  /// Collection path: `{recordsTableUid}/records` — must stay in sync with [recordsTableUid] only.
  static const String records = '$recordsTableUid/records';

  static const String plansTableUid = 'mybeqs5qmcaz887';
  static const String plans = '$plansTableUid/records';
}

/// Hard limits for queries and UI.
abstract class AppLimits {
  static const int recordsQueryLimit = 500;
  static const int timelinePageCount = 10000;
  static const int timelineCenterIndex = 5000;
}

/// Primary Supabase OAuth redirect (Android/iOS browser PKCE). Trailing slash must match Dashboard.
/// AndroidManifest: `<data android:scheme="io.supabase.flutter" android:host="login-callback"/>`.
const String kSupabaseOAuthRedirectUri = 'io.supabase.flutter://login-callback/';

/// Legacy deep link; optional second intent-filter in AndroidManifest.
const String kLegacyMobileAuthRedirectUri = 'mycounter://auth';

/// True when [uri] is a Supabase OAuth return with ?code= (primary or legacy scheme).
bool isMobileSupabaseOAuthReturnUri(Uri uri) {
  final code = uri.queryParameters['code'];
  if (code == null || code.isEmpty) return false;
  if (uri.scheme == 'io.supabase.flutter' && uri.host == 'login-callback') return true;
  if (uri.scheme == 'mycounter' && uri.host == 'auth') return true;
  return false;
}
