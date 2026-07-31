import 'dart:async';

import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../presentation/chat_provider.dart';
import '../domain/conversation_model.dart';
import '../../../shared/widgets/dynamic_shimmer.dart';

import 'widgets/custom_conversation_card.dart';
import 'widgets/empty_history_view.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialConversations();
    });
  }

  void _onScroll() {
    if (!mounted) return;

    // Pagination trigger
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<ChatProvider>().loadMoreConversations(uid);
      }
    }

    // FAB visibility
    if (_scrollController.offset > 300 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 300 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadInitialConversations({bool wait = false}) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    // No artificial delay — Hive local data renders instantly
    if (uid == null) {
      return;
    }

    try {
      if (wait) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
      await context
          .read<ChatProvider>()
          .loadInitialConversations(uid, query: _searchController.text);
    } catch (e) {
      if (mounted) {
        context.showError('something_went_wrong');
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null && mounted) {
        context
            .read<ChatProvider>()
            .loadInitialConversations(uid, query: query);
      }
    });
  }

  Future<void> _refresh() async {
    await _loadInitialConversations(wait: true);
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.lightError, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.l10n.deleteAllConversations,
                style: context.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          context.l10n.deleteAllConfirmMessage,
          style: context.textTheme.bodyMedium?.copyWith(
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
        actions: [
          Row(
            children: [
              Expanded(
                child: context.themedOutlinedButton(
                  label: context.l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: context.themedDangerButton(
                  label: context.l10n.delete,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteAll();
    }
  }

  Future<void> _deleteAll() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    // Local-first delete: conversations disappear immediately from the UI.
    // No loading overlay is needed — Firestore deletion runs in the background.
    try {
      LoadingOverlay.show(context,
          message: context.l10n.deleteAllConversations);
      // Await the delayed period, then properly await the delete operation.
      // Previously the delete was fire-and-forget which allowed the UI to
      // refresh before the Hive soft-delete and outbox enqueue had finished.
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await context.read<ChatProvider>().deleteAllConversations(uid);
      // Reload from Hive — list will be empty since all are soft-deleted
      await _loadInitialConversations();

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
          AppLocalizations.of(context)!.translate('conversation_deleted'),
        );
      }
    } catch (e) {
      if (mounted) context.showError('something_went_wrong');
    } finally {
      LoadingOverlay.hide();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.visibleConversations;
    final isSearching = chatProvider.searchQuery != null &&
        chatProvider.searchQuery!.isNotEmpty;

    return Scaffold(
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              mini: true,
              backgroundColor: context.primaryColor,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              // Fixed Header Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(context.l10n.conversationHistory,
                              style: Theme.of(context).textTheme.displayMedium),
                        ),
                        if (conversations.isNotEmpty || isSearching) ...[
                          SizedBox(
                            height: 28,
                            child: IconButton(
                              onPressed: () =>
                                  AppRoutes.navigateTo(context, AppRoutes.chat),
                              icon: const FaIcon(FontAwesomeIcons.solidMessage),
                              tooltip: context.l10n.newConversation,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 0.0),
                              color: AppColors.info,
                            ),
                          ),
                          GestureDetector(
                            onTap: _confirmDeleteAll,
                            child: const ImageView(
                              image: ImageViewData.asset(
                                AppAssets.deleteIcon,
                              ),
                              width: 28,
                              height: 28,
                            ),
                          )
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.historySubtitle,
                        style: context.textTheme.bodyLarge),

                    // Search Container (Fixed)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: isTablet ? 24 : 16),
                      child: context.themedTextField(
                        enabled: !chatProvider.isLoadingMoreConversations &&
                                conversations.isNotEmpty ||
                            isSearching,
                        onChanged: _onSearchChanged,
                        hint: context.l10n.searchPlaceholder,
                        controller: _searchController,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (conversations.isEmpty &&
                        !isSearching &&
                        chatProvider.isLoadingMoreConversations)
                      _buildShimmerList()
                    else if (conversations.isEmpty && !isSearching)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyHistoryView(isTablet: isTablet),
                      )
                    else if (conversations.isEmpty && isSearching)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: context.screenWidth * 0.8,
                              height: context.screenWidth * 0.8,
                              child: Lottie.asset(
                                AppAssets.emptySearch,
                                reverse: true,
                                repeat: true,
                                fit: BoxFit.cover,
                                imageProviderFactory: (lottieImage) {
                                  return const AssetImage(AppAssets.appLogo);
                                },
                              ),
                            ),
                            Text(
                              context.l10n.noConversationFound(
                                  chatProvider.searchQuery ?? ''),
                              style: context.textTheme.bodyLarge,
                            )
                          ],
                        ),
                      )
                    else
                      ..._buildGroupedLists(conversations),
                    if (chatProvider.isLoadingMoreConversations &&
                        conversations.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.only(bottom: context.verticalSpacing),
                          child: const Center(
                              child: CircularProgressIndicator.adaptive()),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedLists(List<ConversationModel> conversations) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr =
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    final today = <ConversationModel>[];
    final yesterday = <ConversationModel>[];
    final older = <ConversationModel>[];

    for (final c in conversations) {
      final date = c.lastMessageAt ?? c.createdAt ?? now;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      if (dateStr == todayStr) {
        today.add(c);
      } else if (dateStr == yesterdayStr) {
        yesterday.add(c);
      } else {
        older.add(c);
      }
    }

    final slivers = <Widget>[];

    if (today.isNotEmpty) {
      slivers.add(_buildSectionHeader(context.l10n.today));
      slivers.add(_buildListSliver(today));
    }

    if (yesterday.isNotEmpty) {
      // if (today.isNotEmpty) {
      //   slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      // }
      slivers.add(_buildSectionHeader(context.l10n.yesterday));
      slivers.add(_buildListSliver(yesterday));
    }

    if (older.isNotEmpty) {
      // if (today.isNotEmpty || yesterday.isNotEmpty) {
      //   slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      // }
      slivers.add(_buildSectionHeader(context.l10n.older));
      slivers.add(_buildListSliver(older));
    }

    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(height: 32))); // Bottom padding

    return slivers;
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding, vertical: 8),
        child: Text(title, style: context.textTheme.bodyLarge),
      ),
    );
  }

  Widget _buildListSliver(List<ConversationModel> items) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final conversation = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomConversationCard(
                conversation: conversation,
                onTap: () async {
                  final result = await AppRoutes.navigateTo(
                    context,
                    AppRoutes.chatDetail,
                    arguments: ChatDetailArguments(
                      conversationId: conversation.id,
                      initialTitle: conversation.title,
                    ),
                  );
                  // Reload list when a conversation was deleted inside the detail screen
                  if (result == true && mounted) {
                    _loadInitialConversations();
                  }
                },
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      context.isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DynamicShimmer(
                            height: 24,
                            width: (MediaQuery.of(context).size.width / 2),
                            borderRadius: 6),
                        const DynamicShimmer(
                          height: 18,
                          width: 24,
                          borderRadius: 8,
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const DynamicShimmer(
                        height: 16, width: double.infinity, borderRadius: 4),
                    const SizedBox(height: 6),
                    const DynamicShimmer(
                        height: 16, width: 200, borderRadius: 4),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        DynamicShimmer(height: 18, width: 80, borderRadius: 6),
                        SizedBox(width: 12),
                        DynamicShimmer(height: 18, width: 120, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: 6,
        ),
      ),
    );
  }
}
