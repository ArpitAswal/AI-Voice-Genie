# App Flow: Code Execution Pathways

> **Purpose**: This document provides an exhaustive, step-by-step technical explanation of how each feature in **AI Voice Genie** operates at runtime. It maps the exact code calls, ViewModels, Repositories, Data Stores, Native Channels, and Storage mutations across every user journey and validated screen point.

---

## Screen & Navigation Map Overview

```
                                [ SplashScreen ] (Route: '/')
                                       │
                      Resolves AuthState + User Profile Flags
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         ▼                             ▼                             ▼
  [ Unauthenticated ]           [ Incomplete Setup ]          [ Fully Ready ]
   AuthScreen ('/login')               │                      TabBarScreen ('/tab-bar')
         │                             │                             │
   Google Sign-In                      │                             ├── Tab 0: IntroScreen (Home)
         │                             │                             ├── Tab 1: ConversationHistoryScreen
         ├─ New User (onboardingDone=false) ──> OnboardingScreen ('/onboarding')
         │                                            │              └── Tab 2: ProfileView (ProfileScreen)
         ├─ Key Setup Needed (keySetupDone=false) ────> KeySetupScreen ('/key-setup')
         │                                                    │
         └─ Existing & Configured User ───────────────────────┼──────> TabBarScreen ('/tab-bar')
                                                              │
                                   ┌──────────────────────────┴──────────────────────────┐
                                   ▼                                                     ▼
                        ChatScreen ('/chat')                               ChatDetailScreen ('/chat-detail')
                         (Start Conversation)                               (Active Message Conversation)
```

---

## 1. Authentication: Sign In vs. Sign Out vs. Delete Account

### Purpose
- Contrast the exact technical flow, security rules, Firestore mutations, and storage cleanups between **Sign In**, **Sign Out**, and **Delete Account**.

### Execution Pathways

#### A. Sign In (Google OAuth)
```
AuthScreen ('/login') -> Tap "Continue with Google" (AuthButtons in presentation/widgets/)
  -> AuthScreen._handleGoogleSignIn()
  -> LoadingOverlay.show(message: "Signing in...")
  -> AuthProvider.signInWithGoogle()
  -> AuthRepository.signInWithGoogle()
  -> GoogleSignIn.signIn() -> Retrieve GoogleSignInAuthentication
  -> Generate cryptographic SHA-256 Nonce
  -> FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(...))
  -> AuthRepository._createOrUpdateUser()
  -> Read Firestore doc: AIVoiceGenie/AllUsers/{uid}/UserModel
       - If New User: Create new user document with onboardingDone=false, keySetupDone=false
       - If Returning User: Update lastLoginAt timestamp, keep isNewUser=false
  -> Hive Storage: Write session flags to user_box (isLoggedIn=true, userId, userEmail)
  -> AuthProvider.authState = AuthState.authenticated
  -> LoadingOverlay.hide()
  -> AuthScreen._navigateAfterAuth() routes dynamically:
       - !user.onboardingDone -> OnboardingScreen ('/onboarding')
       - !user.keySetupDone   -> KeySetupScreen ('/key-setup')
       - otherwise            -> TabBarScreen ('/tab-bar')
```
*Note*: Apple Sign-In is structured under the same architecture via `signInWithApple()` and pre-built in `auth_buttons.dart`, pending Apple Developer account provisioning.

#### B. Sign Out
```
ProfileView / AccountPanel -> Tap Sign Out -> AppAlertDialog confirmation
  -> ProfileViewModel.signOut(authProvider) in lib/features/profile/presentation/
  -> LoadingOverlay.show(message: "Signing out...")
  -> AuthProvider.signOut()
  -> AuthRepository.signOut()
  -> GoogleSignIn.signOut() + FirebaseAuth.instance.signOut()
  -> Hive Storage: Clear user_box session data (isLoggedIn=false)
  -> AnalyticsService: Clear user ID, log user_signed_out
  -> AuthProvider.authState = AuthState.unauthenticated
  -> LoadingOverlay.hide()
  -> MessageUtils.showSuccess("Signed out successfully")
  -> AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login) (AuthScreen)
```
*Note*: Sign Out is session-level only. The user's Firestore data, encrypted API keys, and local chat history remain safely stored. On next sign-in, session is restored.

