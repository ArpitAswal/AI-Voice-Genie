import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../chat/presentation/widgets/chat_model_selector_dropdown.dart';
import '../../../chat/presentation/widgets/image_generate_count.dart';
import '../../../chat/presentation/widgets/image_generate_size.dart';
import '../../../chat/presentation/widgets/model_image_quality.dart';
import '../../../chat/presentation/widgets/vision_detail_level_selector.dart';
import 'profile_common_widgets.dart';

class ProfileAiPreferencesPanel extends StatelessWidget {
  const ProfileAiPreferencesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Consumer<AiPreferencesProvider>(
        builder: (_, preferences, __) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreferenceRow(
                title: context.l10n.preferredModel,
                description: context.l10n.preferredModelHint,
                child: ChatModelSelectorDropdown(
                  providers: AiProviderId.values,
                  selectedProvider: preferences.preferredProvider,
                  isEnabled: true,
                  onChanged: (provider) {
                    preferences.setPreferredProvider(provider);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.translate('response_length'),
                description: context.l10n.translate('response_length_hint'),
                child: ResponseLengthSelector(
                  selectedLength: preferences.preferredResponseLength,
                  onChanged: (length) {
                    preferences.setPreferredResponseLength(length);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.imageQuality,
                description: context.l10n.imageQualityHint,
                child: ModelImageQuality(
                  selectedQuality: preferences.preferredImageQuality,
                  onChanged: (quality) {
                    preferences.setPreferredImageQuality(quality);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.imageSize,
                description: context.l10n.imageSizeHint,
                child: AiImageSizeSelector(
                  selectedSize: preferences.preferredImageSize,
                  onChanged: (size) {
                    preferences.setPreferredImageSize(size);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.imageCount,
                description: context.l10n.imageCountHint,
                child: ImageGenerateCountSelector(
                  selectedCount: preferences.preferredImageCount,
                  onChanged: (count) {
                    preferences.setPreferredImageCount(count);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.translate('vision_image_count'),
                description:
                    context.l10n.translate('vision_image_count_hint'),
                child: ImageGenerateCountSelector(
                  selectedCount: preferences.preferredVisionImageCount,
                  onChanged: (count) {
                    preferences.setPreferredVisionImageCount(count);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.translate('vision_pdf_count'),
                description: context.l10n.translate('vision_pdf_count_hint'),
                child: ImageGenerateCountSelector(
                  selectedCount: preferences.preferredVisionPdfCount,
                  onChanged: (count) {
                    preferences.setPreferredVisionPdfCount(count);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceRow(
                title: context.l10n.translate('vision_detail_level'),
                description: context.l10n.translate('vision_detail_level_hint'),
                child: VisionDetailLevelSelector(
                  selectedLevel: preferences.preferredVisionDetailLevel,
                  onChanged: (level) {
                    preferences.setPreferredVisionDetailLevel(level);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ResponseLengthSelector extends StatelessWidget {
  final ResponseLength selectedLength;
  final ValueChanged<ResponseLength> onChanged;

  const ResponseLengthSelector({
    super.key,
    required this.selectedLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ResponseLength>(
      enabled: true,
      initialValue: selectedLength,
      onSelected: onChanged,
      color: context.theme.colorScheme.surface,
      elevation: 8,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      menuPadding: const EdgeInsetsGeometry.symmetric(vertical: 8),
      itemBuilder: (context) => ResponseLength.values
          .map(
            (length) => PopupMenuItem<ResponseLength>(
              value: length,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${length.displayName} (${length.maxTokens})",
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: length == selectedLength
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: context.isDark
                                ? AppColors.white
                                : AppColors.primaryLight,
                          ),
                        ),
                      ),
                      if (length == selectedLength)
                        Icon(Icons.check_rounded,
                            color: context.primaryColor, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    length.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding / 2,
          vertical: 6.0,
        ),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLength.displayName,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: context.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _PreferenceRow({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: child),
      ],
    );
  }
}
