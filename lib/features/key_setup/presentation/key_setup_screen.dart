import 'package:ai_voice_genie/core/constants/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/ai_provider_extensions.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/utils/widget_utils.dart';
import '../../../../core/widgets/app_alert_dialog.dart';

import 'api_key_provider.dart';

/// Production-grade API key setup and management screen.
///
/// Refactored for minimal boilerplate, strict WCAG 2.1 AA touch targets (48x48dp),
/// full string localization, and responsive adaptation across Compact, Medium, and Expanded viewports.
///
/// Supports two operating modes:
/// 1. Initial Setup ([isInitialSetup] == true): Immersive onboarding flow without AppBar.
///    Hero header, persistent docked action bar on mobile, requires >= 1 valid key to proceed.
/// 2. Settings Mode ([isInitialSetup] == false): Standard AppBar with back button,
///    compact subtitle context, inline key replacement, deletion, and console link navigation.
class KeySetupScreen extends StatefulWidget {
  final bool isInitialSetup;
  final AiProviderId? initialFocusProvider;

  const KeySetupScreen({
    super.key,
    this.isInitialSetup = true,
    this.initialFocusProvider,
  });

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  final _noScreenshot = NoScreenshot.instance;

  final Map<AiProviderId, GlobalKey> _cardKeys = {
    for (var p in AiProviderId.values) p: GlobalKey(),
  };

