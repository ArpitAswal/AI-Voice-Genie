import 'dart:ui';
import 'package:ai_voice_genie/features/chat/presentation/widgets/chat_input.dart';
import 'package:ai_voice_genie/shared/widgets/chat_model_selector_dropdown.dart';
import 'package:ai_voice_genie/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/preferences/ai_preferences_provider.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../shared/model/image_model.dart';
import '../../../shared/widgets/image_view.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../../usage/presentation/usage_provider.dart';
import '../../voice_speech/presentation/voice_speech_provider.dart';
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
  VoiceProvider? _voiceProvider;
  int _lastMessageCount = 0;
  bool _wasGenerating = false;
  bool _isManualDeleting = false;
  bool _isFetchingOldMessages = false;
  double _previousMaxScrollExtent = 0;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _chatProvider = context.read<ChatProvider>();
    _voiceProvider = context.read<VoiceProvider>();
    _lastMessageCount = _chatProvider!.messages.length;
    _wasGenerating = _chatProvider!.isGenerating;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chatProvider!.messages.isNotEmpty) {
        _scrollToBottom(animated: false);
      }
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<UsageProvider>().loadForMonth(uid);
      }
    });
    _chatProvider!.addListener(_onChatProviderChange);

    if (widget.initialTitle != null) {
      _loadConversation();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _chatProvider == null) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final distanceFromBottom = maxScroll - currentOffset;

    // Show floating button when user is scrolled away from the bottom (> 100px)
    final shouldShowFab = distanceFromBottom > 100;
    if (shouldShowFab != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShowFab;
      });
    }

    if (_scrollController.position.pixels <= 100) {
      _chatProvider!.loadOlderMessages();
    }
  }

  void _scrollToBottomAnimated() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Called on every character/token revealed during typewriter animation.
  /// Keeps the live response in view if the user is following at the bottom,
  /// or automatically shows the scroll-to-bottom FAB if they scrolled away.
  void _onTypewriterTick() {
    if (!mounted || !_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      final distanceFromBottom = maxScroll - currentOffset;

      final isUserDragging =
          _scrollController.position.isScrollingNotifier.value;

      if (!isUserDragging && distanceFromBottom <= 140) {
        _scrollController.jumpTo(maxScroll);
        if (_showScrollToBottom) {
          setState(() {
            _showScrollToBottom = false;
          });
        }
      } else {
        final shouldShowFab = distanceFromBottom > 100;
        if (shouldShowFab != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = shouldShowFab;
          });
        }
      }
    });
  }

  void _onChatProviderChange() {
    if (_chatProvider == null || !mounted) return;

    final currentMessageCount = _chatProvider!.messages.length;
    final currentGenerating = _chatProvider!.isGenerating;
    final currentLoading = _chatProvider!.isLoadingMessages;

    // Safely check if the conversation was completely deleted remotely
    final uid = context.read<AuthProvider>().currentUser?.uid;
    // Delegate to ChatProvider to check deletion state — the widget must not
    // read from LocalChatStore directly (MVVM: data access via provider only).
    // Guard: only check if uid is known and we are not in a manual delete flow.
    if (uid != null && !_isManualDeleting) {
      final isDeleted = _chatProvider!
          .isActiveConversationDeleted(uid, widget.conversationId);
      if (isDeleted && !currentLoading && !currentGenerating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) AppRoutes.pop(context);
        });
        return;
      }
    }

    final currentLoadingMore = _chatProvider!.isLoadingMoreMessages;
    bool justFinishedFetchingOldMessages = false;

    if (currentLoadingMore && !_isFetchingOldMessages) {
      _isFetchingOldMessages = true;
      if (_scrollController.hasClients) {
        _previousMaxScrollExtent = _scrollController.position.maxScrollExtent;
      }
    } else if (!currentLoadingMore && _isFetchingOldMessages) {
      _isFetchingOldMessages = false;
      justFinishedFetchingOldMessages = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final extentIncrease = _scrollController.position.maxScrollExtent -
            _previousMaxScrollExtent;
        if (extentIncrease > 0) {
          _scrollController.jumpTo(_scrollController.offset + extentIncrease);
        }
      });
    }

    bool shouldScroll = false;

    final isLastMessageFromUser = _chatProvider!.messages.isNotEmpty &&
        _chatProvider!.messages.last.isUser;

    // Only scroll to bottom for new messages if the user sent it, or if they are already near the bottom
    if (currentMessageCount > _lastMessageCount &&
        !_isFetchingOldMessages &&
        !currentLoadingMore &&
        !justFinishedFetchingOldMessages) {
      if (isLastMessageFromUser) {
        shouldScroll = true;
      } else {
        final isNearBottom = !_scrollController.hasClients ||
            (_scrollController.position.maxScrollExtent -
                    _scrollController.offset <=
                80.0);
        if (isNearBottom) {
          shouldScroll = true;
        }
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversation(
            conversationId: widget.conversationId,
          );
    });
  }

  /// Scroll to the bottom of the message list (non-recursive, single invocation)
  void _scrollToBottom({bool animated = true}) {
    if (!mounted || !_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final distance = target - offset;

    if (distance <= 10.0) return;

    if (!animated || distance > 2000) {
      _scrollController.jumpTo(target);
      return;
    }

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleSend(
    String prompt,
    List<ChatAttachment> attachments,
    AiProviderId selectedProvider,
  ) async {
    context.read<ChatProvider>().sendMessage(
          prompt: prompt,
          selectedProvider: selectedProvider,
          attachments: attachments,
        );
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(l10n.deleteConversation),
        content: Text(l10n.deleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: context.textTheme.headlineSmall!.color),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: TextStyle(
                  color: context.isDark
                      ? AppColors.darkError
                      : AppColors.lightError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isManualDeleting = true;
    });

    LoadingOverlay.show(context, message: context.l10n.deleting);

    final success = await context.read<ChatProvider>().deleteConversation(
          conversationId: widget.conversationId,
        );

    if (!mounted) return;
    LoadingOverlay.hide();
    if (success) {
      bool isOffline = false;
      try {
        final connectivity = await Connectivity().checkConnectivity();
        isOffline = connectivity.contains(ConnectivityResult.none);
      } catch (e) {
        debugPrint('Connectivity check failed: $e');
      }

      if (!mounted) return;

      if (isOffline) {
        context.showSuccessToast(
          AppLocalizations.of(context)!.offlineDeleteQueued,
        );
      } else {
        context.showSuccessToast(
          context.l10n.conversationDeleted,
        );
      }
      // Pop with `true` so the history screen knows to reload its list.
      AppRoutes.pop<bool>(context, true);
    } else {
      setState(() {
        _isManualDeleting = false;
      });
      context.showError('something_went_wrong');
    }
  }

  Future<void> _handleEditTitle() async {
    final chatProvider = context.read<ChatProvider>();
    final currentTitle =
        chatProvider.activeConversation?.title ?? widget.initialTitle ?? '';

    final newTitle = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangeTitleDialog(initialTitle: currentTitle),
    );

    if (newTitle == null ||
        newTitle.isEmpty ||
        newTitle == currentTitle ||
        !mounted) {
      return;
    }

    LoadingOverlay.show(context, message: context.l10n.renaming);
    try {
      await chatProvider.updateConversationTitle(newTitle);
      if (mounted) {
        context.showSuccessToast(
          context.l10n.conversationNameUpdate,
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
    _chatProvider?.closeActiveConversation();
    _voiceProvider?.stopSpeaking();
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
              titleStr.isEmpty ? l10n.newConversation : titleStr,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: context.textTheme.headlineSmall,
            );
          },
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
        actions: [
          IconButton(
            onPressed: _handleEditTitle,
            icon: const Icon(
              Icons.edit,
              color: AppColors.info,
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    final messages = chatProvider.messages;
                    if (chatProvider.isLoadingMessages && messages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }

                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        final metrics = notification.metrics;
                        final distanceFromBottom =
                            metrics.maxScrollExtent - metrics.pixels;
                        final shouldShowFab = distanceFromBottom > 100;
                        if (shouldShowFab != _showScrollToBottom) {
                          setState(() {
                            _showScrollToBottom = shouldShowFab;
                          });
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16 : 12,
                          horizontal: isTablet ? 16 : 12,
                        ),
                        itemCount: messages.length +
                            (chatProvider.isGenerating ? 1 : 0) +
                            (chatProvider.isLoadingMoreMessages ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Load more indicator at top
                          if (index == 0 && chatProvider.isLoadingMoreMessages) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }

                          final adjustedIndex = chatProvider.isLoadingMoreMessages
                              ? index - 1
                              : index;

                          // Typing indicator at bottom
                          if (adjustedIndex == messages.length &&
                              chatProvider.isGenerating) {
                            return const TypingIndicator();
                          }

                          if (adjustedIndex < 0 ||
                              adjustedIndex >= messages.length) {
                            return const SizedBox.shrink();
                          }

                          return MessageBubble(
                            message: messages[adjustedIndex],
                            isTablet: isTablet,
                            onTypewriterTick: _onTypewriterTick,
                          );
                        },
                      ),
                    );
                  },
                ),
                // Glass-style Scroll to Bottom Floating Action Button
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildScrollToBottomButton(context),
                  ),
                ),
              ],
            ),
          ),
          // ── Input Bar ──────────────────────────────────────────────────────
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
                      top: Radius.circular(context.isTablet ? 30 : 20)),
                  border: Border.all(
                      color: context.theme.dividerTheme.color!, width: 1),
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

                        final apiKeyProvider = context.read<ApiKeyProvider>();
                        if (!apiKeyProvider.validProviders.contains(provider)) {
                          MessageUtils.showErrorToast(
                            context,
                            context.l10n.noKeyForModel,
                          );
                        } else {
                          final usageProvider = context.read<UsageProvider>();
                          final summary = usageProvider.summaryFor(provider);
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
                    Flexible(
                      child: ChatInputBar(
                        onSend: _handleSend,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Glass-style floating action button displayed at bottom-center when user is scrolled up.
  Widget _buildScrollToBottomButton(BuildContext context) {
    return AnimatedScale(
      scale: _showScrollToBottom ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _showScrollToBottom ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: IgnorePointer(
          ignoring: !_showScrollToBottom,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _scrollToBottomAnimated,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.07),
                      border: Border.all(
                        color: context.isDark
                            ? Colors.white.withValues(alpha: 0.20)
                            : Colors.black.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: context.isDark ? 0.35 : 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.90)
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
