import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../key_setup/presentation/api_key_provider.dart';

import '../../../usage/domain/usage_summary_model.dart';
import '../../../usage/presentation/usage_provider.dart';
import '../../../usage/presentation/widgets/budget_editor_sheet.dart';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ProfileSectionTitle(label: context.l10n.aiIntelligence),
                ElevatedButton.icon(
                  onPressed: () =>
                      AppRoutes.navigateTo(context, AppRoutes.apiKeyManagement),
                  style: context.theme.elevatedButtonTheme.style?.copyWith(
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 0.0))),
                  icon: Icon(Icons.key_rounded,
                      size: context.textTheme.headlineSmall?.fontSize),
                  label: Text(context.l10n.keys,
                      style: context.textTheme.headlineSmall
                          ?.copyWith(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 14),
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

// ── Model Intelligence Card ──────────────────────────────────────────────────

class _ModelIntelligenceCard extends StatelessWidget {
  final AiProviderId provider;

  const _ModelIntelligenceCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final color = provider.brandColor(context);

    return Consumer2<UsageProvider, AuthProvider>(
      builder: (context, usageProvider, authProvider, _) {
        final summary = usageProvider.summaryFor(provider);
        final hasBudget = summary?.hasBudget ?? false;
        final spent = usageProvider.lifetimeSpendFor(provider);
        final uid = authProvider.currentUser?.uid;

        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding,
              vertical: context.verticalSpacing),
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
              // ── Header Row ────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileProviderLogo(provider: provider),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      provider.displayName,
                      style: context.textTheme.headlineLarge
                          ?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Spend badge
                  _SpendBadge(
                    spent: spent,
                    summary: summary,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Usage stats ───────────────────────────────────────────────
              if (hasBudget) ...[
                _UsageStatsRow(
                    summary: summary,
                    currentMonthKey: usageProvider.currentMonthKey),
              ],

              // ── Budget section ────────────────────────────────────────────
              if (hasBudget) ...[
                _BudgetProgressBar(
                  spent: spent,
                  summary: summary,
                  color: color,
                  provider: provider,
                  uid: uid,
                ),
                const SizedBox(height: 14)
              ] else ...[
                _SetBudgetCta(
                  provider: provider,
                  uid: uid,
                  color: color,
                ),
                const SizedBox(height: 14),
              ],

              // ── Capabilities ──────────────────────────────────────────────
              Text(
                provider.pricingAndEfficiency(context.l10n),
                style: context.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Spend badge (top right of card) ─────────────────────────────────────────

class _SpendBadge extends StatelessWidget {
  final double spent;
  final UsageSummaryModel? summary;
  final Color color;

  const _SpendBadge({
    required this.spent,
    required this.summary,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = summary != null && summary!.hasBudget;

    if (hasBudget) {
      final fraction = summary!.remainingFraction() ?? 0.0;
      final isExceeded = summary!.isExceeded();

      int percentage = (fraction * 100).round();
      if (percentage == 100 && spent > 0 && !isExceeded) {
        percentage = 99;
      } else if (percentage == 0 &&
          spent.ceil() < summary!.totalBudgetUsd!.ceil()) {
        percentage = 1;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isExceeded
                ? context.l10n.usageBudgetExceeded
                : '$percentage% ${context.l10n.usageBudgetRemaining}',
            style: context.textTheme.labelSmall?.copyWith(
              color: isExceeded ? (context.isDark ? AppColors.darkError : AppColors.lightError) : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Usage stats row ──────────────────────────────────────────────────────────

class _UsageStatsRow extends StatelessWidget {
  final UsageSummaryModel? summary;
  final String currentMonthKey;

  const _UsageStatsRow({required this.summary, required this.currentMonthKey});

  @override
  Widget build(BuildContext context) {
    if (summary == null || !summary!.hasAnyActivity) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          context.l10n.usageNoActivity,
          style: context.textTheme.bodySmall,
        ),
      );
    }

    final s = summary!;
    final monthData = s.getMonth(currentMonthKey);
    final lifetimeTokens = s.lifetimeTokens();

    final padValue = (lifetimeTokens > 0 ||
            monthData.totalTokens > 0 ||
            monthData.requestCount > 0 ||
            monthData.imageCount > 0 ||
            monthData.pdfCount > 0)
        ? 8.0
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: padValue),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          if (lifetimeTokens > 0)
            _StatChip(
              icon: Icons.generating_tokens_outlined,
              label: '${_formatTokens(lifetimeTokens)} Lifetime Tokens',
            ),
          if (monthData.totalTokens > 0)
            _StatChip(
              icon: Icons.token_outlined,
              label: '${_formatTokens(monthData.totalTokens)} Current Month',
            ),
          if (monthData.requestCount > 0)
            _StatChip(
              icon: Icons.question_answer_outlined,
              label: '${monthData.requestCount} ${context.l10n.usageRequests}',
            ),
          if (monthData.imageCount > 0)
            _StatChip(
              icon: Icons.image_outlined,
              label: '${monthData.imageCount} ${context.l10n.usageImages}',
            ),
          if (monthData.pdfCount > 0)
            _StatChip(
                icon: Icons.picture_as_pdf_outlined,
                label: '${monthData.pdfCount} ${context.l10n.usagePdfs}')
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: context.textTheme.bodySmall?.fontSize,
            color: context.textTheme.bodySmall?.color),
        const SizedBox(width: 4),
        Text(label, style: context.textTheme.bodySmall)
      ],
    );
  }
}

// ── Budget progress bar ──────────────────────────────────────────────────────

class _BudgetProgressBar extends StatelessWidget {
  final double spent;
  final UsageSummaryModel? summary;
  final Color color;
  final AiProviderId provider;
  final String? uid;

  const _BudgetProgressBar(
      {required this.spent,
      required this.summary,
      required this.color,
      required this.provider,
      required this.uid});

  @override
  Widget build(BuildContext context) {
    if (summary == null || !summary!.hasBudget) return const SizedBox.shrink();

    final isExceeded = summary!.isExceeded();
    final fraction = (spent / summary!.totalBudgetUsd!).clamp(0.0, 1.0);
    final formattedBudget = '\$${summary!.totalBudgetUsd!.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: uid == null
                  ? null
                  : () async {
                      final result = await BudgetEditorSheet.show(
                        context,
                        provider: provider,
                        existingBudget: summary?.totalBudgetUsd,
                        existingUsed: summary?.alreadyUsedUsd,
                      );
                      if (result == true && context.mounted) {
                        // Reload usage data
                        context.read<UsageProvider>().loadForMonth(uid!);
                      }
                    },
              child: Icon(
                Icons.token_rounded,
                size: context.textTheme.bodySmall!.fontSize! * 2,
                color: context.primaryColor,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(context.l10n.usageEstimatedSpend,
                    style: context.textTheme.bodyLarge),
              ),
            ),
            Text(
              '\$${spent.toStringAsFixed(2)} ${context.l10n.usageOf} $formattedBudget',
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExceeded ? (context.isDark ? AppColors.darkError : AppColors.lightError) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            color: isExceeded ? (context.isDark ? AppColors.darkError : AppColors.lightError) : color,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}

// ── Set budget CTA ────────────────────────────────────────────────────────────

class _SetBudgetCta extends StatelessWidget {
  final AiProviderId provider;
  final String? uid;
  final Color color;

  const _SetBudgetCta({
    required this.provider,
    required this.uid,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uid == null
          ? null
          : () async {
              final result = await BudgetEditorSheet.show(
                context,
                provider: provider,
              );
              if (result == true && context.mounted) {
                context.read<UsageProvider>().loadForMonth(uid!);
              }
            },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing / 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.screenWidth * 0.02),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_chart_rounded, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              context.l10n.usageSetBudget,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activation panel ──────────────────────────────────────────────────────────

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
              const ProfileIconTile(icon: Icons.key, size: 36),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  (AiProviderId.values.length == inactiveProviders.length)
                      ? context.l10n.activateModels
                      : context.l10n.activateMoreModels,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (AiProviderId.values.length == inactiveProviders.length)
                ? context.l10n.activateModelsMessage
                : context.l10n.activateMoreModelsMessage,
            style: context.textTheme.bodySmall?.copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
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
    final color = provider.brandColor(context);

    return GestureDetector(
      onTap: () {
        AppRoutes.navigateTo(
          context,
          AppRoutes.apiKeyManagement,
          arguments: provider,
        );
      },
      child: Container(
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
      ),
    );
  }
}
