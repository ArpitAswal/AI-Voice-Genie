# Changelog

All notable changes to the **AI Voice Genie** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - Unified Multi-Model Engine, Local-First Outbox Sync, On-Device PDF & Batch Management
**Release Date**: October 19, 2026

### 🚀 Added
- **Frontier Multi-Model Portfolio**:
  - **OpenAI**: Integrated `gpt-6-luna` for advanced text synthesis, vision, and document analysis, alongside `gpt-image-2.5-flare` for visual generation.
  - **Google Gemini**: Integrated `gemini-3.5-flash-lite` for multimodal intelligence, `gemini-3.1-flash-lite-image` with aspect-ratio controls (`1:1`, `16:9`, `9:16`) and quality tiers (`1K`, `2K`, `4K`), and `gemini-3.8-flash` with configurable thinking depth (`low`, `medium`, `high`).
  - **Anthropic Claude**: Integrated `claude-haiku-4-5-20251001` for complex code synthesis and document analysis.
- **On-Device PDF Document Compiler**: Pure-Dart client-side PDF document compiler (`PdfDocumentService`) transforms AI responses into styled, publication-ready PDFs with direct in-app preview, public Downloads export, and base64 document ingestion.
- **Durable Local-First Outbox Sync**: Sub-millisecond local rendering via Hive NoSQL paired with an autonomous background outbox queue (`ChatOutboxStore`, `ChatSyncService`) that syncs offline mutations (messages, deletions, title changes) to Cloud Firestore using exponential backoff.
- **Multi-Select Batch Conversation Management**: Long-press any conversation card to enter selection mode, pick multiple conversations, or tap "Select All" to perform atomic two-tier deletions across local Hive and remote Firestore.
- **AI Telemetry & Analytics Hardening**: Added `logPdfDownload`, `logUserAuthFailed`, standardized AI request telemetry on `model_used`, and streamlined `logImageDownload`.
- **Cross-Platform Support Mailer**: Universal mail composer integration across iOS and Android with RFC-3986 encoding, native `<queries>` declarations, third-party mail app deep links (Gmail, Outlook, Yahoo Mail, Spark), and browser webmail fallback.

### 🔄 Changed
- **Header Interface Optimization**: Removed the redundant standalone trash icon from the Conversation History header in favor of the unified multi-select batch deletion workflow.
- **Prompt Sanitization**: Dynamic prompt normalization strips conversational greetings (e.g., "Hey Genie", "Hello Claude") to maximize LLM context windows while preserving follow-up inquiries.
- **Pre-Flight Sanitization**: `ProviderRegistry` automatically filters unsupported parameters per provider before dispatch, eliminating HTTP 400 Bad Request errors.

### 🐛 Fixed
- **Support Mailer URL Launching**: Fixed mail composer failure on iOS and Android where encoded spaces were causing mailer launch failure.
- **Image Download Telemetry**: Cleaned up payload bloat and removed unused parameters from image and PDF download events.

### 🔒 Security
- **OS-Level Screen Defense (`FLAG_SECURE`)**: Prevents screenshots, screen recording, and multitasking card previews on sensitive API key setup screens.
- **Hardware Keystore & Keychain**: API keys are encrypted at rest with AES-256 and stored within Android Keystore and iOS Keychain.
- **Dynamic Memory Masking**: Credentials are obfuscated in memory (`sk-a...789`) to prevent shoulder surfing.
- **Atomic Account Deletion**: Completely wipes remote Cloud Firestore documents, purges local Hive storage, and deletes the authentication profile.

---

## [1.1.0] - Auto-TTS & Smart Prompt Filtering
**Release Date**: August 11, 2026

### 🚀 Added
- **Auto Text-To-Speech**: Added a toggle switch in the Profile preferences to automatically read aloud incoming AI responses.
- **Prompt Sanitization**: Implemented a regex engine to strip conversational greetings ("Hey Genie", "Good morning") from prompts before AI processing and title generation, maximizing model attention.
- **Enhanced Safety Moderation**: Deep integration with Gemini and OpenAI moderation endpoints to gracefully catch safety/content blocks and display localized user-friendly errors instead of crashing.
- **Contextual History Cards**: Updated Conversation History Cards to display the User's last prompt (or attachment type) instead of the AI's response for better context recall.

### 🐛 Fixed
- **TTS Lifecycle Leak**: Audio now immediately stops when navigating away from the Chat Detail screen.
- **Typewriter Re-triggering**: Fixed state persistence bug where returning to a chat re-triggered typewriter animation and voice playback.

## [1.0.0] - Initial Production Release
**Release Date**: July 31, 2026

### 🚀 Added
- **Unified Multi-Model Hub**: Complete integration for OpenAI (GPT-4o, GPT-Image-1), Google Gemini (2.5-Flash, 2.5-Flash-Image), and Anthropic Claude (3.5 Sonnet).
- **Bring Your Own Key (BYOK) Architecture**: Secure setup screen for users to input their own API keys, protected by Android `FLAG_SECURE` (`no_screenshot`).
- **Feature-First MVVM Architecture**: Scalable, modular folder structure utilizing `Provider` for reactive state management.
- **Local-First Caching**: Implemented `Hive` NoSQL database for rapid, $O(1)$ memory pagination of chat histories.
- **Offline Outbox Sync**: Implemented `connectivity_plus` combined with a durable outbox pattern to queue messages sent while offline and sync them upon network restoration.
- **Speech-to-Text Grammar Enhancement**: Real-time regex pipelines to automatically capitalize proper nouns and insert punctuation (e.g., question marks) into raw microphone streams.
- **Pre-Flight Sanitization**: Added capability checks via `ProviderRegistry` to strip unsupported fields before API dispatch (preventing HTTP 400 errors).
- **Firebase Telemetry**: Non-blocking integration with Firebase Analytics for usage tracking and Crashlytics for background unhandled exception reporting.
- **Legal & Support**: Included segmented UI for local Markdown-based Terms of Service & Privacy Policies, plus a `mailto:` support panel.
- **Cross-Platform Readiness**: Base code written in Flutter (`3.38.2`) & Dart (`3.10.0`). *Note: Currently strictly tested and optimized for Android mobile devices.*

### 🔒 Security
- **API Key Encryption**: All keys are encrypted at rest using AES-GCM via `flutter_secure_storage`.
- **Memory Obfuscation**: Keys are visually masked in the UI to prevent shoulder surfing.

### 📦 Assets Included Below:
Please download the APK that matches your Android device architecture (`arm64-v8a` is the most common for modern devices).