#### C. Delete Account
```
ProfileView / AccountPanel -> Tap Delete Account -> Warning AppAlertDialog confirmation
  -> ProfileViewModel.deleteAccount(authProvider) in lib/features/profile/presentation/
  -> LoadingOverlay.show(message: "Deleting account...")
  -> AuthProvider.deleteAccount()
  -> Security Check: Verify recent login (requiresRecentLogin check)
       - If session is stale: Catch FirebaseAuthException('requires-recent-login') and prompt re-auth
  -> Step 1: Remote API Key Deletion
       - Delete Firestore documents at AIVoiceGenie/UsersAPIKeys/{uid}/*
  -> Step 2: Remote User Profile Deletion
       - Hard delete Firestore document at AIVoiceGenie/AllUsers/{uid}/UserModel
  -> Step 3: Local Data Wipe
       - StorageService.clearUserData(): Clear user_box, chat_conversations_box,
         chat_messages_box, chat_outbox_box, chat_sync_state_box
       - UsageProvider.instance?.clear()
  -> Step 4: Firebase Auth User Deletion
       - FirebaseAuth.instance.currentUser?.delete()
  -> Step 5: Sign out from OAuth providers (GoogleSignIn.signOut())
  -> AnalyticsService: Log user_account_deleted event
  -> AuthProvider.authState = AuthState.unauthenticated
  -> LoadingOverlay.hide()
  -> MessageUtils.showSuccess("Account deleted")
  -> AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login) (AuthScreen)
```

---

## 2. API Key Configuration & Setup Flow

```
KeySetupScreen ('/key-setup')
  -> initState(): NoScreenshot.instance.screenshotOff() (Enforces Android FLAG_SECURE & iOS secure window)
  -> KeySetupScreen displays cards for ChatGPT, Gemini, and Claude
  -> User enters API key and taps "Save Key"
  -> ApiKeyProvider.validateAndSaveKey(providerId, apiKey)
  -> ApiKeyRepository.validateKey(providerId, apiKey):
       - OpenAI: HTTP GET https://api.openai.com/v1/models (Header: Bearer key)
       - Gemini: HTTP GET https://generativelanguage.googleapis.com/v1beta/models?key=apiKey
       - Claude: HTTP POST https://api.anthropic.com/v1/messages (Header: x-api-key)
  -> On Validation Success:
       - ApiKeyRepository.saveKey(): Write to Firestore AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}
       - SecureStorageService: Encrypt (AES-256) and store key in Keystore/Keychain
  -> User taps "Continue":
       - ApiKeyProvider.completeSetup()
       - Write keySetupDone=true to Firestore user document
       - Update Hive user_box keySetupCompleted=true
       - Route user into TabBarScreen ('/tab-bar')
  -> dispose(): NoScreenshot.instance.screenshotOn() (Restores screenshot capabilities)
```

---

## 3. Voice Speech-to-Text (STT) & Text-to-Speech (TTS) Flow

### A. Continuous Speech Recognition (STT)
```
ChatInputBar (in ChatScreen or ChatDetailScreen) -> Tap Microphone Icon
  -> VoiceSpeechProvider.toggleListening()
  -> SpeechToText.listen(onResult: _onSpeechResult)
  -> Real-time Speech Engine Loop:
       - Captures raw audio stream from OS native microphone
       - Evaluates intermediate transcripts
       - Applies Real-Time Grammar Enhancement:
           * Proper noun capitalization (e.g. "openai" -> "OpenAI", "gemini" -> "Gemini")
           * Vocative comma formatting & interrogative clause structuring
       - Auto-scrolls text field as user speaks
       - Handles native engine timeout with debounced auto-restart
  -> User Taps Stop or Pauses -> Final transcript injected into ChatInput text controller
```

### B. Home Screen Tap-to-Speak Shortcut
```
IntroScreen (Home Tab 0) -> Tap Big Central Microphone Button
  -> Guard: Verify VoiceProvider.isSttAvailable
  -> AppRoutes.navigateTo(context, AppRoutes.chat, arguments: ChatArguments(startMode: ChatStartMode.voice))
  -> ChatScreen mounts -> Post-frame callback checks startMode == ChatStartMode.voice
  -> Automatically triggers VoiceSpeechProvider.startListening() hands-free
```

### C. Text-to-Speech (TTS) Playback
```
MessageBubble -> Tap Speaker Icon on Assistant Response
  -> VoiceSpeechProvider.speak(text)
  -> Sets playback state to VoiceRecordingState.playing (animates speaker icon)
  -> FlutterTts.setLanguage(locale) & setSpeechRate(0.5)
  -> Strips raw markdown syntax for clean spoken sentences
  -> Audio streams to device speaker
  -> On completion: resets playback state to idle
```
*Architecture Note on Whisper*: `WhisperTranscriptionService` exists in `lib/features/voice_speech/data/` as an isolated cloud transcription module. It is currently gated off (`isUsingWhisper => false` in `VoiceSpeechRepositoryImpl`) in favor of zero-latency device-native continuous STT, keeping voice inputs instant and offline-capable without extra network hops.

