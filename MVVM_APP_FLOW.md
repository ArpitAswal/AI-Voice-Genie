# AI Voice Genie — MVVM App Flow (Phases 0–5 Partial)

---

## How to Read This Document

Each section shows a complete MVVM flow for one feature:

```
USER ACTION
  → VIEW (Screen/Widget)
    → VIEWMODEL (Provider — ChangeNotifier)
      → DOMAIN (Repository Interface + Models)
        → DATA (Repository Impl — Firestore / HTTP / Hive)
          → EXTERNAL (Firebase / AI APIs)
        ← DATA returns typed result / throws typed Exception
      ← DOMAIN returns entity or throws exception
    ← VIEWMODEL updates state → notifyListeners()
  ← VIEW rebuilds via Consumer / Selector / context.watch
USER SEES updated UI
```

---

---

## PHASE 0 — Core Foundation (No User Flow — Infrastructure Only)

These files have no user-facing flow. They are consumed by every other layer.

```
core/
│
├── constants/
│   ├── app_colors.dart         → Color tokens. Used by AppTheme and every widget.
│   ├── app_text_styles.dart    → Typography tokens. Used by AppTheme.
│   ├── app_constants.dart      → App-wide + AI constants (model names, URLs, limits).
│   ├── storage_keys.dart       → All Hive key strings. Used by StorageService callers.
│   └── firebase_collections.dart → All Firestore paths + analytics event/param names.
│
├── enums/
│   └── app_enums.dart          → AiProviderId, AiCapability, AuthState, ApiKeyStatus,
│                                  MessageRole, MessageStatus, SocialAuthProvider,
│                                  ConversationCapability, AiFailureType, AppFeature,
│                                  ThemeType, VoiceRecordingState, AiImageSize (Phase 5)
│
├── extensions/
│   ├── context_extensions.dart → context.isTablet, context.isDark, context.screenWidth,
│   │                              context.horizontalPadding, context.bottomPadding
│   └── string_extensions.dart  → .capitalize, .maskedApiKey, DateTime.toTimeString,
│                                  DateTime.toConversationDate, DateTime.toMessageTimestamp
│
├── theme/
│   ├── app_theme.dart          → getLightTheme(context), getDarkTheme(context)
│   │                              Full Material 3 theming. No widget uses raw colors.
│   └── theme_provider.dart     ← [VIEWMODEL] ThemeMode state + Hive persistence
│                                  Used by: MaterialApp.themeMode via Consumer2
│
├── localization/
│   ├── app_localizations.dart  → translate(key), named getters (appName, appTagline…)
│   │                              EN + HI string maps. 100+ keys.
│   └── locale_provider.dart    ← [VIEWMODEL] Locale state + Hive persistence
│                                  Used by: MaterialApp.locale via Consumer2
│
├── router/
│   └── app_routes.dart         → Route name constants, generateRoute(), navigation helpers
│                                  All Navigator calls go through here.
│                                  Wired screens: Splash, Login, Onboarding, KeySetup,
│                                  Home, Chat, ChatDetail, ConversationHistory
│                                  Placeholders: ImageGen, ImageReader, PDF, Settings, Profile
│
├── services/
│   ├── storage_service.dart    → Hive singleton. Boxes: settings, user, conversationCache.
│   │                              Used by: AuthRepositoryImpl, ApiKeyRepositoryImpl,
│   │                              ChatRepositoryImpl, ThemeProvider, LocaleProvider
│   ├── analytics_service.dart  → Firebase Analytics wrapper (singleton).
│   │                              All events go through here. Never call FA directly.
│   └── secure_storage_service.dart → flutter_secure_storage wrapper. Used for session tokens.
│
├── error/
│   ├── ai_exception.dart       → Sealed AiException hierarchy:
│   │                              AiTransientException, AiRateLimitException,
│   │                              AiHardErrorException, AiCapabilityGapException,
│   │                              AiExhaustedException + mapHttpErrorToAiException()
│   ├── effect_bus.dart         → Singleton broadcast stream. emit(error, stackTrace).
│   │                              safeEffect(() async { ... }) wraps risky async ops.
│   └── global_effect_listener.dart ← [VIEW — wrapper] Listens to EffectBus stream.
│                                  On failure → MessageUtils.showWarning via context.
│                                  Injected at MaterialApp.builder level.
│
├── utils/
│   ├── validators.dart         → Static validators: validateEmail, validatePrompt,
│   │                              validateApiKey, validateImagePrompt, validateRequired
│   ├── message_utils.dart      → Overlay-based feedback system. Two channels: snackbar/toast.
│   │                              Priority dedup. showSuccess/showError/showWarning.
│   │                              Context extensions: context.showSuccess(msg)
│   └── loading_overlay.dart    → Blocking loading dialog. wrap(future), show(), hide().
│                                  Context extensions: context.showLoading(), context.withLoading()
│
└── core.dart                   → Barrel export for all core files.
```

---

---

## PHASE 1 — Authentication

### Flow 1A: Cold Start — Check Existing Session

