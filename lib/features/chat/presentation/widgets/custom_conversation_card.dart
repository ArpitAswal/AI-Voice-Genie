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
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const CustomConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final modelBadge = _modelBadgeIcon(
      context,
      conversation.lastProvider?.displayName ?? '',
    );

    // Time formatting with local timezone
    final localDate =
        (conversation.lastMessageAt ?? conversation.createdAt ?? DateTime.now())
            .toLocal();
    final now = DateTime.now();
    final isToday = localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;
    final timeStr = DateFormat('hh:mm a').format(localDate);
    final tz = localDate.timeZoneName;
    final formatDate = isToday
        ? '$timeStr $tz'
        : '${DateFormat('yyyy-MM-dd').format(localDate)}, $timeStr $tz';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.primaryColor : context.colorScheme.primary.withValues(alpha:
            context.isDark ? 0.5 : 0.7),
            width: 1.2,
          ),
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
                  children: [
                    if (isSelectionMode) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(isSelected),
                          color: isSelected
                              ? context.primaryColor
                              : context.colorScheme.tertiary,
                          size: context.isCompact ? 18.0 : 22.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        conversation.title.isEmpty
                            ? context.l10n.newConversation
                            : conversation.title,
                        style: (context.isCompact
                                ? context.textTheme.titleSmall
                                : context.textTheme.titleMedium)
                            ?.copyWith(
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: context.isCompact ? 14.0 : 16.0,
                            color: context.isDark
                                ? AppColors.darkWarning
                                : AppColors.lightWarning,
                          ),
                        ),
                      )
                    else if (conversation.syncStatus ==
                            SyncStatus.pendingCreate ||
                        conversation.syncStatus == SyncStatus.pendingUpdate)
                      Tooltip(
                        message: context.l10n.waitingToSyncTooltip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.cloud_off_rounded,
                            size: context.isCompact ? 14.0 : 16.0,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    if (!isSelectionMode)
                      Icon(
                        Icons.chevron_right,
                        color: context.isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                        size: context.isCompact ? 18.0 : 20.0,
                      ),
                  ],
                ),
                if (conversation.lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    conversation.lastMessage,
                    style: (context.isCompact
                            ? context.textTheme.bodySmall
                            : context.textTheme.bodyMedium)
                        ?.copyWith(
                      color: context.colorScheme.tertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                modelBadge,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatDate,
                    style: (context.isCompact
                            ? context.textTheme.labelSmall
                            : context.textTheme.bodySmall)
                        ?.copyWith(color: context.colorScheme.tertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelBadgeIcon(BuildContext context, String model) {
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
    final badgeSize = context.isTablet ? 32.0 : 24.0;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        gradient: gradColor,
        borderRadius: BorderRadius.circular(badgeSize * 0.35),
      ),
      child: Center(
        child: FaIcon(
          icon,
          color: Colors.white,
          size: badgeSize * 0.55,
        ),
      ),
    );
  }
}
