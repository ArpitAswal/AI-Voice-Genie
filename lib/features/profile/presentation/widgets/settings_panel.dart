import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import 'profile_common_widgets.dart';

class ProfileSettingsPanel extends StatelessWidget {
  const ProfileSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfilePanel(
      child: Column(
        children: [
          ProfileListTile(
            icon: Icons.palette_outlined,
            title: context.l10n.theme,
            trailing: const _ThemeSwitcher(),
          ),
          const SizedBox(height: 10),
          ProfileListTile(
            icon: Icons.language_rounded,
            title: context.l10n.language,
            trailing: const _LanguagePopupButton(),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final effectiveType = themeProvider.currentThemeType;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            label: context.l10n.themeLight,
            isSelected: effectiveType == ThemeType.light,
            onTap: () =>
                context.read<ThemeProvider>().setTheme(ThemeType.light),
          ),
          _ThemeOption(
            label: context.l10n.themeDark,
            isSelected: effectiveType == ThemeType.dark,
            onTap: () => context.read<ThemeProvider>().setTheme(ThemeType.dark),
          ),
        ],
      ),
    );
  }
}

class _LanguagePopupButton extends StatelessWidget {
  const _LanguagePopupButton();

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLabel = localeProvider.isEnglish
        ? context.l10n.languageEn
        : context.l10n.languageHi;

    return PopupMenuButton<Locale>(
      color: ProfileUiHelpers.panelColor(context),
      tooltip: context.l10n.language,
      onSelected: (locale) => context.read<LocaleProvider>().setLocale(locale),
      elevation: 8,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => LocaleProvider.supportedLocales.map(
        (locale) {
          final isActive =
              locale.languageCode == localeProvider.locale.languageCode;
          return PopupMenuItem<Locale>(
            value: locale,
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale.languageCode == 'en'
                      ? context.l10n.languageEn
                      : context.l10n.languageHi,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? context.primaryColor
                        : context.textTheme.bodySmall?.color,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, color: context.primaryColor),
                ],
              ],
            ),
          );
        },
      ).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more_rounded,
              color: context.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.primaryColor : AppColors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? AppColors.white
                : (context.isDark
                    ? AppColors.darkTextPrimary.withValues(alpha: 0.76)
                    : AppColors.lightTextPrimary.withValues(alpha: 0.66)),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
