import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Screen responsible for displaying local markdown legal documents
/// in a premium, beautifully styled, and responsive layout.
class LegalScreen extends StatelessWidget {
  /// The title displayed in the AppBar (localized).
  final String title;

  /// The relative asset path of the markdown file (e.g., 'legal/privacy_policy.md').
  final String mdFileName;

  const LegalScreen({
    super.key,
    required this.title,
    required this.mdFileName,
  });

  @override
  Widget build(BuildContext context) {
    // Build a standard Scaffold with theme-aware background and AppBar
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(title),
      ),
      // FutureBuilder asynchronously loads the markdown string from app assets
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/$mdFileName'),
        builder: (context, snapshot) {
          // Display a centered loading spinner while reading asset from disk
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // If asset loading fails, display a localized error message
          if (snapshot.hasError) {
            return Center(
              child: Text(
                context.l10n.somethingWentWrong,
                style: context.textTheme.bodyMedium,
              ),
            );
          }

          // Build a scrollable, beautifully styled document layout
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Render the premium hero header banner card
                _buildHeaderBanner(context),
                SizedBox(height: context.verticalSpacing),
                // Render the formatted markdown content card
                _buildMarkdownCard(context, snapshot.data ?? ''),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a modern hero header banner card at the top of the legal document.
  Widget _buildHeaderBanner(BuildContext context) {
    // Determine whether we are viewing Terms of Service or Privacy Policy
    final isTerms = mdFileName.toLowerCase().contains('terms');
    final headerIcon =
        isTerms ? Icons.gavel_rounded : Icons.privacy_tip_rounded;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Glowing themed icon container
        Container(
          width: context.screenWidth * 0.1,
          height: context.screenWidth * 0.1,
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(context.screenWidth * 0.05),
          ),
          child: Icon(
            headerIcon,
            color:
                context.isDark ? AppColors.primaryLight : AppColors.primaryDark,
            size: context.screenWidth * 0.07,
          ),
        ),
        const SizedBox(width: 16),
        // Title and status badges
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: isTerms
                ? [
                    // Terms of Service badges
                    _buildStatusChip(
                      context,
                      label: context.l10n.userAgreement,
                      icon: Icons.gavel_rounded,
                    ),
                    _buildStatusChip(
                      context,
                      label: context.l10n.lastUpdated,
                      icon: Icons.update_rounded,
                    ),
                    _buildStatusChip(
                      context,
                      label: context.l10n.aiGuidelines,
                      icon: Icons.rule_rounded,
                    ),
                  ]
                : [
                    // Privacy Policy badges
                    _buildStatusChip(
                      context,
                      label: context.l10n.officialDocument,
                      icon: Icons.verified_rounded,
                    ),
                    _buildStatusChip(
                      context,
                      label: context.l10n.lastUpdated,
                      icon: Icons.update_rounded,
                    ),
                    _buildStatusChip(
                      context,
                      label: context.l10n.noDataSelling,
                      icon: Icons.lock_outline_rounded,
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  /// Helper to render small status pills inside the header banner.
  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(context.screenWidth * 0.05),
        border: Border.all(
          color:
              context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.black.withValues(alpha: context.isDark ? 0.12 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: context.textTheme.bodySmall?.fontSize,
              color: context.theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a clean card container wrapping the parsed Markdown text.
  Widget _buildMarkdownCard(BuildContext context, String markdownData) {
    return MarkdownBody(
      data: markdownData,
      selectable: true, // Allows users to highlight and copy legal text
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        // Paragraph formatting with generous line spacing
        p: context.textTheme.bodyMedium?.copyWith(
          height: 1.6,
        ),
        pPadding: EdgeInsets.zero,
        // H1 headers with accent branding and bottom margin
        h1: context.textTheme.headlineLarge?.copyWith(
          color: context.primaryColor,
          letterSpacing: -0.5,
        ),
        h1Padding: const EdgeInsets.only(top: 12),
        // H2 headers for clear section demarcation
        h2: context.textTheme.titleMedium,
        h2Padding: EdgeInsets.only(top: context.verticalSpacing / 2),
        // Bullet list indentation and symbol coloring
        listBullet: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        listIndent: 22.0,
        // Blockquote callout boxes with custom left border and background tint
        blockquote: context.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          height: 1.5,
          color: context.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        blockquoteDecoration: BoxDecoration(
          color: context.primaryColor
              .withValues(alpha: context.isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: context.primaryColor, width: 4),
          ),
        ),
        // Horizontal section divider lines
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color:
                  context.textTheme.bodySmall!.color!.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
