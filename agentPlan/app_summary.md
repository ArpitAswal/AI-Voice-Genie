# App Summary

## What the Project Does
- AI Voice Genie is a Flutter-based multi-model AI assistant with a sign-in first experience.
- New users create an authenticated account session, complete onboarding, add at least one AI provider key, and then enter the main app.
- Returning users reuse the existing Firestore account document, refresh local session data, and route based on saved setup state.

## Problem Being Solved
- Users can access multiple AI providers from one app instead of managing separate tools.
- First-run setup is persisted so the app remembers whether onboarding and provider setup are complete.
- Users can end their Firebase session through the profile logout flow while device-level preferences can remain available locally.

## Major Features
- Google and Apple sign-in.
- First-run onboarding.
- AI provider key setup and validation.
- Authenticated app shell with chat, history, and profile sections.
- Logout that clears Firebase Auth, Google Sign-In state, analytics user ID, and user-box session data.

## Technology Stack
- Flutter and Dart.
- Provider for state management.
- Firebase Auth, Firestore, Analytics, and Crashlytics.
- Hive for local persistence.
- HTTP-based AI provider validation and request adapters.

## Architecture Approach
- Feature-first MVVM with repository abstraction.
- Shared services and route handling live in `lib/core`.
- Auth state is resolved before the splash screen leaves, which keeps first-run routing consistent.
- Auth logic is covered with provider-level unit tests using fake repository and analytics services.

## Challenges Solved
- Routing first-time users through onboarding and key setup without exposing stale back-stack routes.
- Persisting session and setup flags locally for fast app startup and returning-user routing.
- Clearing the active auth session on logout so the next launch returns to the login flow.

## Scalability Considerations
- Firestore stores lightweight user/session metadata rather than large local payloads.
- Hive keeps startup checks and same-device preferences fast while Firestore remains the account source of truth.
- The feature-first layout leaves room for additional AI and account features without reworking the app shell.
