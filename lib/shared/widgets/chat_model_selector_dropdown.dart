import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../features/key_setup/presentation/api_key_provider.dart';
import '../../features/usage/presentation/usage_provider.dart';

class ChatModelSelectorDropdown extends StatelessWidget {
  final List<AiProviderId> providers;
  final AiProviderId? selectedProvider;
  final ValueChanged<AiProviderId> onChanged;
  final bool isEnabled;
  final bool showStatusIndicators;

  const ChatModelSelectorDropdown({
    super.key,
    required this.providers,
    required this.selectedProvider,
    required this.onChanged,
    required this.isEnabled,
    this.showStatusIndicators = true,
  });

  @override
  Widget build(BuildContext context) {
    final canSelect = isEnabled && providers.isNotEmpty;
    final usageProvider = context.watch<UsageProvider>();
    final apiKeyProvider = context.watch<ApiKeyProvider>();

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
          final summary = showStatusIndicators
              ? usageProvider.summaryFor(provider)
              : null;
          final isExceeded =
              showStatusIndicators && summary != null && summary.isExceeded();
          final hasKey = !showStatusIndicators ||
              apiKeyProvider.validProviders.contains(provider);
          return PopupMenuItem<AiProviderId>(
            value: provider,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: _ProviderMenuItem(
              provider: provider,
              isSelected: provider == selectedProvider,
              isExceeded: isExceeded,
              hasKey: hasKey,
            ),
          );
        },
      ).toList(),
      child: _SelectorPill(
        provider: selectedProvider,
        showStatusIndicators: showStatusIndicators,
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final AiProviderId? provider;
  final bool showStatusIndicators;

  const _SelectorPill({
    required this.provider,
    this.showStatusIndicators = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = provider?.brandColor(context) ?? AppColors.primaryLight;
    final usageProvider = context.watch<UsageProvider>();
    final apiKeyProvider = context.watch<ApiKeyProvider>();
    final l10n = AppLocalizations.of(context)!;

    final isExceeded = showStatusIndicators &&
        provider != null &&
        (usageProvider.summaryFor(provider!)?.isExceeded() ?? false);
    final hasKey = !showStatusIndicators ||
        (provider != null && apiKeyProvider.validProviders.contains(provider!));

    final tooltipMessage = (!showStatusIndicators || provider == null)
        ? null
        : !hasKey
            ? '${provider!.displayName}: ${l10n.noKeyForModel}'
            : isExceeded
                ? l10n.chatProviderLimitReached(provider!.displayName)
                : null;

    final pillWidget = Container(
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
              color: isExceeded
                  ? AppColors.lightError
                  : (!hasKey ? AppColors.lightWarning : Colors.white),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider?.displayName ?? l10n.selectModel,
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
          ] else if (!hasKey) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.vpn_key_off_rounded,
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

    if (tooltipMessage != null) {
      return Tooltip(
        message: tooltipMessage,
        child: pillWidget,
      );
    }

    return pillWidget;
  }
}

class _ProviderMenuItem extends StatelessWidget {
  final AiProviderId provider;
  final bool isSelected;
  final bool isExceeded;
  final bool hasKey;

  const _ProviderMenuItem({
    required this.provider,
    required this.isSelected,
    this.isExceeded = false,
    this.hasKey = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isExceeded
                ? AppColors.lightError
                : (!hasKey
                    ? AppColors.lightWarning
                    : (context.isDark
                        ? AppColors.white
                        : AppColors.primaryLight)),
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
                  l10n.usageBudgetExceeded,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.lightError,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (!hasKey)
                Text(
                  l10n.noKeyForModel,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.lightWarning,
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
          )
        else if (isExceeded)
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.lightError,
            size: 16,
          )
        else if (!hasKey)
          const Icon(
            Icons.vpn_key_off_rounded,
            color: AppColors.lightWarning,
            size: 16,
          ),
      ],
    );
  }
}
