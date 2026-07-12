import 'package:ai_voice_genie/features/chat/presentation/widgets/chat_input.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/chat_model_selector_dropdown.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/preferences/ai_preferences_provider.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../shared/model/image_model.dart';
import '../../../shared/widgets/image_view.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../domain/chat_attachment.dart';
import 'chat_provider.dart';
import 'widgets/change_title_dialog.dart';

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
  ChatProvider? _chatProvider;
  int _lastMessageCount = 0;
  bool _wasGenerating = false;

  @override
  void initState() {
    super.initState();

    _chatProvider = context.read<ChatProvider>();
    _lastMessageCount = _chatProvider!.messages.length;
    _wasGenerating = _chatProvider!.isGenerating;

    if (_chatProvider!.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(animated: false);
      });
    }
    _chatProvider!.addListener(_onChatProviderChange);

    if (widget.initialTitle != null) {
      _loadConversation();
    }
  }

  void _onChatProviderChange() {
    if (_chatProvider == null || !mounted) return;

    final currentMessageCount = _chatProvider!.messages.length;
    final currentGenerating = _chatProvider!.isGenerating;

    bool shouldScroll = false;

    if (currentMessageCount > _lastMessageCount) {
      shouldScroll = true;
    }
    if (currentGenerating && !_wasGenerating) {
      shouldScroll = true;
    }

    _lastMessageCount = currentMessageCount;
    _wasGenerating = currentGenerating;

    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(animated: true);
      });
    }
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

  /// Scroll to the bottom of the message list
  void _scrollToBottom({bool animated = true}) async {
    if (!_scrollController.hasClients) return;

    // Short delay gives the layout engine time to fully calculate
    // the height of very large MessageBubbles before we record 'maxScrollExtent'.
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || !_scrollController.hasClients) return;

    _doScroll(animated: animated);
  }

  void _doScroll({required bool animated}) {
    if (!mounted || !_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final distance = target - offset;

    // Keep scrolling if we are not at the very bottom
    if (distance <= 10.0) return;

    // If we have to travel a huge distance (e.g., initial load of a large chat),
    // jump instantly to avoid rendering hundreds of items and freezing the main thread.
    if (!animated || distance > 2000) {
      _scrollController.jumpTo(target);
      // After jumping, maxScrollExtent might increase because new items were lazily built.
      // Schedule a trailing jump.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          if (_scrollController.position.maxScrollExtent >
              _scrollController.offset + 10.0) {
            _doScroll(animated: false);
          }
        }
      });
      return;
    }

    _scrollController
        .animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    )
        .then((_) {
      if (mounted && _scrollController.hasClients) {
        // As lazy ListView items build during animation, maxScrollExtent increases.
        // We catch this change and run a trailing scroll if needed.
        if (_scrollController.position.maxScrollExtent >
            _scrollController.offset + 10.0) {
          _doScroll(animated: true);
        }
      }
    });
  }

  Future<void> _handleSend(
      String prompt, List<ChatAttachment> attachments) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final apiKeyProvider = context.read<ApiKeyProvider>();
    final validProviders = apiKeyProvider.validProviders;
    final selectedProvider = _currentSelectedProvider(
      validProviders,
      context.read<AiPreferencesProvider>().preferredProvider,
    );

    await context.read<ChatProvider>().sendMessage(
          uid: uid,
          prompt: prompt,
          selectedProvider: selectedProvider,
          attachments: attachments,
        );

    // Error handling
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.translate('cancel'),
              style: TextStyle(color: context.textTheme.headlineSmall!.color),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: AppColors.lightError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    LoadingOverlay.show(context, message: context.l10n.deleting);

    final success = await context.read<ChatProvider>().deleteConversation(
          uid: uid,
          conversationId: widget.conversationId,
        );

    if (!mounted) return;
    LoadingOverlay.hide();
    if (success) {
      context.showSuccessToast(
        AppLocalizations.of(context)!.translate('conversation_deleted'),
      );
      // Pop with `true` so the history screen knows to reload its list.
      AppRoutes.pop<bool>(context, true);
    } else {
      context.showError('something_went_wrong');
    }
  }

  Future<void> _handleEditTitle() async {
    final chatProvider = context.read<ChatProvider>();
    final currentTitle = chatProvider.activeConversation?.title ?? widget.initialTitle ?? '';

    final newTitle = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangeTitleDialog(initialTitle: currentTitle),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == currentTitle || !mounted) {
      return;
    }

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    LoadingOverlay.show(context, message: AppLocalizations.of(context)!.translate('renaming'));
    try {
      await chatProvider.updateConversationTitle(newTitle, uid);
      if (mounted) {
        context.showSuccessToast(
          AppLocalizations.of(context)!.translate('title_updated_successfully'),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError('something_went_wrong');
      }
    } finally {
      LoadingOverlay.hide();
    }
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatProviderChange);
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
                widget.initialTitle ??
                '';

            if (titleStr.isEmpty) {
              return Shimmer.fromColors(
                baseColor:
                    context.isDark ? Colors.grey[400]! : Colors.grey[200]!,
                highlightColor:
                    context.isDark ? Colors.grey[700]! : Colors.grey[400]!,
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
              maxLines: 1,
              style: context.textTheme.titleLarge,
            );
          },
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
        actions: [
          IconButton(
            onPressed: _handleEditTitle,
            icon: Icon(
              Icons.edit,
              color: context.isDark ? AppColors.primaryDark : AppColors.primaryLight,
            ),
          ),
          GestureDetector(
            onTap: _handleDelete,
            child: const ImageView(
              image: ImageViewData.asset(AppAssets.deleteIcon),
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
      bottomSheet:
          // ── Input Bar ──────────────────────────────────────────────────────
          SafeArea(
        bottom: false,
        child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: context.screenHeight * 0.4,
            ),
            child:
                Consumer3<ApiKeyProvider, ChatProvider, AiPreferencesProvider>(
              builder: (
                _,
                apiKeyProvider,
                chatProvider,
                preferences,
                __,
              ) {
                final validProviders = apiKeyProvider.validProviders;
                final selectedProvider =
                    ChatModelSelection.resolveSelectedProvider(
                  availableProviders: validProviders,
                  selectedProvider: preferences.preferredProvider,
                  preferredProvider: preferences.preferredProvider,
                );

                return Container(
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
                        ChatModelSelectorDropdown(
                          providers: validProviders,
                          selectedProvider: selectedProvider,
                          isEnabled: !chatProvider.isGenerating,
                          onChanged: (provider) {
                            preferences.setPreferredProvider(provider);
                          },
                        ),
                        const SizedBox(height: 4.0),
                        // The Input Component itself
                        Flexible(
                          child: ChatInputBar(
                            isGenerating: chatProvider.isGenerating,
                            isTablet: isTablet,
                            onSend: _handleSend,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final messages = chatProvider.messages;
          if (chatProvider.isLoadingMessages && messages.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 16 : 12,
              horizontal: isTablet ? 16 : 12,
            ).copyWith(bottom: context.screenHeight * 0.2),
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
                return const TypingIndicator();
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
    );
  }

  AiProviderId _currentSelectedProvider(
    List<AiProviderId> validProviders,
    AiProviderId preferredProvider,
  ) {
    return ChatModelSelection.resolveSelectedProvider(
      availableProviders: validProviders,
      selectedProvider: preferredProvider,
      preferredProvider: preferredProvider,
    ) ??
        preferredProvider;
  }
}
