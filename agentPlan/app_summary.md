# App Summary: Project Overview & Presentation

> **Overview**: **AI Voice Genie** is a feature-rich, production-grade Flutter application engineered as a unified, multi-model AI assistant hub. It allows users to harness the capabilities of leading AI providers (OpenAI `gpt-6-luna` & `gpt-image-2.5-flare`, Google `gemini-3.5-flash-lite` & `gemini-3.1-flash-lite-image`, and Anthropic `claude-haiku-4-5-20251001`) through text generation, vision analysis, document parsing, dynamic PDF generation, continuous voice speech, and AI image generation in a single, local-first application.

---

## 1. Executive Summary & Problem Solved

### The Problem
- **Fragmentation**: Users traditionally need separate apps/subscriptions to access OpenAI's ChatGPT, Google's Gemini, and Anthropic's Claude.
- **Privacy & Latency Concerns**: Cloud-only chat history often creates slow load times, unresponsiveness during network outages, and privacy risks when managing media files locally.
- **Credential & Screen Security**: Plaintext API keys on mobile screens create shoulder-surfing and screen recording vulnerabilities.
- **Platform Inconsistencies**: Native image saving often suffers from intrusive permission prompts or broken file storage handling across different Android and iOS OS versions.

### The Solution
- **Unified Multi-Model Hub (BYOK)**: Users connect their own API keys and seamlessly switch between OpenAI (`gpt-6-luna`, `gpt-image-2.5-flare`), Gemini (`gemini-3.5-flash-lite`, `gemini-3.1-flash-lite-image`), and Claude (`claude-haiku-4-5-20251001`) for text generation, image creation, multi-image vision analysis, PDF summarization, and PDF document generation.
- **Anti-Screenshot Screen Protection**: `KeySetupScreen` invokes native OS `FLAG_SECURE` (`no_screenshot: ^1.2.0`) to disable screenshots and screen recordings on API key management screens.
- **Local-First Architecture**: Powered by Hive local databases, chat history is read and rendered instantaneously with zero network delay. Cursor-based pagination (15 conversations/page, 30 initial / 20 scroll-up messages) efficiently loads history. Offline mutations are queued in a durable outbox (`ChatOutboxTask`) and synced to Cloud Firestore in the background.
- **Native OS Scoped Media Storage**: Custom Kotlin and Swift MethodChannels manage image downloads directly into native galleries (`Pictures/AI Voice Genie` on Android MediaStore API 29+, `Photos` on iOS) without broad permission scopes.
- **Compiled PDF Document Generation**: Leverages AI markdown output compiled into styled binary PDF documents on-device (`PdfDocumentService`), with direct caching, public device downloads, and native viewing capabilities.

---

## 2. Core Functional Modules

### A. Authentication & User Profile Management
- **OAuth Sign-In**: Google Sign-In and Apple Sign-In authentication integrated with Firebase Auth using cryptographic SHA-256 nonces. (Presented on `AuthScreen` at `/login`; Google Sign-In is live; Apple Sign-In is pre-built pending developer account provisioning).
- **Modular Auth Structure**: UI auth buttons isolated under `lib/features/auth/presentation/widgets/auth_buttons.dart`.
- **Profile Overview & Editing**: Users can view and edit their profile (`ProfileView` & `EditProfileScreen`). Managed reactively by `ProfileViewModel` in `lib/features/profile/presentation/`. Required fields (Name, Email) are validated, while optional demographic details (Gender, Country, State, Date of Birth, Age) are saved to Firestore.
- **Avatar Preservation**: External OAuth profile pictures are protected when text fields are edited without picking a new image.
- **Sign Out vs. Account Deletion**: Sign Out clears local session state without altering remote user data. Account Deletion requires recent authentication, deletes remote API keys and Firestore profile records, wipes all local Hive database boxes, deletes the Firebase Auth account, and resets provider credentials.

### B. Chat & Pagination System
- **Cursor-Based Pagination**: Seamless infinite scrolling in both Chat History (`ConversationHistoryScreen`, loading 15 older conversations per page) and Chat Detail (`ChatDetailScreen`, loading 30 initial messages, 20 older messages per scroll-up). Hive acts as the local source of truth for instant pagination, while background tasks hydrate missing history from Firestore.
- **Start Conversation Screen (`ChatScreen`)**: Features a curated 5-action suggestion grid for fresh conversations:
  1. **Summarize PDF**: Pre-loads professional document extraction prompt and triggers file picker.
  2. **Generate PDF**: Inserts structured document generation prompt into chat input.
  3. **Generate Code**: Inserts real-world data parsing script request.
  4. **Analyze Image**: Pre-loads multimodal analysis prompt and triggers camera/gallery picker.
  5. **Create Image**: Pre-loads 8K photographic scene generation prompt.
