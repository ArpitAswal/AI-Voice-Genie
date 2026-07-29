import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

abstract final class ChatModelSelection {
  static AiProviderId? resolveSelectedProvider({
    required List<AiProviderId> availableProviders,
    required AiProviderId? selectedProvider,
    required AiProviderId? preferredProvider,
  }) {
    if (availableProviders.isEmpty) return null;

    if (selectedProvider != null &&
        availableProviders.contains(selectedProvider)) {
      return selectedProvider;
    }

    if (preferredProvider != null &&
        availableProviders.contains(preferredProvider)) {
      return preferredProvider;
    }

    return availableProviders.first;
  }
}

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
      itemBuilder: (context) => providers
          .map(
            (provider) => PopupMenuItem<AiProviderId>(
              value: provider,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _ProviderMenuItem(
                provider: provider,
                isSelected: provider == selectedProvider,
              ),
            ),
          )
          .toList(),
      child: _SelectorPill(
        provider: selectedProvider,
        isEnabled: canSelect,
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  final AiProviderId? provider;
  final bool isEnabled;

  const _SelectorPill({
    required this.provider,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = provider!.brandColor(context);

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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider?.displayName ?? AppLocalizations.of(context)!.selectModel,
            style: context.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
          ),
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

  const _ProviderMenuItem({
    required this.provider,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.white : AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            provider.displayName,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.primaryLight,
            ),
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
