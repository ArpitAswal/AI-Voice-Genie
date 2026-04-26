import 'package:ai_voice_genie/features/chat_prompt/presentation/widgets/chat_input.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
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
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Clear any previous conversation state when starting fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().clearConversation();
    });
  }

  Future<void> _handleSend(String prompt, ChatAttachment? attachment) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final validProviders = context.read<ApiKeyProvider>().validProviders;
    final chatProvider = context.read<ChatProvider>();

    // Start sending message without awaiting its completion.
    // This allows synchronous state setup inside ChatProvider to complete,
    // and then execution yields back to navigate immediately.
    chatProvider.sendMessage(
      uid: uid,
      prompt: prompt,
      validProviders: validProviders,
      capability: ConversationCapability.textChat,
      attachment: attachment,
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
                  icon: Icon(Icons.arrow_back,
                      color: context.isDark
                          ? AppColors.primaryLight
                          : AppColors.primaryDark),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.newConversation,
                      style: context.textTheme.titleLarge),
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
                      child: _WelcomeContent(isTablet: isTablet),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Input Bar with Background Container ────────────────────────
          ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: context.screenHeight * 0.4,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.cardTheme.color,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(context.isTablet ? 30 : 20)),
                  border: Border.all(
                      color: context.theme.dividerTheme.color!, width: 1),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                    vertical: context.verticalSpacing,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dummy Model Selection Pill
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.horizontalPadding / 2,
                            vertical: 4.0),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? AppColors.accentLight
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors
                                    .primaryLight, // Match the blue indicator dot
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Genie v4.0",
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: context.isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4.0),
                      // The Input Component itself
                      Flexible(
                        child: Consumer<ChatProvider>(
                          builder: (_, chatProvider, __) => ChatInputBar(
                            isGenerating: chatProvider.isGenerating,
                            isTablet: isTablet,
                            onSend: _handleSend,
                            onVoiceTap: null, // wired Phase 7
                            onAttachTap: null, // wired Phase 5/6
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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
  const _WelcomeContent({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Logo Box
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradientDark),
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
            style: context.textTheme.titleMedium?.copyWith(
                color: context.theme.dividerColor,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isTablet ? 48 : 30),

          // Quick suggestion stacked buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SuggestionActionCard(
                  icon: FontAwesomeIcons.images,
                  label: l10n.createImage,
                  onTap: () {},
                  iconColor: AppColors.primaryLight),
              _SuggestionActionCard(
                  icon: FontAwesomeIcons.laptopCode,
                  label: l10n.generateCode,
                  onTap: () {},
                  iconColor: AppColors.purpleAccent),
              _SuggestionActionCard(
                  icon: FontAwesomeIcons.filePdf,
                  label: l10n.summarizePdf,
                  onTap: () {},
                  iconColor: AppColors.tealAccent),
            ],
          ),

          SizedBox(
              height: context.bottomPadding > 0 ? context.bottomPadding : 20),
        ],
      ),
    );
  }
}

class _SuggestionActionCard extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  const _SuggestionActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: (context.isDark) ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: context.theme.dividerTheme.color ?? AppColors.grey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
