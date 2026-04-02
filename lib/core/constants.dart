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
