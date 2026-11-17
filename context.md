# Project Context & Architectural Decisions

> **Agent Rule**: Read this file at the start of every task. Keep it under 150 lines. Never store code snippets here — only high-level architecture decisions and current focus.

## Stack & Architecture

| Dimension | Decision |
|-----------|----------|
| **Framework** | Flutter (Dart ≥ 3.3) — mobile-first (Android + iOS) |
| **State Management** | Provider (`ChangeNotifier` + `MultiProvider`) — no BLoC/Riverpod |
| **Local Storage** | Hive 2 (conversations, messages, settings) + `flutter_secure_storage` (API keys) |
| **Remote Backend** | Firebase (Auth, Firestore, Storage, Analytics, Crashlytics) |
| **AI Endpoints** | REST HTTP: OpenAI, Gemini, Claude — keys stored per-user in `flutter_secure_storage` |
| **Audio** | `speech_to_text` (STT) + `flutter_tts` (TTS) + `record` (audio capture) |
| **Routing** | Custom router in `lib/core/router/` |
| **Localization** | `flutter_localizations` + `intl` (`.arb` files) |
| **Code-gen** | `hive_generator` via `build_runner` |
| **Screen Protection** | `no_screenshot` on key-setup and key-display screens |
| **UI Typography** | Poppins (400/500/600/700) |

## Feature Modules
| Module | Location | Purpose |
|--------|----------|---------|
| `auth` | `lib/features/auth/` | Google Sign-In + Firebase Auth |
| `chat` | `lib/features/chat/` | Multi-model AI chat interface |
| `voice_speech` | `lib/features/voice_speech/` | STT dictation + TTS playback |
| `key_setup` | `lib/features/key_setup/` | Secure API key entry and storage |
| `image_download` | `lib/features/image_download/` | AI image generation + native save |
| `usage` | `lib/features/usage/` | Monthly token/usage tracking (Firestore) |
| `profile` | `lib/features/profile/` | User profile display and management |
| `onboarding` | `lib/features/onboarding/` | First-run walkthrough |
| `home` | `lib/features/home/` | Main navigation shell |

## Key Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11 | Provider over Riverpod/BLoC | Lower complexity for a one-developer project; sufficient for feature set |
| 2026-11 | Hive for local storage | Zero-latency reads; no SQL schema migrations needed for conversations |
| 2026-11 | `flutter_secure_storage` for API keys | Hardware-backed encryption; mandatory for production key storage |
| 2026-11 | `no_screenshot` on key screens | Prevent clipboard/screenshot key exposure on shared devices |
| 2026-11 | Firebase for backend | Auth + Firestore + Crashlytics in one SDK; reduces backend maintenance |
| 2026-11 | Scoped Storage & Granular Media | Android 13+ removes monolithic storage; PDF downloads use MediaStore with zero prompt; Photos & Camera use granular permissions |
| 2026-11 | Adaptive Dialog & Overlay System | Unified AppAlertDialog & LoadingOverlay across mobile & tablet with max-width clamping (380dp/460dp), M3 button overflow wrapping, and >=44-48dp touch targets |

## Current Focus
- Stabilise voice capture → AI response pipeline (`voice_speech` + `chat` features).
- Ensure usage tracking (`usage` module) correctly reflects per-model token counts in Firestore.
- Responsive UI audit for tablet portrait layouts (target breakpoint `width >= 600`).