```
APP LAUNCH
  → main.dart: runApp(AiVoiceGenieApp)
    → MultiProvider registers:
        ThemeProvider..initialize()   reads Hive → sets ThemeMode
        LocaleProvider..initialize()  reads Hive → sets Locale
        AuthProvider..initialize()    [lazy:false → runs immediately]
          → AuthRepositoryImpl.getCurrentUser()
            → FirebaseAuth.currentUser check
            → if not null → Firestore get(AI_Voice_Genie/users/{uid})
              → DocumentSnapshot exists → UserModel.fromFirestore(data)
              → _persistSession(user) → writes Hive session keys
            → if null → return null
          ← UserModel? returned
        → if user != null → AuthState.authenticated, _analytics.setUserId(uid)
        → if null         → AuthState.unauthenticated
        → notifyListeners()

  → MaterialApp builds with:
      initialRoute: AppRoutes.splash
      onGenerateRoute: AppRoutes.generateRoute → SplashScreen

  → SplashScreen mounts
      _setupAnimations() → logo fade + scale
      _startMinDurationTimer() → 2500ms delay
      Consumer<AuthProvider> listens → addPostFrameCallback → _attemptNavigation()

  AFTER 2500ms + AuthState resolved:
  ┌─ AuthState.authenticated
  │   user.onboardingDone = false → navigateAndRemoveUntil → OnboardingScreen
  │   user.keySetupDone   = false → navigateAndRemoveUntil → KeySetupScreen
  │   both = true                 → navigateAndRemoveUntil → HomeScreen
  │
  └─ AuthState.unauthenticated   → navigateAndRemoveUntil → LoginScreen
```

---

### Flow 1B: Google Sign-In

```
USER sees LoginScreen
  → _GoogleSignInButton rendered (always)
  → _AppleSignInButton rendered (Platform.isIOS only)

USER taps "Continue with Google"
  → _handleGoogleSignIn() called
    → AnalyticsService.logSignInButtonTapped(SocialAuthProvider.google)
                                [FIRES BEFORE auth — tracks intent]
    → context.showLoading('signing_in')
    → AuthProvider.signInWithGoogle()

      [VIEWMODEL → AuthProvider]
      → _performSignIn(() → _repository.signInWithGoogle(), google)
      → AuthState.authenticating → notifyListeners()

        [DATA → AuthRepositoryImpl]
        → GoogleSignIn().signIn()
          → user cancels → returns null → AuthState.unauthenticated → return false
          → user selects account → GoogleSignInAuthentication received
        → GoogleAuthProvider.credential(accessToken, idToken)
        → FirebaseAuth.signInWithCredential(credential)
        → UserCredential returned
        → _createOrUpdateUser(firebaseUser, SocialAuthProvider.google)

            [FIRESTORE READ]
            → Firestore.doc('AI_Voice_Genie/users/{uid}').get()
              → doc NOT exists (NEW USER)
                → _resolveDisplayName → firebase user display name or email prefix
                → _resolveEmail → firebase user email
                → UserModel.toFirestoreNewUser() → Firestore.set(data + serverTimestamps)
                → isNewUser = true
              → doc EXISTS (RETURNING USER)
                → UserModel.fromFirestore(existingData)
                → Firestore.update({lastLoginAt: serverTimestamp})
                → isNewUser = false

            [HIVE WRITE]
            → _persistSession(user)
              → StorageService.setBool(isLoggedIn, true)
              → StorageService.setUserData(userId, uid)
              → StorageService.setUserData(userEmail, email)
              → StorageService.setUserData(userDisplayName, name)
              → StorageService.setBool(onboardingCompleted, user.onboardingDone)
              → StorageService.setBool(keySetupCompleted, user.keySetupDone)

        ← UserModel returned to AuthProvider

      [VIEWMODEL]
      → user.isNewUser → analytics.logUserRegistered()
                      OR analytics.logUserSignedIn()
      → analytics.setUserId(uid)
      → _currentUser = user
      → AuthState.authenticated → notifyListeners()
      → return true

    ← true returned to _handleGoogleSignIn()
    → context.hideLoading()

  → SplashScreen / LoginScreen Consumer fires _attemptNavigation()
    → Same routing logic as Flow 1A
```

---

### Flow 1C: Apple Sign-In (iOS only)

```
USER taps "Continue with Apple"
  → _handleAppleSignIn() called
    → AnalyticsService.logSignInButtonTapped(SocialAuthProvider.apple)
    → context.showLoading('signing_in')
    → AuthProvider.signInWithApple()

      [DATA → AuthRepositoryImpl]
      → _generateNonce() → raw 32-char random string
      → _sha256ofString(rawNonce) → hashedNonce
      → SignInWithApple.getAppleIDCredential(
            scopes: [email, fullName], nonce: hashedNonce)
        → user cancels → SignInWithAppleAuthorizationException(canceled)
                       → return null → silent, no error shown
        → user authenticates → AuthorizationCredentialAppleID received
          → givenName: (only on FIRST sign-in, null on return)
          → email:     (only on FIRST sign-in, null on return)
      → OAuthProvider('apple.com').credential(idToken, rawNonce)
      → FirebaseAuth.signInWithCredential(appleCredential)
      → _createOrUpdateUser(firebaseUser, SocialAuthProvider.apple,
             appleGivenName: credential.givenName,
             appleEmail: credential.email)

          APPLE RETURNING USER — MISSING FIELD STRATEGY:
          → Firestore.doc('AI_Voice_Genie/users/{uid}').get()
          → doc EXISTS:
            → resolvedDisplayName = existingData['displayName'] (stored from first sign-in)
            → resolvedEmail       = existingData['email']       (stored from first sign-in)
            → photoUrl            = ''  (Apple never provides photos)
          → doc NOT EXISTS (first sign-in):
            → resolvedDisplayName = appleGivenName ?? 'User'
            → resolvedEmail       = appleEmail ?? firebaseUser.email ?? ''
            → photoUrl            = ''

      ← Same flow as Google from here
```

