import 'package:ai_voice_genie/core/constants/app_constants.dart';
import 'package:ai_voice_genie/core/utils/loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../core/utils/widget_utils.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<ApiKeyProvider>().loadExistingKeys(uid);
      }
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.signOut),
        content: Text(context.l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => AppRoutes.pop(context, false),
            child: Text(context.l10n.cancel,
                style: TextStyle(color: context.primaryColor)),
          ),
          TextButton(
            onPressed: () => AppRoutes.pop(context, true),
            child: Text(
              context.l10n.signOut,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;
    LoadingOverlay.show(context, message: context.l10n.signingOut);
    await context.read<AuthProvider>().signOut();
    LoadingOverlay.hide();
    if (!mounted) return;
    MessageUtils.showSuccess(context, context.l10n.signOutSuccess);
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding,
              vertical: context.verticalSpacing),
          children: [
            Text(context.l10n.profile, style: context.textTheme.displayMedium),
            _ProfileHeader(user: user),
            const SizedBox(height: 24),
            _SectionTitle(label: context.l10n.appSettings),
            const SizedBox(height: 14),
            const _SettingsPanel(),
            const SizedBox(height: 24),
            _SectionTitle(label: context.l10n.aiIntelligence),
            const SizedBox(height: 14),
            const _AiIntelligenceSection(),
            const SizedBox(height: 24),
            _SectionTitle(label: context.l10n.support),
            const SizedBox(height: 14),
            _SupportPanel(onLogout: _handleLogout),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _photoController = TextEditingController(text: user?.photoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final success = await context.read<AuthProvider>().updateProfile(
          displayName: _nameController.text,
          photoUrl: _photoController.text,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      MessageUtils.showSuccess(context, context.l10n.profileUpdated);
      AppRoutes.pop(context);
    } else {
      context.showError(context.l10n.profileUpdateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.editProfile),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(context.horizontalPadding),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _EditableAvatarPreview(photoController: _photoController),
                  const SizedBox(height: 28),
                  context.themedTextField(
                    controller: _nameController,
                    label: context.l10n.translate('display_name'),
                    prefixIcon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.fieldRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  context.themedTextField(
                    controller: _photoController,
                    label: context.l10n.translate('photo_url_optional'),
                    prefixIcon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 28),
                  context.themedElevatedButton(
                    label: context.l10n.save,
                    onPressed: _isSaving ? null : _saveProfile,
                    isLoading: _isSaving,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim()
        : context.l10n.unAuthenticate;

    return Column(
      children: [
        _ProfileAvatar(
          displayName: displayName,
          photoUrl: user?.photoUrl ?? '',
          size: (context.screenHeight * 0.15),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: context.textTheme.headlineLarge,
        ),
        TextButton.icon(
          onPressed: () => AppRoutes.navigateTo(context, AppRoutes.profileEdit),
          style: TextButton.styleFrom(
              foregroundColor: context.textTheme.bodyLarge?.color),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.l10n.editProfile,
              style: context.textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _EditableAvatarPreview extends StatelessWidget {
  final TextEditingController photoController;

  const _EditableAvatarPreview({required this.photoController});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final displayName = user?.displayName ?? context.l10n.user;
    final photoUrl = photoController.text.trim().isNotEmpty
        ? photoController.text.trim()
        : user?.photoUrl ?? '';

    return _ProfileAvatar(
      displayName: displayName,
      photoUrl: photoUrl,
      size: context.isTablet ? 140 : 116,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String displayName;
  final String photoUrl;
  final double size;

  const _ProfileAvatar({
    required this.displayName,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (photoUrl.trim().isEmpty)
            ? null
            : context.isDark
                ? AppColors.darkVoiceGradient
                : AppColors.lightVoiceGradient,
        boxShadow: [
          BoxShadow(
            color: context.primaryColor.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor:
            context.isDark ? AppColors.cardDark : AppColors.cardLight,
        child: ClipOval(
          child: photoUrl.trim().isEmpty
              ? _InitialsAvatar(displayName: displayName)
              : Image.network(
                  photoUrl.trim(),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _InitialsAvatar(displayName: displayName),
                ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String displayName;

  const _InitialsAvatar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: context.isDark
            ? AppColors.primaryGradientLight
            : AppColors.darkVoiceGradient,
      ),
      child: Text(
        _initials(displayName),
        style: context.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontSize: 44,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: context.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 3,
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.palette_outlined,
            title: context.l10n.theme,
            trailing: const _ThemeSwitcher(),
          ),
          const SizedBox(height: 18),
          _SettingsRow(
            icon: Icons.language_rounded,
            title: context.l10n.language,
            trailing: const _LanguagePopupButton(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ThemeSwitcher — Light | Dark
// isSelected is driven by the STORED ThemeType, not the resolved effective
// theme. This means System is highlighted on first install (default) and
// whenever the user explicitly selects it again.
// ---------------------------------------------------------------------------
class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // Use the stored preference directly — no system resolution.
    final selected = themeProvider.currentThemeType;

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
            label: context.l10n.translate('theme_light'),
            isSelected: selected == ThemeType.light,
            onTap: () =>
                context.read<ThemeProvider>().setTheme(ThemeType.light),
          ),
          _ThemeOption(
            label: context.l10n.translate('theme_dark'),
            isSelected: selected == ThemeType.dark,
            onTap: () => context.read<ThemeProvider>().setTheme(ThemeType.dark),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LanguagePopupButton — opens a PopupMenuButton in-place at the trailing
// position. The active locale is shown with a checkmark. Selecting an option
// calls LocaleProvider.setLocale() and dismisses the popup automatically.
// ---------------------------------------------------------------------------
class _LanguagePopupButton extends StatelessWidget {
  const _LanguagePopupButton();

  static const List<Locale> _locales = [
    Locale('en'),
    Locale('hi'),
  ];

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final activeLocale = localeProvider.locale;
    final activeLabel = activeLocale.languageCode == 'en'
        ? context.l10n.translate('language_en')
        : context.l10n.translate('language_hi');

    return PopupMenuButton<Locale>(
      onSelected: (locale) => context.read<LocaleProvider>().setLocale(locale),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _ProfileHelpers.panelColor(context),
      elevation: 8,
      offset: const Offset(0, 40),
      itemBuilder: (_) => _locales.map((locale) {
        final isActive = locale.languageCode == activeLocale.languageCode;
        final label = locale.languageCode == 'en'
            ? context.l10n.translate('language_en')
            : context.l10n.translate('language_hi');
        return PopupMenuItem<Locale>(
          value: locale,
          child: Row(
            children: [
              Text(
                label,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? context.primaryColor : _ProfileHelpers.mutedTextColor(context),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded,
                    size: 18, color: context.primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              activeLabel,
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: _ProfileHelpers.mutedTextColor(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 18, color: _ProfileHelpers.mutedTextColor(context)),
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
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconTile(icon: icon),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _AiIntelligenceSection extends StatelessWidget {
  const _AiIntelligenceSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyProvider>(
      builder: (context, keyProvider, _) {
        final activeProviders = keyProvider.validProviders;
        List<AiProviderId> inactiveProviders = AiProviderId.values
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
    final color = _ProfileHelpers.providerColor(provider);
    final usage = _ProfileHelpers.providerUsage(provider);

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _ProfileHelpers.panelColor(context),
            _ProfileHelpers.panelColor(context),
            color.withValues(alpha: context.isDark ? 0.2 : 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: _ProfileHelpers.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProviderLogo(provider: provider, size: 48),
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
                style: context.textTheme.headlineMedium
                    ?.copyWith(color: _ProfileHelpers.mutedTextColor(context)),
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
                backgroundColor: Colors.grey.shade400),
          ),
          const SizedBox(height: 18),
          Text(
            provider.features,
            style: context.textTheme.bodyMedium?.copyWith(
              color: _ProfileHelpers.mutedTextColor(context),
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconTile(
                  icon: Icons.auto_awesome_motion_rounded, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.activateModels,
                        style: context.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.activateModelsMessage,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: _ProfileHelpers.mutedTextColor(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: inactiveProviders
                  .map((provider) => _InactiveModelChip(provider: provider))
                  .toList(),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => AppRoutes.navigateTo(
                context,
                AppRoutes.apiKeyManagement,
              ),
              icon: const Icon(Icons.key_rounded, size: 20),
              label: Text(context.l10n.manageKeys),
              style: context.theme.elevatedButtonTheme.style,
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
    final color = _ProfileHelpers.providerColor(provider);

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
          FaIcon(_ProfileHelpers.providerIcon(provider),
              color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            provider.displayName,
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportPanel extends StatelessWidget {
  final VoidCallback onLogout;

  const _SupportPanel({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.help_outline_rounded,
            title: context.l10n.helpCenter,
            onTap: () => context.showWarning('coming_soon'),
          ),
          const SizedBox(height: 18),
          _ActionRow(
            icon: Icons.info_outline_rounded,
            title: context.l10n.about,
            onTap: () => showAboutDialog(
              context: context,
              applicationName: context.l10n.appName,
              applicationVersion: AppConstants.appVersion,
            ),
          ),
          const SizedBox(height: 18),
          _ActionRow(
            icon: Icons.logout_rounded,
            title: context.l10n.signOut,
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          _IconTile(icon: icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _ProfileHelpers.mutedTextColor(context),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ProfileHelpers.panelColor(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: context.isDark
                ? AppColors.darkDivider
                : AppColors.lightDivider),
        boxShadow: _ProfileHelpers.softShadow(context),
      ),
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const _IconTile({required this.icon, this.color, this.size});

  final double iconSize = 36;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size ?? iconSize,
      height: size ?? iconSize,
      decoration: BoxDecoration(
        color: (color ?? context.primaryColor)
            .withValues(alpha: context.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: color ??
            (context.isDark ? AppColors.primaryLight : AppColors.primaryDark),
        size: (size ?? iconSize) * 0.7,
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  final AiProviderId provider;
  final double size;

  const _ProviderLogo({
    required this.provider,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _ProfileHelpers.providerGradient(provider),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          _ProfileHelpers.providerIcon(provider),
          color: AppColors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

// =============================================================================
// _ProfileHelpers — private static utility namespace.
//
// All view-layer helpers for this file live here. Using an abstract final
// class (not instantiable) keeps them out of the global namespace while
// remaining easily accessible as _ProfileHelpers.method().
// =============================================================================
abstract final class _ProfileHelpers {
  // ── Provider branding ───────────────────────────────────────────────────

  static Color providerColor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAiBrand;
      case AiProviderId.gemini:
        return AppColors.geminiBrand;
      case AiProviderId.claude:
        return AppColors.claudeBrand;
    }
  }

  static Gradient providerGradient(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAIGradient;
      case AiProviderId.gemini:
        return AppColors.geminiGradient;
      case AiProviderId.claude:
        return AppColors.claudeGradient;
    }
  }

  static FaIconData providerIcon(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return FontAwesomeIcons.openai;
      case AiProviderId.gemini:
        return FontAwesomeIcons.gemini;
      case AiProviderId.claude:
        return FontAwesomeIcons.claude;
    }
  }

  /// Placeholder usage percentage (replace with real data when available).
  static double providerUsage(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return 0.72;
      case AiProviderId.gemini:
        return 0.64;
      case AiProviderId.claude:
        return 0.81;
    }
  }

  // ── Theme-aware surface helpers ──────────────────────────────────────────

  static Color panelColor(BuildContext context) =>
      context.isDark ? AppColors.cardDark : AppColors.cardLight;

  static Color mutedTextColor(BuildContext context) => context.isDark
      ? AppColors.darkTextPrimary.withValues(alpha: 0.66)
      : AppColors.lightTextPrimary.withValues(alpha: 0.58);

  static List<BoxShadow> softShadow(BuildContext context) => [
        BoxShadow(
          color:
              AppColors.black.withValues(alpha: context.isDark ? 0.12 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ];
}
