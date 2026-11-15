# Platform Extension: Firebase & FlutterFire

> **Activation**: Apply when working with any Firebase-related Dart file, `firebase_options.dart`, Firestore collections, Firebase Auth flows, Firebase Storage, Firebase Analytics, or Crashlytics.

## 1. Initialization Order (Critical)
- `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` MUST be the first async call in `main()`, before `runApp()` and before any `ChangeNotifier` that accesses Firebase is registered.
- `FlutterError.onError` must be wired to `FirebaseCrashlytics.instance.recordFlutterFatalError` immediately after `WidgetsFlutterBinding.ensureInitialized()`.
- Example safe `main()` structure:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    runApp(const MyApp());
  }
  ```

## 2. Firebase Auth
- Always check `FirebaseAuth.instance.currentUser` before accessing any user-scoped Firestore document.
- Listen to `FirebaseAuth.instance.authStateChanges()` in a top-level `ChangeNotifier` (e.g., `AuthNotifier`) and re-route the user (unauthenticated → intro/onboarding, authenticated → home) using the project router (`lib/core/router/`).
- Never store Firebase ID tokens manually. The SDK refreshes them automatically.
- For Google Sign-In: always call `googleSignIn.signOut()` before `firebaseAuth.signOut()` to clear the Google credential cache.

## 3. Cloud Firestore
- **Collection Structure**: Scope all user data under `/users/{uid}/...` so Firestore security rules can enforce `request.auth.uid == uid`.
- **Offline Persistence**: Firestore offline cache is enabled by default on mobile. Do not disable it.
- **Avoid N+1 Reads**: Fetch complete documents; avoid loading document IDs in a list and then fetching each individually.
- **Typed Converters**: Use `withConverter<T>()` to map Firestore documents directly to domain models:
  ```dart
  final ref = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .withConverter<UserProfile>(
        fromFirestore: (snap, _) => UserProfile.fromJson(snap.data()!),
        toFirestore: (profile, _) => profile.toJson(),
      );
  ```
- **Error Handling**: Catch `FirebaseException` and map `e.code` to typed domain failures (`permission-denied` → `AuthFailure`, `unavailable` → `NetworkFailure`).

## 4. Firebase Storage
- Always validate MIME types client-side before uploading (`image/jpeg`, `image/png`, `application/pdf`).
- Use `UploadTask.snapshotEvents` to track upload progress and cancel the task if the user leaves the screen.
- Security rules must require `request.auth != null` and validate `request.resource.contentType.matches('image/.*')` or `'application/pdf'`.

## 5. Firebase Analytics & Crashlytics
- Log meaningful feature events (e.g., `analytics.logEvent(name: 'voice_query_sent', parameters: {'model': modelName})`). Do not log PII.
- Before logging a custom Crashlytics key, confirm it contains no API key fragments, email addresses, or auth tokens.
- In release builds, use `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true)`. In debug builds, disable it to reduce noise.

## 6. Verification Commands
```bash
flutterfire configure     # regenerate firebase_options.dart if project changes
flutter analyze
flutter test
```
