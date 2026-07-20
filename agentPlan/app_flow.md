# App Flow

## Feature
Create account, logout, and login again.

## Purpose
- Show the exact end-to-end execution path for a first-time user.
- Show what data is saved in Firestore, Hive, and Analytics at each step.
- Help QA and developers verify the flow without reading the whole codebase.

## Start and End
- Start: Splash screen on first app open.
- End: Login screen after logout, then authenticated flow again on the next login.

## Execution Flow Chart
`SplashScreen -> AuthProvider.initialize() -> AuthRepository.getCurrentUser()`

`No Firebase session`
`-> LoginScreen -> signInWithGoogle() or signInWithApple()`
`-> AuthProvider._performSignIn()`
`-> AuthRepository.signInWithGoogle()/signInWithApple()`
`-> Firebase Auth credential sign-in`
`-> _createOrUpdateUser()`
`-> Firestore create OR read/update existing user doc`
`-> Hive session save`
`-> AuthProvider.authState = authenticated`
`-> OnboardingScreen if onboardingDone is false`
`-> AuthProvider.markBoardingComplete()`
`-> KeySetupScreen`
`-> ApiKeyProvider.validateAndSaveKey()`
`-> ApiKeyRepository.validateKey()`
`-> ApiKeyRepository.saveKey()`
`-> ApiKeyProvider.completeSetup()`
`-> ApiKeyRepository.completeKeySetup()`
`-> TabBarScreen / ProfileScreen`
`-> Logout confirmation`
`-> ProfileViewModel.signOut()`
`-> AuthProvider.signOut()`
`-> AuthRepository.signOut()`
`-> Google signOut + Firebase Auth signOut + Hive user clear + analytics user clear + user_signed_out`
`-> LoginScreen`
`-> login again uses returning-user branch`

## Function Call Map

| Function | Who Calls It | What It Does | Important Return or Side Effect |
|---|---|---|---|
| `AuthProvider.initialize()` | `main.dart` | Checks whether a Firebase session already exists. | Sets auth state to authenticated or unauthenticated. |
| `AuthRepository.getCurrentUser()` | `AuthProvider.initialize()` | Reads FirebaseAuth current user, then Firestore user profile if a session exists. | Returns a `UserModel` or null. |
| `AuthScreen._handleGoogleSignIn()` / `_handleAppleSignIn()` | User tap on login screen | Shows loading and starts the social sign-in flow. | Calls auth provider sign-in and waits for the result. |
| `AuthProvider.signInWithGoogle()` / `signInWithApple()` | Login screen | Logs the tap event, then starts unified sign-in logic. | Leads to authenticated or unauthenticated state. |
| `AuthProvider._performSignIn()` | Auth provider internals | Applies the shared sign-in success/failure rules. | Sets `currentUser`, analytics user ID, and auth state. |
| `AuthRepository.signInWithGoogle()` / `signInWithApple()` | Auth provider | Runs the provider login, Firebase credential sign-in, and user-document sync. | Returns a `UserModel` for the signed-in user. |
| `_createOrUpdateUser()` | Auth repository | Handles the new-user and returning-user Firestore branch. | Creates a new user doc or refreshes last login on an existing doc. |
| `_persistSession()` | Auth repository | Writes the session snapshot into Hive. | Saves user identity and onboarding/key flags locally. |
| `AuthProvider.markBoardingComplete()` | Onboarding screen | Marks onboarding as complete in memory and in storage. | Updates the user doc and local onboarding flag. |
| `ApiKeyProvider.validateAndSaveKey()` | Key setup screen | Validates a provider key, then saves it if valid. | Stores the API key in Firestore and memory cache. |
| `ApiKeyProvider.completeSetup()` | Key setup screen | Marks setup complete after at least one valid key exists. | Stores `keySetupDone` in Firestore and stores `preferredProvider` locally in Hive. |
| `ProfileViewModel.signOut()` | Profile screen logout action | Wraps the sign-out sequence for the UI. | Returns control to the auth provider. |
| `AuthProvider.signOut()` | Profile view model | Calls repository sign-out, clears analytics user ID, logs sign-out, then clears current user state. | Routes the app back to login. |
| `AuthRepository.signOut()` | Auth provider | Signs out from Google, Firebase Auth, and local session storage. | Clears Firebase session and starts user-box cleanup. |

## New Account Branch