---

### Flow 1D: Sign-In Failure

```
FAILURE during FirebaseAuth.signInWithCredential()
  → FirebaseAuthException caught in AuthRepositoryImpl
  → _mapFirebaseAuthError(e.code) → localization key string
  → throw AuthException(code, technicalMessage)

  → AuthProvider._performSignIn() catches AuthException
  → e.isCancelled == false → not silent
  → _authError = e.code  (e.g. 'no_internet_connection')
  → AuthState.unauthenticated → notifyListeners()

  → context.hideLoading()
  → LoginScreen._consumeError()
    → authProvider.authError != null
    → context.showError('no_internet_connection')
       → MessageUtils.showError → overlay slides in from top
    → authProvider.clearAuthError()

USER sees error message. Stays on LoginScreen. Can retry.
```

---

---

## PHASE 2 — AI Key Setup

### Flow 2A: First-Time Key Setup Screen Mount

```
SplashScreen routes to → OnboardingScreen
  → User swipes through 3 pages (intro content)
  → Taps "Get Started" or skips
    → AppRoutes.navigateAndReplace → KeySetupScreen(isInitialSetup: true)

KeySetupScreen mounts
  → initState() → addPostFrameCallback
    → uid = context.read<AuthProvider>().currentUser?.uid
    → ApiKeyProvider.loadExistingKeys(uid)

      [VIEWMODEL → ApiKeyProvider]
      → _repository.loadKeys(uid)

        [DATA → ApiKeyRepositoryImpl]
        → 3 parallel Firestore.doc().get() calls:
            AI_Voice_Genie/users/{uid}/apiKeys/openai
            AI_Voice_Genie/users/{uid}/apiKeys/gemini
            AI_Voice_Genie/users/{uid}/apiKeys/claude
        → Map<AiProviderId, ApiKeyModel> returned

      ← Map returned to ApiKeyProvider
      → For each found key:
          _storedKeys[provider] = model
          _statuses[provider] = model.isValid ? valid : invalid
      → notifyListeners()

  USER SEES:
  → Three provider cards (ChatGPT, Gemini, Claude)
  → Each card shows current status chip (Not Added / Valid / Invalid)
  → Continue button disabled (no valid keys yet)
  → OR Continue button active (returning user with existing valid keys)
```

---

### Flow 2B: User Validates and Saves an API Key

```
USER taps ChatGPT card TextField → pastes 'sk-proj-...'
  → TextField.onChanged → ApiKeyProvider.clearError(openAi)

USER taps "Add Key" / Validate button
  → _ProviderKeyCardState._handleValidate()
    → ApiKeyProvider.clearError(openAi)
    → _formKey.currentState?.validate()
      → Validators.validateApiKey(value, providerName: 'ChatGPT')
        → null (empty) → show inline field error → STOP
        → length < 20  → show inline field error → STOP
        → passes → continue
    → uid = context.read<AuthProvider>().currentUser?.uid
    → ApiKeyProvider.validateAndSaveKey(uid, AiProviderId.openAi, 'sk-proj-...')

      [VIEWMODEL → ApiKeyProvider]
      → _errors[openAi] = null
      → _statuses[openAi] = ApiKeyStatus.validating → notifyListeners()
      → Card shows spinner, Validate button disabled

        [DATA → ApiKeyRepositoryImpl.validateKey]
        → HTTP GET https://api.openai.com/v1/models
            headers: {Authorization: 'Bearer sk-proj-...'}
            timeout: 90 seconds
        → 200 OK   → return true (VALID)
        → 401/403  → return false (INVALID)
        → 429      → return true  (rate limited but key exists → treat as valid)
        → 500/503  → throw ApiKeyException(serviceUnavailable)
        → timeout  → throw ApiKeyException(timeout)
        → SocketException → throw ApiKeyException(noInternet)

      ← true returned (valid)

        [DATA → ApiKeyRepositoryImpl.saveKey]
        → Firestore.doc('AI_Voice_Genie/users/{uid}/apiKeys/openai').set({
              providerId: 'openai',
              apiKey: 'sk-proj-...',
              isValid: true,
              keyLastValidated: serverTimestamp,
              keyAddedAt: serverTimestamp
          })

      ← saved

      [VIEWMODEL]
      → _storedKeys[openAi] = ApiKeyModel(...)
      → AnalyticsService.logModelKeyAdded(AiProviderId.openAi)
      → _statuses[openAi] = ApiKeyStatus.valid → notifyListeners()

  USER SEES:
  → ChatGPT card turns green, checkmark chip shows "Key is valid"
  → Masked key shown: 'sk-p••••...'
  → Delete icon appears on card
  → Continue button activates (1 valid key now exists)
```

---

### Flow 2C: Key Validation Failure

```
USER pastes invalid key → taps Validate
  → HTTP GET → 401 Unauthorized → return false

  [VIEWMODEL]
  → _errors[openAi] = 'key_invalid'
  → _statuses[openAi] = ApiKeyStatus.invalid → notifyListeners()

  USER SEES:
  → Card border turns red
  → Inline error: "Invalid API key. Please check and try again."
  → Status chip: "Invalid"
  → Continue button stays disabled
  → User can re-paste and retry
```

