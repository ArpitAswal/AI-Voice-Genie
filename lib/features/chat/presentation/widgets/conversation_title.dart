import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/extensions/string_extension.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/conversation_model.dart';

/// Single item in the conversation history list.
///
/// Shows: title, last message preview, date/time, and model indicator dot.
/// Long-press to show delete option.
class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isTablet;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.isTablet,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessageAt = conversation.lastMessageAt;

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete != null ? () => _showDeleteOption(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              // color: context.isDark
              //     ? AppColors.darkBorder
              //     : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // ── Capability Icon ──────────────────────────────────────────────
            _CapabilityIcon(
              capability: conversation.capability,
              isTablet: isTablet,
            ),

            SizedBox(width: isTablet ? 16 : 12),

            // ── Title + Last Message ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontSize: isTablet ? 15 : 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      // Date/time
                      Text(
                        lastMessageAt?.toConversationDate ?? '',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: isTablet ? 11 : 10,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 5 : 4),
                  Row(
                    children: [
                      // Provider dot
                      if (conversation.lastProvider != null) ...[
                        _ProviderDot(provider: conversation.lastProvider!),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          conversation.lastMessage,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: isTablet ? 13 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: isTablet ? 8 : 4),
            Icon(
              Icons.chevron_right_rounded,
              size: isTablet ? 22 : 18,
              color: context.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteOption(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading:
              const Icon(Icons.delete_outline_rounded, color: AppColors.lightError),
          title: Text(
            // Localized delete conversation label (agent rule: no hardcoded strings)
            context.l10n.deleteConversation,
            style: const TextStyle(color: AppColors.lightError),
          ),
          onTap: () {
            Navigator.pop(ctx);
            onDelete?.call();
          },
        ),
      ),
    );
  }
}

class _CapabilityIcon extends StatelessWidget {
  final AiCapability capability;
  final bool isTablet;

  const _CapabilityIcon({
    required this.capability,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (capability) {
      AiCapability.textGeneration => (
          Icons.chat_bubble_outline_rounded,
          AppColors.primaryLight,
        ),
      AiCapability.imageGeneration => (
          Icons.image_outlined,
          AppColors.accentLight,
        ),
      AiCapability.imageUnderstanding => (
          Icons.image_search_outlined,
          AppColors.info,
        ),
      AiCapability.pdfParsing => (
          Icons.picture_as_pdf_outlined,
          AppColors.lightWarning,
        ),
    };

    final size = isTablet ? 44.0 : 38.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: isTablet ? 22 : 18, color: color),
    );
  }
}

class _ProviderDot extends StatelessWidget {
  final AiProviderId provider;
  const _ProviderDot({required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = switch (provider) {
      AiProviderId.openAi => AppColors.openAiBrand,
      AiProviderId.gemini => AppColors.geminiBrand,
      AiProviderId.claude => AppColors.claudeBrand,
    };

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
