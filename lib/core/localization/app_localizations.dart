import 'package:flutter/material.dart';

/// Localization system for AI Voice Genie.
///
/// Supported languages: English (en), Hindi (hi).
/// All user-facing strings must be retrieved via this class.
/// Never hardcode strings in widgets.
///
/// Usage:
/// ```dart
/// // Via named getter (preferred for common strings)
/// AppLocalizations.of(context)!.appName
///
/// // Via translate key (for dynamic or feature-specific strings)
/// AppLocalizations.of(context)!.translate('ai_thinking')
/// ```
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // ==========================================================================
  // LOCALIZED STRING MAPS
  // ==========================================================================

  static final Map<String, Map<String, String>> _strings = {
    // ── ENGLISH ──────────────────────────────────────────────────────────────
    'en': {
      // ── App General ────────────────────────────────────────────────────────
      'app_name': 'AI Voice Genie',
      'app_tagline': 'Your intelligent AI assistant',
      'ai_assist': 'Your AI assistant is ready to assist you.',
      'welcome_message': "Welcome To",
      'morning': 'Good Morning',
      'evening': 'Good Evening',
      'afternoon': 'Good Afternoon',
      'ok': 'OK',
      'cancel': 'Cancel',
      'user': 'User',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'retry': 'Retry',
      'skip': 'Skip',
      'next': 'Next',
      'back': 'Back',
      'done': 'Done',
      'confirm': 'Confirm',
      'yes': 'Yes',
      'no': 'No',
      'loading': 'Loading...',
      'deleting': 'Deleting...',
      'please_wait': 'Please wait...',
      'something_went_wrong': 'Something went wrong. Please try again.',
      'no_internet_connection':
          'No internet connection. Please check your network.',
      'request_timed_out': 'Request timed out. Please try again.',
      'privacy_note':
          'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
      'ask_user_todo': 'WHAT WOULD YOU LIKE TO DO?',
      'ask_question': 'Ask a question',
      'intelligent_models': 'INTELLIGENT AI MODELS',
      'create_image': 'Create Image',
      'generate_code': 'Generate Code',
      'analyze_image': 'Analyze Image',
      'pdf_summarize': 'Summarize PDF',

      // ── Auth ───────────────────────────────────────────────────────────────
      'sign_in_with_google': 'Continue with Google',
      'sign_in_with_apple': 'Continue with Apple',
      'sign_out': 'Sign Out',
      'sign_out_confirm': 'Are you sure you want to sign out?',
      'welcome_back': 'Welcome back',
      'signing_in': 'Signing you in...',
      'signing_out': "Signing you out...",
      'sign_in_failed': 'Sign in failed. Please try again.',
      'sign_out_success': 'Signed out successfully.',

      // ── Onboarding ─────────────────────────────────────────────────────────
      'onboarding_title_1': 'Generate Text & Answer Questions',
      'onboarding_desc_1':
          'Have intelligent conversations with ChatGPT, Gemini, & Claude.',
      'onboarding_title_2': 'Generate & Describe Images',
      'onboarding_desc_2':
          'Generate images, analyze photos, & get answers from PDFs.',
      'onboarding_title_3': 'Speech To Text & Text To Speech',
      'onboarding_desc_3':
          'Speak your prompts & hear AI responses in natural voice.',
      'get_started': 'Get Started',

      // ── API Key Setup ──────────────────────────────────────────────────────
      'setup_title': 'Connect Your AI',
      'setup_subtitle': 'Add your API keys to start using AI models.',
      'add_key': 'Add API Key',
      'update_key': 'Update API Key',
      'remove_key': 'Removing Key',
      'key_remove_msg': 'Are you sure you want to remove this key',
      'key_added_success': 'API key added successfully.',
      'key_removed_success': 'API key removed.',
      'key_invalid': 'Invalid API key.',
      'key_validating': 'Validating key...',
      'key_valid': 'Key is valid',
      'api_key_required': 'API key is required',
      'api_key_too_short': 'This doesn\'t look like a valid API key',
      'api_key_hint': 'Paste your API key here',
      'get_openai_key': 'Get your OpenAI key at platform.openai.com',
      'get_gemini_key': 'Get your Gemini key at aistudio.google.com',
      'get_claude_key': 'Get your Claude key at console.anthropic.com',
      'no_key_added': 'No key added',
      'key_added': 'Key added',
      'key_fetch_error': 'Loading AI Keys failed, Please restart the app.',
      'keys': 'Keys',

      // ── Chat / Conversation ────────────────────────────────────────────────
      'new_conversation': 'New Conversation',
      'type_message': 'Type a message...',
      'send': 'Send',
      'copy_response': 'Copy',
      'copied_to_clipboard': 'Copied to clipboard',
      'delete_conversation': 'Delete Conversation',
      'delete_conversation_confirm':
          'Are you sure you want to delete this conversation? This cannot be undone.',
      'conversation_deleted': 'Conversation deleted.',
      'delete_all_conversations': 'Delete All Conversations',
      'delete_all_confirm_message':
          'Are you sure you want to delete all conversations? This cannot be undone.',
      'deleting_all_conversations': 'Deleting All Conversations..',
      'no_conversations': 'No conversations yet',
      'no_conversations_message': 'Ready when your are.',
      'start_conversation': 'Start a conversation with your AI assistant.',
      'conversation_history': 'History',
      'history_subtitle': 'Review your recent thoughts.',
      'search_placeholder': 'Search conversations...',
      'no_results_found': 'No results found',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'older': 'Older',
      'started_conversation_short': 'Started a conversation...',
      'ai_thinking': 'Generating response...',
      'prompt_required': 'Please enter a message',
      'prompt_too_long': 'Message is too long (max 10,000 characters)',
      'response_failed': 'Failed to get a response. Please try again.',
      'prompt_template_summarize_pdf':
          'Summarize this attached PDF document. Break it down into key highlights, main takeaways, and any actionable items.',
      'prompt_template_generate_code':
          'Write a clean, optimized function in [Language] to handle [Problem/Goal]. Please include brief comments explaining the logic.',
      'prompt_template_analyze_image':
          'Analyze this image and describe what is happening in detail. [Optional: Extract any visible text or UI elements].',
      'prompt_template_create_image':
          'Generate a high-quality, realistic image of [Describe your scene, style, lighting, and details here].',

      // ── AI Model Selection ─────────────────────────────────────────────────
      'select_model': 'Select AI Model',
      'current_model': 'Current model',
      'switch_model': 'Switch Model',
      'model_switched': 'Switched to',
      'no_key_for_model': 'You haven\'t added an API key for this model.',
      'add_key_for_model': 'Add Key',
      'api_keys_secure_note':
          'Your API key is secure. Only the company has the authority to save and manage your personal keys.',
      'gpt_model_message':
          'Master of conversational flow and complex text generation.',
      'gemini_model_message':
          'Multimodal powerhouse for advanced image and data synthesis.',
      'claude_model_message':
          'Expert analytical reasoning and long-form PDF understanding.',

      // ── Capability Gap Messages ────────────────────────────────────────────
      'capability_gap_title': 'Not supported',
      'capability_gap_image_gen':
          'Claude doesn\'t support image generation. Switch to ChatGPT or Gemini.',
      'capability_gap_stt':
          'Claude doesn\'t support voice input. Switch to ChatGPT or Gemini.',
      'capability_gap_tts':
          'Claude doesn\'t support voice output. Switch to ChatGPT or Gemini.',
      'use_another_model': 'Use another model',
      'available_models': 'Available models for this feature',

      // ── Image Generation ───────────────────────────────────────────────────
      'image_generator': 'Image Generator',
      'describe_image': 'Describe the image you want...',
      'generate_image': 'Generate Image',
      'generating_image': 'Creating your image...',
      'image_generated': 'Image generated successfully.',
      'image_generation_failed': 'Failed to generate image. Please try again.',
      'save_image': 'Save Image',
      'image_saved': 'Image saved to gallery.',
      'image_prompt_required': 'Please describe the image you want to generate',
      'image_prompt_too_short': 'Please provide a more detailed description',
      'image_prompt_too_long': 'Description is too long (max 4,000 characters)',

      // ── Image Reading ──────────────────────────────────────────────────────
      'attach_image': 'Attach Image',
      'attach_file': 'Attach file',
      'take_photo': 'Take Photo',
      'choose_from_gallery': 'Choose from Gallery',
      'analyzing_image': 'Analyzing image...',
      'cannot_mix_images_and_pdfs': 'You cannot mix images and PDFs in one request.',
      'max_image_attachments': 'Maximum {count} image attachments allowed',
      'max_pdf_attachments': 'Maximum {count} PDF attachments allowed',
      'image_attached': 'Image attached',
      'remove_image': 'Remove image',
      'remove_file': 'Remove file',

      // ── AI Preferences ─────────────────────────────────────────────────────
      'response_length': 'Response Length',
      'response_length_hint': 'Adjust the maximum length of model replies.',
      'vision_image_count': 'Vision Image Count',
      'vision_image_count_hint':
          'Set the default limit for multi-modal image attachments.',
      'vision_pdf_count': 'Vision PDF Count',
      'vision_pdf_count_hint':
          'Set the default limit for multi-modal PDF attachments.',
      'vision_detail_level': 'Vision Detail Level',
      'vision_detail_level_hint': 'Set detail level for vision requests.',

      // ── PDF Reader ─────────────────────────────────────────────────────────
      'pdf_reader': 'PDF Reader',
      'upload_pdf': 'Upload PDF',
      'choose_pdf': 'Choose PDF File',
      'pdf_uploaded': 'PDF uploaded.',
      'reading_pdf': 'Reading PDF...',
      'ask_about_pdf': 'Ask anything about this PDF...',
      'pdf_too_large': 'PDF is too large. Maximum size is 10MB.',
      'pdf_read_failed': 'Could not read this PDF. Please try another file.',
      'pdf_attached': 'PDF attached',
      'remove_pdf': 'Remove PDF',
      'no_pdf_uploaded': 'No PDF uploaded yet',
      'upload_pdf_subtitle': 'Upload a PDF to ask questions about its content.',

      // ── Voice ──────────────────────────────────────────────────────────────
      'tap_to_speak': 'Tap to speak',
      'listening': 'Listening...',
      'processing_voice': 'Processing...',
      'voice_input_failed': 'Could not understand. Please try again.',
      'voice_output_playing': 'Playing response...',
      'voice_output_stopped': 'Stopped.',
      'microphone_permission_denied':
          'Microphone permission is required for voice input.',
      'open_settings': 'Open Settings',
      'speech_text_unavailable': 'Speech Text not available.',

      // ── Settings ───────────────────────────────────────────────────────────
      'home': 'Home',
      'settings': 'Settings',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'System Default',
      'language': 'Language',
      'language_en': 'English',
      'language_hi': 'हिंदी',
      'notifications': 'Notifications',
      'notifications_enabled': 'Enable notifications',
      'ai_models': 'AI Models',
      'manage_api_keys': 'Manage API Keys',
      'voice_settings': 'Voice Settings',
      'use_ai_tts': 'Use AI Voice (higher quality)',
      'use_ai_stt': 'Use AI Speech Recognition',
      'tts_speed': 'Speech Speed',
      'about': 'About',
      'app_version': 'App Version',
      'privacy_policy': 'Privacy Policy',
      'terms_of_service': 'Terms of Service',

      // ── Profile ────────────────────────────────────────────────────────────
      'profile': 'Profile',
      'account': 'Account',
      'app_settings': 'App Settings',
      'ai_preferences': 'AI Preferences',
      'ai_intelligence': 'AI Intelligence',
      'support': 'Support',
      'edit_profile': 'Edit Profile',
      'display_name': 'Display Name',
      'photo_url': 'Photo URL',
      'photo_url_optional': 'Photo URL (optional)',
      'profile_updated': 'Profile updated successfully.',
      'profile_updating': 'Profile Updating...',
      'profile_update_failed': 'Could not update profile. Please try again.',
      'active_models': 'Active Models',
      'inactive_models': 'Inactive Models',
      'activate_more_models': 'Activate more AI models',
      'activate_more_models_message':
          'Add API keys to unlock more reasoning styles, fallback routing, and feature coverage.',
      'enabled': 'Enabled',
      'not_active': 'Not Active',
      'configure': 'Configure',
      'help_center': 'Help Center',
      'coming_soon': 'Coming soon.',
      'about_app': 'About AI Voice Genie',
      'development_build': 'Development Build',
      'about_mission_title': 'Mission',
      'about_mission_body':
          'AI Voice Genie brings ChatGPT, Gemini, and Claude into one voice-first workspace for chat, images, documents, and everyday thinking.',
      'legal': 'Legal',
      'credits_attribution': 'Credits & Attribution',
      'open_source_licenses': 'Open-source Licenses',
      'contact_support': 'Contact Support',
      'configured': 'Configured',
      'not_configured': 'Not configured',
      'view_licenses': 'View package licenses',
      'about_developer': 'Developer',
      'independent_developer': 'Independent developer',
      'copyright': 'Copyright',
      'link_unavailable': 'This link is not configured yet.',
      'could_not_open_link': 'Could not open this link.',
      'delete_account': 'Delete Account',
      'delete_account_confirm':
          'This will permanently delete your account and all conversations. This cannot be undone.',
      'account_deleted': 'Account deleted.',
      'unauthenticate_profile': 'UnAuthenticate Profile',
      'date_of_birth': 'Date of Birth',
      'age': 'Age',
      'prefer_model': 'Prefer Model',
      'auto_prefer_model': 'Auto Prefer Model',
      'preferred_model': 'Preferred Model',
      'preferred_model_hint':
          'Quick switch the model used for chats. Falls back if unavailable.',
      'image_quality': 'Image Quality',
      'image_quality_hint': 'Set the default quality for image generation.',
      'image_size': 'Image Size',
      'image_size_hint': 'Choose the default output size for images.',
      'image_count': 'Image Count',
      'image_count_hint': 'Choose how many images to generate per request.',
      'quality_low': 'Low',
      'quality_medium': 'Medium',
      'quality_high': 'High',
      'select_photo_source': 'Select Photo Source',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'permission_denied': 'Permission Denied',
      'camera_permission_denied':
          'Camera permission is required to take photos.',
      'gallery_permission_denied':
          'Gallery permission is required to choose photos.',
      'uploading_photo': 'Uploading photo...',

      // ── Validation ─────────────────────────────────────────────────────────
      'field_required': 'This field is required',
      'email_required': 'Email is required',
      'invalid_email': 'Please enter a valid email address',
      'title_required': 'Title is required',
      'title_too_long': 'Title must not exceed 100 characters',
      'date_required': 'Date is required',

      // ── Empty States ───────────────────────────────────────────────────────
      'no_results': 'No results found',
      'no_images': 'No generated images yet',
      'no_images_subtitle': 'Use the Image Generator to create AI images.',

      // ── Error Messages ─────────────────────────────────────────────────────
      'error_rate_limit': 'Rate limit reached. Please try again in a moment.',
      'error_quota_exceeded':
          'API quota exceeded. Please check your billing or plan.',
      'error_invalid_key': 'Invalid API key. Please update it in Settings.',
      'error_invalid_ai_request':
          'The selected AI model could not process this request.',
      'error_all_models_failed':
          'All AI models are currently unavailable. Please try again later.',
      'error_ai_server':
          'The selected AI model is temporarily unavailable. Please try again.',
      'error_engine_overloaded':
          'The AI engine is currently overloaded. Please try again in a few seconds.',
      'error_region_not_supported':
          'This AI model is not available in your region.',
      'error_permission_denied':
          'Permission denied. Please check your API key permissions.',
      'error_unexpected_ai':
          'The selected AI model returned an unexpected error. Please try again.',
      'error_selected_model_capability_gap':
          'The selected AI model cannot complete this task. Choose a model that supports this feature.',
      'error_pdf_too_large': 'PDF exceeds the 10MB size limit.',
      'error_image_too_large': 'Image exceeds the 5MB size limit.',
      'error_no_models_with_key':
          'Please add at least one API key in Settings to use AI features.',
      'error_microphone': 'Microphone is not available on this device.',
      'model_rate_limit': 'rate limit exceeded. Please try again in a moment.',
      'press_back_again_to_exit': 'Press back again to exit',
    },

    // ── HINDI ─────────────────────────────────────────────────────────────────
    'hi': {
      // ── App General ────────────────────────────────────────────────────────
      'app_name': 'AI वॉयस जीनी',
      'app_tagline': 'आपका बुद्धिमान AI सहायक',
      'ai_assist': 'आपका एआई सहायक आपकी सहायता के लिए तैयार है।',
      'welcome_message': 'आपका स्वागत है',
      'morning': 'शुभ प्रभात',
      'evening': 'शुभ संध्या',
      'afternoon': 'शुभ दोपहर',
      'ok': 'ठीक है',
      'cancel': 'रद्द करें',
      'user': 'User',
      'save': 'सहेजें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'close': 'बंद करें',
      'retry': 'पुनः प्रयास करें',
      'skip': 'छोड़ें',
      'next': 'अगला',
      'back': 'वापस',
      'done': 'हो गया',
      'confirm': 'पुष्टि करें',
      'yes': 'हाँ',
      'no': 'नहीं',
      'loading': 'लोड हो रहा है...',
      'deleting': 'हटाया जा रहा है...',
      'please_wait': 'कृपया प्रतीक्षा करें...',
      'something_went_wrong': 'कुछ गलत हो गया। कृपया पुनः प्रयास करें।',
      'no_internet_connection': 'इंटरनेट कनेक्शन नहीं है। अपना नेटवर्क जांचें।',
      'request_timed_out': 'अनुरोध का समय समाप्त हो गया। पुनः प्रयास करें।',
      'privacy_note':
          'आगे बढ़ने पर, आप हमारी सेवा की शर्तों और गोपनीयता नीति से सहमत होते हैं।',
      'ask_user_todo': 'आप क्या करना चाहेंगे?',
      'ask_question': 'प्रश्न पूछें',
      'intelligent_models': 'INTELLIGENT AI MODELS',
      'create_image': 'चित्र बनाएं',
      'generate_code': 'कोड जनरेट करें',
      'analyze_image': 'चित्र का विश्लेषण करें',
      'pdf_summarize': 'पीडीएफ का सारांश प्रस्तुत करेंं',

      // ── Auth ───────────────────────────────────────────────────────────────
      'sign_in_with_google': 'गूगल के साथ जारी रखें',
      'sign_in_with_apple': 'एप्पल के साथ जारी रखें',
      'sign_out': 'साइन आउट',
      'sign_out_confirm': 'क्या आप साइन आउट करना चाहते हैं?',
      'welcome_back': 'वापस आपका स्वागत है',
      'signing_in': 'साइन इन हो रहा है...',
      'signing_out': "साइन आउट हो रहा है...",
      'sign_in_failed': 'साइन इन विफल। कृपया पुनः प्रयास करें।',
      'sign_out_success': 'सफलतापूर्वक साइन आउट हो गए।',

      // ── Onboarding ─────────────────────────────────────────────────────────
      'onboarding_title_1': 'पाठ उत्पन्न करें और प्रश्नों के उत्तर दें',
      'onboarding_desc_1':
          'ChatGPT, Gemini और Claude के साथ सार्थक बातचीत करें।',
      'onboarding_title_2': 'चित्र बनाएं और उनका वर्णन करें',
      'onboarding_desc_2':
          'चित्र बनाएं, तस्वीरों का विश्लेषण करें और पीडीएफ से उत्तर प्राप्त करें।',
      'onboarding_title_3': 'चस्पीच टू टेक्स्ट और टेक्स्ट टू स्पीच',
      'onboarding_desc_3':
          'अपने प्रॉम्प्ट बोलें और AI के जवाब स्वाभाविक आवाज में सुनें।',
      'get_started': 'शुरू करें',

      // ── API Key Setup ──────────────────────────────────────────────────────
      'setup_title': 'अपना AI कनेक्ट करें',
      'setup_subtitle': 'AI मॉडल उपयोग करने के लिए API key जोड़ें।',
      'add_key': 'API Key जोड़ें',
      'update_key': 'API Key अपडेट करें',
      'remove_key': 'कुंजी हटाना',
      'key_remove_msg': 'क्या आप वाकई इस कुंजी को हटाना चाहते हैं?',
      'key_added_success': 'API key सफलतापूर्वक जोड़ी गई।',
      'key_removed_success': 'API key हटाई गई।',
      'key_invalid': 'अमान्य API key।',
      'key_validating': 'Key सत्यापित हो रही है...',
      'key_valid': 'Key वैध है',
      'api_key_required': 'API key आवश्यक है',
      'api_key_too_short': 'यह एक वैध API key नहीं लगती',
      'api_key_hint': 'अपनी API key यहाँ पेस्ट करें',
      'get_openai_key': 'OpenAI key: platform.openai.com',
      'get_gemini_key': 'Gemini key: aistudio.google.com',
      'get_claude_key': 'Claude key: console.anthropic.com',
      'no_key_added': 'Key नहीं जोड़ी गई',
      'key_added': 'Key जोड़ी गई',
      'key_fetch_error':
          'एआई कुंजी लोड करने में विफलता, कृपया ऐप को पुनः आरंभ करें।',
      'keys': 'कुंजी',

      // ── Chat / Conversation ────────────────────────────────────────────────
      'new_conversation': 'नई बातचीत',
      'type_message': 'संदेश लिखें...',
      'send': 'भेजें',
      'copy_response': 'कॉपी करें',
      'copied_to_clipboard': 'क्लिपबोर्ड में कॉपी हो गया',
      'delete_conversation': 'बातचीत हटाएं',
      'delete_conversation_confirm': 'क्या आप इस बातचीत को हटाना चाहते हैं?',
      'conversation_deleted': 'बातचीत हटाई गई।',
      'delete_all_conversations': 'सभी बातचीत हटाएं',
      'delete_all_confirm_message':
          'क्या आप सभी बातचीत हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।',
      'deleting_all_conversations': 'सभी बातचीत हटाई जा रही हैं..',
      'no_conversations': 'अभी कोई बातचीत नहीं',
      'no_conversations_message': 'तैयार जब आप हैं।',
      'start_conversation': 'अपने AI सहायक के साथ बातचीत शुरू करें।',
      'conversation_history': 'इतिहास',
      'history_subtitle': 'अपने हालिया विचारों की समीक्षा करें।',
      'search_placeholder': 'बातचीत खोजें...',
      'no_results_found': 'कोई परिणाम नहीं मिला',
      'today': 'आज',
      'yesterday': 'कल',
      'older': 'पुराने',
      'started_conversation_short': 'बातचीत शुरू की...',
      'ai_thinking': 'जवाब बन रहा है...',
      'prompt_required': 'कृपया एक संदेश दर्ज करें',
      'prompt_too_long': 'संदेश बहुत लंबा है (अधिकतम 10,000 अक्षर)',
      'response_failed': 'जवाब नहीं मिला। पुनः प्रयास करें।',
      'prompt_template_summarize_pdf':
          'इस संलग्न PDF दस्तावेज़ का सारांश दें। इसे मुख्य हाइलाइट्स, मुख्य निष्कर्षों और कार्य योग्य बिंदुओं में बांटें।',
      'prompt_template_generate_code':
          '[Language] में [Problem/Goal] को संभालने के लिए एक साफ़, ऑप्टिमाइज़्ड फ़ंक्शन लिखें। कृपया लॉजिक समझाने वाली छोटी टिप्पणियां शामिल करें।',
      'prompt_template_analyze_image':
          'इस चित्र का विश्लेषण करें और विस्तार से बताएं कि इसमें क्या हो रहा है। [वैकल्पिक: दिखने वाला टेक्स्ट या UI एलिमेंट निकालें].',
      'prompt_template_create_image':
          '[Describe your scene, style, lighting, and details here] की एक उच्च-गुणवत्ता, वास्तविक दिखने वाली छवि जनरेट करें।',

      // ── AI Model Selection ─────────────────────────────────────────────────
      'select_model': 'AI मॉडल चुनें',
      'current_model': 'वर्तमान मॉडल',
      'switch_model': 'मॉडल बदलें',
      'model_switched': 'बदल गया',
      'no_key_for_model': 'इस मॉडल के लिए API key नहीं जोड़ी गई।',
      'add_key_for_model': 'Key जोड़ें',
      'api_keys_secure_note':
          'आपकी API की (key) सुरक्षित है। केवल कंपनी को ही आपकी व्यक्तिगत की (key) सहेजने का अधिकार है।',
      'gpt_model_message': 'संवादात्मक प्रवाह और जटिल पाठ निर्माण में निपुण।',
      'gemini_model_message':
          'उन्नत छवि और डेटा संश्लेषण के लिए मल्टीमॉडल पावरहाउस।',
      'claude_model_message':
          'उत्कृष्ट विश्लेषणात्मक तर्क क्षमता और पीडीएफ फॉर्मेट को समझने की क्षमता।',

      // ── Capability Gap Messages ────────────────────────────────────────────
      'capability_gap_title': 'समर्थित नहीं',
      'capability_gap_image_gen':
          'Claude चित्र नहीं बना सकता। ChatGPT या Gemini का उपयोग करें।',
      'capability_gap_stt':
          'Claude वॉयस इनपुट नहीं करता। ChatGPT या Gemini का उपयोग करें।',
      'capability_gap_tts':
          'Claude वॉयस आउटपुट नहीं करता। ChatGPT या Gemini का उपयोग करें।',
      'use_another_model': 'दूसरा मॉडल उपयोग करें',
      'available_models': 'इस सुविधा के लिए उपलब्ध मॉडल',

      // ── Image Generation ───────────────────────────────────────────────────
      'image_generator': 'इमेज जनरेटर',
      'describe_image': 'जो चित्र चाहिए उसका वर्णन करें...',
      'generate_image': 'चित्र बनाएं',
      'generating_image': 'आपका चित्र बन रहा है...',
      'image_generated': 'चित्र सफलतापूर्वक बन गया।',
      'image_generation_failed': 'चित्र नहीं बन सका। पुनः प्रयास करें।',
      'save_image': 'चित्र सहेजें',
      'image_saved': 'चित्र गैलरी में सहेजा गया।',
      'image_prompt_required': 'कृपया चित्र का वर्णन करें',
      'image_prompt_too_short': 'कृपया अधिक विस्तृत वर्णन दें',
      'image_prompt_too_long': 'वर्णन बहुत लंबा है (अधिकतम 4,000 अक्षर)',

      // ── Image Reading ──────────────────────────────────────────────────────
      'attach_image': 'चित्र जोड़ें',
      'attach_file': 'फ़ाइल जोड़ें',
      'take_photo': 'फ़ोटो लें',
      'choose_from_gallery': 'गैलरी से चुनें',
      'analyzing_image': 'चित्र विश्लेषण हो रहा है...',
      'cannot_mix_images_and_pdfs':
          'आप एक ही अनुरोध में इमेज और PDF को साथ नहीं जोड़ सकते।',
      'max_image_attachments': 'अधिकतम {count} इमेज अटैचमेंट की अनुमति है',
      'max_pdf_attachments': 'अधिकतम {count} PDF अटैचमेंट की अनुमति है',
      'image_attached': 'चित्र जोड़ा गया',
      'remove_image': 'चित्र हटाएं',
      'remove_file': 'फ़ाइल हटाएं',

      // ── AI Preferences ─────────────────────────────────────────────────────
      'response_length': 'उत्तर लंबाई',
      'response_length_hint': 'मॉडल के उत्तर की अधिकतम लंबाई बदलें।',
      'vision_image_count': 'विज़न इमेज संख्या',
      'vision_image_count_hint':
          'बहु-मोडल इमेज अटैचमेंट की डिफ़ॉल्ट सीमा तय करें।',
      'vision_pdf_count': 'विज़न PDF संख्या',
      'vision_pdf_count_hint':
          'बहु-मोडल PDF अटैचमेंट की डिफ़ॉल्ट सीमा तय करें।',
      'vision_detail_level': 'विज़न विवरण स्तर',
      'vision_detail_level_hint': 'विज़न अनुरोधों के लिए विवरण स्तर तय करें।',

      // ── PDF Reader ─────────────────────────────────────────────────────────
      'pdf_reader': 'PDF रीडर',
      'upload_pdf': 'PDF अपलोड करें',
      'choose_pdf': 'PDF फ़ाइल चुनें',
      'pdf_uploaded': 'PDF अपलोड हो गई।',
      'reading_pdf': 'PDF पढ़ी जा रही है...',
      'ask_about_pdf': 'इस PDF के बारे में कुछ भी पूछें...',
      'pdf_too_large': 'PDF बहुत बड़ी है। अधिकतम आकार 10MB है।',
      'pdf_read_failed': 'यह PDF नहीं पढ़ी जा सकी।',
      'pdf_attached': 'PDF जोड़ी गई',
      'remove_pdf': 'PDF हटाएं',
      'no_pdf_uploaded': 'अभी कोई PDF अपलोड नहीं हुई',
      'upload_pdf_subtitle':
          'PDF अपलोड करें और उसकी सामग्री के बारे में प्रश्न पूछें।',

      // ── Voice ──────────────────────────────────────────────────────────────
      'tap_to_speak': 'बोलने के लिए टैप करें',
      'listening': 'सुन रहा हूं...',
      'processing_voice': 'प्रोसेस हो रहा है...',
      'voice_input_failed': 'समझ नहीं आया। पुनः प्रयास करें।',
      'voice_output_playing': 'जवाब सुनाया जा रहा है...',
      'voice_output_stopped': 'रुक गया।',
      'microphone_permission_denied':
          'वॉयस इनपुट के लिए माइक्रोफ़ोन अनुमति आवश्यक है।',
      'open_settings': 'सेटिंग खोलें',
      'speech_text_unavailable': 'भाषण का पाठ उपलब्ध नहीं है।',

      // ── Settings ───────────────────────────────────────────────────────────
      'home': 'होम',
      'settings': 'सेटिंग',
      'appearance': 'दिखावट',
      'theme': 'थीम',
      'theme_light': 'हल्का',
      'theme_dark': 'गहरा',
      'theme_system': 'सिस्टम डिफ़ॉल्ट',
      'language': 'भाषा',
      'language_en': 'English',
      'language_hi': 'हिंदी',
      'notifications': 'सूचनाएं',
      'notifications_enabled': 'सूचनाएं सक्षम करें',
      'ai_models': 'AI मॉडल',
      'manage_api_keys': 'API Keys प्रबंधित करें',
      'voice_settings': 'वॉयस सेटिंग',
      'use_ai_tts': 'AI आवाज़ उपयोग करें (बेहतर गुणवत्ता)',
      'use_ai_stt': 'AI स्पीच रिकग्निशन उपयोग करें',
      'tts_speed': 'बोलने की गति',
      'about': 'के बारे में',
      'app_version': 'ऐप संस्करण',
      'privacy_policy': 'गोपनीयता नीति',
      'terms_of_service': 'सेवा की शर्तें',

      // ── Profile ────────────────────────────────────────────────────────────
      'profile': 'प्रोफ़ाइल',
      'account': 'खाता',
      'app_settings': 'ऐप सेटिंग',
      'ai_preferences': 'AI प्राथमिकताएं',
      'ai_intelligence': 'AI इंटेलिजेंस',
      'support': 'सहायता',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'display_name': 'डिस्प्ले नाम',
      'photo_url': 'फ़ोटो URL',
      'photo_url_optional': 'फ़ोटो URL (वैकल्पिक)',
      'profile_updated': 'प्रोफ़ाइल सफलतापूर्वक अपडेट हुई।',
      'profile_updating': 'प्रोफ़ाइल अपडेट हो रही है...',
      'profile_update_failed':
          'प्रोफ़ाइल अपडेट नहीं हो सकी। कृपया पुनः प्रयास करें।',
      'active_models': 'सक्रिय मॉडल',
      'inactive_models': 'निष्क्रिय मॉडल',
      'activate_more_models': 'और AI मॉडल सक्रिय करें',
      'activate_more_models_message':
          'अधिक reasoning styles, fallback routing और feature coverage के लिए API keys जोड़ें।',
      'enabled': 'सक्षम',
      'not_active': 'सक्रिय नहीं',
      'configure': 'कॉन्फ़िगर करें',
      'help_center': 'हेल्प सेंटर',
      'coming_soon': 'जल्द आ रहा है।',
      'about_app': 'ऐएआई वॉइस जीनियस के बारे में',
      'development_build': 'डेवलपमेंट बिल्ड',
      'about_mission_title': 'मिशन',
      'about_mission_body':
          'AI Voice Genie ChatGPT, Gemini और Claude को chat, images, documents और everyday thinking के लिए एक voice-first workspace में लाता है।',
      'legal': 'कानूनी',
      'credits_attribution': 'क्रेडिट और एट्रिब्यूशन',
      'open_source_licenses': 'ओपन-सोर्स लाइसेंस',
      'contact_support': 'सहायता से संपर्क करें',
      'configured': 'कॉन्फ़िगर किया गया',
      'not_configured': 'कॉन्फ़िगर नहीं किया गया',
      'view_licenses': 'पैकेज लाइसेंस देखें',
      'about_developer': 'डेवलपर',
      'independent_developer': 'स्वतंत्र डेवलपर',
      'copyright': 'कॉपीराइट',
      'link_unavailable': 'यह लिंक अभी कॉन्फ़िगर नहीं है।',
      'could_not_open_link': 'यह लिंक नहीं खुल सका।',
      'delete_account': 'खाता हटाएं',
      'delete_account_confirm':
          'यह आपके खाते और सभी बातचीत को स्थायी रूप से हटा देगा।',
      'account_deleted': 'खाता हटा दिया गया।',
      'unauthenticate_profile': 'अप्रमाणित प्रोफ़ाइल',
      'date_of_birth': 'जन्म तिथि',
      'age': 'आयु',
      'prefer_model': 'पसंदीदा मॉडल',
      'auto_prefer_model': 'ऑटो पसंदीदा मॉडल',
      'preferred_model': 'पसंदीदा मॉडल',
      'preferred_model_hint':
          'चैट के लिए मॉडल जल्दी बदलें। उपलब्ध न होने पर fallback होगा।',
      'image_quality': 'इमेज गुणवत्ता',
      'image_quality_hint': 'इमेज जनरेशन की डिफ़ॉल्ट गुणवत्ता सेट करें।',
      'image_size': 'इमेज आकार',
      'image_size_hint': 'इमेज का डिफ़ॉल्ट आउटपुट आकार चुनें।',
      'image_count': 'इमेज संख्या',
      'image_count_hint': 'प्रति अनुरोध कितनी इमेज बनानी हैं चुनें।',
      'quality_low': 'कम',
      'quality_medium': 'मध्यम',
      'quality_high': 'उच्च',
      'select_photo_source': 'फोटो स्रोत चुनें',
      'camera': 'कैमरा',
      'gallery': 'गैलरी',
      'permission_denied': 'अनुमति अस्वीकृत',
      'camera_permission_denied': 'फोटो लेने के लिए कैमरा अनुमति आवश्यक है।',
      'gallery_permission_denied': 'फोटो चुनने के लिए गैलरी अनुमति आवश्यक है।',
      'uploading_photo': 'फोटो अपलोड हो रही है...',

      // ── Validation ─────────────────────────────────────────────────────────
      'field_required': 'यह फ़ील्ड आवश्यक है',
      'email_required': 'ईमेल आवश्यक है',
      'invalid_email': 'कृपया एक वैध ईमेल पता दर्ज करें',
      'title_required': 'शीर्षक आवश्यक है',
      'title_too_long': 'शीर्षक 100 अक्षरों से अधिक नहीं होना चाहिए',
      'date_required': 'तारीख आवश्यक है',

      // ── Empty States ───────────────────────────────────────────────────────
      'no_results': 'कोई परिणाम नहीं मिला',
      'no_images': 'अभी कोई चित्र नहीं',
      'no_images_subtitle': 'AI चित्र बनाने के लिए इमेज जनरेटर उपयोग करें।',

      // ── Error Messages ─────────────────────────────────────────────────────
      'error_rate_limit':
          'दर सीमा पहुंच गई। कृपया कुछ देर बाद पुनः प्रयास करें।',
      'error_quota_exceeded':
          'API कोटा समाप्त हो गया है। कृपया अपना बिलिंग या प्लान जांचें।',
      'error_invalid_key': 'अमान्य API key। सेटिंग में अपडेट करें।',
      'error_invalid_ai_request':
          'चयनित AI मॉडल इस अनुरोध को प्रोसेस नहीं कर सका।',
      'error_all_models_failed':
          'सभी AI मॉडल अभी उपलब्ध नहीं हैं। बाद में प्रयास करें।',
      'error_ai_server':
          'चयनित AI मॉडल अस्थायी रूप से उपलब्ध नहीं है। कृपया पुनः प्रयास करें।',
      'error_engine_overloaded':
          'AI इंजन अभी ओवरलोड है। कृपया कुछ सेकंड बाद पुनः प्रयास करें।',
      'error_region_not_supported':
          'यह AI मॉडल आपके क्षेत्र में उपलब्ध नहीं है।',
      'error_permission_denied':
          'अनुमति अस्वीकृत। कृपया अपनी API key अनुमतियाँ जांचें।',
      'error_unexpected_ai':
          'चयनित AI मॉडल ने अनपेक्षित त्रुटि लौटाई। कृपया पुनः प्रयास करें।',
      'error_selected_model_capability_gap':
          'चयनित AI मॉडल यह कार्य पूरा नहीं कर सकता। ऐसी सुविधा का समर्थन करने वाला मॉडल चुनें।',
      'error_pdf_too_large': 'PDF 10MB की सीमा से अधिक है।',
      'error_image_too_large': 'चित्र 5MB की सीमा से अधिक है।',
      'error_no_models_with_key':
          'AI सुविधाएं उपयोग करने के लिए सेटिंग में कम से कम एक API key जोड़ें।',
      'error_microphone': 'इस डिवाइस पर माइक्रोफ़ोन उपलब्ध नहीं है।',
      'model_rate_limit':
          'की दर सीमा पार हो गई है। कृपया कुछ देर बाद पुनः प्रयास करें।',
      'press_back_again_to_exit': 'ऐप बंद करने के लिए एक बार फिर वापस दबाएं',
    },
  };

  // ==========================================================================
  // PUBLIC TRANSLATE METHOD
  // ==========================================================================

  /// Translate a key to the current locale's string.
  ///
  /// Returns the key itself if no translation found —
  /// never returns null so the UI always has something to display.
  String translate(String key) {
    return _strings[locale.languageCode]?[key] ?? key;
  }

  // ==========================================================================
  // NAMED GETTERS — for the most commonly used strings
  // ==========================================================================

  String get welcome => translate('welcome_message');
  String get appName => translate('app_name');
  String get appTagline => translate('app_tagline');
  String get aiAssist => translate('ai_assist');
  String get ok => translate('ok');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get loading => translate('loading');
  String get delete => translate('delete');
  String get pleaseWait => translate('please_wait');
  String get somethingWentWrong => translate('something_went_wrong');
  String get noInternet => translate('no_internet_connection');
  String get signInWithGoogle => translate('sign_in_with_google');
  String get signInWithApple => translate('sign_in_with_apple');
  String get signOut => translate('sign_out');
  String get settings => translate('settings');
  String get newConversation => translate('new_conversation');
  String get deleteAllConversations => translate('delete_all_conversations');
  String get deleteAllConfirmMessage => translate('delete_all_confirm_message');
  String get deletingAllConversations =>
      translate('deleting_all_conversations');
  String get typeMessage => translate('type_message');
  String get send => translate('send');
  String get aiThinking => translate('ai_thinking');
  String get tapToSpeak => translate('tap_to_speak');
  String get listening => translate('listening');
  String get fieldRequired => translate('field_required');
  String get emailRequired => translate('email_required');
  String get invalidEmail => translate('invalid_email');
  String get apiKeyRequired => translate('api_key_required');
  String get promptRequired => translate('prompt_required');
  String get getStarted => translate('get_started');
  String get manageApiKeys => translate('manage_api_keys');
  String get selectModel => translate('select_model');
  String get noKeyForModel => translate('no_key_for_model');
  String get privacyNote => translate('privacy_note');
  String get skip => translate('skip');
  String get onboardTitle1 => translate('onboarding_title_1');
  String get onboardDesc1 => translate('onboarding_desc_1');
  String get onboardTitle2 => translate('onboarding_title_2');
  String get onboardDesc2 => translate('onboarding_desc_2');
  String get onboardTitle3 => translate('onboarding_title_3');
  String get onboardDesc3 => translate('onboarding_desc_3');
  String get next => translate('next');
  String get keySetupTitle => translate('setup_title');
  String get keySetupSubTitle => translate('setup_subtitle');
  String get keyValid => translate('key_valid');
  String get keyInvalid => translate('key_invalid');
  String get keyValidating => translate('key_validating');
  String get noKeyAdded => translate('no_key_added');
  String get paste => translate('paste');
  String get openAIKey => translate('get_openai_key');
  String get geminiAIKey => translate('get_gemini_key');
  String get claudeAIkey => translate('get_claude_key');
  String get keyHint => translate('api_key_hint');
  String get addKey => translate('add_key');
  String get keySecureNote => translate('api_keys_secure_note');
  String get done => translate('done');
  String get noModelKey => translate('error_no_models_with_key');
  String get promptTooLong => translate('prompt_too_long');
  String get apiKeyTooShort => translate('api_key_too_short');
  String get imagePromptRequired => translate('image_prompt_required');
  String get imagePromptTooShort => translate('image_prompt_too_short');
  String get imagePromptTooLong => translate('image_prompt_too_long');
  String get titleRequired => translate('title_required');
  String get titleTooLong => translate('title_too_long');
  String get dateRequired => translate('date_required');
  String get home => translate('home');
  String get historySubtitle => translate('history_subtitle');
  String get conversationHistory => translate('conversation_history');
  String get searchPlaceholder => translate('search_placeholder');
  String get noResultsFound => translate('no_results_found');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get older => translate('older');
  String get startedShort => translate('started_conversation_short');
  String get morning => translate('morning');
  String get evening => translate('evening');
  String get afternoon => translate('afternoon');
  String get askTodo => translate('ask_user_todo');
  String get askQuestion => translate('ask_question');
  String get generateImage => translate('generate_image');
  String get uploadPdf => translate('upload_pdf');
  String get intelligentModels => translate('intelligent_models');
  String get chatGPTModelMessage => translate('gpt_model_message');
  String get geminiModelMessage => translate('gemini_model_message');
  String get claudeModelMessage => translate('claude_model_message');
  String get user => translate('user');
  String get startConversation => translate('start_conversation');
  String get createImage => translate('create_image');
  String get generateCode => translate('generate_code');
  String get analyzeImage => translate('analyze_image');
  String get summarizePdf => translate('pdf_summarize');
  String get summarizePdfPrompt => translate('prompt_template_summarize_pdf');
  String get generateCodePrompt => translate('prompt_template_generate_code');
  String get analyzeImagePrompt => translate('prompt_template_analyze_image');
  String get createImagePrompt => translate('prompt_template_create_image');
  String get noConversations => translate('no_conversations');
  String get noConversationsMessage => translate('no_conversations_message');
  String get deleting => translate('deleting');
  String get profile => translate('profile');
  String get editProfile => translate('edit_profile');
  String get profileUpdated => translate('profile_updated');
  String get profileUpdateFailed => translate('profile_update_failed');
  String get unAuthenticate => translate('unauthenticate_profile');
  String get appSettings => translate('app_settings');
  String get aiPreferences => translate('ai_preferences');
  String get aiIntelligence => translate('ai_intelligence');
  String get support => translate('support');
  String get theme => translate('theme');
  String get language => translate('language');
  String get preferredModel => translate('preferred_model');
  String get preferredModelHint => translate('preferred_model_hint');
  String get imageQuality => translate('image_quality');
  String get imageQualityHint => translate('image_quality_hint');
  String get imageSize => translate('image_size');
  String get imageSizeHint => translate('image_size_hint');
  String get imageCount => translate('image_count');
  String get imageCountHint => translate('image_count_hint');
  String get qualityLow => translate('quality_low');
  String get qualityMedium => translate('quality_medium');
  String get qualityHigh => translate('quality_high');
  String get activateModels => translate('activate_more_models');
  String get activateModelsMessage => translate('activate_more_models_message');
  String get helpCenter => translate('help_center');
  String get about => translate('about');
  String get signOutConfirm => translate('sign_out_confirm');
  String get signOutSuccess => translate('sign_out_success');
  String get signingOut => translate('signing_out');
  String get aboutApp => translate('about_app');
  String get appVersion => translate('app_version');
  String get privacyPolicy => translate('privacy_policy');
  String get termsOfService => translate('terms_of_service');
  String get developmentBuild => translate('development_build');
  String get linkUnavailable => translate('link_unavailable');
  String get couldNotOpenLink => translate('could_not_open_link');
  String get profileUpdating => translate('profile_updating');
  String get keyRemoveSuccess => translate('key_removed_success');
  String get removeKey => translate('remove_key');
  String get keyRemoveMsg => translate('key_remove_msg');
  String get keys => translate('keys');
  String get dateOfBirthLabel => translate('date_of_birth');
  String get ageLabel => translate('age');
  String get preferModelLabel => translate('prefer_model');
  String get autoPreferModel => translate('auto_prefer_model');
  String get selectPhotoSource => translate('select_photo_source');
  String get camera => translate('camera');
  String get gallery => translate('gallery');
  String get permissionDenied => translate('permission_denied');
  String get openSettings => translate('open_settings');
  String get cameraDeniedMessage => translate('camera_permission_denied');
  String get galleryDeniedMessage => translate('gallery_permission_denied');
  String get uploadingPhoto => translate('uploading_photo');
  String get modelLimit => translate('model_rate_limit');
  String get pressBackAgainToExit => translate('press_back_again_to_exit');
}

// ==========================================================================
// DELEGATE
// ==========================================================================

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// =============================================================================
// EXTENSION — convenience l10n access on BuildContext
// =============================================================================

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
