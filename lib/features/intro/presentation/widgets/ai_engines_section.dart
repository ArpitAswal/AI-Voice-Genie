import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../key_setup/presentation/api_key_provider.dart';

/// Intelligent AI Engine showcase section.
///
/// Information Hierarchy (Home Screen):
/// - Answers "What can it do for me right now?" (Marketing pitch & Superpower).
/// - Each model card surfaces its core capability highlight and a direct action trigger.
/// - Tapping any model card immediately sets it as preferred and launches chat.
///
/// Responsive Architecture:
/// - Automatically adapts between:
///   - 3-column grid for wide tablet landscape/desktop (>= 800dp).
///   - 2-column grid for tablet portrait (500dp - 799dp).
///   - Single-column list for compact phone viewports (< 500dp).
class AiEnginesSection extends StatelessWidget {
  final ValueChanged<AiProviderId>? onEngineSelected;
  final bool isShortHeight;

  const AiEnginesSection({
    super.key,
    this.onEngineSelected,
    this.isShortHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Text(
          context.l10n.intelligentModels,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Compute column count dynamically to fill the width without cramping
            final int crossAxisCount =
                width >= 1100.0 ? 3 : (width >= 500.0 ? 2 : 1);

            const providers = AiProviderId.values;

            if (crossAxisCount > 1) {
              // Responsive grid distributing cards evenly across the freed-up space
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: (210.0).clamp(200, 240),
                ),
                itemCount: providers.length,
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return _EngineCard(
                    provider: provider,
                    onTap: () => onEngineSelected?.call(provider),
                    isShort: isShortHeight,
                  );
                },
              );
            }

            // Single vertical column for compact phone screens
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: providers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final provider = providers[index];
                return _EngineCard(
                  provider: provider,
                  onTap: () => onEngineSelected?.call(provider),
                  isShort: isShortHeight,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EngineCard extends StatelessWidget {
  final AiProviderId provider;
  final VoidCallback? onTap;
  final bool isShort;

  const _EngineCard({
    required this.provider,
    this.onTap,
    required this.isShort,
  });

  double _logoContextSize(BuildContext context) {
    if (context.isTablet) {
      return 52.0; // Prominent on wide screens
    }
    if (context.isCompact && isShort) {
      return 38.0; // Compact for height-constrained devices
    }
    return 46.0; // Standard mobile & tablet-portrait default
  }

  @override
  Widget build(BuildContext context) {
    final Color modelColor = provider.brandColor(context);
    final LinearGradient gradient = provider.brandGradient(context);
    final FaIconData faIcon = switch (provider) {
      AiProviderId.openAi => FontAwesomeIcons.openai,
      AiProviderId.gemini => FontAwesomeIcons.gemini,
      AiProviderId.claude => FontAwesomeIcons.claude,
    };

    final logoSize = _logoContextSize(context);
    final apiKeyProvider = context.watch<ApiKeyProvider>();
    final hasKey = apiKeyProvider.validProviders.contains(provider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1.2,
        ),
      ),
      color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Model Identity & Superpower Badge ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      // Proportional radius (28% of size) ensures consistent squircle curvature on all screens
                      borderRadius: BorderRadius.circular(logoSize * 0.28),
                      boxShadow: [
                        BoxShadow(
                          color: modelColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: FaIcon(
                        faIcon,
                        color: Colors.white,
                        size: logoSize * 0.52,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (context.isCompact
                                  ? context.textTheme.titleMedium
                                  : context.textTheme.titleLarge)
                              ?.copyWith(
                            color: modelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: modelColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            provider.superpower(context.l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (context.isCompact
                                    ? context.textTheme.labelSmall
                                    : context.textTheme.labelMedium)
                                ?.copyWith(
                              color: modelColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: hasKey
                        ? provider.displayName
                        : '${provider.displayName}: ${context.l10n.noKeyForModel}',
                    child: Icon(
                      hasKey
                          ? Icons.arrow_forward_rounded
                          : Icons.vpn_key_off_rounded,
                      size: 16,
                      color: hasKey ? modelColor : AppColors.lightWarning,
                    ),
                  ),
                ],
              ),

              // Fixed consistent gap between header and bullets across ALL cards
              const SizedBox(height: 12),

              // ── Body: Discrete Bullet Points ("What can it do for me?") ───
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children:
                    provider.introBulletPoints(context.l10n).map((bullet) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: context.isCompact ? 4.5 : 5.5,
                          height: context.isCompact ? 4.5 : 5.5,
                          margin: const EdgeInsets.only(right: 8, left: 2),
                          decoration: BoxDecoration(
                            color: modelColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (context.isCompact
                                    ? context.textTheme.bodySmall
                                    : context.textTheme.bodyMedium)
                                ?.copyWith(
                              color: context.colorScheme.tertiary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),

              // ── Action Footer: Tap to Chat CTA ────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  context.l10n.startConversation,
                  style: (context.isCompact
                          ? context.textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(
                    color: modelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
