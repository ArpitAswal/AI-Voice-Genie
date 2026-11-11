import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../ai_layer/registry/provider_registry.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../../shared/widgets/chat_model_selector_dropdown.dart';
import '../../../../shared/widgets/default_value_dropdown_selector.dart';
import 'profile_common_widgets.dart';

/// Expandable AI Preferences Panel.
/// Shows Preferred Model upfront; expands on tap to configure detailed parameters.
class ProfileAiPreferencesPanel extends StatefulWidget {
  const ProfileAiPreferencesPanel({super.key});

  @override
  State<ProfileAiPreferencesPanel> createState() =>
      _ProfileAiPreferencesPanelState();
}

class _ProfileAiPreferencesPanelState extends State<ProfileAiPreferencesPanel>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Consumer<AiPreferencesProvider>(
        builder: (_, preferences, __) {
          final profile = ProviderRegistry.instance
              .profileFor(preferences.preferredProvider);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.preferredModel,
                    style: (context.isCompact
                            ? context.textTheme.titleSmall
                            : context.textTheme.titleMedium)
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // ── Expand / Collapse Toggle Button ──────────────────────────
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: CircleAvatar(
                      radius: context.isTablet ? 18 : 12,
                      backgroundColor: context.theme.dividerTheme.color
                          ?.withValues(alpha: 0.5),
                      child: RotationTransition(
                        turns: Tween<double>(begin: 0.0, end: 0.5)
                            .animate(_expandAnimation),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: context.isTablet ? 32 : 21,
                          color: context.colorScheme.tertiaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.preferredModelHint,
                style: context.isCompact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ChatModelSelectorDropdown(
                providers: AiProviderId.values,
                selectedProvider: preferences.preferredProvider,
                isEnabled: true,
                showStatusIndicators: false,
                onChanged: (provider) {
                  preferences.setPreferredProvider(provider);
                },
              ),

              // ── Expandable Secondary Parameters (Vertical SizeTransition) ──
              SizeTransition(
                axis: Axis.vertical,
                alignment: Alignment.topCenter,
                sizeFactor: _expandAnimation,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // ── Auto Text-to-Speech ─────────────────────────────────
                      _PreferenceRow(
                        title: context.l10n.autoTts,
                        description: context.l10n.autoTtsHint,
                        child: Transform.scale(
                          scale: 1,
                          child: Switch(
                            value: preferences.autoTextToSpeech,
                            onChanged: (val) {
                              preferences.setAutoTextToSpeech(val);
                            },
                            padding: EdgeInsets.zero,
                            activeThumbColor: Colors.white,
                            activeTrackColor: context.primaryColor,
                            inactiveThumbColor:
                                context.isDark ? AppColors.grey : Colors.white,
                            inactiveTrackColor: context.isDark
                                ? context.primaryColor.withValues(alpha: 0.2)
                                : AppColors.lightDivider,
                            trackOutlineColor: const WidgetStatePropertyAll(
                                Colors.transparent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Response Length ─────────────────────────────────────
                      if (profile
                          .supports(AiPreferenceControl.responseLength)) ...[
                        _PreferenceRow(
                          title: context.l10n.responseLength,
                          description: context.l10n.responseLengthHint,
                          child: ResponseLengthSelector(
                            selectedLength: preferences.preferredResponseLength,
                            provider: preferences.preferredProvider,
                            onChanged: (length) {
                              preferences.setPreferredResponseLength(length);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Gemini Thinking Level ───────────────────────────────
                      if (profile.supports(
                          AiPreferenceControl.geminiThinkingLevel)) ...[
                        _PreferenceRow(
                          title: context.l10n.geminiThinkingLevel,
                          description: context.l10n.geminiThinkingLevelHint,
                          child: GeminiThinkingLevelSelector(
                            selectedLevel:
                                preferences.preferredGeminiThinkingLevel,
                            onChanged: (level) {
                              preferences
                                  .setPreferredGeminiThinkingLevel(level);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── OpenAI Image Controls ───────────────────────────────
                      if (profile
                          .supports(AiPreferenceControl.imageQuality)) ...[
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
                        const SizedBox(height: 16),
                      ],
                      if (profile
                          .supports(AiPreferenceControl.imageBackground)) ...[
                        _PreferenceRow(
                          title: context.l10n.imageBackground,
                          description: context.l10n.imageBackgroundHint,
                          child: ImageBackgroundSelector(
                            selectedBackground:
                                preferences.preferredImageBackground,
                            onChanged: (background) {
                              preferences
                                  .setPreferredImageBackground(background);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (profile.supports(AiPreferenceControl.imageSize)) ...[
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
                      ],
                      if (profile.supports(AiPreferenceControl.imageCount)) ...[
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
                      ],

                      // ── Gemini Image Aspect Ratio ───────────────────────────
                      if (profile
                          .supports(AiPreferenceControl.geminiAspectRatio)) ...[
                        _PreferenceRow(
                          title: context.l10n.geminiAspectRatio,
                          description: context.l10n.geminiAspectRatioHint,
                          child: GeminiAspectRatioSelector(
                            selectedRatio:
                                preferences.preferredGeminiAspectRatio,
                            onChanged: (ratio) {
                              preferences.setPreferredGeminiAspectRatio(ratio);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Vision Controls ─────────────────────────────────────
                      if (profile
                          .supports(AiPreferenceControl.visionImageCount)) ...[
                        _PreferenceRow(
                          title: context.l10n.visionImageCount,
                          description: context.l10n.visionImageCountHint,
                          child: ImageGenerateCountSelector(
                            selectedCount:
                                preferences.preferredVisionImageCount,
                            onChanged: (count) {
                              preferences.setPreferredVisionImageCount(count);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (profile
                          .supports(AiPreferenceControl.visionPdfCount)) ...[
                        _PreferenceRow(
                          title: context.l10n.visionPdfCount,
                          description: context.l10n.visionPdfCountHint,
                          child: ImageGenerateCountSelector(
                            selectedCount: preferences.preferredVisionPdfCount,
                            onChanged: (count) {
                              preferences.setPreferredVisionPdfCount(count);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (profile
                          .supports(AiPreferenceControl.visionDetailLevel)) ...[
                        _PreferenceRow(
                          title: context.l10n.visionDetailLevel,
                          description: context.l10n.visionDetailLevelHint,
                          child: VisionDetailLevelSelector(
                            selectedLevel:
                                preferences.preferredVisionDetailLevel,
                            onChanged: (level) {
                              preferences.setPreferredVisionDetailLevel(level);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Gemini Key Note / Information Banner ────────────────
                      if (preferences.preferredProvider ==
                          AiProviderId.gemini) ...[
                        const SizedBox(height: 4),
                        _InfoBanner(
                          title: context.l10n.geminiInfoTitle,
                          description: context.l10n.geminiInfoDesc,
                        ),
                      ],

                      // ── Claude Key Note / Information Banner ────────────────
                      if (preferences.preferredProvider ==
                          AiProviderId.claude) ...[
                        const SizedBox(height: 4),
                        _InfoBanner(
                          title: context.l10n.claudeInfoTitle,
                          description: context.l10n.claudeInfoDesc,
                        ),
                      ],
                    ],
                  ),
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
    if (!context.isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            child,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: context.textTheme.bodySmall,
        ),
        SizedBox(
            height: (title.contains('Speech'))
                ? 0
                : (context.isCompact)
                    ? 12
                    : 8),
        Align(alignment: Alignment.centerLeft, child: child),
      ],
    );
  }
}

/// Informational banner displaying capability notes for selected AI providers.
class _InfoBanner extends StatelessWidget {
  final String title;
  final String description;

  const _InfoBanner({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: context.isDark
            ? context.primaryColor.withValues(alpha: 0.2)
            : context.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.transparent
              : context.primaryColor.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: context.isTablet ? 22 : 18,
            color: context.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: (context.isCompact
                          ? context.textTheme.titleSmall
                          : context.textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: (context.isCompact
                          ? context.textTheme.bodySmall
                          : context.textTheme.bodyMedium)
                      ?.copyWith(
                    height: 1.4,
                    color: context.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
