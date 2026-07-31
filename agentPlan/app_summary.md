# App Summary: Project Overview & Presentation

> **Overview**: **AI Voice Genie** is a feature-rich, production-grade Flutter application designed to serve as a unified, multi-model AI assistant hub. It allows users to harness the capabilities of leading AI providers (OpenAI `gpt-4o` & `gpt-image-1`, Google `gemini-2.5-flash`, and Anthropic `claude-3-5-sonnet`) through text generation, vision analysis, document parsing, voice speech, and AI image generation in a single, local-first application.

---

## 1. Executive Summary & Problem Solved

### The Problem
- **Fragmentation**: Users traditionally need separate apps/subscriptions to access OpenAI's ChatGPT, Google's Gemini, and Anthropic's Claude.
- **Privacy & Latency Concerns**: Cloud-only chat history often creates slow load times, unresponsiveness during network outages, and privacy risks when managing media files locally.
- **Credential & Screen Security**: Plaintext API keys on mobile screens create shoulder-surfing and screen recording vulnerabilities.
- **Platform Inconsistencies**: Native image saving often suffers from intrusive permission prompts or broken file storage handling across different Android and iOS OS versions.

### The Solution
- **Unified Multi-Model Hub (BYOK)**: Users connect their own API keys and seamlessly switch between OpenAI (`gpt-4o`, `gpt-image-1`), Gemini (`gemini-2.5-flash`), and Claude (`claude-3-5-sonnet`) for text generation, image creation, multi-image vision analysis, and PDF summarization.
- **Anti-Screenshot Screen Protection**: `KeySetupScreen` invokes native OS `FLAG_SECURE` (`no_screenshot: ^1.2.0`) to disable screenshots and screen recordings on API key management screens.
- **Local-First Architecture**: Powered by Hive local databases, chat history is read and rendered instantaneously with zero network delay. Cursor-based pagination (15 conversations/page, 30 initial / 20 scroll-up messages) efficiently loads history. Offline mutations are queued in a durable outbox (`ChatOutboxTask`) and synced to Cloud Firestore in the background.
- **Native OS Scoped Media Storage**: Custom Kotlin and Swift MethodChannels manage image downloads directly into native galleries (`Pictures/AI Voice Genie` on Android MediaStore API 29+, `Photos` on iOS) without broad permission scopes.

---

## 2. Core Functional Modules

### A. Authentication & User Profile Management
- **OAuth Sign-In**: Google Sign-In and Apple Sign-In authentication integrated with Firebase Auth using cryptographic SHA-256 nonces.
- **Profile Overview & Editing**: Users can view and edit their profile (`ProfileView` & `EditProfileScreen`). Required fields (Name, Email) are validated, while optional demographic details (Gender, Country, State, Date of Birth, Age) are saved to Firestore.
- **Avatar Preservation**: External OAuth profile pictures are protected when text fields are edited without picking a new image.
- **Sign Out vs. Account Deletion**: Sign Out clears local session state without altering remote user data. Account Deletion requires recent authentication, deletes remote API keys and Firestore profile records, wipes all local Hive database boxes, deletes the Firebase Auth account, and resets provider credentials.

### B. Chat & Pagination System
- **Cursor-Based Pagination**: Seamless infinite scrolling in both Chat History (loading 15 older conversations per page) and Chat Detail (loading 30 initial messages, 20 older messages per scroll-up). Hive acts as the local source of truth for instant pagination, while background tasks hydrate missing history from Firestore.
- **Modular Presentation Architecture**: Long screens like `ChatHistoryScreen` are cleanly broken down into focused sub-widgets (`CustomConversationCard`, `EmptyHistoryView`) in `lib/features/chat/presentation/widgets/`.
- **Instant Local Search**: Text search applies instantly across the entire local Hive database, enabling users to find historical conversations even if they haven't been paginated into the visible UI yet.

### C. Multi-Model AI Orchestration Engine
- **Centralized Orchestrator**: `AiOrchestrator` normalizes user prompts and routes execution to provider-specific adapters (`OpenAIAdapter`, `GeminiAdapter`, `ClaudeAdapter`).
- **Models Used**:
  - OpenAI: `gpt-4o` (Text/Vision/PDF) and `gpt-image-1` (Image Generation).
  - Gemini: `gemini-2.5-flash` (Text/Vision/PDF) and `gemini-2.5-flash-image` (Image Generation).
  - Claude: `claude-3-5-sonnet` (Text/Vision/PDF).
- **Capability Matrix**: Maps model capabilities and dynamically sets system prompts, token bounds, and temperature preferences.
- **Attachment Pipeline**: Handles image uploads via Cloudinary and performs text extraction on PDF documents (`PdfReaderService`) before building AI payloads.

