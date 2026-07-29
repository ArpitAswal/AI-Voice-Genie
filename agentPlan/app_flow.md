# App Flow: Code Execution Pathways

> **Purpose**: This document provides an exhaustive, step-by-step technical explanation of how each feature in **AI Voice Genie** operates at runtime. It maps the exact code calls, ViewModels, Repositories, Data Stores, Native Channels, and Storage mutations across every user journey.

---

## 1. Authentication: Sign In vs. Sign Out vs. Delete Account

### Purpose
- Contrast the exact technical flow, security rules, Firestore mutations, and storage cleanups between **Sign In**, **Sign Out**, and **Delete Account**.

### Execution Pathways

#### A. Sign In (Google / Apple)
```
LoginScreen -> Tap Google/Apple Button
  -> AuthProvider.signInWithGoogle() / signInWithApple()
  -> AuthRepository.signInWithGoogle() / signInWithApple()
  -> Firebase Auth OAuth Credential Sign-In
  -> AuthRepository._createOrUpdateUser()
  -> Read Firestore doc: AIVoiceGenie/AllUsers/{uid}/UserModel
       - If New User: Create new user document with onboardingDone=false, keySetupDone=false
       - If Returning User: Update lastLoginAt timestamp, keep isNewUser=false
  -> Hive Storage: Write session flags to user_box (isLoggedIn=true, userId, userEmail)
  -> AuthProvider.authState = authenticated
  -> Router redirects to OnboardingScreen / KeySetupScreen / IntroScreen
```

#### B. Sign Out
```
ProfileView / AccountPanel -> Tap Sign Out -> Confirm Dialog
  -> ProfileViewModel.signOut() -> AuthProvider.signOut()
  -> AuthRepository.signOut()
  -> GoogleSignIn.signOut() + FirebaseAuth.instance.signOut()
  -> Hive Storage: Clear user_box session data (isLoggedIn=false)
  -> AnalyticsService: Clear user ID, log user_signed_out
  -> AuthProvider.authState = unauthenticated
  -> AppRoutes redirects UI immediately back to LoginScreen
```
*Note*: Sign Out is session-level only. The user's Firestore data, API keys, and local chat history remain safely stored. On next sign-in, session is restored.

#### C. Delete Account
```
ProfileView / AccountPanel -> Tap Delete Account -> Warning Confirmation Sheet
  -> AuthProvider.deleteAccount()
  -> Security Check: Verify recent login (requiresRecentLogin check)
       - If session is stale: Throw AuthException requiring re-authentication
  -> Step 1: Remote API Key Deletion
       - Delete Firestore documents at AIVoiceGenie/UsersAPIKeys/{uid}/*
  -> Step 2: Remote User Profile Deletion
       - Hard delete Firestore document at AIVoiceGenie/AllUsers/{uid}/UserModel
  -> Step 3: Local Data Wipe
       - StorageService.clearUserData(): Clear user_box, chat_conversations_box,
         chat_messages_box, chat_outbox_box, chat_sync_state_box
  -> Step 4: Firebase Auth User Deletion
       - FirebaseAuth.instance.currentUser?.delete()
  -> Step 5: Sign out from Google / Apple OAuth providers
  -> AnalyticsService: Log user_account_deleted event
  -> AuthProvider.authState = unauthenticated -> Redirect to LoginScreen
```

---

## 2. API Key Configuration & Setup Flow

```
KeySetupScreen / SettingsPanel -> Enter Provider Key (OpenAI / Gemini / Claude)
  -> ApiKeyProvider.validateAndSaveKey(providerId, apiKey)
  -> ApiKeyRepository.validateKey(providerId, apiKey)
       - OpenAI: HTTP GET https://api.openai.com/v1/models (Header: Bearer key)
       - Gemini: HTTP GET https://generativelanguage.googleapis.com/v1beta/models?key=apiKey
       - Claude: HTTP POST https://api.anthropic.com/v1/messages (Header: x-api-key)
  -> On Validation Success:
       - ApiKeyRepository.saveKey(): Write to Firestore AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}
       - SecureStorageService: Encrypt and store key locally
  -> ApiKeyProvider.completeSetup()
       - Write keySetupDone=true to Firestore user document
       - Update Hive user_box keySetupCompleted=true
       - Route user into main application shell
```

