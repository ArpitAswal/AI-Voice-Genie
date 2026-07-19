# App Summary

## What the Project Does
- AI Voice Genie is a Flutter-based multi-model AI assistant with a sign-in first experience.
- New users create an authenticated account session, complete onboarding, add at least one AI provider key, and then enter the main app.
- Returning users reuse the existing Firestore account document, refresh local session data, and route based on saved setup state.
- After setup, users can start a first chat from the intro experience, select a saved AI provider, send a manual or predefined prompt, and receive the model response in the chat detail screen.

## Problem Being Solved
- Users can access multiple AI providers from one app instead of managing separate tools.
- First-run setup is persisted so the app remembers whether onboarding and provider setup are complete.
- Users can end their Firebase session through the profile logout flow while device-level preferences can remain available locally.

## Major Features
- Google and Apple sign-in.
- First-run onboarding.
- AI provider key setup and validation.
- Authenticated app shell with chat, history, and profile sections.
- New-chat flow with selected model, prompt templates, image/PDF attachments, optimistic user messages, and AI responses.
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
- Chat requests are routed through `ChatProvider`, normalized by `AiOrchestrator`, executed by provider-specific adapters, persisted through `ChatRepositoryImpl`, and cached locally for fast history recovery.

## Challenges Solved
- Routing first-time users through onboarding and key setup without exposing stale back-stack routes.
- Persisting session and setup flags locally for fast app startup and returning-user routing.
- Clearing the active auth session on logout so the next launch returns to the login flow.
- Starting a new conversation quickly by creating optimistic in-memory chat state before the AI network call finishes.
- Keeping AI usage measurable through request analytics and fire-and-forget usage-cost tracking.

## Scalability Considerations
- Firestore stores lightweight user/session metadata rather than large local payloads.
- Hive keeps startup checks and same-device preferences fast while Firestore remains the account source of truth.
- The feature-first layout leaves room for additional AI and account features without reworking the app shell.
- AI provider adapters keep OpenAI, Gemini, and Claude request formats isolated behind one orchestrator entry point.
- Chat persistence separates conversation metadata from message documents, which supports history screens and future pagination or cleanup improvements.

## Current Chat Flow Notes
- The first chat starts from the `IntroScreen` message button; the intro quick-action chips are currently visual only.
- Predefined chat actions live inside `ChatScreen` and prepare the composer, but the user still taps send.
- Manual prompts and predefined prompts share the same AI execution, Firestore save, Hive cache, analytics, and usage flow.
- The main implementation risks are missing pre-send blocking when no valid provider key exists, attachment-only prompt validation inconsistency, and one analysis-message mapping bug that can lose PDF/image response content type.
