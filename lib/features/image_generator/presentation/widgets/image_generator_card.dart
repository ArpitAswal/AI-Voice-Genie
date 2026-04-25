import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';

/// Displays a successfully generated image with action buttons.
///
/// Shows:
///   - The generated image (from Uint8List bytes — works for both
///     OpenAI URL-fetched bytes and Gemini base64-decoded bytes)
///   - Provider chip (which AI generated this)
///   - The original prompt text
///   - Save to Gallery button
///   - Share button
///   - Generate Another button (resets the screen for a new prompt)
///
/// Callbacks:
///   [onSave]            → triggered when user taps Save to Gallery
///   [onGenerateAnother] → triggered when user wants a new image
class GeneratedImageCard extends StatelessWidget {
  /// Raw image bytes — used directly with Image.memory()
  final Uint8List imageBytes;

  /// Which AI provider generated this image
  final AiProviderId provider;

  /// The prompt that was used to generate this image
  final String prompt;

  /// Whether a save operation is in progress
  final bool isSaving;

  /// Called when user taps Save to Gallery
  final VoidCallback onSave;

  /// Called when user taps Generate Another
  final VoidCallback onGenerateAnother;

  final bool isTablet;

  const GeneratedImageCard({
    super.key,
    required this.imageBytes,
    required this.provider,
    required this.prompt,
    required this.isSaving,
    required this.onSave,
    required this.onGenerateAnother,
    required this.isTablet,
  });

  /// Share the image using the system share sheet.
  ///
  /// Writes bytes to a temp file first, then passes it to share_plus.
  Future<void> _handleShare(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'ai_voice_genie_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: prompt,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        context.showError('something_went_wrong');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Provider chip ────────────────────────────────────────────────────
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 10),
        //   child: ModelIndicatorChip(
        //     provider: provider,
        //     isTablet: isTablet,
        //   ),
        // ),

        // ── Generated image ──────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageBytes,
            width: double.infinity,
            fit: BoxFit.cover,
            // Show a shimmer placeholder while the image decodes
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return _ImagePlaceholder(isTablet: isTablet);
            },
            errorBuilder: (context, error, stackTrace) {
              return _ImageErrorWidget(isTablet: isTablet);
            },
          ),
        ),

        SizedBox(height: isTablet ? 14 : 10),

        // ── Prompt text ──────────────────────────────────────────────────────
        Text(
          prompt,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        SizedBox(height: isTablet ? 20 : 16),

        // ── Action buttons row ────────────────────────────────────────────────
        Row(
          children: [
            // Save to Gallery
            Expanded(
              child: _ActionButton(
                label: l10n.translate('save_image'),
                icon: Icons.download_rounded,
                isLoading: isSaving,
                onTap: onSave,
                isTablet: isTablet,
                isPrimary: true,
              ),
            ),

            SizedBox(width: isTablet ? 12 : 8),

            // Share
            Expanded(
              child: _ActionButton(
                label: l10n.translate('send'),
                icon: Icons.share_rounded,
                isLoading: false,
                onTap: () => _handleShare(context),
                isTablet: isTablet,
                isPrimary: false,
              ),
            ),
          ],
        ),

        SizedBox(height: isTablet ? 12 : 8),

        // ── Generate Another button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: isTablet ? 48 : 42,
          child: TextButton.icon(
            onPressed: onGenerateAnother,
            icon: Icon(
              Icons.refresh_rounded,
              size: isTablet ? 20 : 18,
            ),
            label: Text(l10n.translate('generate_image')),
            style: TextButton.styleFrom(
              foregroundColor: context.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              textStyle: context.textTheme.titleSmall?.copyWith(
                fontSize: isTablet ? 15 : 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ACTION BUTTON — Save / Share
// =============================================================================

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isTablet;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
    required this.isTablet,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final height = isTablet ? 50.0 : 44.0;

    if (isPrimary) {
      return SizedBox(
        height: height,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onTap,
          icon: isLoading
              ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.white,
            ),
          )
              : Icon(icon, size: isTablet ? 20 : 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            textStyle: context.textTheme.titleSmall?.copyWith(
              fontSize: isTablet ? 15 : 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: isTablet ? 20 : 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          textStyle: context.textTheme.titleSmall?.copyWith(
            fontSize: isTablet ? 15 : 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IMAGE PLACEHOLDER — shown while bytes are decoding
// =============================================================================

class _ImagePlaceholder extends StatelessWidget {
  final bool isTablet;
  const _ImagePlaceholder({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: isTablet ? 400 : 300,
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primaryLight.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// =============================================================================
// IMAGE ERROR WIDGET — shown when bytes fail to decode
// =============================================================================

class _ImageErrorWidget extends StatelessWidget {
  final bool isTablet;
  const _ImageErrorWidget({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: isTablet ? 400 : 300,
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.cardDark
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: isTablet ? 48 : 36,
            color: context.isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            AppLocalizations.of(context)!.translate('image_generation_failed'),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}