---

### Flow 2D: Complete Setup → Navigate to Home

```
USER has at least one valid key → taps "Done" (Continue button)
  → _handleContinue() called
    → uid = context.read<AuthProvider>().currentUser?.uid
    → context.showLoading('please_wait')
    → ApiKeyProvider.completeSetup(uid)

      [VIEWMODEL → ApiKeyProvider]
      → preferred = firstValidProvider (first AiProviderId with valid status)
      → _isCompletingSetup = true → notifyListeners()
      → _repository.completeKeySetup(uid, preferred)

        [DATA → ApiKeyRepositoryImpl.completeKeySetup]
        → Firestore.doc('AI_Voice_Genie/users/{uid}').update({
              keySetupDone: true,
              preferredProvider: 'openai'
          })
        → StorageService.setBool(keySetupCompleted, true)
        → StorageService.setString(preferredProviderId, 'openai')

      ← success

      [VIEWMODEL]
      → _isCompletingSetup = false → notifyListeners()
      → return true

    → context.hideLoading()
    → AppRoutes.navigateAndRemoveUntil → HomeScreen

  USER SEES: HomeScreen. Full stack cleared.
  Next cold start: Hive keySetupCompleted = true → SplashScreen routes directly to Home.
```

---

---

## PHASE 3 — AI Orchestration Layer

### The AI Execution Engine — How Every AI Request Flows

This layer sits between all feature Providers and the three AI providers.
Features never import adapters. They only call AiOrchestrator.execute().

```
FEATURE PROVIDER calls:
  AiOrchestrator.instance.execute(
    request:            AiRequest(capability, uid, prompt, ...),
    userKeyedProviders: [AiProviderId.openAi, AiProviderId.gemini]
  )

[AI ORCHESTRATION LAYER]
  → ModelSelector.isCapabilityAvailable(capability, userKeyedProviders)
      → ProviderRegistry.instance.providersFor(capability)
          → filters: only providers supporting the capability
          → sorts: by priority ascending
      → filters: only providers in userKeyedProviders set
      → if empty list → AiExhaustedException('error_no_models_with_key')
                     → EffectBus.instance.emit(error, StackTrace.current)
                     → GlobalEffectListener catches → context.showWarning
                     → throw AiExhaustedException to caller

  → orderedProviders = ModelSelector.select(capability, userKeyedProviders)

  CAPABILITY MATRIX LOOKUP (ProviderRegistry):
  ┌──────────┬─────────┬──────────┬────────────┬────────────┐
  │ Provider │ TextGen │ ImageGen │ ImageRead  │ PdfParsing │ Priority
  ├──────────┼─────────┼──────────┼────────────┼────────────┤
  │ OpenAI   │   ✅    │   ✅     │    ✅       │    ✅      │   1
  │ Gemini   │   ✅    │   ✅     │    ✅       │    ✅      │   2
  │ Claude   │   ✅    │   ❌     │    ✅       │    ✅      │   3
  └──────────┴─────────┴──────────┴────────────┴────────────┘

  FOR EACH provider in orderedProviders:
  │
  ├── ApiKeyRepository.loadKey(uid, providerId)
  │     → Firestore.doc('AI_Voice_Genie/users/{uid}/apiKeys/{id}').get()
  │     → null → skip this provider (key deleted mid-session)
  │
  ├── AnalyticsService.logAiRequestInitiated(provider, capability)
  │
  ├── adapter.execute(request, apiKey)  ← AiProviderAdapter.execute()
  │     routes to: generateText | generateImage | analyzeImage | parsePdf
  │
  │   SUCCESS → AiResponse
  │     → AnalyticsService.logAiRequestSuccess(provider, capability, ms, tokens)
  │     → return AiResponse to caller ✅
  │
  │   AiHardErrorException (401/400/403)
  │     → AnalyticsService.logAiRequestFailed(provider, capability, hardError, false)
  │     → throw immediately — NO fallback, NO retry
  │
  │   AiRateLimitException (429)
  │     → AnalyticsService.logAiRequestFailed(provider, capability, rateLimit, true)
  │     → skip immediately → try next provider
  │     → if next exists → logAiFallbackTriggered(from, to, rateLimit)
  │
  │   AiTransientException (timeout, 503, network)
  │     → retry up to AppConstants.maxRetryAttempts (2) times
  │     → between retries: await Future.delayed(500ms * attempt)  [exponential backoff]
  │     → retries exhausted → skip → try next provider
  │     → if next exists → logAiFallbackTriggered(from, to, transient)
  │
  └── ALL providers failed:
        → AiExhaustedException('error_all_models_failed', triedProviders)
        → EffectBus.instance.emit(error, StackTrace.current)
        → GlobalEffectListener → context.showWarning('error_all_models_failed')
        → throw AiExhaustedException to caller
```

---

### Adapter Internal Flow (per provider)