### Google
- Google account picker returns a Google user.
- Firebase credential is created from Google tokens.
- `_createOrUpdateUser()` checks whether the Firestore user doc already exists.
- If the doc does not exist, a new user model is created from Google profile data.
- The new Firestore doc is saved with default `onboardingDone = false` and `keySetupDone = false`.
- Hive is updated with the same session flags and user profile data.

### Apple
- Apple credential is requested with a nonce.
- Firebase credential is created from the Apple ID token and raw nonce.
- `_createOrUpdateUser()` again checks Firestore for the user doc.
- If this is the first sign-in, name/email are taken from the Apple credential first, then fallback values are used if needed.
- Apple never provides a photo, so `photoUrl` stays empty.
- The same Firestore and Hive writes happen as the Google new-user branch.

## Returning Login Branch
- On the next login, Firebase Auth finds the existing account.
- `_createOrUpdateUser()` sees the Firestore user doc already exists.
- It reads stored profile data from Firestore instead of rebuilding the user from the social provider.
- `lastLoginAt` is updated in Firestore and `isNewUser` is written as false.
- Hive is refreshed with the stored onboarding and key-setup flags.
- The auth model only carries the fields represented in `UserModel`, so Firestore fields that are not modeled there are not surfaced to later screens through this path.

## Data Saved By Stage

| Stage | Firestore | Hive | Analytics |
|---|---|---|---|
| First sign-in success | New user doc at `AIVoiceGenie/AllUsers/{uid}/UserModel` with `uid`, `email`, `displayName`, `photoUrl`, `authProvider`, `onboardingDone`, `keySetupDone`, `dateOfBirth`, `age`, `createdAt`, `lastLoginAt`. | `isLoggedIn`, `userId`, `userEmail`, `userDisplayName`, `userPhotoUrl`, `onboardingCompleted`, `keySetupCompleted`. | `authentication_button_tapped`, then `user_registered` with `user_id`, `auth_provider`, and `user_email`. |
| Returning sign-in success | Existing user doc updated with `lastLoginAt` and `isNewUser = false`. | Same session keys are refreshed from Firestore. | `authentication_button_tapped`, then `user_signed_in` with `user_id`, `auth_provider`, and `user_email`. |
| Onboarding complete | `onboardingDone = true` and `lastUpdatedAt` are written on the user doc. | `onboardingCompleted = true` is written locally. | No onboarding analytics event is logged. |
| API key saved | API key doc at `AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}` with raw `apiKey`, `providerId`, `isValid`, `lastValidated`, and `keyAddedAt` when present. | Provider key is cached in memory for masked display. | `model_added` is logged after a successful save with user and model details. |
| Key setup complete | `keySetupDone = true` is written on the user doc. | `keySetupCompleted = true` and `preferredProviderId` are stored. | No dedicated key-setup-complete analytics event is logged. |
| Logout | No Firestore profile write from the logout path itself. | `user_box` cleanup is started and `isLoggedIn = false` cleanup is started. | Analytics user ID is cleared and `user_signed_out` logs `user_id`. |

## Async and Await Judgment
- Awaited operations:
  - Firebase initialization
  - auth session resolution
  - OAuth sign-in
  - Firebase Auth credential sign-in
  - Firestore user document create/read/update
  - Hive session persistence
  - key validation
  - key save
  - key setup completion
  - sign-out
- Fire-and-forget style behavior:
  - splash navigation waits on state changes, but it does not directly perform auth
  - onboarding persistence is wrapped in `EffectBus.safeEffect`, so navigation can continue while the write runs
  - Google sign-in button analytics is wrapped in `EffectBus.safeEffect`
  - analytics is intended to be non-blocking for the user, even though the service wrapper awaits internally

## QA Verdict

### What Looks Correct
- New accounts are created only after a real Firebase sign-in succeeds.
- Returning logins reuse the existing user document instead of creating duplicates.
- The app saves the session locally so startup can route quickly.
- Provider keys are validated before they are saved.
- Logout returns the app to the login screen.
- Returning users now mark `isNewUser = false` in Firestore.

### What May Need Improvement
- Medium: `AuthRepository.signOut()` clears only the user box and `isLoggedIn` flag, and it does not await those storage calls. That can leave user-specific cleanup running after the method returns and makes logout cleanup less reliable than the rest of the flow.
- Low: `ApiKeyProvider.loadExistingKeys()` is triggered without awaiting in the splash/login route path, so the UI can navigate before the key cache is fully loaded. This is usually fine, but a tester should know the key cards may populate slightly later.

