import 'package:ai_voice_genie/features/chat_prompt/presentation/widgets/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
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

  Future<void> _handleSend(String prompt) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final validProviders = context.read<ApiKeyProvider>().validProviders;

    // ChatProvider.sendMessage creates the conversation and first message
    final success = await context.read<ChatProvider>().sendMessage(
          uid: uid,
          prompt: prompt,
          validProviders: validProviders,
          capability: ConversationCapability.textChat,
        );

    if (!mounted) return;

    if (success) {
      final conversationId =
          context.read<ChatProvider>().activeConversation?.id;

      if (conversationId != null) {
        // Navigate to ChatDetailScreen — replaces this screen so back goes to Home
        AppRoutes.navigateAndReplace(
          context,
          AppRoutes.chatDetail,
          arguments: ChatDetailArguments(
            conversationId: conversationId,
          ),
        );
      }
    } else {
      final error = context.read<ChatProvider>().errorMessage;
      if (error != null) {
        context.showError(error);
        context.read<ChatProvider>().clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('new_conversation')),
      ),
      body: Column(
        children: [
          // ── Welcome content ────────────────────────────────────────────────
          Expanded(
            child: _WelcomeContent(isTablet: isTablet),
          ),

          // ── Input Bar ──────────────────────────────────────────────────────
          Consumer<ChatProvider>(
            builder: (_, chatProvider, __) => ChatInputBar(
              isGenerating: chatProvider.isGenerating,
              isTablet: isTablet,
              onSend: _handleSend,
              onVoiceTap: null, // wired Phase 7
              onAttachTap: null, // wired Phase 5/6
            ),
          ),
        ],
      ),
    );
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

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI pulse icon
            Container(
              width: isTablet ? 80 : 64,
              height: isTablet ? 80 : 64,
              decoration: BoxDecoration(
                gradient: context.isDark
                    ? AppColors.primaryGradientDark
                    : AppColors.primaryGradientLight,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: isTablet ? 36 : 28,
                color: AppColors.white,
              ),
            ),

            SizedBox(height: isTablet ? 24 : 20),

            Text(
              l10n.appName,
              style: context.textTheme.headlineLarge?.copyWith(
                fontSize: isTablet ? 26 : 22,
              ),
            ),

            SizedBox(height: isTablet ? 10 : 8),

            Text(
              l10n.appTagline,
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: isTablet ? 40 : 32),

            // Quick suggestion chips
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(label: 'Explain a concept'),
                _SuggestionChip(label: 'Write some code'),
                _SuggestionChip(label: 'Summarise text'),
                _SuggestionChip(label: 'Translate something'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Tapping a suggestion chip pre-fills the input — wired in Phase 4 polish
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