  void _scrollToProvider(AiProviderId provider) {
    final key = _cardKeys[provider];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.1, // Positions the card comfortably near the top
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _setScreenshotProtection(true);

    // Self-healing check: ensure keys are loaded into memory if not already present.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final keyProvider = context.read<ApiKeyProvider>();
      final success = await keyProvider.loadExistingKeysIfNeeded();
      if (!mounted) return;
      if (!success && keyProvider.loadError != null) {
        _showLoadErrorSnackbar(keyProvider.loadError!);
      }
    });
  }

  void _showLoadErrorSnackbar(String errorCode) {
    context.showError(
      context.l10n.translate(errorCode),
      actionLabel: context.l10n.retry,
      onAction: () async {
        final keyProvider = context.read<ApiKeyProvider>();
        final success = await keyProvider.loadExistingKeys();
        if (!mounted) return;
        if (!success && keyProvider.loadError != null) {
          _showLoadErrorSnackbar(keyProvider.loadError!);
        }
      },
    );
  }

  @override
  void dispose() {
    _setScreenshotProtection(false);
    super.dispose();
  }

  Future<void> _setScreenshotProtection(bool enable) async {
    try {
      if (enable) {
        await _noScreenshot.screenshotOff();
      } else {
        await _noScreenshot.screenshotOn();
      }
    } catch (e) {
      debugPrint('Screenshot protection error: $e');
    }
  }

  Future<void> _handleContinue() async {
    final keyProvider = context.read<ApiKeyProvider>();

    if (keyProvider.hasAtLeastOneValidKey) {
      keyProvider.completeSetup();
    }

    if (widget.isInitialSetup) {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.tabBar);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: widget.isInitialSetup
          ? null
          : AppBar(
              backgroundColor: context.theme.scaffoldBackgroundColor,
              surfaceTintColor: context.colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 1.5,
              leading: IconButton(
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: context.colorScheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                context.l10n.manageApiKeys,
                style: context.subHeaderStyle()?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface,
                    ),
              ),
              centerTitle: true,
            ),
      // Persistent docked action bar displayed for all Compact viewports (< 600dp) during initial setup
      bottomNavigationBar: (context.isCompact)
          ? _DockedActionBar(
              onContinue: _handleContinue,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            // debugPrint("constraint width: $width, height: $height");

            // Material 3 Responsive Viewport Dispatching:
            // 1. Phone landscape or severely height-constrained (< 500dp height): scrollable single column
            if (height < 540.0 && width < 600) {
              return _buildCompactLayout(context);
            }
            // 2. Expanded viewport (>= 840dp width): 2-pane master-detail workspace
            if (width >= 840.0) {
              return _buildExpandedLayout(context);
            }
            // 3. Medium viewport (600dp <= width < 840dp): centered tablet portrait layout
            if (width >= 600.0) {
              return _buildMediumLayout(context);
            }
            // 4. Compact viewport (< 600dp width): phone portrait layout
            return _buildCompactLayout(context);
          },
        ),
      ),
    );
  }

  // ── 1. Compact Viewport (< 600dp, Mobile Phone Portrait) ─────────────────────

  Widget _buildCompactLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: context.verticalSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextAwareHeader(isInitialSetup: widget.isInitialSetup),
          _SetupAndTrustHubCard(onProviderTap: _scrollToProvider),
          const SizedBox(height: 20.0),
          _ProviderCardsList(
            autoFocusProvider: widget.initialFocusProvider,
            cardKeys: _cardKeys,
          ),
          SizedBox(height: context.viewPadding.bottom + 16.0),
        ],
      ),
    );
  }

  // ── 2. Medium Viewport (600dp <= width < 840dp, Tablet Portrait) ─────────────

  Widget _buildMediumLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650.0),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContextAwareHeader(isInitialSetup: widget.isInitialSetup),
              _SetupAndTrustHubCard(onProviderTap: _scrollToProvider),
              const SizedBox(height: 24.0),
              _ProviderCardsList(
                autoFocusProvider: widget.initialFocusProvider,
                cardKeys: _cardKeys,
              ),
              const SizedBox(height: 24.0),
              Consumer<ApiKeyProvider>(
                builder: (context, keyProvider, _) => _ContinueButton(
                  isLoading: keyProvider.isCompletingSetup,
                  hasKeys: keyProvider.hasAtLeastOneValidKey,
                  onTap: _handleContinue,
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Expanded Viewport (width >= 840dp, Tablet Landscape / Desktop) ───────

  Widget _buildExpandedLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180.0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalSpacing,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Left Pane: Sticky Trust & Progress Hub (360dp) ─────────
              SizedBox(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 300, maxWidth: 400),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ContextAwareHeader(
                            isInitialSetup: widget.isInitialSetup),
                        _SetupAndTrustHubCard(onProviderTap: _scrollToProvider),
                        const SizedBox(height: 24.0),
                        Consumer<ApiKeyProvider>(
                          builder: (context, keyProvider, _) => _ContinueButton(
                            isLoading: keyProvider.isCompletingSetup,
                            hasKeys: keyProvider.hasAtLeastOneValidKey,
                            onTap: _handleContinue,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32.0),

              // ── Right Pane: Fluid Scrollable Provider Workspace ────────
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _ProviderCardsList(
                    autoFocusProvider: widget.initialFocusProvider,
                    cardKeys: _cardKeys,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE PROVIDER CARDS LIST
// =============================================================================

/// Displays vertical list of provider cards with normalized spacing.
class _ProviderCardsList extends StatelessWidget {
  final AiProviderId? autoFocusProvider;
  final Map<AiProviderId, GlobalKey>? cardKeys;

  const _ProviderCardsList({
    this.autoFocusProvider,
    this.cardKeys,
  });

  @override
  Widget build(BuildContext context) {
    final double spacing = context.isCompact ? 16.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: AiProviderId.values.map((provider) {
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: _ModernProviderCard(
            key: cardKeys?[provider] ?? ValueKey(provider),
            provider: provider,
            autoFocus: autoFocusProvider == provider,
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// CONTEXT-AWARE HEADER
// =============================================================================

/// Dynamic header supporting two distinct navigation architectures:
///
/// 1. **Initial Setup Flow** ([isInitialSetup] == true):
///    Renders an in-body hero header containing [context.l10n.keySetupTitle]
///    and an info row with [context.l10n.keySetupSubTitle].
///    Scrolls naturally with the body content so vertical screen space is yielded
///    to the cards as the user scrolls.
///
/// 2. **Settings Flow** ([isInitialSetup] == false):
///    Returns [const SizedBox.shrink()] to eliminate duplicate titles and empty vertical
///    padding, allowing the scrollable body to start immediately with the setup hub
///    beneath the pinned, elevated [AppBar].
class _ContextAwareHeader extends StatelessWidget {
  final bool isInitialSetup;

  const _ContextAwareHeader({required this.isInitialSetup});

  @override
  Widget build(BuildContext context) {
    if (!isInitialSetup) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.keySetupTitle,
          style: context.titleHeaderStyle()?.copyWith(
                color: context.colorScheme.primary,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: context.iconDense,
              color: context.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.keySetupSubTitle,
                style: context.descStyle()?.copyWith(
                      color: context.colorScheme.onSurface,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),
      ],
    );
  }
}

// =============================================================================
// UNIFIED SETUP & TRUST HUB (INTERACTIVE TABLE OF CONTENTS)
// =============================================================================

/// Unified setup and trust hub displaying live configuration progress,
/// an interactive quick-jump table of contents for AI providers,
/// and hardware-backed keystore security verification.
class _SetupAndTrustHubCard extends StatelessWidget {
  final ValueChanged<AiProviderId>? onProviderTap;

  const _SetupAndTrustHubCard({this.onProviderTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyProvider>(
      builder: (context, keyProvider, _) {
        final activeCount = keyProvider.validProviders.length;
        final totalCount = AiProviderId.values.length;
        final progressRatio = totalCount > 0 ? activeCount / totalCount : 0.0;
        final hasKeys = keyProvider.hasAtLeastOneValidKey;

        return Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Section A: Status & Progress Header
              _HubStatusHeader(
                activeCount: activeCount,
                totalCount: totalCount,
                hasKeys: hasKeys,
                progressRatio: progressRatio,
              ),
              const SizedBox(height: 12.0),

              // Section B: Interactive Provider Checklist / Table of Contents
              _HubChecklistSection(
                keyProvider: keyProvider,
                onProviderTap: onProviderTap,
              ),

              // Section C: 1px Theme Divider
              Divider(
                height: 24,
                thickness: 1,
                color: context.isDark
                    ? AppColors.darkDivider
                    : AppColors.lightDivider,
              ),

              // Section D: Hardware Security Footer
              const _HubSecuritySection(),
            ],
          ),
        );
      },
    );
  }
}

/// Header sub-widget displaying progress bar, configuration status icon, and active count badge.
class _HubStatusHeader extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final bool hasKeys;
  final double progressRatio;

  const _HubStatusHeader({
    required this.activeCount,
    required this.totalCount,
    required this.hasKeys,
    required this.progressRatio,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = hasKeys
        ? (context.isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
        : (context.isDark ? AppColors.darkWarning : AppColors.lightWarning);

    final badgeColor = activeCount > 0
        ? (context.isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
        : (context.isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              hasKeys ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: statusColor,
              size: context.iconStandard,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.configurationStatus,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.keysActiveProgress(activeCount, totalCount),
                style: context.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressRatio,
            minHeight: 8,
            backgroundColor:
                context.isDark ? AppColors.darkDivider : AppColors.lightDivider,
            valueColor: AlwaysStoppedAnimation<Color>(
              activeCount > 0
                  ? (context.isDark
                      ? AppColors.darkSuccess
                      : AppColors.lightSuccess)
                  : context.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Interactive table of contents checklist for jumping directly to provider cards.
class _HubChecklistSection extends StatelessWidget {
  final ApiKeyProvider keyProvider;
  final ValueChanged<AiProviderId>? onProviderTap;

  const _HubChecklistSection({
    required this.keyProvider,
    this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: AiProviderId.values.map((provider) {
        final isConfigured =
            keyProvider.statusFor(provider) == ApiKeyStatus.valid;
        final statusColor = isConfigured
            ? context.colorScheme.primary
            : context.colorScheme.tertiary;
        final statusLabel = isConfigured
            ? context.l10n.translate('configured')
            : context.l10n.notConfigured;

        return Semantics(
          button: true,
          label: '${provider.displayName}, $statusLabel',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap:
                  onProviderTap != null ? () => onProviderTap!(provider) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        isConfigured
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: context.iconDense,
                        color: isConfigured
                            ? context.colorScheme.primary
                            : context.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.displayName,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: isConfigured
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isConfigured
                                ? context.colorScheme.primary
                                : context.colorScheme.tertiary,
                          ),
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight:
                              isConfigured ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Integrated hardware security footer highlighting local keystore encryption.
class _HubSecuritySection extends StatelessWidget {
  const _HubSecuritySection();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 24,
          color: context.primaryColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.hardwareSecurity,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.keySecureNote,
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colorScheme.tertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DOCKED ACTION BAR (COMPACT MOBILE VIEWPORT)
// =============================================================================

/// Docked bottom action bar for compact phones to ensure high-priority CTA visibility.
class _DockedActionBar extends StatelessWidget {
  final VoidCallback onContinue;

  const _DockedActionBar({
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyProvider>(
      builder: (context, keyProvider, _) {
        final hasKeys = keyProvider.hasAtLeastOneValidKey;

        return Container(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            context.verticalSpacing,
            context.horizontalPadding,
            context.viewPadding.bottom + 8.0,
          ),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: context.theme.dividerTheme.color ??
                    (context.isDark
                        ? AppColors.darkDivider
                        : AppColors.lightDivider),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: _ContinueButton(
            isLoading: keyProvider.isCompletingSetup,
            hasKeys: hasKeys,
            onTap: onContinue,
          ),
        );
      },
    );
  }
}

// =============================================================================
// MODERN PROVIDER CARD (4-ZONE MODULAR ARCHITECTURE)
// =============================================================================

/// Modular Material 3 API provider card with 4 functional zones:
/// 1. Header (Logo, Name, Status Chip)
/// 2. Capability Wrap Badges
/// 3. Active Masked Key Display with 48dp Replace & Delete targets
/// 4. Prominent Console Link & Form Input with 48dp suffix targets
class _ModernProviderCard extends StatefulWidget {
  final AiProviderId provider;
  final bool autoFocus;

  const _ModernProviderCard({
    super.key,
    required this.provider,
    this.autoFocus = false,
  });

  @override
  State<_ModernProviderCard> createState() => _ModernProviderCardState();
}

class _ModernProviderCardState extends State<_ModernProviderCard> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _obscureKey = true;
  bool _isReplacing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleValidate() async {
    final apiKeyProvider = context.read<ApiKeyProvider>();
    if (apiKeyProvider.statusFor(widget.provider) == ApiKeyStatus.validating) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanKey = _keyController.text.trim();
    await apiKeyProvider.validateAndSaveKey(
      providerId: widget.provider,
      apiKey: cleanKey,
    );

    if (mounted &&
        apiKeyProvider.statusFor(widget.provider) == ApiKeyStatus.valid) {
      _keyController.clear();
      setState(() => _isReplacing = false);

      if (apiKeyProvider.validProviders.length == 1) {
        context
            .read<AiPreferencesProvider>()
            .setPreferredProvider(widget.provider);
      }
    }
  }

  Future<void> _handleDelete() async {
    final isConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.removeKey),
        content: Text(context.l10n.keyRemoveMsg),
        actions: [
          TextButton(
            onPressed: () => AppRoutes.pop(context, false),
            child: Text(
              context.l10n.cancel,
              style: context.buttonLabelStyle(),
            ),
          ),
          TextButton(
            onPressed: () => AppRoutes.pop(context, true),
            child: Text(
              context.l10n.delete,
              style: context.buttonLabelStyle()?.copyWith(
                    color: context.isDark
                        ? AppColors.darkError
                        : AppColors.lightError,
                  ),
            ),
          ),
        ],
      ),
    );

    if (isConfirm != true || !mounted) return;

    _keyController.clear();
    setState(() => _isReplacing = false);
    context.read<ApiKeyProvider>().deleteKey(providerId: widget.provider);
    MessageUtils.showSuccess(
      context,
      "${widget.provider.displayName} ${context.l10n.keyRemoveSuccess}",
    );
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _keyController.text = data!.text!.trim();
      if (mounted) {
        context.read<ApiKeyProvider>().clearError(widget.provider);
      }
    }
  }

  Future<void> _launchConsoleUrl() async {
    final uri = Uri.parse(_providerConsoleUrl(widget.provider));
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        context.showWarning(context.l10n.linkUnavailable);
      }
    }
  }

  void _cancelReplace() {
    setState(() {
      _isReplacing = false;
      _keyController.clear();
    });
    context.read<ApiKeyProvider>().clearError(widget.provider);
  }

  static String _providerConsoleUrl(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return 'https://platform.openai.com/api-keys';
      case AiProviderId.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case AiProviderId.claude:
        return 'https://console.anthropic.com/settings/keys';
    }
  }

  Color _borderColor(ApiKeyStatus status, AiProviderId provider) {
    switch (status) {
      case ApiKeyStatus.valid:
        return provider.brandColor(context);
      case ApiKeyStatus.invalid:
        return context.isDark ? AppColors.darkError : AppColors.lightError;
      case ApiKeyStatus.validating:
        return context.isDark ? AppColors.darkWarning : AppColors.lightWarning;
      case ApiKeyStatus.notAdded:
        return context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    }
  }

  /// Formats masked key into prefix...suffix monospace display (e.g., sk-...4aB9)
  String _formatMaskedKey(String? maskedKey) {
    if (maskedKey == null || maskedKey.isEmpty) return '••••••••••••';
    return maskedKey.replaceAll(RegExp(r'•{3,}'), '••••••');
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ApiKeyProvider, (ApiKeyStatus, String?, bool)>(
      selector: (_, provider) => (
        provider.statusFor(widget.provider),
        provider.errorFor(widget.provider),
        provider.isCloudSyncFailed(widget.provider),
      ),
      builder: (context, state, _) {
        final status = state.$1;
        final error = state.$2;
        final isSyncFailed = state.$3;
        final isValidating = status == ApiKeyStatus.validating;
        final isValid = status == ApiKeyStatus.valid;
        final showActiveState = isValid && !_isReplacing;
        final brandColor = widget.provider.brandColor(context);

        return Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor(status, widget.provider),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Zone 1: Header Row (Stepped Icon Logo + Name + Status Chip) ─
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProviderLogo(
                    provider: widget.provider,
                    size: context.iconAvatar,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.provider.displayName,
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: brandColor,
                      ),
                    ),
                  ),
                  _StatusChip(
                    status: status,
                    isSyncFailed: isSyncFailed,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Zone 2: Capability Badges (Horizontal Wrap) ─────────────
              _CapabilityTagCloud(provider: widget.provider),
              const SizedBox(height: 14),

              // ── Zone 3: Active Valid State ──────────────────────────────
              if (showActiveState) ...[
                Selector<ApiKeyProvider, String?>(
                  selector: (_, p) => p.maskedKeyFor(widget.provider),
                  builder: (context, maskedKey, _) => Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: brandColor.withValues(alpha: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.vpn_key_rounded,
                                size: context.iconDense,
                                color: brandColor,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _formatMaskedKey(maskedKey),
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: brandColor,
                                    letterSpacing: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 48×48dp hit-tested action cluster for Replace and Delete
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: context.l10n.replaceKeyHint,
                              icon: Icon(
                                Icons.sync_rounded,
                                size: context.iconStandard,
                                color: context.colorScheme.tertiary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isReplacing = true;
                                  _keyController.clear();
                                });
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _focusNode.requestFocus();
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: context.l10n.delete,
                              icon: Image.asset(
                                AppAssets.deleteIcon,
                                width: context.iconDense,
                                height: context.iconDense,
                              ),
                              onPressed: _handleDelete,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Cloud sync failure banner
                if (isSyncFailed) ...[
                  const SizedBox(height: 12),
                  _CloudSyncErrorBanner(
                    onRetry: () => context
                        .read<ApiKeyProvider>()
                        .retryCloudSync(widget.provider),
                  ),
                ],
              ],

              // ── Zone 4: Form Input State (Unconfigured / Replace Mode) ────
              if (!showActiveState) ...[
                if (_isReplacing) ...[
                  _ReplaceModeBanner(
                    brandColor: brandColor,
                    onCancel: _cancelReplace,
                  ),
                  const SizedBox(height: 10),
                ],

                // Prominent "Get API Key ↗" console helper link placed above input field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.keyHint,
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    InkResponse(
                      onTap: _launchConsoleUrl,
                      radius: 24,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.getApiKey,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: brandColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: brandColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Form(
                  key: _formKey,
                  child: context.themedTextField(
                    controller: _keyController,
                    focus: _focusNode,
                    obscureText: _obscureKey,
                    enabled: !isValidating,
                    hint: context.l10n.keyHint,
                    // 48×48dp touch targets for visibility toggle and paste buttons
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: _obscureKey ? 'Show key' : 'Hide key',
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: context.iconStandard,
                            color: context.colorScheme.tertiary,
                          ),
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Paste key',
                          icon: Icon(
                            Icons.content_paste_rounded,
                            size: context.iconStandard,
                            color: context.colorScheme.tertiary,
                          ),
                          onPressed: isValidating ? null : _handlePaste,
                        ),
                      ],
                    ),
                    validator: (value) => Validators.validateApiKey(
                      value,
                      providerName: widget.provider.displayName,
                      providerId: widget.provider,
                      context: context,
                    ),
                    onChanged: (_) {
                      context
                          .read<ApiKeyProvider>()
                          .clearError(widget.provider);
                    },
                  ),
                ),

                // Validation error row
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.lightError,
                        size: context.iconDense,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.l10n.translate(error),
                          style: context.legalTextStyle()?.copyWith(
                              color: context.isDark
                                  ? AppColors.darkError
                                  : AppColors.lightError,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Validate & Save Button (48dp height minimum touch target)
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48.0),
                    child: ElevatedButton(
                      onPressed: isValidating ? null : _handleValidate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 12.0,
                        ),
                      ),
                      child: isValidating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              _isReplacing
                                  ? context.l10n.updateKey
                                  : context.l10n.addKey,
                              style: context.buttonLabelStyle()?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// CAPABILITY TAG CLOUD (M3 HORIZONTAL WRAP BADGES)
// =============================================================================

/// Displays localized capability bullet points as a compact horizontal Wrap of chips.
class _CapabilityTagCloud extends StatelessWidget {
  final AiProviderId provider;

  const _CapabilityTagCloud({required this.provider});

  @override
  Widget build(BuildContext context) {
    final rawInfo = provider.capabilitiesInfo(context.l10n);
    final tags = rawInfo
        .split('\n')
        .map((s) => s.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: context.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: context.colorScheme.outline,
            ),
          ),
          child: Text(
            tag,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.tertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =============================================================================
// PROVIDER LOGO
// =============================================================================

/// Brand mark for AI providers using discrete stepped tokens.
class _ProviderLogo extends StatelessWidget {
  final AiProviderId provider;
  final double size;

  const _ProviderLogo({required this.provider, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: provider.brandGradient(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: provider.brandColor(context).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: FaIcon(
          _providerIcon(provider),
          color: AppColors.white,
          size: size * 0.55,
        ),
      ),
    );
  }

  FaIconData _providerIcon(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return FontAwesomeIcons.openai;
      case AiProviderId.gemini:
        return FontAwesomeIcons.gemini;
      case AiProviderId.claude:
        return FontAwesomeIcons.claude;
    }
  }
}

// =============================================================================
// STATUS CHIP
// =============================================================================

/// Status chip displaying connection state with standardized padding.
class _StatusChip extends StatelessWidget {
  final ApiKeyStatus status;
  final bool isSyncFailed;

  const _StatusChip({
    required this.status,
    this.isSyncFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ApiKeyStatus.valid && isSyncFailed) {
      final color =
          context.isDark ? AppColors.darkWarning : AppColors.lightWarning;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: color, size: context.iconDense),
            const SizedBox(width: 4),
            Text(
              context.l10n.syncFailed,
              style: context.legalTextStyle()?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    final (label, color, icon) = switch (status) {
      ApiKeyStatus.valid => (
          context.l10n.keyValid,
          context.isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
          Icons.check_circle_rounded,
        ),
      ApiKeyStatus.invalid => (
          context.l10n.keyInvalid,
          context.isDark ? AppColors.darkError : AppColors.lightError,
          Icons.cancel_rounded,
        ),
      ApiKeyStatus.validating => (
          context.l10n.keyValidating,
          context.isDark ? AppColors.darkWarning : AppColors.lightWarning,
          Icons.hourglass_top_rounded,
        ),
      ApiKeyStatus.notAdded => (
          context.l10n.noKeyAdded,
          context.isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          Icons.add_circle_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.legalTextStyle()?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// REPLACEMENT AND ERROR BANNERS
// =============================================================================

/// Banner indicating key replacement mode with dismiss button.
class _ReplaceModeBanner extends StatelessWidget {
  final Color brandColor;
  final VoidCallback onCancel;

  const _ReplaceModeBanner({
    required this.brandColor,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded,
              size: context.iconDense, color: context.colorScheme.onSurface),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.replaceKeyHint,
              style: context.legalTextStyle()?.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            onPressed: onCancel,
            icon: Icon(
              Icons.close_rounded,
              size: context.iconDense,
              color: context.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner warning when cloud sync fails with an interactive retry button and loading feedback.
class _CloudSyncErrorBanner extends StatefulWidget {
  final Future<void> Function() onRetry;

  const _CloudSyncErrorBanner({required this.onRetry});

  @override
  State<_CloudSyncErrorBanner> createState() => _CloudSyncErrorBannerState();
}

class _CloudSyncErrorBannerState extends State<_CloudSyncErrorBanner> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final warningColor =
        context.isDark ? AppColors.darkWarning : AppColors.lightWarning;

    return Container(
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warningColor.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: context.iconDense,
            color: warningColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.cloudSyncFailedDesc,
              style: context
                  .legalTextStyle()
                  ?.copyWith(color: warningColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: !_isRetrying,
            label: context.l10n.retry,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isRetrying ? null : _handleRetry,
                child: Center(
                  child: _isRetrying
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: warningColor,
                          ),
                        )
                      : Text(
                          context.l10n.retry,
                          style: context.buttonLabelStyle()?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: warningColor,
                              ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CONTINUE BUTTON
// =============================================================================

/// Primary action button for finishing or skipping API key setup.
class _ContinueButton extends StatelessWidget {
  final bool isLoading;
  final bool hasKeys;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.isLoading,
    required this.hasKeys,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String label = hasKeys ? context.l10n.done : context.l10n.skip;

    return SizedBox(
      width: double.infinity,
      child: context.themedElevatedButton(
        onPressed: isLoading ? null : onTap,
        label: label,
        textStyle: context
            .buttonLabelStyle()
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
