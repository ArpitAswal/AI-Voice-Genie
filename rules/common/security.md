# Common Application Security Rules

## 1. Secrets & Credentials
- **Zero Hardcoded Secrets**: Never commit API keys (OpenAI, Gemini, Claude), OAuth secrets, Firebase service account keys, signing keystores (`.jks`, `.keystore`, `.p12`), or tokens into source files or version control.
- Load user-supplied API keys exclusively from `flutter_secure_storage` (Android Keystore / iOS Keychain backed). Never read them from `SharedPreferences`, Hive boxes, or plain files.
- Keep `.env` and `local.properties` in `.gitignore`. Verify before every push.
- Treat client-side binaries as public. Never store production master keys inside mobile code.

## 2. Secure Local Storage
- **API Keys**: Store only in `flutter_secure_storage`. Encrypt before persisting to Hive if caching is required, using the `encrypt` package (AES-256 CBC) with an IV generated per session.
- Never store auth tokens, session tokens, or PII in plaintext Hive boxes or `SharedPreferences`.
- After successful auth, Firebase ID tokens are managed by the Firebase SDK — do not cache them manually.

## 3. Screen & Capture Protection
- Activate `no_screenshot` on all screens that display API keys or sensitive user data (use the `NoScreenshot` widget wrapper or the platform channel call on `initState`).
- Verify this protection is lifted on non-sensitive screens to avoid user friction.

## 4. Safe Networking
- Enforce HTTPS/TLS 1.2+ for all REST calls (OpenAI, Gemini, Claude endpoints, Firebase).
- Never enable cleartext traffic in release builds (`android:usesCleartextTraffic` must be absent or `false` in release manifest).
- Redact `Authorization` headers, `x-api-key` values, and tokens from all console/Crashlytics logs.
- Set explicit connect and read timeouts on every `http.Client` call (recommended: connect 10 s, read 60 s for LLM streaming).

## 5. Firebase-Specific Security
- Apply least-privilege Firestore security rules: users may only read/write their own documents (`request.auth.uid == resource.data.userId`).
- Never use `allow read, write: if true;` in production Firestore rules.
- Restrict Firebase Storage rules to authenticated users and validate MIME types.

## 6. Input Validation & Permissions
- Validate and sanitize all external inputs: deep links, push notification payloads.
- Request only the minimum permissions required: microphone (voice capture), camera/gallery (image picker), storage (file picker). Explain each request with rationale strings in `Info.plist` and `AndroidManifest.xml`.
- Use parameterized queries for local Hive lookups; never construct query strings by concatenation.