### D. Voice & Speech Capabilities
- **Continuous Speech Recognition (STT)**: Real-time microphone listening with automatic grammar formatting (proper noun capitalization, vocative comma insertion, question clause structuring) and auto-scrolling input.
- **Text-to-Speech (TTS)**: Built-in voice playback for assistant text responses.

### E. Native AI Image Downloading
- **Overlay Download Button**: Positioned on AI-generated images in the chat stream with per-image loading spinners, checkmark success feedback, and error handling.
- **Scoped Storage**: Uses native Kotlin MediaStore logic (Android) and Swift Photo Library logic (iOS) to save clean filenames (`aivoicegenie_{timestamp}_{index}.ext`) directly to the gallery with platform-specific success toasts.

### F. AI Usage Tracking & Spending Limits
- **Usage Metrics & Pricing Table**: Real-time tracking of prompt tokens, completion tokens, total token consumption, and estimated USD costs per AI model based on `UsagePricingTable`.
- **Budget Controls**: Enables users to set monthly spending limits ($) and receive visual budget alert banners when spending limits are approached.

### G. Personalization, Legal & Support
- **AI Preferences**: Custom settings for default provider, vision detail level, image size/quality, and token limits. Powered by an `AiModelCapabilityProfile` matrix that dynamically hides unsupported controls (e.g. hiding image settings when Claude is selected) and reveals provider-specific features (e.g. Gemini aspect ratios `1:1`, `16:9`, `4:3`, `3:4`).
- **Multilingual Support**: Real-time language switching between English and Hindi powered by `LocaleProvider` and `AppLocalizations`.
- **Theming**: Theme switching between Light, Dark, and System modes via `ThemeProvider`.
- **Legal & Support**: Dedicated Privacy Policy (`assets/legal/privacy_policy.md`), Terms of Service (`assets/legal/terms_of_service.md`), About App metadata, and Support panel (`LegalScreen`, `AboutScreen`, `SupportPanel`).

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
| **Telemetry & Quality** | Firebase Analytics & Crashlytics | `^11.3.3` / `^4.3.0` | Telemetry event logging and automated crash reporting. |

---

## 4. Advanced Algorithms & Engineering (Tech Lead Info)

1. **Cursor-Based Pagination Algorithm**: To maintain $O(1)$ memory overhead and 60-120fps UI scrolling, the app does not load full Hive tables. Instead, it sorts keys lexicographically (`timestamp_conversationId`) and selectively fetches discrete chunks (15 conversations or 20 messages) based on cursor offsets.
2. **Eventual Consistency & Exponential Backoff**: Network drops are handled seamlessly. Offline mutations are serialized to a `ChatOutboxTask` queue. The background `ChatSyncService` monitors `connectivity_plus` and drains the queue using exponential backoff to handle transient cloud rate limits without data loss.
3. **STT Grammar Enhancement Heuristics**: Raw native microphone streams are intercepted and formatted using regex pipelines before reaching the AI. The pipeline capitalizes proper nouns (e.g., "openai" → "OpenAI"), inserts vocative commas, and detects interrogative clauses to append question marks automatically.
4. **Zero-Trust Memory & Screen Protection**: Sensitive API keys are never trusted in plain text. They are AES-GCM encrypted via `flutter_secure_storage`, masked in UI memory (`sk-a...789`), and protected from OS scraping via `FLAG_SECURE` (`no_screenshot`).
5. **Pre-Flight Payload Sanitization**: The `ProviderRegistry` executes a strict capability check before every HTTP request, stripping unsupported fields (like Gemini aspect ratios on Claude models) to guarantee a 0% rate of 400 Bad Request exceptions.

---

## 5. Architectural Highlights & Engineering Decisions

1. **Clean MVVM Structure**: Strict separation between Presentation (Widgets/Screens), ViewModel (Providers), Domain (Entities/Interfaces), and Data (Repositories/Hive Stores/Native Channels).
2. **Local-First Outbox Pattern**: UI operations complete immediately against local Hive storage. Pending remote mutations are queued as `ChatOutboxTask` items and processed asynchronously by `ChatSyncService`.
3. **Screen Security Policy**: Enforces `no_screenshot` on API key entry screens to prevent screen capturing or background preview leaks of sensitive keys.
4. **Non-Blocking Telemetry**: Analytics and background sync operations run asynchronously without blocking UI interactions or screen transitions.
5. **Scoped Native Permissions**: Lightweight MethodChannel respects modern Android 10+ scoped storage (no permission prompt) and iOS add-only photo access.
