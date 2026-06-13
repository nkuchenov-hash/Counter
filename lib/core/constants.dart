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

/// PocketBase/backend collection names. Used by providers to avoid magic strings.
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
