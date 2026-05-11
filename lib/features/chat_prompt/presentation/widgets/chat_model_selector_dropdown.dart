import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';

abstract final class ChatModelSelection {
  static AiProviderId? resolveSelectedProvider({
    required List<AiProviderId> availableProviders,
    required AiProviderId? selectedProvider,
    required String? preferredProviderId,
  }) {
    if (availableProviders.isEmpty) return null;

    if (selectedProvider != null &&
        availableProviders.contains(selectedProvider)) {
      return selectedProvider;
    }

    final preferredProvider = _providerFromId(preferredProviderId);
    if (preferredProvider != null &&
        availableProviders.contains(preferredProvider)) {
      return preferredProvider;
    }

    return availableProviders.first;
  }

  static AiProviderId? _providerFromId(String? providerId) {
    if (providerId == null || providerId == 'auto') return null;

    for (final provider in AiProviderId.values) {
      if (provider.id == providerId) return provider;
    }

    return null;
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
      color: context.isDark ? AppColors.cardDark : AppColors.white,
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
    final color =
        provider == null ? AppColors.grey : _ProviderStyle.colorFor(provider!);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding / 2,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider?.displayName ?? 'Genie v4.0',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isEnabled ? color : context.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isEnabled ? color : context.textTheme.bodySmall?.color,
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
    final color = _ProviderStyle.colorFor(provider);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            provider.displayName,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: context.isDark ? AppColors.white : AppColors.primaryLight,
            ),
          ),
        ),
        if (isSelected)
          Icon(
            Icons.check_rounded,
            color: color,
            size: 18,
          ),
      ],
    );
  }
}

abstract final class _ProviderStyle {
  static Color colorFor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAiBrand;
      case AiProviderId.gemini:
        return AppColors.geminiBrand;
      case AiProviderId.claude:
        return AppColors.claudeBrand;
    }
  }
}