```
OpenAiAdapter.generateText(request, apiKey)
  → HTTP POST https://api.openai.com/v1/chat/completions
      headers: {Authorization: Bearer {apiKey}}
      body:    {model: gpt-4o, messages: [...history, userPrompt], max_tokens: 2048}
  → 200 → jsonDecode → AiResponse.text(text, tokenCount, responseTimeMs)
  → non-200 → mapHttpErrorToAiException(statusCode, provider, body)
                → 429 → AiRateLimitException
                → 401 → AiHardErrorException
                → 503 → AiTransientException
  → SocketException → AiTransientException('No internet')
  → Timeout → AiTransientException (via Future.timeout)

GeminiAdapter.generateImage(request, apiKey)
  → HTTP POST https://generativelanguage.googleapis.com/v1beta/
              models/gemini-2.0-flash-exp-image-generation:generateContent?key={apiKey}
      body: {contents: [{parts: [{text: prompt}]}],
             generationConfig: {responseModalities: ['IMAGE','TEXT']}}
  → 200 → extract inlineData.data (base64 PNG) → AiResponse.imageBase64(base64)
  → 400 + "api key" in body → AiHardErrorException (Gemini uses 400 not 401)
  → other non-200 → mapHttpErrorToAiException(statusCode, provider, body)

ClaudeAdapter.generateText(request, apiKey)
  → HTTP POST https://api.anthropic.com/v1/messages
      headers: {x-api-key: apiKey, anthropic-version: 2023-06-01}
      body: {model: claude-sonnet-4-5, max_tokens: 2048,
             system: '...', messages: [...]}
  → 200 → data['content'][0]['text'] → AiResponse.text(text, inputTokens+outputTokens)
  → non-200 → mapHttpErrorToAiException(statusCode, provider, body)

ClaudeAdapter.generateImage() → throws UnsupportedError (never called — registry blocks it)
```

---

---

## PHASE 3 (Continued) — HomeScreen

### Flow 3A: HomeScreen — Navigation Hub

```
USER reaches HomeScreen (after full setup)
  → HomeScreen builds:
      AppBar:
        → _ModelIndicator (Selector<ApiKeyProvider, AiProviderId?>)
            → apiKeyProvider.firstValidProvider → shows colored dot + provider name
            → Tap → _showModelSwitcher() → BottomSheet with provider options
        → Settings IconButton → AppRoutes.navigateTo → settingsScreen (placeholder)
        → Profile IconButton → AppRoutes.navigateTo → profile (placeholder)
      Body:
        → _HomeTabBody(currentIndex: 0) → _PlaceholderTabBody (Chat tab)
        → Switches on tab index → shows relevant placeholder
      FAB:
        → index 0 (Chat)  → navigateTo AppRoutes.chat
        → index 1 (Image) → navigateTo AppRoutes.imageGenerator
        → null for PDF and History tabs
      BottomNavigationBar:
        → 4 tabs: Chat, Image, PDF, History
        → Tab tap → setState(_currentTabIndex) → body rebuilds

USER taps bottom nav "History" tab
  → _currentTabIndex = 3
  → Body shows ConversationHistoryScreen placeholder
  → (Full history screen in conversation_history tab — accessed via tab or direct route)
```

---

---

## PHASE 4 — Chat Feature

### Flow 4A: New Conversation — Send First Message

```
USER taps "New Conversation" FAB on HomeScreen
  → AppRoutes.navigateTo → AppRoutes.chat → ChatScreen

ChatScreen mounts
  → initState → addPostFrameCallback
    → ChatProvider.clearConversation()
       → _activeConversation = null
       → _messages.clear()
       → isGenerating = false
       → notifyListeners()

USER SEES: ChatScreen with welcome UI
  → App logo + tagline
  → Quick suggestion chips (stub)
  → ChatInputBar at bottom (text field + send + stubbed voice/attach)

USER types "Explain black holes in simple terms" → taps Send

  → ChatInputBar._handleSend()
    → Validators.validatePrompt(prompt, context) → null (passes)
    → _controller.clear()
    → widget.onSend(prompt) → ChatScreen._handleSend(prompt)
      → uid = authProvider.currentUser?.uid
      → validProviders = apiKeyProvider.validProviders  [e.g. [openAi, gemini]]
      → ChatProvider.sendMessage(uid, prompt, validProviders, textChat)

        [VIEWMODEL → ChatProvider]

        STEP 1: Optimistic user message
        → userMessage = MessageModel.userMessage(prompt)
                         {id: uuid, role: user, status: sending, isOptimistic: true}
        → _messages.add(userMessage)
        → _isGenerating = true → notifyListeners()

        STEP 2: Create conversation (first message)
        → _repository.createConversation(uid, prompt, textChat, validProviders.first)

            [DATA → ChatRepositoryImpl.createConversation]
            → conversationId = Uuid().v4()
            → title = prompt.substring(0, 80)
            → Firestore.doc('AI_Voice_Genie/users/{uid}/conversations/{id}').set({
                  title, lastMessage: prompt, messageCount: 0,
                  capability: 'text', lastProvider: 'openai',
                  createdAt: serverTimestamp, lastMessageAt: serverTimestamp
              })
            ← ConversationModel returned

        → AnalyticsService.logConversationStarted(textChat, openAi)
        → _activeConversation = conversationModel

        STEP 3: Build context history
        → _buildTruncatedHistory(validProviders)
          → takes all non-optimistic messages → map to {role, content}
          → estimate total chars → if over 70% of openAi context limit (89,600 tokens × 4 chars)
            → remove oldest messages until within limit
          → returns List<Map<String,String>> (empty for first message)

        STEP 4: Execute via orchestrator
        → AiOrchestrator.instance.execute(
              request: AiRequest(
                capability: textGeneration,
                uid: uid,
                prompt: 'Explain black holes in simple terms',
                conversationHistory: []
              ),
              userKeyedProviders: [openAi, gemini]
          )
          → [Full orchestration flow as described in Phase 3]
          → OpenAI responds → AiResponse.text('Black holes are regions...')

        ← AiResponse returned

        STEP 5: Add AI message to list
        → aiMessage = MessageModel.aiResponse(
              content: 'Black holes are regions...',
              modelUsed: AiProviderId.openAi,
              tokenCount: 342
          )
        → Replace optimistic user message with confirmed (status: delivered, isOptimistic: false)
        → _messages.add(aiMessage)

        STEP 6: Persist to Firestore & Cloudinary (non-blocking via EffectBus.safeEffect)
        → ChatRepositoryImpl.saveMessagePair()
            → If AI message contains massive base64 image data:
                → Uploads to Cloudinary via CloudinaryService.
                → Replaces base64 payload with secure Cloudinary URL.
            → Firestore batch write:
                set('messages/{userMsgId}', userMessage.toFirestore())
                set('messages/{aiMsgId}',   sanitizedAiMessage.toFirestore())
        → ChatRepositoryImpl.updateConversationMetadata(
              uid, conversationId,
              lastMessage: 'Black holes are regions...',
              lastProvider: openAi, newMessageCount: 2)
            → Firestore.update({lastMessage, lastProvider, messageCount, lastMessageAt})

        STEP 7: Update Hive cache (non-blocking via EffectBus.safeEffect)
        → ChatRepositoryImpl.cacheMessages(conversationId, _messages)
            → jsonEncode(messages) → StorageService.setConversationCache('messages_{id}', json)
            → The Cloudinary URL is cached locally for fast replay on reopen.

        STEP 8: Analytics
        → AnalyticsService.logFeatureUsed(AppFeature.textChat)

        → _isGenerating = false → notifyListeners()
        → return true

      ← true returned to ChatScreen._handleSend()
      → conversationId = chatProvider.activeConversation?.id  ← 'conv-uuid-abc'
      → AppRoutes.navigateAndReplace → AppRoutes.chatDetail
           arguments: ChatDetailArguments(conversationId: 'conv-uuid-abc')

  USER SEES: ChatDetailScreen
    → Their message bubble (right, primary color)
    → AI response bubble (left, card color) with ModelIndicatorChip "ChatGPT"
    → Timestamp under each bubble
    → ChatInputBar ready for next message
```

