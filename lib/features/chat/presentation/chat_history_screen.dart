import 'dart:async';

import 'package:ai_voice_genie/core/utils/widget_utils.dart';
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
  final Set<String> _selectedConversationIds = <String>{};

  bool get _isSelectionMode => _selectedConversationIds.isNotEmpty;

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

  bool _areAllSelected(List<ConversationModel> conversations) {
    if (conversations.isEmpty) return false;
    return conversations.every((c) => _selectedConversationIds.contains(c.id));
  }

  void _toggleSelectAll(List<ConversationModel> conversations) {
    setState(() {
      if (_areAllSelected(conversations)) {
        _selectedConversationIds.clear();
      } else {
        _selectedConversationIds.addAll(conversations.map((c) => c.id));
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedConversationIds.length;
    if (count == 0) return;

    final isTablet = context.isTablet;
    final isDark = context.isDark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? AppColors.darkError : AppColors.lightError,
              size: isTablet ? 32 : 28,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.l10n.deleteSelectedConversations,
                style: (isTablet
                        ? context.textTheme.headlineSmall
                        : context.textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          context.l10n.deleteSelectedConfirm(count),
          style: (isTablet
                  ? context.textTheme.bodyLarge
                  : context.textTheme.bodyMedium)
              ?.copyWith(
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: context.themedOutlinedButton(
                  label: context.l10n.cancel,
                  height: isTablet ? 50.0 : 44.0,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: context.themedDangerButton(
                  label: context.l10n.delete,
                  height: isTablet ? 50.0 : 44.0,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final idsToDelete = _selectedConversationIds.toList();
    try {
      LoadingOverlay.show(
        context,
        message: context.l10n.deleteSelectedConversations,
      );

      await context.read<ChatProvider>().deleteMultipleConversations(
            uid: uid,
            conversationIds: idsToDelete,
          );

      setState(() {
        _selectedConversationIds.clear();
      });

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
          context.l10n.conversationsDeleted,
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
    final isShortHeight = context.screenHeight <= 550;
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.visibleConversations;
    final isSearching = chatProvider.searchQuery != null &&
        chatProvider.searchQuery!.isNotEmpty;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _selectedConversationIds.clear();
          });
        }
      },
      child: Scaffold(
        floatingActionButton: (_showScrollToTop && !_isSelectionMode)
            ? FloatingActionButton(
                onPressed: _scrollToTop,
                mini: true,
                backgroundColor: context.primaryColor,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _isSelectionMode ? () async {} : _refresh,
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
                      if (_isSelectionMode) ...[
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: context.isCompact ? 22.0 : 24.0,
                              ),
                              tooltip: context.l10n.cancel,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedConversationIds.clear();
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.l10n.selectedCount(
                                    _selectedConversationIds.length),
                                style: (context.isCompact
                                        ? context.textTheme.titleMedium
                                        : context.textTheme.titleLarge)
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                  minHeight: 48, minWidth: 48),
                              icon: Icon(
                                _areAllSelected(conversations)
                                    ? Icons.deselect_rounded
                                    : Icons.select_all_rounded,
                                color: context.primaryColor,
                                size: context.isCompact ? 22.0 : 26.0,
                              ),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              tooltip: _areAllSelected(conversations)
                                  ? context.l10n.deselectAll
                                  : context.l10n.selectAll,
                              onPressed: () => _toggleSelectAll(conversations),
                            ),
                            Tooltip(
                              message: context.l10n.deleteSelectedConversations,
                              child: IconButton(
                                constraints: const BoxConstraints(
                                    minHeight: 48, minWidth: 48),
                                icon: Image.asset(
                                  AppAssets.deleteIcon,
                                  color: _selectedConversationIds.isEmpty
                                      ? AppColors.lightError
                                          .withValues(alpha: 0.38)
                                      : AppColors.lightError,
                                  height: context.isCompact ? 22.0 : 26.0,
                                  width: context.isCompact ? 22.0 : 26.0,
                                ),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _selectedConversationIds.isEmpty
                                    ? null
                                    : _confirmDeleteSelected,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.conversationHistory,
                                    style: (context.isCompact
                                            ? (isShortHeight
                                                ? context
                                                    .textTheme.headlineSmall
                                                : context
                                                    .textTheme.headlineMedium)
                                            : context.textTheme.headlineLarge)
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.l10n.historySubtitle,
                                    style: (context.isCompact
                                            ? (isShortHeight
                                                ? context.textTheme.bodySmall
                                                : context.textTheme.bodyMedium)
                                            : context.textTheme.bodyLarge)
                                        ?.copyWith(
                                      color: context.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (conversations.isNotEmpty || isSearching) ...[
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => AppRoutes.navigateTo(
                                    context, AppRoutes.chat),
                                icon: FaIcon(
                                  FontAwesomeIcons.solidMessage,
                                  size: isShortHeight ? 16.0 : 21.0,
                                ),
                                tooltip: context.l10n.newConversation,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  backgroundColor: context.primaryColor
                                      .withValues(alpha: 0.12),
                                  foregroundColor: context.primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Search Container (Fixed)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical:
                                isShortHeight ? 8.0 : (isTablet ? 20.0 : 16.0),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  context.isExpanded ? 640.0 : double.infinity,
                            ),
                            child: context.themedTextField(
                                enabled:
                                    !chatProvider.isLoadingMoreConversations &&
                                            conversations.isNotEmpty ||
                                        isSearching,
                                onChanged: _onSearchChanged,
                                hint: context.l10n.searchPlaceholder,
                                controller: _searchController,
                                suffixIcon: IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    icon: Icon(Icons.clear_rounded,
                                        color: context.colorScheme.tertiary))),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (conversations.isEmpty &&
                          isSearching &&
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
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(context.horizontalPadding),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: isShortHeight
                                          ? 130.0
                                          : (isTablet
                                              ? 240.0
                                              : (context.screenWidth * 0.55)
                                                  .clamp(150.0, 200.0)),
                                      height: isShortHeight
                                          ? 130.0
                                          : (isTablet
                                              ? 240.0
                                              : (context.screenWidth * 0.55)
                                                  .clamp(150.0, 200.0)),
                                      child: Lottie.asset(
                                        AppAssets.emptySearch,
                                        reverse: true,
                                        repeat: true,
                                        fit: BoxFit.contain,
                                        imageProviderFactory: (lottieImage) {
                                          return const AssetImage(
                                              AppAssets.appLogo);
                                        },
                                      ),
                                    ),
                                    Text(
                                      context.l10n.noConversationFound(
                                          chatProvider.searchQuery ?? ''),
                                      style: (context.isCompact
                                              ? context.textTheme.titleMedium
                                              : context.textTheme.titleLarge)
                                          ?.copyWith(
                                        color: context.colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._buildGroupedLists(conversations, context),
                      if (chatProvider.isLoadingMoreConversations &&
                          conversations.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: context.verticalSpacing),
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
      ),
    );
  }

  int _resolveCrossAxisCount(BuildContext context) {
    if (context.isExpanded && context.screenWidth >= 1050.0) {
      return 3;
    } else if (context.isTablet) {
      return 2;
    }
    return 1;
  }

  List<Widget> _buildGroupedLists(
      List<ConversationModel> conversations, BuildContext context) {
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
      slivers.add(_buildSectionHeader(context.l10n.today, context));
      slivers.add(_buildListSliver(today));
    }

    if (yesterday.isNotEmpty) {
      slivers.add(_buildSectionHeader(context.l10n.yesterday, context));
      slivers.add(_buildListSliver(yesterday));
    }

    if (older.isNotEmpty) {
      slivers.add(_buildSectionHeader(context.l10n.older, context));
      slivers.add(_buildListSliver(older));
    }

    slivers.add(const SliverToBoxAdapter(
        child: SizedBox(height: 32))); // Bottom padding

    return slivers;
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    final isShortHeight = context.screenHeight <= 550.0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.horizontalPadding,
          right: context.horizontalPadding,
          top: 0.0,
          bottom: 10.0,
        ),
        child: Text(
          title,
          style: (context.isCompact
                  ? (isShortHeight
                      ? context.textTheme.titleSmall
                      : context.textTheme.titleMedium)
                  : context.textTheme.titleLarge)
              ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.tertiary),
        ),
      ),
    );
  }

  Future<void> _handleConversationTap(
    ConversationModel conversation,
    bool isSelected,
  ) async {
    if (_isSelectionMode) {
      setState(() {
        if (isSelected) {
          _selectedConversationIds.remove(conversation.id);
        } else {
          _selectedConversationIds.add(conversation.id);
        }
      });
      return;
    }
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
  }

  Widget _buildListSliver(List<ConversationModel> items) {
    final crossAxisCount = _resolveCrossAxisCount(context);

    if (crossAxisCount > 1) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            mainAxisExtent: (155.0).clamp(120.0, 180.0),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final conversation = items[index];
              final isSelected =
                  _selectedConversationIds.contains(conversation.id);
              return CustomConversationCard(
                conversation: conversation,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _selectedConversationIds.add(conversation.id);
                    });
                  }
                },
                onTap: () => _handleConversationTap(conversation, isSelected),
              );
            },
            childCount: items.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final conversation = items[index];
            final isSelected =
                _selectedConversationIds.contains(conversation.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomConversationCard(
                conversation: conversation,
                isSelectionMode: _isSelectionMode,
                isSelected: isSelected,
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _selectedConversationIds.add(conversation.id);
                    });
                  }
                },
                onTap: () => _handleConversationTap(conversation, isSelected),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildShimmerItem() {
    final isTablet = context.isTablet;
    final badgeSize = isTablet ? 32.0 : 24.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DynamicShimmer(
                    height: isTablet ? 22.0 : 18.0,
                    width: (context.screenWidth * 0.4).clamp(100.0, 180.0),
                    borderRadius: 6,
                  ),
                  const DynamicShimmer(
                    height: 16,
                    width: 20,
                    borderRadius: 4,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DynamicShimmer(
                height: isTablet ? 16.0 : 14.0,
                width: double.infinity,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              DynamicShimmer(
                height: isTablet ? 16.0 : 14.0,
                width: 240,
                borderRadius: 4,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DynamicShimmer(
                height: badgeSize,
                width: badgeSize,
                borderRadius: badgeSize * 0.35,
              ),
              const SizedBox(width: 8),
              DynamicShimmer(
                height: isTablet ? 14.0 : 12.0,
                width: 180,
                borderRadius: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    final crossAxisCount = _resolveCrossAxisCount(context);

    if (crossAxisCount > 1) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            mainAxisExtent: (155.0).clamp(120.0, 180.0),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildShimmerItem(),
            childCount: (context.isExpanded ? 12 : 8),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildShimmerItem(),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}
