import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../profile/presentation/widgets/profile_common_widgets.dart';

/// Screen responsible for displaying local markdown legal documents
/// in a premium, beautifully styled, and responsive layout.
class LegalScreen extends StatefulWidget {
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
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  Future<String>? _documentFuture;
  Locale? _cachedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_cachedLocale != currentLocale || _documentFuture == null) {
      _cachedLocale = currentLocale;
      _documentFuture = _loadDocument(currentLocale);
    }
  }

  /// Asynchronously loads the legal markdown file.
  /// If the current locale is Hindi ('hi'), it attempts to load the Hindi asset
  /// (e.g. 'legal/privacy_policy_hi.md'), gracefully falling back to English if missing.
  Future<String> _loadDocument(Locale locale) async {
    if (locale.languageCode == 'hi') {
      final hiFileName = widget.mdFileName.replaceAll('.md', '_hi.md');
      try {
        return await rootBundle.loadString('assets/$hiFileName');
      } catch (_) {
        // Fallback to default asset if localized variant fails to load
      }
    }
    return await rootBundle.loadString('assets/${widget.mdFileName}');
  }

  @override
  Widget build(BuildContext context) {
    final double maxContentWidth = context.isExpanded
        ? 880.0
        : (context.isMedium ? 720.0 : double.infinity);

    // Build a standard Scaffold with theme-aware background and AppBar
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // FutureBuilder asynchronously loads the markdown string from app assets
      body: FutureBuilder<String>(
        future: _documentFuture,
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

          // Build a scrollable, beautifully styled and constrained document layout
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                  vertical: context.verticalSpacing,
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
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a modern hero header banner card at the top of the legal document.
  Widget _buildHeaderBanner(BuildContext context) {
    // Determine whether we are viewing Terms of Service or Privacy Policy
    final isTerms = widget.mdFileName.toLowerCase().contains('terms');
    final headerIcon =
        isTerms ? Icons.gavel_rounded : Icons.privacy_tip_rounded;

    final iconBoxSize = context.isTablet ? 48.0 : 42.0;
    final iconSize = context.isTablet ? 24.0 : 20.0;

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Glowing themed icon container
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(
              alpha: context.isDark ? 0.2 : 0.12,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.primaryColor.withValues(
                alpha: context.isDark ? 0.35 : 0.25,
              ),
            ),
          ),
          child: Icon(
            headerIcon,
            color:
                context.isDark ? AppColors.primaryLight : AppColors.primaryDark,
            size: iconSize,
          ),
        ),
        const SizedBox(width: 14),
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
      padding: EdgeInsets.symmetric(
        horizontal: context.isTablet ? 12 : 10,
        vertical: context.isTablet ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: ProfileUiHelpers.softShadow(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: (context.isTablet
                    ? context.textTheme.bodyMedium
                    : context.textTheme.bodySmall)
                ?.fontSize,
            color: context.theme.colorScheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: (context.isTablet
                    ? context.textTheme.bodyMedium
                    : context.textTheme.bodySmall)
                ?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a clean card container wrapping the parsed Markdown text with adaptive typography.
  Widget _buildMarkdownCard(BuildContext context, String markdownData) {
    final bool isTablet = context.isTablet;
    return MarkdownBody(
      data: markdownData,
      selectable: true, // Allows users to highlight and copy legal text
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        // Paragraph formatting with generous line spacing
        p: (isTablet
                ? context.textTheme.bodyLarge
                : context.textTheme.bodyMedium)
            ?.copyWith(
          height: 1.6,
        ),
        pPadding: const EdgeInsets.only(bottom: 12.0),
        // H1 headers with accent branding and bottom margin
        h1: (isTablet
                ? context.textTheme.headlineLarge
                : context.textTheme.headlineMedium)
            ?.copyWith(
          color: context.primaryColor,
          letterSpacing: -0.5,
          fontWeight: FontWeight.bold,
        ),
        h1Padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        // H2 headers for clear section demarcation
        h2: (isTablet
                ? context.textTheme.titleLarge
                : context.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.bold),
        h2Padding: EdgeInsets.only(top: context.verticalSpacing, bottom: 8.0),
        // H3 headers
        h3: (isTablet
                ? context.textTheme.titleMedium
                : context.textTheme.titleSmall)
            ?.copyWith(fontWeight: FontWeight.w600),
        h3Padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
        // Bullet list indentation and symbol coloring
        listBullet: (isTablet
                ? context.textTheme.bodyLarge
                : context.textTheme.bodyMedium)
            ?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: isTablet ? 18 : 15,
        ),
        listIndent: 22.0,
        // Blockquote callout boxes with custom left border and background tint
        blockquote: (isTablet
                ? context.textTheme.bodyLarge
                : context.textTheme.bodyMedium)
            ?.copyWith(
          fontStyle: FontStyle.italic,
          height: 1.5,
          color: context.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
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