---

## 3. Voice Speech-to-Text (STT) & Text-to-Speech (TTS) Flow

### A. Continuous Speech Recognition (STT)
```
ChatInputBar -> Tap Microphone Icon
  -> VoiceSpeechProvider.toggleListening()
  -> SpeechToText.listen(onResult: _onSpeechResult)
  -> Real-time Speech Engine Loop:
       - Captures raw audio stream from OS native microphone
       - Evaluates intermediate transcripts
       - Applies Real-Time Grammar Enhancement:
           * Proper noun capitalization (e.g. "openai" -> "OpenAI")
           * Vocative comma formatting & question clause segmentation
       - Auto-scrolls ChatInputBar text field as user speaks
       - Handles native engine timeout with debounced auto-restart
  -> User Taps Stop or Pauses -> Final transcript injected into ChatInputBar
```

### B. Text-to-Speech (TTS) Playback
```
MessageBubble -> Tap Speaker Icon (AI Response)
  -> VoiceSpeechProvider.speak(text)
  -> FlutterTts.setLanguage(locale) & setSpeechRate(0.5)
  -> FlutterTts.speak(cleanMarkdownText(text))
  -> Engine streams audio to device speaker while updating TTS playback state
```

---

## 4. Chat Prompt Execution & Multi-Media Attachments

```
ChatInputBar / ChatDetailScreen -> Submit Prompt with optional Attachments
  -> ChatProvider.sendMessage(promptText, attachments, preferredModel)
  
  Step 1: Attachment Processing (If Attachments Present)
    - Images (Camera / Gallery):
        * CloudinaryService.uploadImage(): Uploads image to Cloudinary CDN
        * Creates ChatAttachment(type: image, url: cdnUrl)
    - PDF Documents:
        * PdfReaderService.extractText(): Extracts raw text content from PDF file
        * Truncates text to safe token limits
        * Creates ChatAttachment(type: pdf, extractedText: text, fileName: name)

  Step 2: Optimistic Local State & Outbox
    - Create optimistic user MessageModel and local ConversationModel
    - Write immediately to Hive boxes (`chat_messages_box`, `chat_conversations_box`)
    - Enqueue `createConversation` & `sendMessage` in `chat_outbox_box`
    - UI updates instantly via notifyListeners()

  Step 3: AI Orchestration & Network Execution
    - AiOrchestrator.processRequest()
    - Select Adapter based on model: OpenAIAdapter / GeminiAdapter / ClaudeAdapter
    - Build provider payload incorporating:
        * System instructions & capability matrix
        * Conversation history
        * Vision image URLs / PDF extracted text blocks
        * User preferences (temperature, max tokens)
    - Stream HTTP response -> Receive response string & token counts

  Step 4: Assistant Message Persistence & Sync
    - Create assistant MessageModel with response text, model info, token usage
    - Save assistant message to Hive `chat_messages_box`
    - Enqueue assistant `sendMessage` task in `chat_outbox_box`
    - Trigger ChatSyncService background outbox drain to sync with Firestore
    - Log Analytics: logAiRequestSuccess()
```

---

## 5. AI Preferences Configuration Flow & Capability Matrix

```
ProfileView -> AiPreferencesPanel
  -> User changes setting (e.g. Selected Provider, Image Size, Vision Quality, Response Length)
  -> AiPreferencesProvider.setPreference(key, value)
  -> AiPreferencesService (Hive): Persists setting in `app_settings_box`
  -> ProfileAiPreferencesPanel UI immediately updates:
       - Checks ProviderRegistry.instance.profileFor(selectedProvider)
       - Hides controls that the selected provider does not support (e.g. Claude hides image generation controls).
       - Shows provider-specific controls (e.g. Gemini Aspect Ratio & Resolution Tier).
  -> ChatProvider.sendMessage() triggered:
       - Reads raw preferences from AiPreferencesProvider
       - Calls ProviderRegistry.instance.sanitizePreferences()
       - Generates an EffectiveAiRequestPreferences object stripped of unsupported fields
       - Builds final AiRequest passed to AiOrchestrator
```

---

## 6. AI Usage Tracking & Spending Limits Flow