## Testing Notes
- First run:
  - clear the app session
  - sign in with Google or Apple
  - verify Firestore gets a new user document
  - verify Hive gets the session values
  - verify onboarding appears
  - verify key setup blocks continuation until at least one valid key exists
- Logout:
  - confirm logout dialog appears
  - confirm Firebase session is removed
  - confirm the app returns to Login
- Login again:
  - sign in with the same account
  - verify the flow skips document creation and uses the returning-user branch
  - verify `lastLoginAt` updates
  - verify `isNewUser` is false in Firestore after returning login

## Async Priority Judgment
- Must await:
  - Firebase Auth sign-in and sign-out
  - Firestore user-doc create/update
  - API key validation and save
  - key setup completion write
  - sign-out local storage cleanup, because logout should not return before session state is cleared
- Can be fire-and-forget:
  - analytics logs
  - key-cache loading when it is only warming UI state
  - splash-to-login navigation itself, because it only reacts to auth state
- Should be reconsidered:
  - onboarding completion currently behaves like a background effect; it is acceptable for UI speed, but QA should verify that a failed Firestore write is surfaced through the global effect path
  - logout storage cleanup should be awaited so stale state cannot survive a fast relaunch

## Analytics Parameter Judgment
- Good and necessary:
  - `authentication_button_tapped.auth_provider` because it tells us which provider users actually press
  - `user_registered.auth_provider` and `user_signed_in.auth_provider` because they confirm which provider actually succeeded
  - `model_added.user_id` because it makes key events easier to analyze in exported reports
  - `model_added.model_used` because it identifies the provider
- Useful but optional:
  - `user_registered.user_email` and `user_signed_in.user_email` because Firebase Analytics already has user ID; email can be sensitive and should only be kept if reporting truly needs it
  - `model_added.model_name` because it is human-readable but duplicates `model_used`
  - `model_added.model_features` because it helps reporting, but it is static metadata and may be more than the event needs
  - `model_removed.model_name` and `model_features` for the same reason
- Missing but potentially useful:
  - a success/failure result or duration field for key validation if you want to study how often validation is slow or rejected
  - a sign-out source parameter if logout can later happen from more than Profile

---

## Feature
First-time chat prompt with the selected AI model.

## Purpose
- Show how a first-time authenticated user starts a new chat from `IntroScreen`.
- Show both prompt-start paths: predefined action and manually typed prompt.
- Show which functions run, what data is saved, which analytics/usage events fire, and which heavy work is awaited or fire-and-forget.
- Help QA verify the first prompt response on screen without reading the full Flutter code.

## Start and End
- Start: User is already authenticated, onboarding is complete, and at least one provider API key exists.
- Entry screen: `IntroScreen()`.
- End: `ChatDetailScreen` displays the user message and the AI response or a failed AI message.

## Execution Flow Chart
`IntroScreen`
`-> top-right message button`
`-> AppRoutes.navigateTo(context, AppRoutes.chat)`
`-> ChatScreen.initState()`
`-> ChatProvider.clearConversation()`
`-> ChatScreen shows model dropdown + predefined actions + ChatInputBar`

`Manual prompt path`
`-> user types prompt`
`-> ChatInputBar._syncCanSend() enables send`
`-> ChatInputBar._handleSend()`
`-> Validators.validatePrompt()`
`-> ChatScreen._handleSend()`

`Predefined action path`
`-> user taps Summarize PDF / Analyze Image / Generate Code / Create Image`
`-> ChatScreen action handler hides suggestions`
`-> ChatInputController.setPrompt() OR pickPdfWithPrompt() OR pickImageWithPrompt()`
`-> ChatInputBar inserts template and optionally attaches file`
`-> user taps send`
`-> ChatInputBar._handleSend()`
`-> Validators.validatePrompt()`
`-> ChatScreen._handleSend()`

