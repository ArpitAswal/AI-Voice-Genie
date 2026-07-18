# App Flow

## Feature
Create account, logout, and login again.

## Purpose
- Show the exact end-to-end execution path for a first-time user.
- Show what data is saved in Firestore, Hive, and Analytics at each step.
- Help QA and developers verify the flow without reading the whole codebase.

## Start and End
- Start: Splash screen on first app open.
- End: Login screen after logout, then authenticated flow again on the next login.

## Execution Flow Chart
`SplashScreen -> AuthProvider.initialize() -> AuthRepository.getCurrentUser()`

`No Firebase session`
`-> LoginScreen -> signInWithGoogle() or signInWithApple()`
`-> AuthProvider._performSignIn()`
`-> AuthRepository.signInWithGoogle()/signInWithApple()`
`-> Firebase Auth credential sign-in`
`-> _createOrUpdateUser()`
`-> Firestore create OR read/update existing user doc`
`-> Hive session save`
`-> AuthProvider.authState = authenticated`
`-> OnboardingScreen if onboardingDone is false`
`-> AuthProvider.markBoardingComplete()`
`-> KeySetupScreen`
`-> ApiKeyProvider.validateAndSaveKey()`
`-> ApiKeyRepository.validateKey()`
`-> ApiKeyRepository.saveKey()`
`-> ApiKeyProvider.completeSetup()`
`-> ApiKeyRepository.completeKeySetup()`
`-> TabBarScreen / ProfileScreen`
`-> Logout confirmation`
`-> ProfileViewModel.signOut()`
`-> AuthProvider.signOut()`
`-> AuthRepository.signOut()`
`-> Google signOut + Firebase Auth signOut + Hive user clear + analytics user clear + user_signed_out`
`-> LoginScreen`
`-> login again uses returning-user branch`

## Function Call Map

| Function | Who Calls It | What It Does | Important Return or Side Effect |
|---|---|---|---|
| `AuthProvider.initialize()` | `main.dart` | Checks whether a Firebase session already exists. | Sets auth state to authenticated or unauthenticated. |
| `AuthRepository.getCurrentUser()` | `AuthProvider.initialize()` | Reads FirebaseAuth current user, then Firestore user profile if a session exists. | Returns a `UserModel` or null. |
| `AuthScreen._handleGoogleSignIn()` / `_handleAppleSignIn()` | User tap on login screen | Shows loading and starts the social sign-in flow. | Calls auth provider sign-in and waits for the result. |
| `AuthProvider.signInWithGoogle()` / `signInWithApple()` | Login screen | Logs the tap event, then starts unified sign-in logic. | Leads to authenticated or unauthenticated state. |
| `AuthProvider._performSignIn()` | Auth provider internals | Applies the shared sign-in success/failure rules. | Sets `currentUser`, analytics user ID, and auth state. |
| `AuthRepository.signInWithGoogle()` / `signInWithApple()` | Auth provider | Runs the provider login, Firebase credential sign-in, and user-document sync. | Returns a `UserModel` for the signed-in user. |
| `_createOrUpdateUser()` | Auth repository | Handles the new-user and returning-user Firestore branch. | Creates a new user doc or refreshes last login on an existing doc. |
| `_persistSession()` | Auth repository | Writes the session snapshot into Hive. | Saves user identity and onboarding/key flags locally. |
| `AuthProvider.markBoardingComplete()` | Onboarding screen | Marks onboarding as complete in memory and in storage. | Updates the user doc and local onboarding flag. |
| `ApiKeyProvider.validateAndSaveKey()` | Key setup screen | Validates a provider key, then saves it if valid. | Stores the API key in Firestore and memory cache. |
| `ApiKeyProvider.completeSetup()` | Key setup screen | Marks setup complete after at least one valid key exists. | Stores `keySetupDone` and `preferredProvider`. |
| `ProfileViewModel.signOut()` | Profile screen logout action | Wraps the sign-out sequence for the UI. | Returns control to the auth provider. |
| `AuthProvider.signOut()` | Profile view model | Calls repository sign-out, clears analytics user ID, logs sign-out, then clears current user state. | Routes the app back to login. |
| `AuthRepository.signOut()` | Auth provider | Signs out from Google, Firebase Auth, and local session storage. | Clears Firebase session and starts user-box cleanup. |

## New Account Branch

### Google
- Google account picker returns a Google user.
- Firebase credential is created from Google tokens.
- `_createOrUpdateUser()` checks whether the Firestore user doc already exists.
- If the doc does not exist, a new user model is created from Google profile data.
- The new Firestore doc is saved with default `onboardingDone = false` and `keySetupDone = false`.
- Hive is updated with the same session flags and user profile data.

### Apple
- Apple credential is requested with a nonce.
- Firebase credential is created from the Apple ID token and raw nonce.
- `_createOrUpdateUser()` again checks Firestore for the user doc.
- If this is the first sign-in, name/email are taken from the Apple credential first, then fallback values are used if needed.
- Apple never provides a photo, so `photoUrl` stays empty.
- The same Firestore and Hive writes happen as the Google new-user branch.

## Returning Login Branch
- On the next login, Firebase Auth finds the existing account.
- `_createOrUpdateUser()` sees the Firestore user doc already exists.
- It reads stored profile data from Firestore instead of rebuilding the user from the social provider.
- `lastLoginAt` is updated in Firestore and `isNewUser` is written as false.
- Hive is refreshed with the stored onboarding and key-setup flags.
- The auth model only carries the fields represented in `UserModel`, so Firestore fields that are not modeled there are not surfaced to later screens through this path.

