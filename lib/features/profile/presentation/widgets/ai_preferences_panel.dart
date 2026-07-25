import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../../shared/widgets/chat_model_selector_dropdown.dart';
import '../../../../shared/widgets/default_value_dropdown_selector.dart';
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _PreferenceRow(
                title: context.l10n.imageQuality,
                description: context.l10n.imageQualityHint,
                child: ModelImageQualitySelector(
                  selectedQuality: preferences.preferredImageQuality,
                  onChanged: (quality) {
                    preferences.setPreferredImageQuality(quality);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _PreferenceRow(
                title: context.l10n.imageBackground,
                description: context.l10n.imageBackgroundHint,
                child: ImageBackgroundSelector(
                    selectedBackground: preferences.preferredImageBackground,
                    onChanged: (background) {
                      preferences.setPreferredImageBackground(background);
                    }),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _PreferenceRow(
                title: context.l10n.translate('vision_image_count'),
                description: context.l10n.translate('vision_image_count_hint'),
                child: ImageGenerateCountSelector(
                  selectedCount: preferences.preferredVisionImageCount,
                  onChanged: (count) {
                    preferences.setPreferredVisionImageCount(count);
                  },
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(description, style: context.textTheme.bodySmall),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: child),
      ],
    );
  }
}
