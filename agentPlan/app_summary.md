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
- Offline-first chat persistence with Hive conversation/message records, durable outbox tasks, and background Firestore synchronization.
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
- Chat requests are routed through `ChatProvider`, normalized by `AiOrchestrator`, executed by provider-specific adapters, saved into Hive records through `ChatRepositoryImpl`, and synchronized to Firestore in the background through `ChatSyncService`.
- Chat UI now reads conversation and message state from Hive-backed streams instead of relying only on direct Firestore responses.

## Challenges Solved
- Routing first-time users through onboarding and key setup without exposing stale back-stack routes.
- Persisting session and setup flags locally for fast app startup and returning-user routing.
- Clearing the active auth session on logout so the next launch returns to the login flow.
- Starting a new conversation quickly by creating optimistic in-memory chat state before the AI network call finishes.
- Keeping AI usage measurable through request analytics and fire-and-forget usage-cost tracking.
- Keeping chat history responsive by storing conversation metadata and messages locally, then using an outbox to retry Firestore writes/deletes when connectivity returns.

## Scalability Considerations
- Firestore stores lightweight user/session metadata rather than large local payloads.
- Hive keeps startup checks and same-device preferences fast while Firestore remains the account source of truth.
- The feature-first layout leaves room for additional AI and account features without reworking the app shell.
- AI provider adapters keep OpenAI, Gemini, and Claude request formats isolated behind one orchestrator entry point.
- Chat persistence separates local conversation records, local message records, outbox tasks, sync state, and remote Firestore documents, which supports offline history rendering and eventual consistency.

## Current Chat Flow Notes
- The first chat starts from the `IntroScreen` message button; the intro quick-action chips are currently visual only.
- Predefined chat actions live inside `ChatScreen` and prepare the composer, but the user still taps send.
- Manual prompts and predefined prompts share the same AI execution, local Hive persistence, outbox enqueue, background Firestore sync, analytics, and usage flow.
- First-send now blocks before navigation when the selected preferred provider has no saved valid API key.
- Individual chat delete is local-first and queues remote deletion; history cards can show pending or failed sync states.
- The main implementation risks are first prompt not being durably saved before the AI call finishes, history refresh still forcing a full Firestore server fetch, delete-all timing using a delayed non-awaited call, title rename remaining remote-first, and stale outbox tasks potentially staying stuck in `processing` after an app kill.
