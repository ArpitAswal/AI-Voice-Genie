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
