# Supabase Auth & Yandex OAuth Setup

## 1. Supabase project

- Create a project at [supabase.com](https://supabase.com).
- In **Authentication → URL Configuration**, add to **Redirect URLs**:
  - Web: `https://your-domain.com` (or `http://localhost:xxxx` for local).
  - Android/Windows: `mycounter://auth`
- In **Authentication → Providers**, enable **Yandex** and set your Yandex OAuth client ID and secret (from [Yandex OAuth](https://oauth.yandex.ru/)).

## 2. App configuration

- In `lib/main.dart`, set:
  - `_supabaseUrl` = your project URL (e.g. `https://YOUR_PROJECT_REF.supabase.co`).
  - `_supabaseAnonKey` = your project anon/public key.

## 3. Android Deep Linking (mycounter://auth)

The app already includes the intent-filter in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="mycounter" android:host="auth"/>
</intent-filter>
```

No extra steps needed. After Yandex OAuth, the system opens the app with `mycounter://auth?code=...` and the app exchanges the code for a session via `DatabaseService.exchangeCodeForSession(code)`.

## 4. Manual tests

### Web

1. Set `_supabaseUrl` and `_supabaseAnonKey` in `main.dart`.
2. Add your web origin (e.g. `http://localhost:PORT`) to Supabase **Redirect URLs**.
3. Run: `flutter run -d chrome`.
4. On the auth screen, click **Continue with Yandex**.
5. Complete Yandex sign-in in the opened tab.
6. You should be redirected back to the app and see the dashboard (loading then main UI).
7. If it fails: check Debug Console for errors; confirm redirect URL in Supabase matches the browser origin; confirm Yandex provider is enabled and credentials are correct.

### Android emulator / device

1. Use the same Supabase URL/anon key and add `mycounter://auth` to Redirect URLs.
2. Run: `flutter run -d android`.
3. On the auth screen, tap **Continue with Yandex**.
4. Complete Yandex sign-in in the browser.
5. The app should reopen (deep link) and show the dashboard after loading.
6. If the app does not reopen or stays on auth: confirm the intent-filter is in `AndroidManifest.xml`; confirm `mycounter://auth` is in Supabase Redirect URLs; check logcat for errors.

### Windows

1. Add `mycounter://auth` to Supabase Redirect URLs.
2. Register the custom protocol for Windows if required by your build (e.g. in installer or registry so `mycounter://auth` opens the app).
3. Run the app, click **Continue with Yandex**, complete sign-in; the app should receive the redirect and exchange the code (implementation may require protocol registration for Windows).
