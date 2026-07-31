# Changelog

All notable changes to the **AI Voice Genie** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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