import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:ai_voice_genie/features/key_setup/presentation/api_key_provider.dart';
import 'package:ai_voice_genie/core/preferences/ai_preferences_provider.dart';
import 'package:ai_voice_genie/core/extensions/ai_provider_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_alert_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/status_message_utils.dart';

/// API key setup screen shown once after first sign-in.
///
/// Displays three provider cards (ChatGPT, Gemini, Claude).
/// Each card allows the user to paste, validate, and save their key.
/// At least one valid key is required to proceed to TabBarScreen.
///
/// Can also be accessed from Settings for key management (Phase 8).
class KeySetupScreen extends StatefulWidget {
  /// Whether this is the initial setup (true) or accessed from Settings (false)
  final bool isInitialSetup;

  /// The provider to automatically focus when the screen opens (e.g. from deep link or button)
  final AiProviderId? initialFocusProvider;

  const KeySetupScreen(
      {super.key, this.isInitialSetup = true, this.initialFocusProvider});

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  final noScreenshot = NoScreenshot.instance;

  @override
  void initState() {
    super.initState();
    switchScreenShotState(true);

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
    switchScreenShotState(false);
    super.dispose();
  }

  Future<void> switchScreenShotState(bool value) async {
    if (value) {
      // Disable screenshots & screen recording
      await noScreenshot.screenshotOff();
    } else {
      // Re-enable screenshots & screen recording
      await noScreenshot.screenshotOn();
    }
  }

