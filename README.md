# AI Voice Genie

AI Voice Genie is a Flutter app for multi-model AI chat with provider selection, conversation history, and image-generation support.

## Project Overview
- Flutter application using Provider-based MVVM.
- Firebase handles authentication, Firestore persistence, analytics, and crash reporting.
- Hive handles local preferences and conversation cache.

## Key Features
- Google and Apple sign-in.
- API key setup for OpenAI, Gemini, and Claude.
- New chat and chat detail conversation flow.
- Conversation history with reopen support.
- Local replay of generated image messages.

## Setup
1. Install Flutter 3.3 or newer.
2. Run `flutter pub get`.
3. Configure Firebase with `flutterfire configure` if the generated options file needs to be regenerated.
4. Launch the app with `flutter run`.

## Environment Configuration
- Firebase configuration lives in `lib/firebase_options.dart`.
- AI provider keys are stored in Firestore through the key setup flow.
- No Firebase Storage setup is required for generated chat images in the current design.

## Build Instructions
- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`

## Deployment Instructions
- Ensure Firebase project settings match the generated FlutterFire options.
- Publish mobile builds through the platform-specific release process.

## Architecture Overview
- `lib/core` contains shared app infrastructure.
- `lib/ai_layer` contains AI orchestration and provider adapters.
- `lib/features` contains the user-facing MVVM feature modules.

## Folder Structure
- `lib/core`: constants, routing, theme, localization, services, utilities.
- `lib/ai_layer`: AI request and response handling.
- `lib/features/auth`: authentication flow.
- `lib/features/key_setup`: provider key setup.
- `lib/features/chat_prompt`: chat history, detail, and send flow.
- `lib/features/home`: tab-based navigation.

## Contribution Guide
- Follow the existing feature-first structure.
- Update documentation when flows or persistence change.
- Prefer reusable shared components over one-off widgets.