---

## 4. Start Conversation & Pre-Built Quick Actions Flow

```
IntroScreen (Tap Message Button) OR Navigation to ChatScreen ('/chat')
  -> ChatScreen displays Top Bar ("New Conversation"), Centered Welcome Content, and Dropdown Provider Selector
  -> While conversation is fresh (no user input sent yet), _SuggestionGrid renders 5 curated actions:
       1. "Summarize PDF" (FontAwesomeIcons.fileLines):
            - Calls pickPdfWithPrompt("Summarize the key findings, executive takeaways...")
            - Opens FilePicker -> Extracts PDF text -> Populates input bar
       2. "Generate PDF" (FontAwesomeIcons.filePdf):
            - Injects prompt: "Generate a professional PDF report on the fundamentals of Artificial Intelligence..."
       3. "Generate Code" (FontAwesomeIcons.laptopCode):
            - Injects prompt: "Write a Python script to parse a CSV file, compute summary statistics..."
       4. "Analyze Image" (FontAwesomeIcons.magnifyingGlass):
            - Calls pickImageWithPrompt("Analyze this image in detail and describe the visual scene...")
            - Opens ImagePicker -> Attaches image -> Populates input bar
       5. "Create Image" (FontAwesomeIcons.images):
            - Injects prompt: "A serene Japanese Zen garden with cherry blossoms, a stone lantern..."
  -> As soon as a prompt is submitted, _hideSuggestions() smoothly collapses the grid via AnimatedSwitcher
```

---

## 5. Chat Prompt Execution & Multi-Media Attachments

```
ChatInputBar / ChatScreen / ChatDetailScreen -> Submit Prompt with optional Attachments
  -> ChatProvider.sendMessage(promptText, attachments, preferredModel)
  
  Step 1: Attachment Processing (If Attachments Present)
    - Images (Camera / Gallery):
        * ImagePicker / FlutterImageCompress: Selects & compresses image bytes
        * Encodes to base64 for direct vision payload dispatch to OpenAI/Gemini/Claude
    - PDF Documents:
        * FilePicker: Picks on-device PDF files (max 10MB per file, 15MB total)
        * Encodes raw PDF bytes directly into base64 for native multimodal ingestion (Gemini application/pdf, Claude type: document, OpenAI file_data)
        * Creates ChatAttachment(type: pdf, fileName: name, mimeType: application/pdf)

  Step 2: Optimistic Local State & Outbox
    - Create optimistic user MessageModel and local ConversationModel
    - Write immediately to Hive boxes (chat_messages_box, chat_conversations_box)
    - Enqueue createConversation & sendMessage in chat_outbox_box
    - UI updates instantly via notifyListeners()

  Step 3: AI Orchestration & Network Execution
    - AiOrchestrator.processRequest()
    - Select Adapter based on model:
        * OpenAIAdapter (gpt-6-luna / gpt-image-2.5-flare)
        * GeminiAdapter (gemini-3.5-flash-lite / gemini-3.1-flash-lite-image / gemini-3.8-flash)
        * ClaudeAdapter (claude-haiku-4-5-20251001)
    - Build provider payload incorporating:
        * System instructions & capability matrix
        * Conversation history
        * Vision image URLs / PDF extracted text blocks
        * User preferences (temperature, token limits, thinking level)
    - Stream HTTP response -> Receive response string & token counts

  Step 4: Assistant Message Persistence & Sync
    - Create assistant MessageModel with response text, model info, token usage
    - Save assistant message to Hive chat_messages_box
    - Enqueue assistant sendMessage task in chat_outbox_box
    - Trigger ChatSyncService background outbox drain to sync with Firestore
    - Log Analytics: logAiRequestSuccess()
```

---

## 6. On-Device PDF Document Generation Flow

