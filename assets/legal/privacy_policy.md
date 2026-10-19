# Privacy Policy for AI Voice Genie

**Last Updated:** October 2026  
**Effective Date:** October 2026

---

## 1. 🛡️ Introduction & Commitment

Welcome to **AI Voice Genie** ("we," "our," or "us"). AI Voice Genie is an independent, voice-first, multi-model artificial intelligence mobile application engineered around a **Bring Your Own Key (BYOK)** and **Local-First** privacy architecture.

We believe that your data, prompts, voice, and API credentials belong exclusively to you. This Privacy Policy outlines with complete transparency what data we collect, how it is processed on your device and synchronized to the cloud, how third-party AI providers handle your requests, and the comprehensive controls you retain over your information.

By downloading, accessing, or using AI Voice Genie, you consent to the practices described in this Privacy Policy.

---

## 2. 🔑 Bring Your Own Key (BYOK) & Credential Security

AI Voice Genie does not resell AI access or broker third-party API billing. Instead, you supply your own API keys for supported providers (**OpenAI**, **Google Gemini**, and **Anthropic Claude**):

- **Hardware-Backed Encryption:** Your API keys are encrypted at rest using AES-256 cryptographic standards (`encrypt`) and stored within your device's hardware-backed secure storage (Android Keystore and iOS Keychain via `flutter_secure_storage`).
- **Cloud Backup:** For seamless synchronization across your signed-in sessions, encrypted API key references are stored in your private, authenticated Google Cloud Firestore record (`UsersAPIKeys/{uid}`). Only your authenticated account can read or modify these records.
- **Client Memory Masking:** API keys are dynamically masked in memory (e.g., `sk-a...789`) to prevent unauthorized shoulder-surfing.
- **Screen Capture Protection (`FLAG_SECURE`):** Key management screens enforce operating system-level window security (`FLAG_SECURE` on Android and secure window buffering on iOS) to block screenshots, screen recordings, and background task switcher leaks.
- **No Third-Party Access:** Your API keys are used exclusively to authenticate requests dispatched directly to your chosen AI providers. They are never sent to external servers, advertisers, or third-party analytics.

---

## 3. 📊 Information We Collect

To deliver a voice-first, multimodal assistant experience, we collect only essential, functional data:

- **Account Authentication Data:** When you sign in using Google Sign-In or Apple Sign-In via Firebase Authentication, we collect your unique Firebase User ID (`uid`), email address, display name, and authentication tokens.
- **Optional Profile Information:** If you choose to customize your profile in settings, optional demographic fields (such as gender, country, state, and date of birth) are saved to your private Firestore profile document.
- **Voice & Speech Audio:** When you tap the microphone to dictate a prompt, audio is processed in real time by your device's native speech recognition engine (Apple Speech framework on iOS / Android SpeechRecognizer). **Audio streams are never recorded to disk, uploaded to Voice Genie servers, or stored.** Transcribed text is placed directly into your chat input bar.
- **Text Prompts & Chat History:** Text queries, conversation titles, and AI assistant responses are stored locally on your device in a high-speed Hive database and synchronized to your private Cloud Firestore collection.
- **Media & Document Attachments:** Photos, gallery images, and PDF documents you attach to messages for vision or document analysis. Attachments are stored securely in your private Firebase Cloud Storage bucket and encoded as needed for multimodal AI processing.
- **AI Usage & Budget Telemetry:** Prompt tokens, completion tokens, model names, and estimated token expenditures are calculated and logged to your private profile to power the in-app AI Intelligence usage meters and monthly spending limit alerts.
- **Diagnostic Metrics:** Anonymized technical metrics (operating system version, device model, and crash traces via Firebase Crashlytics) are collected solely to detect stability issues and fix bugs.

---

## 4. ⚙️ How We Process & Store Your Data

- **Local-First Architecture:** Your conversations and settings are stored locally on your device in encrypted/isolated Hive NoSQL boxes. This enables instant application startup, offline viewing, and sub-millisecond local search.
- **Durable Offline Outbox:** When you perform actions while disconnected (such as sending messages or deleting conversations), mutations are queued in an on-device outbox (`ChatOutboxTask`) and synchronized to Cloud Firestore using exponential backoff once connectivity is restored.
- **On-Device PDF Generation:** When you request a PDF report, the document is compiled locally on your device (`PdfDocumentService`) from AI-generated markdown. It is saved directly to your local application cache or public device storage upon your explicit export action.