- **Modular Presentation Architecture**: Long screens like `ChatHistoryScreen` are cleanly broken down into focused sub-widgets (`CustomConversationCard`, `EmptyHistoryView`) in `lib/features/chat/presentation/widgets/`.
- **Instant Local Search**: Text search applies instantly across the entire local Hive database, enabling users to find historical conversations even if they haven't been paginated into the visible UI yet.

### C. Multi-Model AI Orchestration Engine
- **Centralized Orchestrator**: `AiOrchestrator` normalizes user prompts and routes execution to provider-specific adapters (`OpenAIAdapter`, `GeminiAdapter`, `ClaudeAdapter`).
- **Models Used**:
  - OpenAI: `gpt-6-luna` (Text, Vision, PDF, Reasoning, PDF Generation) and `gpt-image-2.5-flare` (Image Generation).
  - Gemini: `gemini-3.5-flash-lite` (Text, Multimodal Vision, PDF Parsing), `gemini-3.1-flash-lite-image` (Image Generation), and `gemini-3.8-flash` (Reasoning with thinkingConfig).
  - Claude: `claude-haiku-4-5-20251001` (Advanced Text Reasoning, Vision Analysis, Complex PDF Document Analysis).
- **Capability Matrix**: Maps model capabilities and dynamically sets system prompts, token bounds, and temperature preferences.
- **Attachment Pipeline**: Handles image uploads via Cloudinary and performs text extraction on PDF documents (`PdfReaderService`) before building AI payloads.
- **PDF Generation Pipeline**: `PdfDocumentService` intercepts PDF creation intents, renders formatted markdown into binary PDFs, and saves them locally for device opening and public downloads.

### D. Voice & Speech Capabilities
- **Continuous Speech Recognition (STT)**: Real-time microphone listening with automatic grammar formatting (proper noun capitalization, vocative comma insertion, question clause structuring) and auto-scrolling input.
- **Home Screen Tap-to-Speak**: Big microphone button on `IntroScreen` launches `ChatScreen` in `ChatStartMode.voice` mode, automatically triggering STT dictation upon mount.
- **Voice Architecture & Whisper Status**: STT is powered by zero-latency device-native recognition (`speech_to_text`). While `WhisperTranscriptionService` exists in the data layer as an experimental cloud transcription pipeline, it is intentionally gated (`isUsingWhisper => false`) in production, keeping voice interactions instant and independent of additional cloud latency.
- **Text-to-Speech (TTS) & Auto-Playback**: Built-in voice playback for assistant text responses with playback state indicators, plus a user-configurable Auto-TTS toggle.
- **Prompt Sanitization Engine**: Intercepts user prompts to cleanly strip conversational greetings ("Hey Genie", "Good morning") to maximize AI reasoning context and generate highly relevant conversation titles.

### E. Safety & Moderation
- **Moderation Layer**: Deep integration with Gemini and OpenAI moderation endpoints to gracefully catch and localize safety violation blocks (e.g. `finishReason: "SAFETY"`), returning a user-friendly UI exception instead of a crash.

### F. Native AI Image & PDF Downloading
- **Overlay Download Button**: Positioned on AI-generated images in the chat stream with per-image loading spinners, checkmark success feedback, and error handling.
- **Scoped Storage**: Uses native Kotlin MediaStore logic (Android) and Swift Photo Library logic (iOS) to save clean filenames (`aivoicegenie_{timestamp}_{index}.ext`) directly to the gallery with platform-specific success toasts.
- **PDF Exporting**: Generated PDFs can be opened directly in the native device document viewer or saved to public Downloads via `PdfDocumentService`.

### G. AI Usage Tracking & Spending Limits
- **Integrated AI Intelligence Section**: Housed directly in `ProfileView` under `AiIntelligenceSection` (no separate screen needed).
- **Usage Metrics & Pricing Table**: Real-time tracking of prompt tokens, completion tokens, total token consumption, and estimated USD costs per AI model based on `UsagePricingTable`.
- **Budget Controls**: Enables users to set monthly spending limits ($) via `BudgetEditorSheet` and receive visual budget alert banners when spending limits are approached.

### H. Personalization, Legal & Support
- **AI Preferences**: Custom settings for default provider, vision detail level, image size/quality, Auto-TTS preference, response length bounds, and Gemini thinking levels. Powered by an `AiModelCapabilityProfile` matrix that dynamically hides unsupported controls.
- **Multilingual Support**: Real-time language switching between English and Hindi powered by `LocaleProvider` and `AppLocalizations`.
- **Theming**: Theme switching between Light, Dark, and System modes via `ThemeProvider`.
- **Legal & Support**: Dedicated Privacy Policy (`assets/legal/privacy_policy.md`), Terms of Service (`assets/legal/terms_of_service.md`), About App metadata (`AboutScreen`), and developer contact via `SupportPanel`.