```
AI Request Completes / App Opens
  -> UsageProvider.loadUsageData()
  -> UsageRepositoryImpl reads Firestore doc: AIVoiceGenie/UsersUsage/{uid}
  -> Displays: Total tokens consumed, prompt tokens, completion tokens, estimated cost ($)
  -> Spending Limit Check:
       - User can set custom monthly budget via UsageScreen
       - If estimated cost exceeds budget limit:
           * Surfaces alert banner in UI
           * Option to adjust budget or restrict high-cost models
```

---

## 7. AI-Generated Image Downloading & Native Device Saving

```
MessageBubble -> User taps GeneratedImageDownloadButton on AI Image
  -> ImageDownloadProvider.downloadImage(imageKey, imageSource, provider)
  -> ImageDownloadProvider sets state to ImageDownloadState.loading (UI shows spinner)
  -> ImageDownloadRepositoryImpl.downloadAndSaveImage():
       - Resolve image source: HTTP fetch / Base64 decode isolate / File read
       - Validate max size (25 MB limit)
       - Detect MIME type (PNG/JPEG/WEBP)
       - Generate clean filename: "aivoicegenie_{timestamp}_{index}.ext"
  -> DeviceImageSaveServiceImpl.saveImageBytes(bytes, fileName, mimeType)
  -> MethodChannel ("com.example.voice_genie/image_save"):
       - Android (ImageSavePlugin.kt): MediaStore insert into Pictures/AI Voice Genie (API 29+) or legacy write (API 28-)
       - iOS (ImageSavePlugin.swift): PHPhotoLibrary add-only write to Photos
  -> Result returned: DeviceImageSaveResult.success
  -> ImageDownloadProvider sets state to success -> Button displays green checkmark
  -> Context Snackbar:
       - Android: "Image saved to Pictures/AI Voice Genie"
       - iOS: "Image saved to Photos"
  -> Analytics logged: logImageDownload(result: success, provider: provider)
  -> Auto-reset timer resets button to idle after 2 seconds
```

---

## 8. Profile Information Editing & Avatar Preservation

```
ProfileView -> Tap Edit Profile -> EditProfileScreen
  -> EditProfileScreen initializes controllers with current UserModel
  -> User updates fields:
       - Required Validation: Name (non-empty), Email (valid format)
       - Optional Fields: Gender, Country, State, Date of Birth (Age auto-computed)
       - Optional Photo: Select new avatar OR leave untouched
  -> Tap "Update Profile"
  -> AuthProvider.updateUserProfile(...)
       - If New Photo Selected: Upload to Cloudinary -> get new photoUrl
       - If Photo Untouched: Retain existing photoUrl (preserves Google/Apple OAuth photo)
  -> AuthRepository.updateUserProfile(): Write updated fields to Firestore AllUsers/{uid}/UserModel
  -> Update local Hive session box (`user_box`)
  -> AuthProvider updates currentUser state & calls notifyListeners()
  -> Displays success toast & pops back to ProfileView
```

---

## 9. Localization & Language Switching Flow

```
ProfileView / SettingsPanel -> Toggle Language (English / Hindi)
  -> LocaleProvider.setLocale(Locale('hi') / Locale('en'))
  -> LocaleProvider persists choice in Hive `app_settings_box`
  -> AppLocalizations.load(locale) loads translations map
  -> UI re-renders instantly using context.l10n.key / translate(key)
```

---

## 10. Legal & About Information Viewing Flow

```
ProfileView / SupportPanel -> Tap "Privacy Policy", "Terms of Service", or "About App"
  -> Navigation to LegalScreen / AboutScreen
  -> LegalScreen: Segmented control toggles between Privacy Policy and Terms of Service
  -> Displays localized legal terms, data handling policies, and app version metadata
```

---

## 11. Offline Chat History & Outbox Background Sync Flow

```
User performs Chat Mutation (Create / Delete / Title Edit) while Offline
  -> LocalChatStore updates Hive box immediately -> UI reflects change instantly
  -> ChatOutboxStore enqueues ChatOutboxTask (taskType, payload, status=pending)
  -> Background Worker: ChatSyncService detects network connectivity restore
       - Reads pending outbox tasks
       - Sets status = processing
       - Executes RemoteChatStore Firestore API call
       - On Success: Deletes task from outbox & updates LocalChatStore syncStatus = synced
       - On Failure: Retries on next connection event with exponential backoff
```
