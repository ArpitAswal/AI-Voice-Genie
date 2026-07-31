import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/conversation_model.dart';

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
                      ? AppColors.tealAccent.withValues(alpha: 0.5)
                      : AppColors.cyanAccent.withValues(alpha: 0.3),
                  blurRadius: 3.0,
                  spreadRadius: 1)
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
                // ── Sync status indicators ─────────────────────────────────
                if (conversation.syncStatus == SyncStatus.syncFailed)
                  Tooltip(
                    message: context.l10n.syncFailedTooltip,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: context.isDark
                            ? AppColors.darkWarning
                            : AppColors.lightWarning,
                      ),
                    ),
                  )
                else if (conversation.syncStatus == SyncStatus.pendingCreate ||
                    conversation.syncStatus == SyncStatus.pendingUpdate)
                  Tooltip(
                    message: context.l10n.waitingToSyncTooltip,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: AppColors.info,
                      ),
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
            if (conversation.lastMessage.isNotEmpty) ...[
              Text(
                conversation.lastMessage,
                style: context.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8)
            ],
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
