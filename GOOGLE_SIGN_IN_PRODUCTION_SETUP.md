# Google Sign-In (Production + Closed Testing)

This project now uses Supabase OAuth with platform-specific redirects and a hardened Google sign-in flow.

## 1) Supabase Dashboard (Auth -> Providers -> Google)

Set:

- `Enable Sign in with Google`: `ON`
- `Client IDs`: include all relevant client IDs, comma-separated:
  - Web OAuth client ID
  - Android OAuth client ID(s) for your package/signing keys
- `Client Secret (for OAuth)`: use the **Web** OAuth client secret
- `Skip nonce checks`: `OFF` (keep secure for production)
- `Allow users without an email`: `OFF` (recommended)
- `Callback URL (for OAuth)`: copy this value exactly from Supabase and use it in Google Cloud redirect URIs

## 2) Google Cloud Console

Create OAuth clients:

- Web client:
  - Add Supabase callback URL to `Authorized redirect URIs`
- Android client:
  - Package name: `com.mspace.app`
  - Add SHA-1/SHA-256 for:
    - local debug/release keystore (if used)
    - Play App Signing certificate (required for closed testing/release)

Configure OAuth consent screen:

- App in `In production` if possible.
- If still in testing, add every tester email used in closed testing.

## 3) Flutter runtime config (required)

Pass redirect URLs with `--dart-define`:

```bash
flutter run --flavor prod -d chrome \
  --dart-define=AUTH_REDIRECT_WEB=https://your-web-domain.com
```

```bash
flutter run --flavor prod -d android \
  --dart-define=AUTH_REDIRECT_MOBILE=io.supabase.artisanmarketplace://login-callback
```

Notes:

- `AUTH_REDIRECT_WEB` must exactly match an allowed redirect URL.
- `AUTH_REDIRECT_MOBILE` must match Android manifest deep link config.

## 4) Android callback wiring (already added in code)

`android/app/src/main/AndroidManifest.xml` now includes:

- Scheme: `io.supabase.artisanmarketplace`
- Host: `login-callback`

This is required for browser -> app OAuth return.

## 5) Closed testing checklist

- Use **prod** flavor and release signing.
- Ensure Play App Signing SHA is added in Google OAuth Android client.
- Ensure Supabase Google provider has correct client IDs and Web secret.
- Verify login works on:
  - internal test track install from Play
  - a tester account in consent screen (if app not yet fully published)
- Confirm the authenticated user row has `user_type` populated (not legacy `role` only).
