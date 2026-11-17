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
import '../../usage/presentation/usage_provider.dart';
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

  /// Optional initial intent action triggered on launch.
  final ChatInitialAction initialAction;

  const ChatScreen({
    super.key,
    this.startMode = ChatStartMode.normal,
    this.initialAction = ChatInitialAction.none,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatInputController _chatInputController = ChatInputController();
  bool _showSuggestions = true;

  /// Guards against calling startVoiceInput more than once per screen lifecycle.
  bool _didAutoStartVoice = false;

  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();
    // Clear any previous conversation state when starting fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chatProvider = context.read<ChatProvider>();
      _chatProvider?.clearConversation();

      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<UsageProvider>().loadForMonth(uid);
      }

      // Auto-start voice input when opened from the Home voice button.
      // We guard with _didAutoStartVoice to ensure this fires at most once
      // even if the widget rebuilds or the post-frame callback fires twice.
      if (widget.startMode == ChatStartMode.voice && !_didAutoStartVoice) {
        _didAutoStartVoice = true;
        _chatInputController.startVoiceInput();
      }

      // Dispatch initial exploration intent payload if navigated from Home quick actions
      switch (widget.initialAction) {
        case ChatInitialAction.summarizePdf:
          _handleSummarizePdfPrompt();
          break;
        case ChatInitialAction.generateImage:
          _handleCreateImage();
          break;
        case ChatInitialAction.analyzeImage:
          _handleAnalyzeImagePrompt();
          break;
        case ChatInitialAction.generatePdf:
          _handleGeneratePdf();
          break;
        case ChatInitialAction.generateCode:
          _handleGenerateCode();
          break;
        case ChatInitialAction.askQuestion:
          _chatInputController.requestFocus();
          break;
        case ChatInitialAction.none:
          break;
      }

      // Gracefully alert user if active model is not configured with an API key
      final preferredProvider =
          context.read<AiPreferencesProvider>().preferredProvider;
      final apiKeyProvider = context.read<ApiKeyProvider>();
      if (!apiKeyProvider.validProviders.contains(preferredProvider)) {
        MessageUtils.showErrorToast(
          context,
          context.l10n.noKeyForModel,
        );
      } else {
        final usageProvider = context.read<UsageProvider>();
        final summary = usageProvider.summaryFor(preferredProvider);
        if (summary != null && summary.isExceeded()) {
          MessageUtils.showErrorToast(
            context,
            context.l10n
                .chatProviderLimitReached(preferredProvider.displayName),
          );
        }
      }
    });
  }

  /// Handles dispatching a new prompt from the root chat screen.
  ///
  /// Flow:
  /// 1. Synchronously starts a new conversation via [ChatProvider.startNewConversation],
  ///    clearing previous conversation state and dispatching the AI request in the background.
  /// 2. Immediately transitions to [ChatDetailScreen] without an upfront conversation ID,
  ///    observing the in-memory optimistic user message and typing indicator instantly without UI freeze.
  Future<void> _handleSend(
    String prompt,
    List<ChatAttachment> attachments,
    AiProviderId selectedProvider,
  ) async {
    _chatProvider?.startNewConversation(
      prompt: prompt,
      selectedProvider: selectedProvider,
      attachments: attachments,
    );

    if (!mounted) return;

    AppRoutes.navigateAndReplace(
      context,
      AppRoutes.chatDetail,
      arguments: const ChatDetailArguments(),
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

  void _handleSummarizePdfPrompt() {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    _chatInputController.setPrompt(l10n.summarizePdfPrompt);
  }

  void _handleAnalyzeImagePrompt() {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    _chatInputController.setPrompt(l10n.analyzeImagePrompt);
  }

  void _handleGeneratePdf() {
    _hideSuggestions();
    final l10n = AppLocalizations.of(context)!;
    _chatInputController.setPrompt(l10n.generatePdfPrompt);
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
    final isShortHeight = context.screenHeight <= 550.0;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Minimal Custom Top Bar ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
                vertical: isShortHeight ? 2.0 : 6.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: context.isCompact ? 22.0 : 24.0,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.newConversation,
                      style: (context.isCompact
                              ? (isShortHeight
                                  ? context.textTheme.titleSmall
                                  : context.textTheme.titleMedium)
                              : context.textTheme.headlineSmall)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
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
                          isShortHeight: isShortHeight,
                          showSuggestions: _showSuggestions,
                          onSummarizePdf: _handleSummarizePdfPrompt,
                          onGeneratePdf: _handleGeneratePdf,
                          onGenerateCode: _handleGenerateCode,
                          onAnalyzeImage: _handleAnalyzeImagePrompt,
                          onCreateImage: _handleCreateImage,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Input Bar with Background Container ────────────────────────
            Consumer2<ApiKeyProvider, AiPreferencesProvider>(
              builder: (
                _,
                apiKeyProvider,
                preferences,
                __,
              ) {
                final selectedProvider = preferences.preferredProvider;
                final bool isFloatingCard = isTablet && !isShortHeight;
                final double inputMaxWidth = isTablet ? 840.0 : double.infinity;

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: inputMaxWidth),
                    margin: isFloatingCard
                        ? EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            bottom: 16.0 + context.bottomPadding,
                          )
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: context.theme.cardTheme.color ??
                          (context.isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight),
                      borderRadius: isFloatingCard
                          ? BorderRadius.circular(24)
                          : const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                      border: Border.all(
                        color: context.theme.dividerTheme.color ??
                            (context.isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider),
                        width: 1,
                      ),
                      boxShadow: isFloatingCard
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.35 : 0.08,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      14.0,
                      isShortHeight ? 6.0 : 10.0,
                      14.0,
                      isFloatingCard
                          ? 10.0
                          : (isShortHeight ? 6.0 : 10.0) +
                              context.bottomPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChatModelSelectorDropdown(
                          providers: AiProviderId.values,
                          selectedProvider: selectedProvider,
                          isEnabled: (_chatProvider?.isGenerating == true)
                              ? false
                              : true,
                          onChanged: (provider) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            preferences.setPreferredProvider(provider);

                            if (!apiKeyProvider.validProviders
                                .contains(provider)) {
                              MessageUtils.showErrorToast(
                                context,
                                context.l10n.noKeyForModel,
                              );
                            } else {
                              final usageProvider =
                                  context.read<UsageProvider>();
                              final summary =
                                  usageProvider.summaryFor(provider);
                              if (summary != null && summary.isExceeded()) {
                                MessageUtils.showErrorToast(
                                  context,
                                  context.l10n.chatProviderLimitReached(
                                      provider.displayName),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 4.0),
                        // The Input Component itself
                        Flexible(
                          child: ChatInputBar(
                            controller: _chatInputController,
                            onUserInteracted: _hideSuggestions,
                            onSend: _handleSend,
                            onEmptyInput: _showSuggestionsState,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WELCOME CONTENT
// =============================================================================

class _WelcomeContent extends StatelessWidget {
  final bool isTablet;
  final bool isShortHeight;
  final bool showSuggestions;
  final VoidCallback onSummarizePdf;
  final VoidCallback onGeneratePdf;
  final VoidCallback onGenerateCode;
  final VoidCallback onAnalyzeImage;
  final VoidCallback onCreateImage;

  const _WelcomeContent({
    required this.isTablet,
    required this.isShortHeight,
    required this.showSuggestions,
    required this.onSummarizePdf,
    required this.onGeneratePdf,
    required this.onGenerateCode,
    required this.onAnalyzeImage,
    required this.onCreateImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final logoSize = isShortHeight
        ? 64.0
        : (isTablet ? 120.0 : (context.screenWidth * 0.25).clamp(80.0, 100.0));

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: isShortHeight ? 12.0 : 20.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Logo Box
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.isDark
                  ? AppColors.primaryGradientDark
                  : AppColors.primaryGradientLight,
              boxShadow: [
                BoxShadow(
                  color: context.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: ImageView(
                image: const ImageViewData.asset(AppAssets.appLogo),
                width: logoSize * 0.85,
                height: logoSize * 0.85,
                filterQuality: FilterQuality.high,
                fit: BoxFit.contain,
              ),
            ),
          ),

          SizedBox(height: isShortHeight ? 10.0 : (isTablet ? 20.0 : 14.0)),
          Text(
            l10n.startConversation,
            style: (context.isCompact
                    ? (isShortHeight
                        ? context.textTheme.titleSmall
                        : context.textTheme.titleMedium)
                    : context.textTheme.headlineSmall)
                ?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isShortHeight ? 14.0 : (isTablet ? 32.0 : 22.0)),

          // Suggestion actions are visible only while this is a fresh chat.
          AnimatedSwitcher(
            duration: AppConstants.mediumDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: child,
              ),
            ),
            child: showSuggestions
                ? Center(
                    child: _SuggestionGrid(
                      key: const ValueKey('chat_suggestions'),
                      isTablet: isTablet,
                      isShortHeight: isShortHeight,
                      actions: [
                        _SuggestionAction(
                          icon: FontAwesomeIcons.fileLines,
                          label: l10n.summarizePdf,
                          onTap: onSummarizePdf,
                        ),
                        _SuggestionAction(
                          icon: FontAwesomeIcons.filePdf,
                          label: l10n.generatePdf,
                          onTap: onGeneratePdf,
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
                  )
                : const SizedBox.shrink(key: ValueKey('chat_suggestions_gone')),
          ),
        ],
      ),
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
  final bool isShortHeight;
  final List<_SuggestionAction> actions;

  const _SuggestionGrid({
    super.key,
    required this.isTablet,
    required this.isShortHeight,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final maxGridWidth = isTablet ? 680.0 : 420.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxGridWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final bool isMultiColumn = isTablet || availableWidth >= 480.0;
          final double itemWidth = isMultiColumn
              ? ((availableWidth - (2 * 12.0)) / 3).clamp(160.0, 240.0)
              : ((availableWidth - 10.0) / 2).clamp(130.0, 200.0);
          final double itemHeight = isShortHeight ? 44.0 : 48.0;

          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 10.0,
            runSpacing: 10.0,
            children: actions.map((action) {
              return SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _SuggestionActionCard(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                  isShortHeight: isShortHeight,
                ),
              );
            }).toList(),
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
  final bool isShortHeight;

  const _SuggestionActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isShortHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        context.isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  icon,
                  size: isShortHeight ? 15.0 : (context.isTablet ? 18.0 : 16.0),
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: (context.isCompact
                            ? (isShortHeight
                                ? context.textTheme.labelMedium
                                : context.textTheme.labelLarge)
                            : context.textTheme.titleSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
