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
      color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 8,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.theme.dividerTheme.color ?? AppColors.lightDivider,
        ),
      ),
      itemBuilder: (context) => providers
          .map(
            (provider) => PopupMenuItem<AiProviderId>(
              value: provider,
              padding: EdgeInsets.zero,
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
    Color textColor =
        context.isDark ? AppColors.primaryDark : AppColors.primaryLight;
    Color bgColor = context.isDark ? AppColors.cardDark : AppColors.cardLight;
    return Container(
      width: double.infinity,
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(color: bgColor),
              color: bgColor,
              // Don't add border radius here since it should stretch to the edges of the popup menu which has its own border radius, but wait, the popup menu has rounded corners (16).
              // If the item reaches the top/bottom it might clip. But let's add a slight margin/borderRadius to make it look like a pill inside, or just fill.
              // Actually, the image shows it filling the space but with rounded corners at the top? No, the image shows it filling the whole top area.
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.displayName,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 21,
              color: textColor,
            ),
        ],
      ),
    );
  }
}