`Shared send path`
`-> read AuthProvider.currentUser.uid`
`-> read AiPreferencesProvider.preferredProvider`
`-> verify preferred provider exists in ApiKeyProvider.validProviders`
`-> if preferred provider has no valid key, show no-key error and stop before navigation`
`-> ChatProvider.sendMessage() starts without await`
`-> optimistic user MessageModel is added`
`-> new ConversationModel is created in memory`
`-> ChatScreen reads ChatProvider.activeConversation.id`
`-> AppRoutes.navigateAndReplace(context, AppRoutes.chatDetail)`
`-> ChatDetailScreen listens to existing ChatProvider state`
`-> AiOrchestrator.execute()`
`-> ApiKeyRepository.loadKey(uid, selectedProvider)`
`-> selected provider adapter sends HTTP request`
`-> Analytics logs initiated and success/failure`
`-> Usage event is saved fire-and-forget on success`
`-> ChatRepository.createOrAppendMessagePair() writes Hive records locally`
`-> ChatOutboxStore.enqueue() stores a durable Firestore sync task`
`-> ChatSyncService.processOutbox() tries Firestore sync in background`
`-> ChatProvider adds AI message and stops generating`
`-> ChatDetailScreen shows response`
`-> RemoteChatStore.saveMessagePairBatch() writes Firestore when outbox drains`
`-> LocalChatStore.markConversationSynced() updates local sync status after remote success`

## Function Call Map

| Function | Who Calls It | What It Does | Important Return or Side Effect |
|---|---|---|---|
| `IntroScreen._buildTopNavBar()` | `IntroScreen.build()` | Builds the working chat entry button. | Tapping the message icon navigates to `AppRoutes.chat`. |
| `AppRoutes.navigateTo(context, AppRoutes.chat)` | Intro message button | Opens the new chat screen. | Keeps Intro in the back stack. |
| `ChatScreen.initState()` | Flutter lifecycle | Schedules a fresh chat reset after the first frame. | Calls `ChatProvider.clearConversation()`. |
| `ChatProvider.clearConversation()` | `ChatScreen.initState()` | Clears active conversation, messages, loading, generating, and error state. | Ensures the first prompt starts a new conversation. |
| `ChatModelSelection.resolveSelectedProvider()` | `ChatDetailScreen` dropdown and send flow | Chooses a current model from valid providers and saved preference after a conversation is already open. | Detail screen falls back to a valid provider when the preferred provider is unavailable. |
| `AiPreferencesProvider.setPreferredProvider()` | Model dropdown change | Saves the preferred provider. | Later sends use the selected model first. |
| `ChatScreen._handleGenerateCode()` / `_handleCreateImage()` | Predefined action taps | Inserts a localized prompt template. | Does not send automatically. User must tap send. |
| `ChatScreen._handleSummarizePdf()` / `_handleAnalyzeImage()` | Predefined action taps | Opens PDF/image picker and inserts a localized prompt template. | Attachment and template are prepared before send. |
| `ChatInputController.setPrompt()` | Chat screen predefined text actions | Imperatively tells `ChatInputBar` to insert a template. | Focuses composer and enables send. |
| `ChatInputController.pickPdfWithPrompt()` / `pickImageWithPrompt()` | Chat screen attachment actions | Opens picker, validates attachment, then inserts template. | Adds `ChatAttachment` bytes/path/name/mime metadata. |
| `ChatInputBar._handleSend()` | Send button | Validates prompt, copies attachments, clears composer, then calls parent `onSend`. | Awaited locally so the input cleanup completes in order. |
| `ChatScreen._handleSend()` | `ChatInputBar.onSend` | Reads user and preferred provider, verifies that provider has a valid key, then starts `ChatProvider.sendMessage()`. | If the preferred provider is not valid, it shows `no_key_for_model` and does not navigate. If valid, it does not await the AI request and navigates to detail immediately. |
| `ChatProvider.sendMessage()` | Chat screen or chat detail | Resolves capability, creates optimistic user message, creates conversation, executes AI, persists result. | Updates provider state used by `ChatDetailScreen`. |
| `ChatProvider._resolveRequestCapability()` | `sendMessage()` | Converts prompt/attachments into `textGeneration`, `imageGeneration`, `imageUnderstanding`, or `pdfParsing`. | Drives provider capability checks and request payload. |
| `AiOrchestrator.execute()` | `ChatProvider.sendMessage()` | Validates selected provider, capability support, API key availability, retry rules, analytics, and adapter execution. | Returns `AiResponse` or throws an `AiException`. |
| `ApiKeyRepository.loadKey()` | Orchestrator | Loads selected provider key from memory cache or Firestore. | First chat after setup can read from Firestore because provider and orchestrator use different repository instances. |
| `OpenAiAdapter` / `GeminiAdapter` / `ClaudeAdapter` | Orchestrator | Sends the provider-specific HTTP request. | Returns normalized `AiResponse`. |
| `ChatProvider._buildAiMessage()` | `sendMessage()` | Converts `AiResponse` into an assistant `MessageModel`. | Has a bug for `analysis` responses because the branch does not return. |
| `ChatRepository.createOrAppendMessagePair()` | `ChatProvider.sendMessage()` | Saves conversation metadata and both messages to Hive, then queues an outbox task. | UI/history can read local records immediately; Firestore sync is background. |
| `LocalChatStore.saveConversation()` | Chat repository and sync service | Writes one conversation record to `chat_conversations_box`. | Stores local-only sync metadata such as `pendingCreate`, `pendingUpdate`, `pendingDelete`, `synced`, and `syncFailed`. |
| `LocalChatStore.saveMessage()` | Chat repository and sync service | Writes one message record to `chat_messages_box`. | Replaces the old whole-conversation JSON cache for active offline-first flows. |
| `ChatOutboxStore.enqueue()` | Chat repository | Stores a durable Hive task in `chat_outbox_box`. | Queued Firestore work survives app restarts and supports idempotency keys. |
| `ChatSyncService.processOutbox()` | Repository enqueue, auth startup, retry timer, connectivity restore | Runs due outbox tasks sequentially. | Prevents parallel remote mutations from racing on the same conversation. |
| `RemoteChatStore.saveMessagePairBatch()` | Sync service | Writes conversation, user message, and AI message to Firestore in a batch. | Uses deterministic local IDs, so retries do not duplicate messages. |
| `ChatDetailScreen._onChatProviderChange()` | Provider listener | Reacts to new messages, generation state, loading state, and local deletion state. | Scrolls to latest content and pops the screen if the conversation is deleted. |
| `ConversationHistoryScreen.watchConversations()` | History screen init | Listens to Hive conversation stream through the repository. | History renders from local records and updates when sync merges or local mutations happen. |