---

## 5. 🤖 Third-Party AI Providers & Data Transmission

When you submit a chat prompt, image, or PDF document, AI Voice Genie dispatches the request directly to the AI provider corresponding to your selected model, authenticated with **your own API key**:

- **OpenAI, LLC:** Processes text, vision, and image generation requests for GPT and DALL·E models (`gpt-6-luna`, `gpt-image-2.5-flare`).
- **Google LLC:** Powers Firebase backend services (Authentication, Firestore, Cloud Storage) and processes multimodal and reasoning requests for Gemini models (`gemini-3.5-flash-lite`, `gemini-3.1-flash-lite-image`, `gemini-3.8-flash`).
- **Anthropic, PBC:** Processes advanced reasoning, coding, and complex document requests for Claude models (`claude-haiku-4-5-20251001`).

> 🔒 **Enterprise Privacy Guarantee:** Each of these frontier providers maintains strict developer API data commitments stipulating that data sent via commercial API keys is **NOT used to train foundational AI models**. Your prompts and attachments are processed strictly to fulfill your active inference requests. We encourage you to review the API privacy policies of [OpenAI](https://openai.com/policies/privacy-policy), [Google Cloud](https://cloud.google.com/terms/cloud-privacy-notice), and [Anthropic](https://www.anthropic.com/privacy).

We do **NOT** sell, monetize, rent, or trade your personal data, chat history, or credentials to any third party or advertising network.

---

## 6. 🔐 Device Permissions

You retain full authority over mobile permissions and may modify or revoke them at any time in your device's System Settings:

- **Microphone (`RECORD_AUDIO` / `NSMicrophoneUsageDescription`):** Required only while actively speaking to convert voice into text.
- **Camera (`CAMERA` / `NSCameraUsageDescription`):** Required only if you take a photo within the app to attach to a prompt.
- **Photo Library & Gallery (`READ_MEDIA_IMAGES` / `NSPhotoLibraryUsageDescription`):** Required to attach images from your device gallery.
- **Photo Saving (`NSPhotoLibraryAddUsageDescription`):** Used on iOS to save AI-generated images to your Photos app upon your tap of the download button. On Android (API 29+), images are saved via scoped MediaStore without broad storage permissions.
- **Speech Recognition (`NSSpeechRecognitionUsageDescription`):** Required on iOS for real-time speech-to-text dictation.

---

## 7. 🗑️ Data Retention & Account Deletion

You possess unconditional sovereignty over your data:

- **Single & Multi-Select Conversation Deletion:** You can delete individual conversations, select multiple specific conversations, or wipe your entire chat archive at any time from the History screen. Deletions immediately soft-delete locally and trigger permanent cloud and attachment removal in the background.
- **Atomic Account Deletion:** You can permanently delete your account at any time using the **"Delete Account"** option in Profile settings. Executing account deletion initiates an atomic purge:
  1. All remote API keys are destroyed from Cloud Firestore.
  2. Your user profile and metadata are hard-deleted.
  3. All conversations, messages, and attachments are purged from Firestore and Firebase Cloud Storage.
  4. All local Hive database boxes and secure storage credentials on your device are wiped clean.
  5. Your Firebase Authentication account is permanently deleted.

---

## 8. 👶 Children's Privacy

AI Voice Genie is not directed to children under the age of 13 (or 16 in certain jurisdictions). We do not knowingly collect personal information from children. If you become aware that a child has provided us with personal data, please contact us immediately so we can remove such information and delete the associated account.

---

## 9. 🔄 Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect enhancements in app functionality, security protocols, or legal requirements. Any revisions will be reflected with an updated "Last Updated" date at the top of this document and will be immediately accessible within the application. Continued use of the application after changes constitutes acceptance of the revised policy.

---

## 10. 📬 Contact Us

For questions, feedback, or privacy-related inquiries regarding this policy, please reach out to:

- **Support Email:** `arpitaswal995@gmail.com`
- **Developer:** Arpit Aswal (Independent Developer)
- **Application:** AI Voice Genie