import 'package:ai_voice_genie/features/chat/presentation/widgets/chat_input.dart';
import 'package:ai_voice_genie/shared/widgets/chat_model_selector_dropdown.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/preferences/ai_preferences_provider.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../domain/chat_attachment.dart';
import 'chat_provider.dart';

/// Entry point for starting a brand new conversation.
///
/// On first message send:
///   1. Creates conversation document in Firestore
///   2. Navigates to ChatDetailScreen for the ongoing conversation
///
/// This screen is intentionally minimal — it shows only branding
/// and the input bar. The real conversation UI is in ChatDetailScreen.
///
/// [startMode] controls whether the mic automatically starts listening
/// after the first frame. When [ChatStartMode.voice] is passed (from the
/// Home screen mic button), voice input begins immediately without the
/// user having to tap the in-app mic button.
class ChatScreen extends StatefulWidget {
  /// How the chat was opened. Defaults to [ChatStartMode.normal].
  final ChatStartMode startMode;

  const ChatScreen({super.key, this.startMode = ChatStartMode.normal});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatInputController _chatInputController = ChatInputController();
  bool _showSuggestions = true;

  /// Guards against calling startVoiceInput more than once per screen lifecycle.
  bool _didAutoStartVoice = false;

  @override
  void initState() {
    super.initState();
    // Clear any previous conversation state when starting fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().clearConversation();

      // Auto-start voice input when opened from the Home voice button.
      // We guard with _didAutoStartVoice to ensure this fires at most once
      // even if the widget rebuilds or the post-frame callback fires twice.
      if (widget.startMode == ChatStartMode.voice && !_didAutoStartVoice) {
        _didAutoStartVoice = true;
        _chatInputController.startVoiceInput();
      }
    });
  }

  Future<void> _handleSend(
      String prompt, List<ChatAttachment> attachments) async {
    _hideSuggestions();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final apiKeyProvider = context.read<ApiKeyProvider>();
    final selectedProvider =
        context.read<AiPreferencesProvider>().preferredProvider;
    if (!apiKeyProvider.validProviders.contains(selectedProvider)) {
      MessageUtils.showErrorToast(context, context.l10n.noKeyForModel);
      return;
    }

    final chatProvider = context.read<ChatProvider>();

    // Start sending message without awaiting its completion.
    // This allows synchronous state setup inside ChatProvider to complete,
    // and then execution yields back to navigate immediately.
    chatProvider.sendMessage(
      uid: uid,
      prompt: prompt,
      selectedProvider: selectedProvider,
      attachments: attachments,
    );

    if (!mounted) return;

    final conversationID = chatProvider.activeConversation?.id;
    AppRoutes.navigateAndReplace(
      context,
      AppRoutes.chatDetail,
      arguments: ChatDetailArguments(
          conversationId: conversationID ?? '', initialTitle: null),
    );
  }

  void _hideSuggestions() {
    if (!_showSuggestions) return;
    debugPrint('⚠️ Hiding suggestions');
    setState(() => _showSuggestions = false);
  }

  void _showSuggestionsState() {
    if (_showSuggestions) return;
    debugPrint('⚠️ Showing suggestions');
    setState(() => _showSuggestions = true);
  }

  Future<void> _handleSummarizePdf() async {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    await _chatInputController.pickPdfWithPrompt(l10n.summarizePdfPrompt);
  }

  Future<void> _handleAnalyzeImage() async {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    await _chatInputController.pickImageWithPrompt(l10n.analyzeImagePrompt);
  }

  void _handleGenerateCode() {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    _chatInputController.setPrompt(l10n.generateCodePrompt);
  }

  void _handleCreateImage() {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    _chatInputController.setPrompt(l10n.createImagePrompt);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
        body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Minimal Custom Top Bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.newConversation,
                      style: context.textTheme.headlineMedium),
                ),
              ],
            ),
          ),

          // ── Scrollable Welcome Content ─────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: _WelcomeContent(
                        isTablet: isTablet,
                        showSuggestions: _showSuggestions,
                        onSummarizePdf: _handleSummarizePdf,
                        onGenerateCode: _handleGenerateCode,
                        onAnalyzeImage: _handleAnalyzeImage,
                        onCreateImage: _handleCreateImage,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Input Bar with Background Container ────────────────────────
          Consumer3<ApiKeyProvider, ChatProvider, AiPreferencesProvider>(
            builder: (
              _,
              apiKeyProvider,
              chatProvider,
              preferences,
              __,
            ) {
              final selectedProvider = preferences.preferredProvider;

              return Container(
                  decoration: BoxDecoration(
                    color: context.theme.cardTheme.color,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(context.isTablet ? 30 : 20),
                    ),
                    border: Border.all(
                      color: context.theme.dividerTheme.color!,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: context.horizontalPadding / 2,
                      vertical: context.verticalSpacing / 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatModelSelectorDropdown(
                        providers: AiProviderId.values,
                        selectedProvider: selectedProvider,
                        isEnabled: !chatProvider.isGenerating,
                        onChanged: (provider) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          preferences.setPreferredProvider(provider);
                        },
                      ),
                      const SizedBox(height: 4.0),
                      // The Input Component itself
                      Flexible(
                        child: ChatInputBar(
                          isGenerating: chatProvider.isGenerating,
                          isTablet: isTablet,
                          controller: _chatInputController,
                          onUserInteracted: _hideSuggestions,
                          onSend: _handleSend,
                          onEmptyInput: _showSuggestionsState,
                        ),
                      ),
                    ],
                  ));
            },
          ),
        ],
      ),
    ));
  }
}