## Prompt Start Paths

| Path | Tester Action | Expected Behavior | Notes |
|---|---|---|---|
| Manual text prompt | Type any valid prompt, then tap send. | User message appears, app navigates to chat detail, typing indicator appears, AI response appears. | This is the cleanest first-time chat path. |
| Generate Code predefined action | Tap Generate Code, review/edit inserted template, tap send. | Template is sent as a normal text prompt. | No attachment is involved. |
| Create Image predefined action | Tap Create Image, review/edit inserted template, tap send. | Prompt is detected as `imageGeneration` if it matches the image-generation heuristic. | Selected provider must support image generation. |
| Summarize PDF predefined action | Tap Summarize PDF, select PDF, tap send. | PDF bytes and prompt are sent as `pdfParsing`. | Attachments cannot mix PDF and image types. |
| Analyze Image predefined action | Tap Analyze Image, select image, tap send. | Image bytes and prompt are sent as `imageUnderstanding`. | Image count and size are validated before send. |
| Voice input from chat composer | Tap mic, accept transcript, then send. | Transcript is inserted like manual text. | The actual send path is the same as manual text. |

## Data Saved By Stage

| Stage | Firestore | Hive / Local State | Analytics / Usage |
|---|---|---|---|
| Enter chat from Intro | No Firestore write. | `ChatProvider.clearConversation()` clears in-memory conversation and messages. | No dedicated event is logged for opening new chat. |
| Change selected model | No Firestore write from this flow. | Preferred provider is saved through `AiPreferencesProvider` into Hive-backed storage. | No `model_switched` event is currently logged from `AiPreferencesProvider.setPreferredProvider()`. |
| Attachment selection | No Firestore write yet. | Attachment bytes, name, path, MIME type, and file size live in `ChatInputBar` state until send. | No attachment-selection event is logged. |
| Send with selected model missing a key | No Firestore write. | Composer remains on `ChatScreen`; no conversation is created. | No AI analytics event is logged because the request never reaches `AiOrchestrator`. |
| First send starts | No Firestore write yet. | Optimistic user `MessageModel` and new `ConversationModel` are created in memory. New conversation message stream is subscribed. | No `conversation_started` event is called, even though the analytics service supports it. |
| AI request starts | API key is read from `AIVoiceGenie/UsersAPIKeys/{uid}/{providerId}`. | Request object stores `requestId`, prompt, history, capability, response length, image/PDF bytes, and image settings. | `ai_request_initiated` logs `model_attempted` and `capability`. |
| AI request success | Usage event is saved at `AIVoiceGenie/AllUsers/UserModel/{uid}/usageEvents/{eventId}` by current constants. | Normalized `AiResponse` is converted into an assistant message. | `ai_request_success` logs `model_used`, `capability`, `response_time_ms`, and `token_count`; usage write is fire-and-forget. |
| AI request failure | No usage event is saved. | Failed assistant `MessageModel` is created with a friendly error message. | `ai_request_failed` logs `model_attempted`, `capability`, `failure_type`, and `fallback_triggered=false`; capability gaps also log `ai_capability_gap`. |
| Local-first persistence after AI result | No immediate Firestore write required. | `chat_conversations_box` stores one `LocalConversationRecord`; `chat_messages_box` stores one user `LocalMessageRecord` and one AI `LocalMessageRecord`; records start as pending sync. | No separate persistence event is logged. |
| Outbox enqueue | No immediate Firestore write required. | `chat_outbox_box` stores an `upsert_message_pair` task with conversation payload, user message payload, AI message payload, message IDs, attempt metadata, and idempotency key. | No analytics event. |
| Background Firestore sync | Conversation doc at `AIVoiceGenie/Conversations/{uid}/{conversationId}`. Message docs at `AIVoiceGenie/Conversations/{uid}/{conversationId}/ModelMessages/UserRef-{id}` and `AIRef-{id}`. | On success, local conversation sync status becomes `synced`; outbox task is removed. On retryable failure, task remains pending with backoff. | No analytics event. |
| Response visible | Firestore may still be pending. | `ChatDetailScreen` renders from provider memory and Hive message stream. | No dedicated response-rendered event. |
| History list load | Firestore may be queried by manual refresh/getConversations, but UI source is Hive stream. | `ConversationHistoryScreen` listens to `watchConversations()` and filters/searches local conversation records. | No analytics event. |
| Delete individual conversation | Firestore deletion is queued, not blocking the UI result. | Conversation and its messages are soft-deleted locally with `pendingDelete`; outbox stores `delete_conversation`. Remote success hard-deletes Hive records. | Success toast changes if connectivity reports offline. |
| Delete all conversations | Firestore deletion is queued through one `delete_all_conversations` task. | All local conversations/messages are soft-deleted; history stream becomes empty. | Success toast changes if connectivity reports offline. |

