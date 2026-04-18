import 'package:ai_voice_genie/features/chat_prompt/presentation/widgets/chat_input.dart';
import 'package:ai_voice_genie/features/chat_prompt/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import 'chat_provider.dart';

/// Active conversation screen showing full message history.
///
/// Opened in two ways:
///   1. After sending first message in ChatScreen (replaces ChatScreen)
///   2. Directly from ConversationHistoryScreen (resume conversation)
///
/// Features:
///   - Full message list with scroll-to-bottom on new message
///   - Typing indicator while AI is generating
///   - Load older messages on scroll-up
///   - Delete conversation from AppBar action
///   - Model indicator chip on each AI response
class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final String? initialTitle;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.initialTitle,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if(widget.initialTitle != null) {
      _loadConversation();
    }
    _scrollController.addListener(_onScroll);
  }

  void _loadConversation() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversation(
            uid: uid,
            conversationId: widget.conversationId,
          );
    });
  }

  /// Load older messages when scrolled to top
  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid == null) return;

      context.read<ChatProvider>().loadMoreMessages(
            uid: uid,
            conversationId: widget.conversationId,
          );
    }
  }

  /// Scroll to the bottom of the message list
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleSend(String prompt) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final validProviders = context.read<ApiKeyProvider>().validProviders;

    await context.read<ChatProvider>().sendMessage(
          uid: uid,
          prompt: prompt,
          validProviders: validProviders,
        );

    // Scroll to bottom after response
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Show error if any
    if (!mounted) return;
    final error = context.read<ChatProvider>().errorMessage;
    if (error != null) {
      context.showError(error);
      context.read<ChatProvider>().clearError();
    }
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('delete_conversation')),
        content: Text(l10n.translate('delete_conversation_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final success = await context.read<ChatProvider>().deleteConversation(uid);

    if (!mounted) return;
    if (success) {
      context.showSuccessToast(
        AppLocalizations.of(context)!.translate('conversation_deleted'),
      );
      AppRoutes.pop(context);
    } else {
      context.showError('something_went_wrong');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Consumer<ChatProvider>(
          builder: (_, chatProvider, __) {
            final titleStr = chatProvider.activeConversation?.title ??
            widget.initialTitle ?? '';

            if (titleStr.isEmpty) {
              return Shimmer.fromColors(
                baseColor: context.isDark ? Colors.grey[400]! : Colors.grey[200]!,
                highlightColor: context.isDark ? Colors.grey[700]! : Colors.grey[400]!,
                child: Container(
                  height: context.topPadding / 1.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            }

            return Text(
              titleStr.isEmpty ? l10n.translate('new_conversation') : titleStr,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleLarge,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: _handleDelete,
            tooltip: l10n.translate('delete_conversation'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message List ───────────────────────────────────────────────────
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.messages;
                if (chatProvider.isLoadingMessages && messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (messages.isEmpty) {
                  return _EmptyConversation(isTablet: isTablet);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 12,
                  ),
                  itemCount: messages.length +
                      (chatProvider.isGenerating ? 1 : 0) +
                      (chatProvider.isLoadingMessages ? 1 : 0),
                  itemBuilder: (context, index) {

                    // Load more indicator at top
                    if (index == 0 && chatProvider.isLoadingMessages) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final adjustedIndex =
                        chatProvider.isLoadingMessages ? index - 1 : index;

                    // Typing indicator at bottom
                    if (adjustedIndex == messages.length &&
                        chatProvider.isGenerating) {
                      return TypingIndicator(
                        provider: chatProvider.activeConversation?.lastProvider,
                        isTablet: isTablet,
                      );
                    }

                    if (adjustedIndex < 0 || adjustedIndex >= messages.length) {
                      return const SizedBox.shrink();
                    }

                    return MessageBubble(
                      message: messages[adjustedIndex],
                      isTablet: isTablet,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input Bar ──────────────────────────────────────────────────────
          Consumer<ChatProvider>(
            builder: (_, chatProvider, __) => ChatInputBar(
              isGenerating: chatProvider.isGenerating,
              isTablet: isTablet,
              onSend: _handleSend,
              // Voice and attach stubbed — wired in Phase 5/7
              onVoiceTap: null,
              onAttachTap: null,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyConversation extends StatelessWidget {
  final bool isTablet;
  const _EmptyConversation({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: isTablet ? 72 : 56,
              color: context.isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              l10n.translate('type_message'),
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
