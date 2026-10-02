import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../features/usage/presentation/usage_provider.dart';

class ChatModelSelectorDropdown extends StatelessWidget {
  final List<AiProviderId> providers;
  final AiProviderId? selectedProvider;
  final ValueChanged<AiProviderId> onChanged;
  final bool isEnabled;

  const ChatModelSelectorDropdown({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.onChanged,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final canSelect = isEnabled && providers.isNotEmpty;
    final usageProvider = context.watch<UsageProvider>();

    return PopupMenuButton<AiProviderId>(
      enabled: canSelect,
      initialValue: selectedProvider,
      onSelected: onChanged,
      color: context.theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      itemBuilder: (context) => providers.map(
        (provider) {
          final summary = usageProvider.summaryFor(provider);
          final isExceeded = summary != null && summary.isExceeded();
          return PopupMenuItem<AiProviderId>(
            value: provider,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: _ProviderMenuItem(
              provider: provider,
              isSelected: provider == selectedProvider,
              isExceeded: isExceeded,
            ),
          );
        },
      ).toList(),
      child: _SelectorPill(
        provider: selectedProvider,
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final AiProviderId? provider;

  const _SelectorPill({
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = provider?.brandColor(context) ?? AppColors.primaryLight;
    final usageProvider = context.watch<UsageProvider>();
    final isExceeded = provider != null &&
        (usageProvider.summaryFor(provider!)?.isExceeded() ?? false);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding / 2,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isExceeded ? AppColors.lightError : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider?.displayName ?? AppLocalizations.of(context)!.selectModel,
            style: context.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if (isExceeded) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: Colors.white,
            ),
          ],
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _ProviderMenuItem extends StatelessWidget {
  final AiProviderId provider;
  final bool isSelected;
  final bool isExceeded;

  const _ProviderMenuItem({
    required this.provider,
    required this.isSelected,
    this.isExceeded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isExceeded
                ? AppColors.lightError
                : (context.isDark ? AppColors.white : AppColors.primaryLight),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.displayName,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      context.isDark ? AppColors.white : AppColors.primaryLight,
                ),
              ),
              if (isExceeded)
                Text(
                  AppLocalizations.of(context)!.usageBudgetExceeded,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.lightError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isSelected)
          Icon(
            Icons.check_rounded,
            color: context.isDark ? AppColors.white : AppColors.primaryLight,
            size: context.textTheme.bodyMedium?.fontSize,
          ),
      ],
    );
  }
}
