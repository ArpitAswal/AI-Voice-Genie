import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../key_setup/presentation/api_key_provider.dart';
import 'profile_common_widgets.dart';

class ProfileAiIntelligenceSection extends StatelessWidget {
  const ProfileAiIntelligenceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyProvider>(
      builder: (context, keyProvider, _) {
        final activeProviders = keyProvider.validProviders;
        final inactiveProviders = AiProviderId.values
            .where((provider) => !activeProviders.contains(provider))
            .toList();

        return Column(
          children: [
            if (activeProviders.isEmpty)
              _ActivationPanel(inactiveProviders: inactiveProviders)
            else ...[
              ...activeProviders.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ModelIntelligenceCard(provider: provider),
                ),
              ),
              if (inactiveProviders.isNotEmpty)
                _ActivationPanel(inactiveProviders: inactiveProviders),
            ],
          ],
        );
      },
    );
  }
}

class _ModelIntelligenceCard extends StatelessWidget {
  final AiProviderId provider;

  const _ModelIntelligenceCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = ProfileUiHelpers.providerColor(provider);
    final usage = ProfileUiHelpers.providerUsage(provider);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProfileUiHelpers.panelColor(context),
            ProfileUiHelpers.panelColor(context),
            color.withValues(alpha: context.isDark ? 0.2 : 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: ProfileUiHelpers.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileProviderLogo(provider: provider, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.translate('enabled'),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(usage * 100).round()}%',
                style: context.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: usage,
              minHeight: 12,
              color: color,
              backgroundColor: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            provider.features,
            style: context.textTheme.bodyMedium?.copyWith(
              color: ProfileUiHelpers.mutedTextColor(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationPanel extends StatelessWidget {
  final List<AiProviderId> inactiveProviders;

  const _ActivationPanel({required this.inactiveProviders});

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ProfileIconTile(icon: Icons.auto_awesome_motion_rounded, size: 48,),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.activateModels,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.activateModelsMessage,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: ProfileUiHelpers.mutedTextColor(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (inactiveProviders.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: inactiveProviders
                  .map((provider) => _InactiveModelChip(provider: provider))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => AppRoutes.navigateTo(
                context,
                AppRoutes.apiKeyManagement,
              ),
              style: context.theme.elevatedButtonTheme.style,
              icon: const Icon(Icons.key_rounded, size: 20),
              label: Text(context.l10n.manageApiKeys),
            ),
          ),
        ],
      ),
    );
  }
}

class _InactiveModelChip extends StatelessWidget {
  final AiProviderId provider;

  const _InactiveModelChip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = ProfileUiHelpers.providerColor(provider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(ProfileUiHelpers.providerIcon(provider),
              color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            provider.displayName,
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          )
        ],
      ),
    );
  }
}