  Future<void> _handleContinue() async {
    final keyProvider = context.read<ApiKeyProvider>();

    if (keyProvider.hasAtLeastOneValidKey) {
      // Ensure completion in background if not already completed
      keyProvider.completeSetup();
    }
    // Instant smooth navigation without blocking on full-screen spinner
    AppRoutes.navigateAndRemoveUntil(context, AppRoutes.tabBar);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;

    return Scaffold(
      appBar: widget.isInitialSetup
          ? null // No app bar on initial setup — full immersive flow
          : AppBar(
              title: Text(context.l10n.manageApiKeys),
            ),
      body: SafeArea(
        child: Consumer<ApiKeyProvider>(
          builder: (context, keyProvider, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
                vertical: isTablet ? 32 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isInitialSetup) ...[
                    _SetupHeader(isTablet: isTablet),
                    SizedBox(height: isTablet ? 32 : 24),
                  ],

                  // ── Three Provider Cards ───────────────────────────
                  ...AiProviderId.values.map(
                    (provider) => Padding(
                      padding: EdgeInsets.only(
                        bottom: isTablet ? 20 : 16,
                      ),
                      child: _ProviderKeyCard(
                        provider: provider,
                        isTablet: isTablet,
                        autoFocus: widget.initialFocusProvider == provider,
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 8 : 4),

                  // ── Helper note ────────────────────────────────────
                  _SecurityNote(isTablet: isTablet),

                  // ── Continue Button ──────────────────────────────────────────
                  if (widget.isInitialSetup) ...[
                    SizedBox(height: isTablet ? 36 : 24),
                    _ContinueButton(
                      isTablet: isTablet,
                      isLoading: keyProvider.isCompletingSetup,
                      hasKeys: keyProvider.hasAtLeastOneValidKey,
                      onTap: _handleContinue,
                    )
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SETUP HEADER
// =============================================================================

class _SetupHeader extends StatelessWidget {
  final bool isTablet;
  const _SetupHeader({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keySetupTitle,
          style: context.textTheme.displaySmall,
        ),
        SizedBox(height: isTablet ? 8 : 6),
        Text(
          context.l10n.keySetupSubTitle,
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}

// =============================================================================
// PROVIDER KEY CARD
// =============================================================================

class _ProviderKeyCard extends StatefulWidget {
  final AiProviderId provider;
  final bool isTablet;
  final bool autoFocus;

  const _ProviderKeyCard({
    required this.provider,
    required this.isTablet,
    this.autoFocus = false,
  });

  @override
  State<_ProviderKeyCard> createState() => _ProviderKeyCardState();
}

class _ProviderKeyCardState extends State<_ProviderKeyCard> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _obscureKey = true;

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

  /// Validate and save key handler.
  ///
  /// Flow:
  /// 1. Clears any existing error on the card.
  /// 2. Executes form validation (length and provider mismatch checks).
  /// 3. Trims key input to prevent whitespace/newline corruption.
  /// 4. Dispatches validation and save to ApiKeyProvider.
  /// 5. On validation success: clears _keyController to eliminate sensitive plaintext from memory
  ///    and auto-sets preferred provider if this is the user's first valid key.
  Future<void> _handleValidate() async {
    final apiKeyProvider = context.read<ApiKeyProvider>();
    // Synchronous guard against rapid double-taps
    if (apiKeyProvider.statusFor(widget.provider) == ApiKeyStatus.validating) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanKey = _keyController.text.trim();
    await apiKeyProvider.validateAndSaveKey(
      providerId: widget.provider,
      apiKey: cleanKey,
    );

    // If key became valid:
    if (mounted &&
        apiKeyProvider.statusFor(widget.provider) == ApiKeyStatus.valid) {
      // Clear controller to wipe sensitive plaintext from memory
      _keyController.clear();

      // Auto-set as default preferred provider if this is the very first key added
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
                    style: TextStyle(color: context.primaryColor),
                  ),
                ),
                TextButton(
                  onPressed: () => AppRoutes.pop(context, true),
                  child: Text(
                    context.l10n.delete,
                    style: const TextStyle(color: AppColors.lightError),
                  ),
                ),
              ],
            ));

    if (isConfirm != true || !mounted) return;

    _keyController.clear();
    context.read<ApiKeyProvider>().deleteKey(providerId: widget.provider);
    MessageUtils.showSuccess(context,
        "${widget.provider.displayName} ${context.l10n.keyRemoveSuccess}");
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _keyController.text = data!.text!.trim();
      // Clear error when user pastes new content
      if (mounted) {
        context.read<ApiKeyProvider>().clearError(widget.provider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ApiKeyProvider, (ApiKeyStatus, String?, bool)>(
      // Only rebuild this card when its own provider's state changes
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

        return Container(
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor(status, widget.provider),
              width: isValid ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card Header: provider logo + name + status chip ────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _ProviderLogo(
                      provider: widget.provider,
                      size: widget.isTablet ? 40 : 36,
                    ),
                    SizedBox(width: widget.isTablet ? 14 : 10),
                    Expanded(
                      child: Text(
                        widget.provider.displayName,
                        style: context.textTheme.headlineMedium?.copyWith(
                            color: widget.provider.brandColor(context)),
                      ),
                    ),
                    _StatusChip(
                      status: status,
                      isTablet: widget.isTablet,
                      isSyncFailed: isSyncFailed,
                    ),
                  ],
                ),

                SizedBox(height: widget.isTablet ? 14 : 10),

                Text(
                  widget.provider.technicalSpecs(context.l10n),
                  style: context.textTheme.bodySmall,
                ),

                // ── Key input — hidden when valid ──────────────────────────
                if (!isValid) ...[
                  SizedBox(height: widget.isTablet ? 16 : 12),

                  Form(
                    key: _formKey,
                    child: context.themedTextField(
                      controller: _keyController,
                      focus: _focusNode,
                      obscureText: _obscureKey,
                      enabled: !isValidating,
                      hint: context.l10n.keyHint,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle visibility
                          IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
                            padding: EdgeInsets.zero,
                          ),
                          // Paste button
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.content_paste_rounded,
                              size: 20,
                            ),
                            onPressed: isValidating ? null : _handlePaste,
                            tooltip: context.l10n.paste,
                          ),
                        ],
                      ),
                      validator: (value) {
                        return Validators.validateApiKey(
                          value,
                          providerName: widget.provider.displayName,
                          providerId: widget.provider,
                          context: context,
                        );
                      },
                      onChanged: (_) {
                        // Clear inline error as user types
                        context
                            .read<ApiKeyProvider>()
                            .clearError(widget.provider);
                      },
                    ),
                  ),

                  // ── Inline error from validation ────────────────────────
                  if (error != null && error.isNotEmpty) ...[
                    SizedBox(height: widget.isTablet ? 8 : 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.lightError,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.translate(error),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: AppColors.lightError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (error == null || error.isEmpty) ...[
                    SizedBox(height: widget.isTablet ? 8 : 2)
                  ],

                  // ── Provider link + Validate button row ─────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Link to get a key
                      Expanded(
                        child: Text(
                          _getKeyText(widget.provider),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: widget.provider.brandColor(context),
                          ),
                        ),
                      ),
                      SizedBox(width: context.isTablet ? 16 : 6),
                      ElevatedButton(
                        onPressed: isValidating ? null : _handleValidate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.provider.brandColor(context),
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.isTablet ? 24 : 10,
                              vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isValidating
                            ? SizedBox(
                                height: widget.isTablet ? 34 : 28,
                                width: widget.isTablet ? 34 : 28,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                context.l10n.addKey,
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],

                // ── Valid state — show masked key ───────────────────────────
                if (isValid) ...[
                  Selector<ApiKeyProvider, String?>(
                    selector: (_, p) => p.maskedKeyFor(widget.provider),
                    builder: (context, maskedKey, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              maskedKey ?? '••••••••••••',
                              style: context.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: widget.provider.brandColor(context),
                                letterSpacing: 1,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          GestureDetector(
                            onTap: _handleDelete,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.isTablet ? 10 : 8,
                                vertical: context.isTablet ? 5 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.provider
                                    .brandColor(context)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.l10n.deleteKey,
                                style: context.textTheme.labelSmall?.copyWith(
                                    color: widget.provider.brandColor(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSyncFailed) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (context.isDark
                                ? AppColors.darkWarning
                                : AppColors.lightWarning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (context.isDark
                                  ? AppColors.darkWarning
                                  : AppColors.lightWarning)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 16,
                            color: context.isDark
                                ? AppColors.darkWarning
                                : AppColors.lightWarning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cloud sync failed. Active on this device only.',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.isDark
                                    ? AppColors.darkWarning
                                    : AppColors.lightWarning,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context
                                .read<ApiKeyProvider>()
                                .retryCloudSync(widget.provider),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                'Retry',
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.isDark
                                      ? AppColors.darkWarning
                                      : AppColors.lightWarning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helper Methods ──────────────────────────────────────────────────────────

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

  String _getKeyText(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return context.l10n.openAIKey;
      case AiProviderId.gemini:
        return context.l10n.geminiAIKey;
      case AiProviderId.claude:
        return context.l10n.claudeAIkey;
    }
  }
}

// =============================================================================
// PROVIDER LOGO
// =============================================================================

class _ProviderLogo extends StatelessWidget {
  final AiProviderId provider;
  final double size;

  const _ProviderLogo({required this.provider, required this.size});

  @override
  Widget build(BuildContext context) {
    Gradient gradColor;

    switch (provider) {
      case AiProviderId.openAi:
        gradColor = AppColors.openAIGradient;
        break;
      case AiProviderId.gemini:
        gradColor = AppColors.geminiGradient;
        break;
      case AiProviderId.claude:
        gradColor = AppColors.claudeGradient;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradColor,
        borderRadius: BorderRadius.circular(size * 0.5),
      ),
      child: Center(
        child: FaIcon(_providerIcon(provider),
            color: AppColors.white, size: size * 0.6),
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

class _StatusChip extends StatelessWidget {
  final ApiKeyStatus status;
  final bool isTablet;
  final bool isSyncFailed;

  const _StatusChip({
    required this.status,
    required this.isTablet,
    this.isSyncFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ApiKeyStatus.valid && isSyncFailed) {
      final color =
          context.isDark ? AppColors.darkWarning : AppColors.lightWarning;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 10 : 8,
          vertical: isTablet ? 5 : 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: color, size: isTablet ? 14 : 12),
            const SizedBox(width: 4),
            Text(
              'Sync Failed',
              style: context.textTheme.labelSmall?.copyWith(
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
          Icons.check_circle_rounded
        ),
      ApiKeyStatus.invalid => (
          context.l10n.keyInvalid,
          context.isDark ? AppColors.darkError : AppColors.lightError,
          Icons.cancel_rounded
        ),
      ApiKeyStatus.validating => (
          context.l10n.keyValidating,
          context.isDark ? AppColors.darkWarning : AppColors.lightWarning,
          Icons.hourglass_top_rounded
        ),
      ApiKeyStatus.notAdded => (
          context.l10n.noKeyAdded,
          context.isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
          Icons.add_circle_outline_rounded
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 10 : 8,
        vertical: isTablet ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isTablet ? 14 : 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECURITY NOTE
// =============================================================================

class _SecurityNote extends StatelessWidget {
  final bool isTablet;
  const _SecurityNote({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.security,
          size: isTablet ? 32 : 24,
        ),
        SizedBox(width: isTablet ? 12 : 8),
        Expanded(
          child: Text(context.l10n.keySecureNote,
              style: context.textTheme.bodySmall),
        ),
      ],
    );
  }
}

// =============================================================================
// CONTINUE BUTTON
// =============================================================================

class _ContinueButton extends StatelessWidget {
  final bool isTablet;
  final bool isLoading;
  final bool hasKeys;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.isTablet,
    required this.isLoading,
    required this.hasKeys,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return context.themedElevatedButton(
      onPressed: isLoading ? null : onTap,
      label: hasKeys ? context.l10n.done : context.l10n.skip,
    );
  }
}