---

### Flow 4B: Send Follow-Up Message (Context Continuity)

```
USER types "How massive are they?" → taps Send
  (conversation already has 2 messages — user + AI)

  → ChatProvider.sendMessage(uid, prompt, validProviders, textChat)

    STEP 3: Build context history (NOW HAS CONTENT)
    → _messages = [userMsg1, aiMsg1]  (both non-optimistic)
    → history = [
          {role: 'user',      content: 'Explain black holes...'},
          {role: 'assistant', content: 'Black holes are regions...'}
      ]
    → totalChars ≈ 200 → well within limit → no truncation

    → AiOrchestrator.execute(
          request: AiRequest(
              capability: textGeneration,
              prompt: 'How massive are they?',
              conversationHistory: history  ← AI receives full context
          ),
          userKeyedProviders: [openAi, gemini]
      )
    → AI understands the conversation context and responds accordingly

  USER SEES: Third message added. AI response references the conversation context.
```

---

### Flow 4C: Failure — All AI Providers Exhausted

```
USER sends message → AiOrchestrator tries all providers → all fail

  → AiExhaustedException thrown
  → EffectBus.instance.emit(error, StackTrace.current)
  → GlobalEffectListener._handleFailure()
    → 'error_all_models_failed' → context.showWarning → overlay slides from top

  → ChatProvider catches AiExhaustedException
  → _rollbackOptimisticMessage(userMessage.id)
      → _messages.removeWhere(m => m.id == id && m.isOptimistic)
  → _errorMessage = e.message
  → _isGenerating = false → notifyListeners()
  → return false

  → ChatDetailScreen observes error:
    → chatProvider.errorMessage != null
    → context.showError(error) [second message via snackbar channel]
    → chatProvider.clearError()

  USER SEES:
  → Their message DISAPPEARS (optimistic rollback)
  → Warning overlay at top: "All AI models are currently unavailable"
  → Error snackbar: same message via different channel
  → Input bar re-enabled → can retry
```

---

### Flow 4D: Resume Conversation from History

