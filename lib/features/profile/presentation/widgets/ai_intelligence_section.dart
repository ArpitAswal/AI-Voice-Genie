import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../key_setup/presentation/api_key_provider.dart';
import '../../../usage/domain/usage_budget_model.dart';
import '../../../usage/domain/usage_summary_model.dart';
import '../../../usage/presentation/usage_provider.dart';
import '../../../usage/presentation/widgets/budget_editor_sheet.dart';
import 'profile_common_widgets.dart';

class ProfileAiIntelligenceSection extends StatefulWidget {
  const ProfileAiIntelligenceSection({super.key});

  @override
  State<ProfileAiIntelligenceSection> createState() =>
      _ProfileAiIntelligenceSectionState();
}

class _ProfileAiIntelligenceSectionState
    extends State<ProfileAiIntelligenceSection> {
  final _noScreenshot = NoScreenshot.instance;

  @override
  void initState() {
    super.initState();
    _secureScreen();
  }

  Future<void> _secureScreen() async {
    await _noScreenshot.screenshotOff();
  }

  @override
  void dispose() {
    _noScreenshot.screenshotOn();
    super.dispose();
  }

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
                    style: context.theme.elevatedButtonTheme.style,
                    icon: const Icon(Icons.key_rounded, size: 20),
                    label: Text(context.l10n.keys),
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
    final color = ProfileUiHelpers.providerColor(provider);

    return Consumer2<UsageProvider, AuthProvider>(
      builder: (context, usageProvider, authProvider, _) {
        final summary = usageProvider.summaryFor(provider);
        final budget = usageProvider.budgetFor(provider);
        final spent = usageProvider.spendFor(provider);
        final uid = authProvider.currentUser?.uid;

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
              // ── Header Row ────────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileProviderLogo(provider: provider, size: 48),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      provider.displayName,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Spend badge
                  _SpendBadge(
                    spent: spent,
                    budget: budget,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Usage stats ───────────────────────────────────────────────
              _UsageStatsRow(summary: summary),
              const SizedBox(height: 14),

              // ── Budget section ────────────────────────────────────────────
              if (budget != null && budget.hasBudget) ...[
                _BudgetProgressBar(
                  spent: spent,
                  budget: budget,
                  color: color,
                ),
                _BudgetActions(
                  provider: provider,
                  budget: budget,
                  uid: uid,
                ),
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
                provider.features,
                style: context.textTheme.bodySmall?.copyWith(
                  color: ProfileUiHelpers.mutedTextColor(context),
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
  final UsageBudgetModel? budget;
  final Color color;

  const _SpendBadge({
    required this.spent,
    required this.budget,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget != null && budget!.hasBudget;

    if (hasBudget) {
      final fraction = budget!.remainingFraction(spent) ?? 0.0;
      final isExceeded = budget!.isExceeded(spent);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isExceeded
                ? context.l10n.usageBudgetExceeded
                : '${(fraction * 100).round()}% ${context.l10n.usageBudgetRemaining}',
            style: context.textTheme.labelSmall?.copyWith(
              color: isExceeded ? AppColors.lightError : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    // No budget — just show spend
    if (spent > 0) {
      return Text(
        '\$${spent.toStringAsFixed(2)}',
        style: context.textTheme.headlineMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Usage stats row ──────────────────────────────────────────────────────────

class _UsageStatsRow extends StatelessWidget {
  final UsageSummaryModel? summary;

  const _UsageStatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null || !summary!.hasActivity) {
      return Text(
        context.l10n.usageNoActivity,
        style: context.textTheme.bodySmall?.copyWith(
          color: ProfileUiHelpers.mutedTextColor(context),
        ),
      );
    }

    final s = summary!;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (s.totalTokens > 0)
          _StatChip(
            icon: Icons.token_rounded,
            label: '${_formatTokens(s.totalTokens)} ${context.l10n.usageTokens}',
          ),
        if (s.requestCount > 0)
          _StatChip(
            icon: Icons.chat_bubble_outline_rounded,
            label: '${s.requestCount} ${context.l10n.usageRequests}',
          ),
        if (s.imageCount > 0)
          _StatChip(
            icon: Icons.image_outlined,
            label: '${s.imageCount} ${context.l10n.usageImages}',
          ),
        if (s.pdfCount > 0)
          _StatChip(
            icon: Icons.picture_as_pdf_outlined,
            label: '${s.pdfCount} ${context.l10n.usagePdfs}',
          ),
      ],
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
        Icon(icon, size: 13,
            color: ProfileUiHelpers.mutedTextColor(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: ProfileUiHelpers.mutedTextColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Budget progress bar ──────────────────────────────────────────────────────

class _BudgetProgressBar extends StatelessWidget {
  final double spent;
  final UsageBudgetModel budget;
  final Color color;

  const _BudgetProgressBar({
    required this.spent,
    required this.budget,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = budget.isExceeded(spent);
    final fraction = (spent / budget.monthlyBudgetUsd!).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.usageEstimatedSpend,
              style: context.textTheme.bodySmall?.copyWith(
                color: ProfileUiHelpers.mutedTextColor(context),
              ),
            ),
            Text(
              '\$${spent.toStringAsFixed(2)} ${context.l10n.usageOf} ${budget.formattedBudget}',
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExceeded ? AppColors.lightError : null,
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
            color: isExceeded ? AppColors.lightError : color,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}

// ── Budget management actions ─────────────────────────────────────────────────

class _BudgetActions extends StatelessWidget {
  final AiProviderId provider;
  final UsageBudgetModel budget;
  final String? uid;

  const _BudgetActions({
    required this.provider,
    required this.budget,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: uid == null
          ? null
          : () async {
              final result = await BudgetEditorSheet.show(
                context,
                provider: provider,
                existingBudget: budget.monthlyBudgetUsd,
              );
              if (result == true && context.mounted) {
                // Reload usage data
                context.read<UsageProvider>().loadForMonth(uid!);
              }
            },
      icon: Icon(Icons.token_rounded, size: context.textTheme.bodySmall!.fontSize! * 2, color: context.primaryColor,),
      label: Text(
        'Edit budget',
        style: context.textTheme.bodySmall,
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
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
              const ProfileIconTile(
                  icon: Icons.key, size: 36),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  (AiProviderId.values.length == inactiveProviders.length) ? context.l10n.activateModels : context.l10n.activateMoreModels,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (AiProviderId.values.length == inactiveProviders.length) ? context.l10n.activateModelsMessage : context.l10n.activateMoreModelsMessage,
            style: context.textTheme.bodySmall?.copyWith(
              color: ProfileUiHelpers.mutedTextColor(context),
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
          FaIcon(ProfileUiHelpers.providerIcon(provider), color: color, size: 16),
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