## Data Saved By Stage

| Stage | Firestore | Hive | Analytics |
|---|---|---|---|
| First sign-in success | New user doc at `AIVoiceGenie/AllUsers/{uid}/UserModel` with `uid`, `email`, `displayName`, `photoUrl`, `authProvider`, `onboardingDone`, `keySetupDone`, `dateOfBirth`, `age`, `createdAt`, `lastLoginAt`. | `isLoggedIn`, `userId`, `userEmail`, `userDisplayName`, `userPhotoUrl`, `onboardingCompleted`, `keySetupCompleted`. | `authentication_button_tapped`, then `user_registered` with `user_id`, `auth_provider`, and `user_email`. |
| Returning sign-in success | Existing user doc updated with `lastLoginAt` and `isNewUser = false`. | Same session keys are refreshed from Firestore. | `authentication_button_tapped`, then `user_signed_in` with `user_id`, `auth_provider`, and `user_email`. |
| Onboarding complete | `onboardingDone = true` and `lastUpdatedAt` are written on the user doc. | `onboardingCompleted = true` is written locally. | No onboarding analytics event is logged. |
| API key saved | API key doc at `AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}` with raw `apiKey`, `providerId`, `isValid`, `lastValidated`, and `keyAddedAt` when present. | Provider key is cached in memory for masked display. | `model_added` is logged after a successful save with user and model details. |
| Key setup complete | `keySetupDone = true` and `preferredProvider` are written on the user doc. | `keySetupCompleted = true` and `preferredProviderId` are stored. | No dedicated key-setup-complete analytics event is logged. |
| Logout | No Firestore profile write from the logout path itself. | `user_box` cleanup is started and `isLoggedIn = false` cleanup is started. | Analytics user ID is cleared and `user_signed_out` logs `user_id`. |

## Async and Await Judgment
- Awaited operations:
  - Firebase initialization
  - auth session resolution
  - OAuth sign-in
  - Firebase Auth credential sign-in
  - Firestore user document create/read/update
  - Hive session persistence
  - key validation
  - key save
  - key setup completion
  - sign-out
- Fire-and-forget style behavior:
  - splash navigation waits on state changes, but it does not directly perform auth
  - onboarding persistence is wrapped in `EffectBus.safeEffect`, so navigation can continue while the write runs
  - Google sign-in button analytics is wrapped in `EffectBus.safeEffect`
  - analytics is intended to be non-blocking for the user, even though the service wrapper awaits internally

## QA Verdict

### What Looks Correct
- New accounts are created only after a real Firebase sign-in succeeds.
- Returning logins reuse the existing user document instead of creating duplicates.
- The app saves the session locally so startup can route quickly.
- Provider keys are validated before they are saved.
- Logout returns the app to the login screen.
- Returning users now mark `isNewUser = false` in Firestore.

### What May Need Improvement
- Medium: `AuthRepository.signOut()` clears only the user box and `isLoggedIn` flag, and it does not await those storage calls. That can leave user-specific cleanup running after the method returns and makes logout cleanup less reliable than the rest of the flow.
- Low: `ApiKeyProvider.loadExistingKeys()` is triggered without awaiting in the splash/login route path, so the UI can navigate before the key cache is fully loaded. This is usually fine, but a tester should know the key cards may populate slightly later.

## Testing Notes
- First run:
  - clear the app session
  - sign in with Google or Apple
  - verify Firestore gets a new user document
  - verify Hive gets the session values
  - verify onboarding appears
  - verify key setup blocks continuation until at least one valid key exists
- Logout:
  - confirm logout dialog appears
  - confirm Firebase session is removed
  - confirm the app returns to Login
- Login again:
  - sign in with the same account
  - verify the flow skips document creation and uses the returning-user branch
  - verify `lastLoginAt` updates
  - verify `isNewUser` is false in Firestore after returning login

## Async Priority Judgment
- Must await:
  - Firebase Auth sign-in and sign-out
  - Firestore user-doc create/update
  - API key validation and save
  - key setup completion write
  - sign-out local storage cleanup, because logout should not return before session state is cleared
- Can be fire-and-forget:
  - analytics logs
  - key-cache loading when it is only warming UI state
  - splash-to-login navigation itself, because it only reacts to auth state
- Should be reconsidered:
  - onboarding completion currently behaves like a background effect; it is acceptable for UI speed, but QA should verify that a failed Firestore write is surfaced through the global effect path
  - logout storage cleanup should be awaited so stale state cannot survive a fast relaunch

## Analytics Parameter Judgment
- Good and necessary:
  - `authentication_button_tapped.auth_provider` because it tells us which provider users actually press
  - `user_registered.auth_provider` and `user_signed_in.auth_provider` because they confirm which provider actually succeeded
  - `model_added.user_id` because it makes key events easier to analyze in exported reports
  - `model_added.model_used` because it identifies the provider
- Useful but optional:
  - `user_registered.user_email` and `user_signed_in.user_email` because Firebase Analytics already has user ID; email can be sensitive and should only be kept if reporting truly needs it
  - `model_added.model_name` because it is human-readable but duplicates `model_used`
  - `model_added.model_features` because it helps reporting, but it is static metadata and may be more than the event needs
  - `model_removed.model_name` and `model_features` for the same reason
- Missing but potentially useful:
  - a success/failure result or duration field for key validation if you want to study how often validation is slow or rejected
  - a sign-out source parameter if logout can later happen from more than Profile