```
User submits PDF creation prompt (or taps "Generate PDF" quick action)
  -> ChatProvider detects capability == AiCapability.pdfGeneration
  -> AI model returns structured document content formatted in Markdown
  -> ChatProvider._handleAiResponseSuccess():
       - Extracts document title via PdfDocumentService.extractDocumentTitle(prompt, markdown)
       - Formats clean file name via PdfDocumentService.formatFileName(docTitle)
       - Invokes PdfDocumentService.instance.compileMarkdownToPdf(markdown, title: docTitle)
           * Parses markdown headings, bullet points, blockquotes, code blocks, tables
           * Sanitizes typography and builds document layout using pdf package
           * Returns compiled Uint8List binary PDF bytes
       - Invokes PdfDocumentService.instance.savePdfToDevice(bytes, cleanFileName):
           * Writes binary bytes to app local cache directory
           * Creates ChatPdfInfo(title, fileName, localPath, pageCount, fileSizeBytes)
  -> Assistant MessageModel persisted with attached ChatPdfInfo
  -> MessageBubble renders customized PDF Card with document title, size, and page count
  -> User Interactions on PDF Card:
       - Tap Preview/Open -> PdfDocumentService.instance.openPdf(pdfInfo):
           * Opens file in native OS document viewer via platform intent / QuickLook
       - Tap Download/Save -> PdfDocumentService.instance.savePdfToPublicDownloads(pdfInfo):
           * Copies file to device public Downloads folder via MediaStore (Android) or Share Sheet (iOS)
           * Shows localized success toast via MessageUtils
```

---

## 7. AI Preferences Configuration Flow & Capability Matrix

```
ProfileView -> AiPreferencesPanel
  -> User changes setting (Selected Provider, Response Length, Image Size, Vision Detail, Thinking Level)
  -> AiPreferencesProvider.setPreference(key, value)
  -> AiPreferencesService (Hive): Persists setting in app_settings_box
  -> ProfileAiPreferencesPanel UI immediately updates:
       - Checks ProviderRegistry.instance.profileFor(selectedProvider)
       - Dynamically hides controls not supported by selected provider (e.g. hides image settings for Claude)
       - Dynamically exposes provider-specific controls:
           * Gemini: Aspect Ratio (1:1, 16:9, 9:16), Image Size Tier (1K, 2K, 4K), Thinking Level (Low, Medium, High)
           * OpenAI: Pixel Size (1024x1024, 1024x1536, 1536x1024), Quality (Low, Medium, High), Background (Auto, Opaque, Transparent), Vision Detail (Auto, Low, High)
  -> ChatProvider.sendMessage() triggered:
       - Reads preferences from AiPreferencesProvider
       - Calls ProviderRegistry.instance.sanitizePreferences()
       - Generates EffectiveAiRequestPreferences object stripped of unsupported fields
       - Passes safe payload to AiOrchestrator (guaranteeing 0% HTTP 400 bad request errors)
```

---

## 8. AI Usage Tracking & Spending Limits Flow

```
AI Request Completes / App Opens / ProfileView Mounted
  -> ProfileView initState() -> UsageProvider.loadForMonth(uid)
  -> UsageRepositoryImpl reads Firestore doc: AIVoiceGenie/UsersUsage/{uid}
  -> ProfileView -> AiIntelligenceSection displays:
       - Total tokens consumed, prompt tokens, completion tokens
       - Estimated cost ($ USD) computed via UsagePricingTable
  -> Budget Limit Configuration:
       - User taps "Set Budget" / "Edit Budget" -> Opens BudgetEditorSheet modal
       - User inputs monthly spending limit -> UsageProvider.setBudget(uid, limit)
       - Persists to Firestore and Hive
  -> Spending Limit Check:
       - If estimated cost approaches 80% or 100% of budget:
           * Surfaces warning banner in UI
           * Disables or warns against high-cost model calls
```

---

## 9. AI-Generated Image Downloading & Native Device Saving

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

## 10. Profile Information Editing & Avatar Preservation

```
ProfileView -> Tap Edit Profile -> EditProfileScreen ('/profile/edit')
  -> EditProfileScreen initializes controllers with current UserModel
  -> User updates fields:
       - Required Validation: Name (non-empty), Email (valid format)
       - Optional Fields: Gender, Country, State, Date of Birth (Age auto-computed)
       - Optional Photo: Select new avatar OR leave untouched
  -> Tap "Update Profile"
  -> AuthProvider.updateUserProfile(...)
       - If New Photo Selected: Compress bytes -> Upload to Cloudinary -> get new photoUrl
       - If Photo Untouched: Retain existing photoUrl (preserves Google/Apple OAuth photo)
  -> AuthRepository.updateUserProfile(): Write updated fields to Firestore AllUsers/{uid}/UserModel
  -> Update local Hive session box (user_box)
  -> AuthProvider updates currentUser state & calls notifyListeners()
  -> Displays success toast via MessageUtils & pops back to ProfileView
```

