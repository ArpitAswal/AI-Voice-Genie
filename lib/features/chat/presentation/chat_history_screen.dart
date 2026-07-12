import 'package:ai_voice_genie/core/constants/app_constants.dart';
import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import 'chat_provider.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../../../shared/widgets/dynamic_shimmer.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final ChatRepository _repository = ChatRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  late final ChatProvider _chatProvider;

  List<ConversationModel> _allConversations = [];
  List<ConversationModel> _filteredConversations = [];

  bool _isLoading = true;
  String _searchQuery = '';
  int _lastHistoryVersion = -1;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _lastHistoryVersion = _chatProvider.conversationHistoryVersion;
    _chatProvider.addListener(_onChatProviderChanged);
    _loadConversations();
  }

  void _onChatProviderChanged() {
    if (!mounted) return;

    final currentVersion = _chatProvider.conversationHistoryVersion;
    if (currentVersion == _lastHistoryVersion) return;

    _lastHistoryVersion = currentVersion;
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final uid = context.read<AuthProvider>().currentUser?.uid;
    await Future.delayed(const Duration(seconds: 1), () {});
    if (uid == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final conversations = await _repository.getConversations(uid);
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _filteredConversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showError('something_went_wrong');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConversations = _allConversations;
      } else {
        _filteredConversations = _allConversations.where((c) {
          return c.title.toLowerCase().contains(query.toLowerCase()) ||
              c.lastMessage.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _refresh() async {
    await _loadConversations();
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            context.isDark ? AppColors.cardDark : AppColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.lightError, size: 28),
            const SizedBox(width: 12),
            Expanded(
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
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
    LoadingOverlay.show(context, message: context.l10n.deleteAllConversations);
    try {
      await _repository.deleteAllConversations(uid);
      await _loadConversations();
    } catch (e) {
      if (mounted) context.showError('something_went_wrong');
    } finally {
      LoadingOverlay.hide();
    }
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onChatProviderChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
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
                            Text(
                              context.l10n.conversationHistory,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                      color: context.isDark
                                          ? AppColors.primaryLight
                                          : AppColors.primaryDark),
                            ),
                            if (_allConversations.isNotEmpty && !_isLoading)
                              GestureDetector(
                                onTap: _confirmDeleteAll,
                                child: const ImageView(
                                  image: ImageViewData.asset(
                                    AppAssets.deleteIcon,
                                  ),
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.historySubtitle,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),

                        // Search Container (Fixed)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 24 : 16),
                          child: context.themedTextField(
                            enabled: !_isLoading,
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
                      slivers: [
                        if (_isLoading)
                          _buildShimmerList()
                        else if (_filteredConversations.isEmpty &&
                            _searchQuery.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyHistory(isTablet: isTablet),
                          )
                        else if (_filteredConversations.isEmpty &&
                            _searchQuery.isNotEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                context.l10n.noResultsFound,
                                style: context.textTheme.bodyLarge,
                              ),
                            ),
                          )
                        else
                          ..._buildGroupedLists(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedLists() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr =
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    final today = <ConversationModel>[];
    final yesterday = <ConversationModel>[];
    final older = <ConversationModel>[];

    for (final c in _filteredConversations) {
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
      if (today.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      }
      slivers.add(_buildSectionHeader(context.l10n.yesterday));
      slivers.add(_buildListSliver(yesterday));
    }

    if (older.isNotEmpty) {
      if (today.isNotEmpty || yesterday.isNotEmpty) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      }
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
        child: Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
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
                    _loadConversations();
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

class CustomConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const CustomConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modelBadge = _modelBadgeIcon(
      conversation.lastProvider?.displayName ?? '',
    );

    // Time formatting
    final date =
        conversation.lastMessageAt ?? conversation.createdAt ?? DateTime.now();

    final formatDate = DateFormat('yyyy-MM-dd, HH:mm a').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: (context.isDark)
                      ? AppColors.tealAccent.withValues(alpha: 0.3)
                      : AppColors.cyanAccent.withValues(alpha: 0.2),
                  blurRadius: 3.0,
                  spreadRadius: 1.5)
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.title.isEmpty
                        ? context.l10n.newConversation
                        : conversation.title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conversation.lastMessage.isEmpty
                  ? context.l10n.startedShort
                  : conversation.lastMessage,
              style: context.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                modelBadge,
                const SizedBox(width: 12),
                Text(formatDate, style: context.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelBadgeIcon(String model) {
    Gradient gradColor = AppColors.geminiGradient;
    FaIconData icon = FontAwesomeIcons.gemini;
    switch (model) {
      case AppConstants.openAiDisplayName:
        gradColor = AppColors.openAIGradient;
        icon = FontAwesomeIcons.openai;
        break;
      case AppConstants.geminiDisplayName:
        gradColor = AppColors.geminiGradient;
        icon = FontAwesomeIcons.gemini;
        break;
      case AppConstants.claudeDisplayName:
        gradColor = AppColors.claudeGradient;
        icon = FontAwesomeIcons.claude;
        break;
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: gradColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
          child: FaIcon(
        icon,
        color: Colors.white,
        size: 14,
      )),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyHistory extends StatelessWidget {
  final bool isTablet;
  const _EmptyHistory({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: isTablet ? 72 : 56,
            color:
                context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          SizedBox(height: isTablet ? 14 : 8),
          Text(
            l10n.noConversationsMessage,
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 28 : 14),
          SizedBox(
            height: isTablet ? 52 : 46,
            child: ElevatedButton(
              onPressed: () => AppRoutes.navigateTo(context, AppRoutes.chat),
              child: Text(l10n.translate('new_conversation')),
            ),
          ),
        ],
      ),
    );
  }
}