## Provider API Calls

| Capability | OpenAI | Gemini | Claude |
|---|---|---|---|
| Text prompt | `POST /v1/chat/completions` | `POST /v1beta/models/{model}:generateContent` | `POST /v1/messages` |
| Image generation | `POST /v1/images/generations` | `POST /v1beta/models/{imageModel}:generateContent` | Not supported by registry/adapter flow. |
| Image understanding | `POST /v1/chat/completions` with image content | `POST /v1beta/models/{model}:generateContent` with image content | `POST /v1/messages` with image content block. |
| PDF parsing | `POST /v1/responses` | `POST /v1beta/models/{model}:generateContent` with PDF context | `POST /v1/messages` with PDF text/context. |

## Async and Await Judgment

| Operation | Current Behavior | Judgment |
|---|---|---|
| `ChatScreen._handleSend()` first send | Validates the preferred provider has a key, starts `ChatProvider.sendMessage()` without `await`, then navigates to detail. | Acceptable because invalid-key sends stop before navigation and valid sends create the conversation ID synchronously before the first awaited call. |
| `ChatDetailScreen._handleSend()` subsequent sends | Awaits `ChatProvider.sendMessage()`. | Correct, because the user is already inside the conversation and should see completion/error handling in place. |
| Provider API key load | Awaited. | Correct. The AI call must not start without the selected key. |
| AI HTTP request | Awaited. | Correct. The UI response depends on it. |
| Retry delay after transient provider error | Awaited. | Correct, but only for transient errors. Hard errors and rate limits correctly stop. |
| Cloudinary upload for generated images | Awaited with `Future.wait`. | Correct if generated image URLs must be persisted and shown consistently. |
| Hive local message pair write | Awaited after AI response message is built. | Correct for local durability. However, the user prompt itself is still only in memory until the AI call finishes or fails and the final pair is written. |
| Outbox enqueue | Awaited as part of local persistence. | Correct. Firestore sync must not be attempted without a durable task. |
| Firestore sync for message pair | Fire-and-forget through `ChatSyncService.processOutbox()`. | Correct for UI responsiveness. Remote writes retry from Hive outbox instead of blocking chat rendering. |
| Firestore conversation/message streams | Long-lived subscriptions managed by `ChatSyncService`. | Correct direction. Conversation stream starts after auth; message stream starts when a conversation is opened. |
| Delete individual remote work | Fire-and-forget through outbox. | Correct. Local soft delete hides the chat immediately and remote hard delete can finish later. |
| Delete all remote work | Fire-and-forget through outbox, but the history UI currently waits one artificial second and does not await the delayed repository call. | Should be improved. The architecture is local-first, but the screen-level delay/non-awaited call can make QA timing flaky. |
| Legacy `cacheMessages()` JSON cache | Still exists in repository/storage for backward compatibility. | Not the primary new flow. Keep only for migration or remove after stable offline-first rollout. |
| Usage event save | Fire-and-forget. | Correct. Usage tracking must not block the AI response. |
| Analytics request initiated/success/failure | Awaited inside orchestrator. | Should be reconsidered. Analytics is useful but should not add latency to chat response; fire-and-forget through `EffectBus.safeEffect` would be better unless strict ordering is required. |