---

## 11. Localization & Language Switching Flow

```
ProfileView / SettingsPanel -> Toggle Language (English / Hindi)
  -> LocaleProvider.setLocale(Locale('hi') / Locale('en'))
  -> LocaleProvider persists choice in Hive app_settings_box
  -> AppLocalizations.load(locale) loads translations map
  -> UI re-renders instantly using context.l10n.key / translate(key)
```

---

## 12. Legal, About & Support Information Flow

```
ProfileView / SupportPanel
  -> Tap "About App" -> AppRoutes.navigateTo(context, AppRoutes.about) (AboutScreen)
       - Displays app logo, current version (PackageInfo), developer details, and copyright
  -> Tap "Privacy Policy" -> AppRoutes.navigateTo(context, AppRoutes.privacy) (LegalScreen)
       - Loads and parses assets/legal/privacy_policy.md
  -> Tap "Terms of Service" -> AppRoutes.navigateTo(context, AppRoutes.terms) (LegalScreen)
       - Loads and parses assets/legal/terms_of_service.md
  -> Tap "Support" -> SupportPanel triggers mailto: URL via url_launcher to contact developer directly
```

---

## 13. Offline Chat History & Outbox Background Sync Flow

```
User performs Chat Mutation (Create / Delete / Title Edit) while Offline
  -> LocalChatStore updates Hive box immediately -> UI reflects change instantly
  -> ChatOutboxStore enqueues ChatOutboxTask (taskType, payload, status=pending)
  -> Background Worker: ChatSyncService detects network connectivity restore via connectivity_plus
       - Reads pending outbox tasks
       - Sets status = processing
       - Executes RemoteChatStore Firestore API call
       - On Success: Deletes task from outbox & updates LocalChatStore syncStatus = synced
       - On Failure: Retries on next connection event with exponential backoff
```

---

## 14. Cursor-Based Pagination & Hydration Flow

### A. Chat History Pagination (Conversations)
```
ConversationHistoryScreen (Tab 1) -> User scrolls to bottom (maxScrollExtent - 200)
  -> ChatProvider.loadMoreConversations()
  -> ChatRepositoryImpl.getConversationPage(limit: 15, cursor, searchQuery)
  -> LocalChatStore.getConversationPage()
       - Scans local Hive box for conversations matching the search query
       - Skips items up to cursor (timestamp + id)
       - Returns the next page of up to 15 items instantly
  -> UI adds items to visibleConversations
  Note: Artificial 300ms delay is injected so the loading spinner is visible, preventing runaway fast-scrolls.
```

### B. Chat Detail Pagination (Messages)
```
ChatDetailScreen -> User scrolls up to read older history
  -> ChatProvider.loadOlderMessages()
  -> ChatRepositoryImpl.getOlderMessagePage(limit: 20, cursor)
  -> LocalChatStore.getMessagePage()
       - Returns next 20 older messages from local Hive memory
  -> Background Hydration:
       - ChatRepositoryImpl simultaneously calls RemoteChatStore.getOlderMessages()
       - If Firestore has older messages not in Hive, they are fetched and merged into LocalChatStore
       - The UI stream reactively pushes these newly downloaded older messages seamlessly
```

---

## 15. Dynamic Status Message & Alert System Flow

```
Any Screen / Component -> Calls context.showSuccess / showError / showWarning
  -> StatusMessageUtils delegates to _MessageManager.instance.show(...)
  -> Priority & Severity Mapping:
       - Error: Priority 3 (Highest) -> Top slide-down overlay (Red)
       - Warning: Priority 2 (Medium) -> Top slide-down overlay (Amber)
       - Success: Priority 1 (Lowest) -> Bottom slide-up overlay (Green)
  -> Smart Deduplication & Preemption:
       - If identical message is already visible in channel: extends auto-dismiss timer without flicker
       - If higher priority arrives: immediate preemption and replacement of lower priority message
       - If lower priority arrives while higher is visible: discarded to protect user awareness of critical alert
  -> Multi-Channel Stacking:
       - Supports independent _Channel.snackbar and _Channel.toast simultaneously
       - When two messages occupy the same edge, applies stack offset (64.0 px) to prevent collision
  -> Auto-Dismiss & Gesture Handling:
       - Timer dismisses after configured duration (2s for success, 4s for warning/error)
       - User can swipe horizontally or vertically to dismiss instantly
```