```
USER opens ConversationHistoryScreen
  → ConversationHistoryScreen mounts
    → _loadConversations()
      → ChatRepositoryImpl.getConversations(uid, limit: 15)
          → Firestore.collection('AI_Voice_Genie/users/{uid}/conversations')
                .orderBy('lastMessageAt', descending: true).limit(15).get()
          ← List<ConversationModel> returned
      → setState → _conversations = results → ListView.builder renders tiles
    → ConversationHistoryScreen listens to ChatProvider.conversationHistoryVersion
      → when chat saves or deletes a conversation, the list auto-refreshes without a manual pull-to-refresh

  → ConversationTile renders:
      CapabilityIcon | Title + lastMessage preview | Date | ChevronRight
      Provider color dot shows which AI was last used

USER taps a conversation tile
  → AppRoutes.navigateTo → AppRoutes.chatDetail
       arguments: ChatDetailArguments(conversationId: 'conv-uuid-xyz', initialTitle: 'Explain black holes...')

ChatDetailScreen mounts with conversationId
  → _loadConversation()
    → ChatProvider.loadConversation(uid, conversationId)

      FAST PATH (Hive):
    → ChatRepositoryImpl.getCachedMessages(conversationId)
          → StorageService.getConversationCache('messages_conv-uuid-xyz')
          → jsonDecode → List<MessageModel> returned instantly
      → _messages.addAll(cached) → _isLoadingMessages = false → notifyListeners()
      → UI shows messages immediately from cache

      FRESH PATH (Firestore — background):
      → ChatRepositoryImpl.getConversation(uid, conversationId)
          → Firestore.doc('AI_Voice_Genie/users/{uid}/conversations/{id}').get()
          ← ConversationModel (with title, messageCount, lastProvider)
      → ChatRepositoryImpl.getMessages(uid, conversationId, limit: 30)
          → Firestore.collection('messages').orderBy('timestamp', descending: true).limit(30).get()
          → reversed to chronological order
          → merge cached image/pdf payloads back into the fresh Firestore records
          → if Firestore stores only lightweight metadata, the local cache restores the image bubble
          ← List<MessageModel>
      → _messages.clear() → _messages.addAll(fresh)
      → _hasMoreMessages = fresh.length >= 30
      → Update Hive cache with fresh data
      → notifyListeners()

  USER SEES full conversation history loaded. Can send new messages.
```

---

### Flow 4E: Load Older Messages (Pagination)

```
USER scrolls to the very top of a long conversation
  → _scrollController listener fires when pixels <= minScrollExtent + 100
  → ChatProvider.loadMoreMessages(uid, conversationId)
    → _isLoadingMessages = true → notifyListeners() → spinner at top of list
    → ChatRepositoryImpl.getMessages(uid, conversationId, limit: 20)
        [with beforeDocument cursor set to oldest currently loaded message]
    ← older messages returned
    → _messages.insertAll(0, older)  ← prepended to beginning
    → _hasMoreMessages = older.length >= 20
    → _isLoadingMessages = false → notifyListeners()

  USER SEES: Older messages appear above current ones. Scroll position maintained.
```

---

---

## PHASE 5 (Partial) — Image Generator

### Flow 5A: Image Generation — Successful

```
USER taps "Image" tab on HomeScreen → taps FAB
  → AppRoutes.navigateTo → AppRoutes.imageGenerator (placeholder for now)

[When ImageGeneratorScreen is complete:]

USER types "A majestic snow leopard on a mountain peak at sunset"
USER selects "Landscape" size tab
USER taps "Generate"

  → ImageGeneratorProvider.generateImage(uid, prompt, validProviders)

      STEP 1: Capability check (BEFORE any network call)
      → ModelSelector.isCapabilityAvailable(imageGeneration, [openAi, gemini])
        → ProviderRegistry.providersFor(imageGeneration)
           → [openAi (priority 1), gemini (priority 2)]  ← claude excluded
        → filter by userKeyedProviders → [openAi, gemini]
        → not empty → proceed

      [IF user only has Claude key:]
      → ModelSelector.isCapabilityAvailable(imageGeneration, [claude])
        → capableConfigs filtered by userKeyedProviders → empty list
        → return false
      → AnalyticsService.logAiCapabilityGap(claude, imageGeneration)
      → _errorMessage = 'capability_gap_image_gen'
      → notifyListeners()
      → return false
      → UI shows: "Claude doesn't support image generation. Switch to ChatGPT or Gemini."

      [HAPPY PATH — user has openAi or gemini key:]

      STEP 2: Generate
      → _isGenerating = true → notifyListeners() → loading UI shows
      → AiOrchestrator.execute(
            request: AiRequest(
                capability: imageGeneration,
                uid: uid,
                prompt: 'A majestic snow leopard...',
                imageSize: AiImageSize.landscape
            ),
            userKeyedProviders: [openAi, gemini]
        )
        → OpenAiAdapter.generateImage(request, apiKey)
            → POST /v1/images/generations
               {model: dall-e-3, prompt, n:1, size: '1792x1024', response_format: 'url'}
            → 200 → {data: [{url: 'https://oaidalleapiprodscus.blob...'}]}
            ← AiResponse.imageUrl(url, responseTimeMs)

      STEP 3: Process response into displayable bytes
      → ImageRepositoryImpl.processImageResponse(response)
        → contentType == imageUrl → HTTP GET response.imageUrl
        → 200 → httpResponse.bodyBytes → Uint8List (PNG bytes)
        ← Uint8List returned

      STEP 4: Save to conversation history (non-blocking)
      → EffectBus.instance.safeEffect(() async {
            ImageRepositoryImpl.saveImageConversation(uid, prompt, response, openAi)
              → ChatRepositoryImpl.createConversation(uid, prompt, imageGeneration, openAi)
              → ChatRepositoryImpl.saveMessages([userMessage, aiImageMessage])
              → ChatRepositoryImpl.updateConversationMetadata(...)
              ← conversationId returned
        })

      STEP 5: Set result
      → _currentImage = GeneratedImageResult(
            imageBytes: Uint8List,
            provider: openAi,
            prompt: 'A majestic snow leopard...',
            remoteUrl: 'https://oai...',
            conversationId: 'conv-img-uuid'
        )
      → AnalyticsService.logFeatureUsed(AppFeature.imageGeneration)
      → _isGenerating = false → notifyListeners()

  USER SEES:
  → Generated image displayed in full width card
  → Provider chip: "ChatGPT" with OpenAI brand color
  → Save to Gallery button
  → Share button
  → Generate Another button (clears image, re-shows prompt input)
```