## QA Verdict

### What Looks Correct
- The first chat flow creates a clean new conversation because `ChatProvider.clearConversation()` runs when `ChatScreen` opens.
- Manual prompt and predefined prompt actions converge into the same send pipeline, so QA can test one shared persistence/AI path after prompt preparation.
- The first send navigates quickly because conversation creation happens before the AI network call.
- The selected model is stored separately from the typed prompt, and every message records the requested/used provider.
- AI success and AI failure both create assistant messages, so the conversation history can show what happened instead of silently losing failed requests.
- Usage tracking is correctly fire-and-forget because it is not required to render the AI response.
- First-send now blocks before navigation when the selected preferred provider has no valid API key.
- Chat messages and conversation metadata now use Hive records instead of only the old `messages_{conversationId}` JSON blob.
- History list now watches Hive through `watchConversations()`, so local records can render without waiting for Firestore.
- Firestore write/delete work is now queued through a durable outbox and processed by `ChatSyncService`, which is the correct production direction.
- Individual conversation delete is now local-first: it soft-deletes local records, queues remote deletion, and hard-deletes local records only after remote success.
- Sync badges are exposed in the history card for pending and failed sync states.

### Issues or Improvements
- Medium: `IntroScreen` quick action chips are visual only. The real chat entry is the top-right message button, then the predefined actions inside `ChatScreen`. If product expects Intro quick actions to start prompting, that navigation is not implemented.
- Medium: First prompt durability is not fully local-first before the AI call. The optimistic user message is in memory, but the Hive message/outbox write happens only after the AI response or failure is built.
- Medium: `ConversationHistoryScreen._loadConversations()` still calls `getConversations()`, which forces a Firestore server fetch before falling back to Hive. The stream is local-first, but refresh/load still performs a full remote collection read rather than purely incremental sync.
- Medium: `RemoteChatStore.watchConversations()` does not use `lastConversationSyncAt`; it listens to the full conversation collection ordered by `lastMessageAt`. The sync-state field exists, but incremental conversation streaming is not implemented yet.
- Medium: `ConversationHistoryScreen._deleteAll()` waits one artificial second and does not await the `deleteAllConversationsLocalFirst()` call inside the delayed callback. This can make UI timing and toast behavior unreliable.
- Medium: `updateConversationTitle()` still updates Firestore directly through the old repository path. The outbox has an `updateConversationTitle` type, but the title-edit flow is not local-first yet.
- Medium: `ChatOutboxStore.markProcessing()` can leave a task stuck as `processing` if the app is killed after marking processing but before success/failure is stored. Startup should reset stale processing tasks to pending.
- Low: Retryable outbox failures after three attempts are kept pending with a 10-minute backoff, so conversation `syncFailed` is only marked for non-retryable upsert errors. QA should not expect a warning badge for normal offline retry states beyond pending.
- Low: `StorageService.clearAll()` clears only settings, user, and legacy conversation cache boxes. If full account wipe uses this method, new chat boxes are not cleared there; logout uses `clearChatBoxes(uid)` correctly.
- Low: `conversation_started` analytics exists but is not called when the first conversation is created. Add it only if conversation-start metrics are important, not for every low-value screen step.
- Low: First-send error is represented as a failed assistant message, but `ChatScreen` does not await and does not show a toast after navigation. QA should verify the failed bubble is visible and understandable.