// =============================================================================
// WELCOME CONTENT
// =============================================================================

class _WelcomeContent extends StatelessWidget {
  final bool isTablet;
  final bool showSuggestions;
  final VoidCallback onSummarizePdf;
  final VoidCallback onGenerateCode;
  final VoidCallback onAnalyzeImage;
  final VoidCallback onCreateImage;

  const _WelcomeContent({
    required this.isTablet,
    required this.showSuggestions,
    required this.onSummarizePdf,
    required this.onGenerateCode,
    required this.onAnalyzeImage,
    required this.onCreateImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App Logo Box
        Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.isDark
                  ? AppColors.primaryGradientDark
                  : AppColors.primaryGradientLight),
          child: ImageView(
            image: const ImageViewData.asset(AppAssets.appLogo),
            width: context.screenWidth / 4,
            height: context.screenWidth / 4,
            filterQuality: FilterQuality.high,
            fit: BoxFit.cover,
          ),
        ),

        SizedBox(height: context.isTablet ? 24 : 12),
        Text(
          l10n.startConversation,
          style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: isTablet ? 48 : 30),

        // Suggestion actions are visible only while this is a fresh chat.
        AnimatedSwitcher(
          duration: AppConstants.mediumDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: showSuggestions
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _SuggestionGrid(
                      key: const ValueKey('chat_suggestions'),
                      isTablet: isTablet,
                      actions: [
                        _SuggestionAction(
                          icon: FontAwesomeIcons.filePdf,
                          label: l10n.summarizePdf,
                          onTap: onSummarizePdf,
                        ),
                        _SuggestionAction(
                          icon: FontAwesomeIcons.laptopCode,
                          label: l10n.generateCode,
                          onTap: onGenerateCode,
                        ),
                        _SuggestionAction(
                          icon: FontAwesomeIcons.magnifyingGlass,
                          label: l10n.analyzeImage,
                          onTap: onAnalyzeImage,
                        ),
                        _SuggestionAction(
                          icon: FontAwesomeIcons.images,
                          label: l10n.createImage,
                          onTap: onCreateImage,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('chat_suggestions_gone')),
        ),

        SizedBox(
            height: context.bottomPadding > 0 ? context.bottomPadding : 20),
      ],
    );
  }
}

class _SuggestionAction {
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _SuggestionGrid extends StatelessWidget {
  final bool isTablet;
  final List<_SuggestionAction> actions;

  const _SuggestionGrid({
    super.key,
    required this.isTablet,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isTablet ? 4 : 2;
    final maxWidth = isTablet ? 760.0 : 420.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTablet ? 2.4 : 3.2,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _SuggestionActionCard(
            icon: action.icon,
            label: action.label,
            onTap: action.onTap,
          );
        },
      ),
    );
  }
}

class _SuggestionActionCard extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        alignment: Alignment.center,
        // padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.theme.dividerTheme.color!),
            gradient: context.isDark
                ? AppColors.primaryGradientDark
                : AppColors.primaryGradientLight),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon,
                size: 20,
                color: context.isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