### I. Optimized Status Message & Notification System
- **Severity-Based Priority**: `StatusMessageUtils` implements an animated overlay system categorizing alerts into Error (Priority 3, top slide), Warning (Priority 2, top slide), and Success (Priority 1, bottom slide).
- **Smart Deduplication**: Identical incoming notifications extend the active display timer rather than causing visual flicker or duplicate overlays.
- **Channel Isolation & Dual Stacking**: Independent channels (`_Channel.snackbar` and `_Channel.toast`) stack with vertical offset if occupying the same screen edge.
- **Swipe-to-Dismiss**: Responsive gesture detection allows users to swipe away notifications immediately.

---

## 3. Technology Stack & Key Libraries

| Component | Technology / Library | Version Constraint | Purpose |
|---|---|---|---|
| **Core Framework** | Flutter | **3.38.2** | Cross-platform mobile development (Android & iOS). |
| **Language** | Dart | **3.10.0** | Null-safe object-oriented programming language. |
| **State Management** | Provider | `^6.1.2` | Reactive state propagation and MVVM ViewModel implementation. |
| **Cloud Infrastructure** | Firebase Auth & Firestore | `^5.3.1` / `^5.4.4` | User session management and remote cloud database synchronization. |
| **Local Persistence** | Hive | `^2.2.3` | Zero-latency local storage for session data, chat conversations, messages, outbox tasks, and app settings. |
| **Secure Storage** | `flutter_secure_storage` & `encrypt` | `^9.2.2` / `^5.0.3` | Encrypted platform storage (Android Keystore / iOS Keychain) for sensitive API keys. |
| **Screen Security** | `no_screenshot` | `^1.2.0` | Disables screenshots & screen recordings on API key management screens (`FLAG_SECURE`). |
| **Native Integration** | MethodChannel (`ImageSavePlugin`) | Custom Kotlin / Swift | Native MediaStore (Android API 29+) and PhotoKit (iOS) image download extensions. |
| **Document Compilation** | `pdf` & Multimodal Engine | `^3.13.1` / Native Base64 | On-device PDF compilation from AI markdown (`PdfDocumentService`) and native LLM PDF ingestion. |
| **Telemetry & Quality** | Firebase Analytics & Crashlytics | `^11.3.3` / `^4.3.0` | Telemetry event logging and automated crash reporting. |

---

## 4. Advanced Algorithms & Engineering (Tech Lead Info)

1. **Cursor-Based Pagination Algorithm**: To maintain $O(1)$ memory overhead and 60-120fps UI scrolling, the app does not load full Hive tables. Instead, it sorts keys lexicographically (`timestamp_conversationId`) and selectively fetches discrete chunks (15 conversations or 20 messages) based on cursor offsets.
2. **Eventual Consistency & Exponential Backoff**: Network drops are handled seamlessly. Offline mutations are serialized to a `ChatOutboxTask` queue. The background `ChatSyncService` monitors `connectivity_plus` and drains the queue using exponential backoff to handle transient cloud rate limits without data loss.
3. **STT Grammar Enhancement Heuristics**: Raw native microphone streams are intercepted and formatted using regex pipelines before reaching the AI. The pipeline capitalizes proper nouns (e.g., "openai" → "OpenAI"), inserts vocative commas, and detects interrogative clauses to append question marks automatically.
4. **Zero-Trust Memory & Screen Protection**: Sensitive API keys are never trusted in plain text. They are AES-GCM encrypted via `flutter_secure_storage`, masked in UI memory (`sk-a...789`), and protected from OS scraping via `FLAG_SECURE` (`no_screenshot`).
5. **Pre-Flight Payload Sanitization**: The `ProviderRegistry` executes a strict capability check before every HTTP request, stripping unsupported fields (like Gemini aspect ratios on Claude models) to guarantee a 0% rate of 400 Bad Request exceptions.
6. **Dynamic Markdown-to-PDF Compilation**: `PdfDocumentService` parses structured markdown, extracts headers/metadata, formats typography cleanly, and generates valid binary PDF documents on a background thread without external cloud API dependencies.

---

## 5. Architectural Highlights & Engineering Decisions

1. **Clean MVVM Structure**: Strict separation between Presentation (Widgets/Screens/ViewModels), Domain (Entities/Interfaces), and Data (Repositories/Hive Stores/Native Channels). Specifically, ViewModels such as `ProfileViewModel` live in `presentation/`, and UI action buttons like `AuthButtons` live in `presentation/widgets/`.
2. **Local-First Outbox Pattern**: UI operations complete immediately against local Hive storage. Pending remote mutations are queued as `ChatOutboxTask` items and processed asynchronously by `ChatSyncService`.
3. **Screen Security Policy**: Enforces `no_screenshot` on API key entry screens to prevent screen capturing or background preview leaks of sensitive keys.
4. **Non-Blocking Telemetry**: Analytics and background sync operations run asynchronously without blocking UI interactions or screen transitions.
5. **Scoped Native Permissions**: Lightweight MethodChannel respects modern Android 10+ scoped storage (no permission prompt) and iOS add-only photo access.