## Analytics Parameter Judgment
- Good and necessary:
  - `ai_request_initiated.model_attempted` and `capability` identify which model/capability users attempted.
  - `ai_request_success.model_used`, `capability`, `response_time_ms`, and `token_count` are important for model quality, cost, and latency analysis.
  - `ai_request_failed.model_attempted`, `capability`, and `failure_type` are important for debugging bad keys, unsupported capability, rate limit, transient outage, and hard provider failures.
  - usage event `requestId`, provider, model, capability, input/output/total tokens, image count, PDF count, estimated cost, and month key are useful and should stay.
- Useful but missing:
  - `conversation_id` and `message_id` in usage events already exist in the model but are not populated by the orchestrator, so cost cannot be traced back to a specific chat message.
  - `source` for first prompt, such as `manual`, `generate_code`, `create_image`, `summarize_pdf`, or `analyze_image`, would help compare which entry path users actually use.
- Not necessary right now:
  - Dedicated events for every prompt-template tap are optional. The important measurable moment is the AI request that actually sends.

## Testing Notes
- First-time manual prompt:
  - From `IntroScreen`, tap the top-right message button.
  - Confirm `ChatScreen` opens with a selected valid model if a key exists.
  - Type a prompt and tap send.
  - Confirm navigation replaces the route with `ChatDetailScreen`.
  - Confirm the user bubble appears immediately, a generating state appears, then the AI response appears.
  - Verify `chat_conversations_box` gets one `{uid}_{conversationId}` record with pending sync status before/while remote sync is pending.
  - Verify `chat_messages_box` gets separate `{uid}_{conversationId}_{messageId}` records for the user and AI messages.
  - Verify `chat_outbox_box` gets an `upsert_message_pair` task with conversation payload, user message payload, AI message payload, and idempotency key.
  - Verify Firestore conversation and two message docs are saved after `ChatSyncService` drains the outbox.
  - Verify the outbox task is removed and local conversation status becomes `synced` after Firestore success.
  - Verify `ai_request_initiated` and either success or failure analytics are logged.
- First-time predefined prompt:
  - Repeat the same entry path from `IntroScreen`.
  - Tap Generate Code or Create Image and verify a prompt is inserted but not sent automatically.
  - Tap Summarize PDF or Analyze Image and verify picker validation, attachment preview, template insertion, then send.
  - Confirm the resolved capability matches the action: code/text is `textGeneration`, create image is `imageGeneration`, image attachment is `imageUnderstanding`, PDF attachment is `pdfParsing`.
- History/detail offline-sync checks:
  - Open conversation history and verify the list is rendered from `watchConversations()`/Hive records, not only from a Firestore response.
  - Open an existing conversation and verify `ChatProvider.loadConversation()` reads local conversation metadata and subscribes to `watchMessages()`.
  - Verify opening a conversation starts `ChatSyncService.watchOpenConversation()` so remote message changes can merge into Hive.
  - Turn off network after a chat is locally saved but before outbox sync completes; verify the history card shows a pending sync badge and the outbox task remains pending.
  - Restore network and verify `ChatOutboxStore.resetCooldownTasksForRetry()` plus `ChatSyncService.processOutbox()` eventually syncs Firestore and removes the task.
- Delete checks:
  - Delete one conversation while online and verify it disappears immediately from history because `LocalChatStore.softDeleteConversation()` marks `isDeleted = true`.
  - Verify `chat_outbox_box` stores `delete_conversation` and Firestore deletion happens through `RemoteChatStore.deleteConversationRemote()`.
  - Delete one conversation while offline and verify the app shows the offline queued success message and keeps the outbox task pending.
  - Delete all conversations and verify local history clears through soft-deleted Hive records, then Firestore deletion is queued as one `delete_all_conversations` task.
  - Specifically verify delete-all timing because the screen currently waits one second and does not await the delayed repository call.
- Failure checks:
  - Select a provider with no saved key and attempt send; verify `no_key_for_model` appears and the app stays on `ChatScreen`.
  - If one provider has a valid key and another provider is preferred but unkeyed, verify the new-chat screen behavior. Current code blocks instead of falling back to the valid provider.
  - Select a provider that does not support the capability and verify `ai_capability_gap` plus a failed assistant message.
  - Simulate provider/network failure and verify the failed message persists and generating state stops.
  - Simulate a non-retryable Firestore error for `upsert_message_pair`; verify local conversation moves to `syncFailed` and the history card shows the warning badge.
  - Simulate app kill after an outbox task is marked `processing`; verify whether the task is retried on next launch. Current code may leave it stuck, so this should be treated as a bug if reproduced.
