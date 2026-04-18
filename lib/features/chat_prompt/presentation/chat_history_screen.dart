import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';
import '../../../core/enums/app_enums.dart';

class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() => _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final ChatRepository _repository = ChatRepositoryImpl();
  
  List<ConversationModel> _allConversations = [];
  List<ConversationModel> _filteredConversations = [];
  
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
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

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Scaffold(
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          Text(
                            "History",
                            style: context.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 40,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Review your recent thoughts.",
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Search Container
                          Container(
                            decoration: BoxDecoration(
                              color: context.isDark ? AppColors.cardDark.withValues(alpha: 0.5) : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search conversations...',
                                hintStyle: context.textTheme.bodyMedium?.copyWith(
                                  color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_filteredConversations.isEmpty && _searchQuery.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHistory(isTablet: isTablet),
                    )
                  else if (_filteredConversations.isEmpty && _searchQuery.isNotEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          "No results found",
                          style: context.textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    ..._buildGroupedLists(),
                ],
              ),
          ),
      ),
    );
  }

  List<Widget> _buildGroupedLists() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

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
      slivers.add(_buildSectionHeader("Today"));
      slivers.add(_buildListSliver(today));
    }

    if (yesterday.isNotEmpty) {
      if(today.isNotEmpty) slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      slivers.add(_buildSectionHeader("Yesterday"));
      slivers.add(_buildListSliver(yesterday));
    }

    if (older.isNotEmpty) {
      if(today.isNotEmpty || yesterday.isNotEmpty) slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      slivers.add(_buildSectionHeader("Older"));
      slivers.add(_buildListSliver(older));
    }
    
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32))); // Bottom padding

    return slivers;
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                onTap: () {
                  AppRoutes.navigateTo(
                    context,
                    AppRoutes.chatDetail,
                    arguments: ChatDetailArguments(
                      conversationId: conversation.id,
                      initialTitle: conversation.title,
                    ),
                  );
                },
              ),
            );
          },
          childCount: items.length,
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
    // Determine sender badge text (Genie vs You)
    final bool isGenie = conversation.lastProvider != null;
    final badgeText = isGenie ? "Genie" : "You";
    
    // Time formatting
    final date = conversation.lastMessageAt ?? conversation.createdAt ?? DateTime.now();
    
    final now = DateTime.now();
    final isSameYear = now.year == date.year;
    
    String timeStr;
    final itemDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (itemDate == today) {
        timeStr = DateFormat('jm').format(date); // 10:42 AM
    } else if (itemDate == yesterday) {
        timeStr = "Yesterday"; // as per design image
    } else if (isSameYear) {
        timeStr = DateFormat('MMM d').format(date);
    } else {
        timeStr = DateFormat('MMM d, yyyy').format(date);
    }

    // Color definitions based on the image
    final Color badgeBg = context.isDark ? const Color(0xFF1D243D) : AppColors.primaryLight.withValues(alpha: 0.2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.title.isEmpty ? "New Conversation" : conversation.title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conversation.lastMessage.isEmpty ? "Started a conversation..." : conversation.lastMessage,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.isDark ? Colors.white70 : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  timeStr,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
            color: context.isDark
                ? AppColors.darkDivider
                : AppColors.lightDivider,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            l10n.translate('no_conversations'),
            style: context.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            l10n.translate('no_conversations_subtitle'),
            style: context.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 28 : 24),
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
