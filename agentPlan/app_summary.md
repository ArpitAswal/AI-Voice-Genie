# App Summary: Project Overview & Presentation

> **Overview**: **AI Voice Genie** is a feature-rich, production-grade Flutter application designed to serve as a unified, multi-model AI assistant hub. It allows users to harness the capabilities of leading AI providers (OpenAI, Gemini, and Claude) through text, vision, document analysis, voice speech, and AI image generation in a single, local-first application.

---

## 1. Executive Summary & Problem Solved

### The Problem
- **Fragmentation**: Users traditionally need separate apps/subscriptions to access OpenAI's ChatGPT, Google's Gemini, and Anthropic's Claude.
- **Privacy & Latency Concerns**: Cloud-only chat history often creates slow load times, unresponsiveness during network outages, and privacy risks when managing media files locally.
- **Platform Inconsistencies**: Native image saving often suffers from intrusive permission prompts or broken file storage handling across different Android and iOS OS versions.

### The Solution
- **Unified Multi-Model Hub**: Users connect their own API keys and seamlessly switch between OpenAI, Gemini, and Claude for text generation, image creation, multi-image vision analysis, and PDF summarization.
- **Local-First Architecture**: Powered by Hive local databases, chat history is read and rendered instantaneously with zero network delay. Offline mutations are queued in a durable outbox and synced to Cloud Firestore in the background when connected.
- **Native OS Scoped Media Storage**: Custom Kotlin and Swift MethodChannels manage image downloads directly into native galleries (`Pictures/AI Voice Genie` on Android MediaStore API 29+, `Photos` on iOS) without requesting unnecessary permission broad scopes.

---

## 2. Core Functional Modules

### A. Authentication & User Profile Management
- **OAuth Sign-In**: Google Sign-In and Apple Sign-In authentication integrated with Firebase Auth.
- **Profile Overview & Editing**: Users can view and edit their profile (`ProfileView` & `EditProfileScreen`). Required fields (Name, Email) are validated, while optional demographic details (Gender, Country, State, Date of Birth, Age) are saved to Firestore.
- **Avatar Preservation**: External OAuth profile pictures are protected when text fields are edited without picking a new image.
- **Sign Out vs. Account Deletion**: Sign Out clears local session state without altering remote user data. Account Deletion requires recent authentication, deletes remote API keys and Firestore profile records, wipes all local Hive database boxes, deletes the Firebase Auth account, and resets provider credentials.

### B. Multi-Model AI Orchestration Engine
- **Centralized Orchestrator**: `AiOrchestrator` normalizes user prompts and routes execution to provider-specific adapters (`OpenAIAdapter`, `GeminiAdapter`, `ClaudeAdapter`).
- **Capability Matrix**: Maps model capabilities (text, vision, image generation, document parsing) and dynamically sets system prompts, token bounds, and temperature preferences.
- **Attachment Pipeline**: Handles image uploads via Cloudinary and performs text extraction on PDF documents (`PdfReaderService`) before building AI payloads.

### C. Voice & Speech Capabilities
- **Continuous Speech Recognition (STT)**: Real-time microphone listening with automatic grammar formatting (proper noun capitalization, vocative comma insertion, question clause structuring) and auto-scrolling input.
- **Text-to-Speech (TTS)**: Built-in voice playback for assistant text responses.

### D. Native AI Image Downloading
- **Overlay Download Button**: Positioned on AI-generated images in the chat stream with per-image loading spinners, checkmark success feedback, and error handling.
- **Scoped Storage**: Uses native Kotlin MediaStore logic (Android) and Swift Photo Library logic (iOS) to save clean filenames (`aivoicegenie_{timestamp}_{index}.ext`) directly to the gallery with platform-specific success toasts.

### E. AI Usage Tracking & Spending Limits
- **Usage Metrics**: Tracks prompt tokens, completion tokens, total token consumption, and estimated costs per AI model.
- **Budget Controls**: Enables users to set monthly spending limits and receive visual budget alerts.

### F. Personalization & Localization
- **AI Preferences**: Custom settings for default provider, vision detail level, image size/quality, and token limits. Powered by an `AiModelCapabilityProfile` matrix that dynamically hides unsupported controls (e.g. hiding image settings when Claude is selected) and reveals provider-specific features (e.g. Gemini aspect ratios).
- **Multilingual Support**: Real-time language switching between English and Hindi powered by `LocaleProvider` and `AppLocalizations`.
- **Theming**: Theme switching between Light, Dark, and System modes via `ThemeProvider`.
- **Legal & Info**: Dedicated Privacy Policy, Terms of Service, and About App screens (`LegalScreen`, `AboutScreen`).

---

## 3. Technology Stack & Key Libraries

| Component | Technology / Library | Purpose |
|---|---|---|
| **Core Framework** | Flutter & Dart | Cross-platform mobile development (Android & iOS). |
| **State Management** | Provider (`ChangeNotifier`) | Reactive, predictable state propagation and MVVM ViewModel implementation. |
| **Cloud Infrastructure** | Firebase Auth, Cloud Firestore | User session management and remote cloud database synchronization. |
| **Local Persistence** | Hive (`Hive.box`) | Zero-latency local storage for session data, chat conversations, messages, outbox tasks, and app settings. |
| **Secure Storage** | `flutter_secure_storage` | Platform-level encrypted storage for sensitive API keys. |
| **Native Integration** | MethodChannel (`ImageSavePlugin`) | Native Kotlin (Android MediaStore) and Swift (iOS PHPhotoLibrary) image download extensions. |
| **Media Hosting** | Cloudinary API | Cloud storage for user avatar picture uploads. |
| **Telemetry & Quality** | Firebase Analytics & Crashlytics | Fire-and-forget analytics logging and automated crash reporting. |

---

## 4. Architectural Highlights & Engineering Decisions

1. **Clean MVVM Structure**: Strict separation between Presentation (Widgets/Screens), ViewModel (Providers), Domain (Entities/Interfaces), and Data (Repositories/Hive Stores/Native Channels).
2. **Local-First Outbox Pattern**: UI operations complete immediately against local Hive storage. Pending remote mutations are queued as `ChatOutboxTask` items and processed asynchronously by `ChatSyncService`.
3. **Non-Blocking Telemetry**: Analytics and background sync operations run asynchronously without blocking UI interactions or screen transitions.
4. **Scoped Native Permissions**: Avoided heavy third-party plugins by writing a lightweight MethodChannel that respects modern Android 10+ scoped storage (no permission prompt) and iOS add-only photo access.
