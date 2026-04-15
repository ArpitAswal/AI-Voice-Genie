import 'package:ai_voice_genie/features/chat_prompt/presentation/widgets/conversation_title.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation_model.dart';

/// Displays a paginated list of the user's past conversations.
///
/// Tapping a tile resumes the conversation in ChatDetailScreen.
/// Supports pull-to-refresh and infinite scroll pagination.
class ConversationHistoryScreen extends StatefulWidget {
  const ConversationHistoryScreen({super.key});

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final ChatRepository _repository = ChatRepositoryImpl();
  final ScrollController _scrollController = ScrollController();

  final List<ConversationModel> _conversations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    if (_isLoading || !_hasMore) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final results = <ConversationModel>[];

      setState(() {
        _conversations.addAll(results);
        _hasMore = results.length >= 15;
        _isLoading = false;
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _refresh() async {
    _conversations.clear();
    _hasMore = true;
    _isInitialLoad = true;
    await _loadConversations();
  }

  Future<void> _deleteConversation(ConversationModel conversation) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    try {
      // await _repository.deleteConversation(
      //   uid: uid,
      //   conversationId: conversation.id,
      // );

      setState(
          () => _conversations.removeWhere((c) => c.id == conversation.id));

      if (!mounted) return;
      context.showSuccessToast(
        AppLocalizations.of(context)!.translate('conversation_deleted'),
      );
    } catch (e) {
      if (!mounted) return;
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
    final l10n = AppLocalizations.of(context)!;
    final isTablet = context.isTablet;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('conversation_history')),
      ),
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _EmptyHistory(isTablet: isTablet)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _conversations.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _conversations.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final conversation = _conversations[index];
                      return ConversationTile(
                        conversation: conversation,
                        isTablet: isTablet,
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
                        onDelete: () => _deleteConversation(conversation),
                      );
                    },
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
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
      ),
    );
  }
}