---

---

## Provider Registration Summary (main.dart)

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
                           // Reads Hive → sets ThemeMode immediately
    ChangeNotifierProvider(create: (_) => LocaleProvider()..initialize()),
                           // Reads Hive → sets Locale immediately
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..initialize(),
      lazy: false,         // EAGER — auth resolves before SplashScreen finishes
    ),
    ChangeNotifierProvider(create: (_) => ApiKeyProvider()),
                           // Lazy — loaded when KeySetupScreen or HomeScreen needs it
    ChangeNotifierProvider(create: (_) => ChatProvider()),
                           // Lazy — loaded when ChatScreen is first pushed
    // Phase 5 (partial): ImageGeneratorProvider — added when screen is complete
    // Phase 6: PdfProvider
    // Phase 7: VoiceProvider
    // Phase 8: SettingsProvider
  ],
)
```

---

---

## Route Registry — Current State

```
Route                    Screen                          Status      Phase
─────────────────────────────────────────────────────────────────────────────
/                        SplashScreen                    ✅ WIRED    Phase 1
/login                   LoginScreen                     ✅ WIRED    Phase 1
/onboarding              OnboardingScreen                ✅ WIRED    Phase 2
/key-setup               KeySetupScreen(initial: true)   ✅ WIRED    Phase 2
/home                    HomeScreen                      ✅ WIRED    Phase 3
/chat                    ChatScreen                      ✅ WIRED    Phase 4
/chat-detail             ChatDetailScreen                ✅ WIRED    Phase 4
/history                 ConversationHistoryScreen       ✅ WIRED    Phase 4
/image-generator         _PlaceholderScreen              ⏳ PENDING  Phase 5
/image-reader            _PlaceholderScreen              ⏳ PENDING  Phase 5
/pdf-reader              _PlaceholderScreen              ⏳ PENDING  Phase 6
/settings                _PlaceholderScreen              ⏳ PENDING  Phase 8
/api-keys                _PlaceholderScreen              ⏳ PENDING  Phase 8
/profile                 _PlaceholderScreen              ⏳ PENDING  Phase 8
```

---

---

## Data Persistence Map

```
What is stored    Where              Key / Path                     When written
──────────────────────────────────────────────────────────────────────────────────
Theme mode        Hive (settings)    StorageKeys.themeMode          User changes theme
Locale            Hive (settings)    StorageKeys.locale             User changes language
isLoggedIn        Hive (settings)    StorageKeys.isLoggedIn         After successful sign-in
userId            Hive (user)        StorageKeys.userId             After successful sign-in
userEmail         Hive (user)        StorageKeys.userEmail          After successful sign-in
userDisplayName   Hive (user)        StorageKeys.userDisplayName    After successful sign-in
userPhotoUrl      Hive (user)        StorageKeys.userPhotoUrl       After successful sign-in
onboardingDone    Hive (settings)    StorageKeys.onboardingCompleted After onboarding (future)
keySetupDone      Hive (settings)    StorageKeys.keySetupCompleted  After completeSetup()
preferredProvider Hive (settings)    StorageKeys.preferredProviderId After completeSetup()
Messages cache    Hive (conv cache)  'messages_{conversationId}'    After each send + load
Last conv ID      Hive (conv cache)  StorageKeys.lastOpenConversationId On conversation open

User profile      Firestore          AI_Voice_Genie/users/{uid}                   On sign-in
API keys          Firestore          AI_Voice_Genie/users/{uid}/apiKeys/{prov}    On validation
Conversations     Firestore          AI_Voice_Genie/users/{uid}/conversations/{id} On first send
Messages          Firestore          .../conversations/{id}/messages/{id}         On each send
```

---

---

## Error Propagation Map

```
Where error occurs          How it travels                    What user sees
────────────────────────────────────────────────────────────────────────────────────
AuthRepositoryImpl          throw AuthException(code)
  └→ AuthProvider           catches → _authError = code       LoginScreen.showError(code)
                            → notifyListeners()               overlay slides from top

ApiKeyRepositoryImpl        throw ApiKeyException(code)
  └→ ApiKeyProvider         catches → _errors[provider] = code Card inline error text
                            → notifyListeners()

AiOrchestrator              All providers fail
  └→ EffectBus.emit(error)  ← GlobalEffectListener            showWarning overlay (top)
  └→ throw AiExhaustedException
  └→ ChatProvider           catches → _errorMessage = code    context.showError(code)
  └→ ImageGeneratorProvider catches → _errorMessage = code    context.showError(code)

ChatRepositoryImpl          Firestore save fails (background)
  └→ EffectBus.safeEffect() catches → EffectBus.emit(error)
  └→ GlobalEffectListener                                      showWarning overlay (top)

AiOrchestrator              Hard error (401/400)
  └→ throw AiHardErrorException
  └→ ChatProvider           catches → _errorMessage = code    context.showError(code)
                            NOTE: does NOT fallback to next provider

ModelSelector               Capability gap detected
  └→ ImageGeneratorProvider _errorMessage = 'capability_gap'  Inline gap message
                            logAiCapabilityGap analytics event
```
