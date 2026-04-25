import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/pdf_doc_model.dart';

/// Displays a loaded PDF's metadata in a card format.
///
/// Shows: PDF icon, file name, page count, file size, word count.
/// Shows a truncation warning if the PDF text was cut for AI context.
/// Provides a Remove button to clear the PDF and start fresh.
class PdfUploadCard extends StatelessWidget {
  final PdfDocumentModel document;
  final bool isTablet;
  final VoidCallback onRemove;

  const PdfUploadCard({
    super.key,
    required this.document,
    required this.isTablet,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PDF header row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PDF icon
                Container(
                  width: isTablet ? 48 : 40,
                  height: isTablet ? 48 : 40,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.warning,
                    size: isTablet ? 26 : 22,
                  ),
                ),

                SizedBox(width: isTablet ? 14 : 10),

                // File name + metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.fileName,
                        style: context.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isTablet ? 6 : 4),
                      // Metadata chips row
                      Wrap(
                        spacing: isTablet ? 12 : 8,
                        children: [
                          _MetaChip(
                            icon: Icons.description_outlined,
                            label: '${document.pageCount} '
                                '${document.pageCount == 1 ? l10n.translate("page") : l10n.translate("pages")}',
                            isTablet: isTablet,
                          ),
                          _MetaChip(
                            icon: Icons.storage_outlined,
                            label: document.fileSizeLabel,
                            isTablet: isTablet,
                          ),
                          _MetaChip(
                            icon: Icons.text_fields_rounded,
                            label: '${document.wordCount} '
                                '${l10n.translate("words")}',
                            isTablet: isTablet,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Remove button
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.error,
                  ),
                  iconSize: isTablet ? 22 : 18,
                  onPressed: onRemove,
                  tooltip: l10n.translate('remove_pdf'),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: isTablet ? 36 : 30,
                    minHeight: isTablet ? 36 : 30,
                  ),
                ),
              ],
            ),

            // ── Truncation warning ───────────────────────────────────────────
            if (document.wasTruncated) ...[
              SizedBox(height: isTablet ? 12 : 10),
              _TruncationWarning(isTablet: isTablet),
            ],

            // ── No text layer warning ────────────────────────────────────────
            if (!document.hasText && !document.wasTruncated) ...[
              SizedBox(height: isTablet ? 12 : 10),
              _NoTextWarning(isTablet: isTablet),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// META CHIP — file info pill
// =============================================================================

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTablet;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isTablet ? 13 : 11,
          color: context.isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        SizedBox(width: isTablet ? 4 : 3),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: isTablet ? 11 : 10,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TRUNCATION WARNING
// =============================================================================

class _TruncationWarning extends StatelessWidget {
  final bool isTablet;
  const _TruncationWarning({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: isTablet ? 15 : 13,
            color: AppColors.warning,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!
                  .translate('pdf_text_truncated'),
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
                fontSize: isTablet ? 11 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NO TEXT WARNING — scanned PDFs with no text layer
// =============================================================================

class _NoTextWarning extends StatelessWidget {
  final bool isTablet;
  const _NoTextWarning({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: isTablet ? 15 : 13,
            color: AppColors.error,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!
                  .translate('pdf_no_text_layer'),
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.error,
                fontSize: isTablet ? 11 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}