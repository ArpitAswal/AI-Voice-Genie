import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:ai_voice_genie/features/key_setup/presentation/api_key_provider.dart';
import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/loading_overlay.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../../shared/widgets/image_view.dart';
import '../../auth/presentation/auth_provider.dart';

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

  const KeySetupScreen({super.key, this.isInitialSetup = true});

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen> {
  @override
  void initState() {
    super.initState();
    // Load any previously saved keys on mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
       bool success = await context.read<ApiKeyProvider>().loadExistingKeys(uid);
       if(!success && mounted){
         context.showError('key_fetch_error');
       }
      }
    });
  }

  Future<void> _handleContinue() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    LoadingOverlay.show(context, message: context.l10n.pleaseWait);

    final success = await context.read<ApiKeyProvider>().completeSetup(uid);

    LoadingOverlay.hide();

    if (!mounted) return;

    if (success) {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.tabBar);
    } else {
      context.showError('something_went_wrong');
    }
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
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 8 : 4),

                  // ── Helper note ────────────────────────────────────
                  _SecurityNote(isTablet: isTablet),

                  SizedBox(height: isTablet ? 36 : 24),

                  // ── Continue Button ──────────────────────────────────────────
                  if (widget.isInitialSetup)
                    _ContinueButton(
                      isTablet: isTablet,
                      isEnabled: keyProvider.hasAtLeastOneValidKey,
                      isLoading: keyProvider.isCompletingSetup,
                      onTap: _handleContinue,
                    ),
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
          style: context.textTheme.bodyLarge,
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

  const _ProviderKeyCard({
    required this.provider,
    required this.isTablet,
  });

  @override
  State<_ProviderKeyCard> createState() => _ProviderKeyCardState();
}

class _ProviderKeyCardState extends State<_ProviderKeyCard> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureKey = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleValidate() async {
    // Clear provider error on retry
    context.read<ApiKeyProvider>().clearError(widget.provider);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    await context.read<ApiKeyProvider>().validateAndSaveKey(
          uid: uid,
          providerId: widget.provider,
          apiKey: _keyController.text,
        );
  }

  Future<void> _handleDelete(String provider) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final isConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ));

    if (isConfirm != true || !mounted) return;

    LoadingOverlay.show(context, message: context.l10n.deleting);
    _keyController.clear();

    await context.read<ApiKeyProvider>().deleteKey(
          uid: uid,
          providerId: widget.provider,
        );
    LoadingOverlay.hide();

    if (!mounted) return;
    MessageUtils.showSuccess(context, "$provider ${context.l10n.keyRemoveSuccess}");
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
    return Selector<ApiKeyProvider, (ApiKeyStatus, String?)>(
      // Only rebuild this card when its own provider's state changes
      selector: (_, provider) => (
        provider.statusFor(widget.provider),
        provider.errorFor(widget.provider),
      ),
      builder: (context, state, _) {
        final status = state.$1;
        final error = state.$2;
        final isValidating = status == ApiKeyStatus.validating;
        final isValid = status == ApiKeyStatus.valid;

        return Container(
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor(status),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProviderLogo(
                      provider: widget.provider,
                      size: widget.isTablet ? 40 : 36,
                    ),
                    SizedBox(width: widget.isTablet ? 14 : 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.provider.displayName,
                            style: context.textTheme.titleSmall?.copyWith(
                                color: _providerColor(widget.provider)),
                          ),
                          Text(
                            widget.provider.features,
                            style: context.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: status, isTablet: widget.isTablet),
                  ],
                ),

                // ── Key input — hidden when valid ──────────────────────────
                if (!isValid) ...[
                  SizedBox(height: widget.isTablet ? 16 : 12),

                  Form(
                    key: _formKey,
                    child: context.themedTextField(
                      controller: _keyController,
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
                          ),
                          // Paste button
                          IconButton(
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
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.translate(error),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: AppColors.error,
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
                    children: [
                      // Link to get a key
                      Expanded(
                        child: Text(
                          _getKeyText(widget.provider),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: _providerColor(widget.provider),
                          ),
                        ),
                      ),
                      SizedBox(width: context.isTablet ? 16 : 6),
                      ElevatedButton(
                        onPressed: isValidating ? null : _handleValidate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _providerColor(widget.provider),
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 24 : 10,
                            vertical: 0
                          ),
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
                                style:
                                    context.textTheme.labelMedium?.copyWith(
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
                        children: [
                          Text(
                            maskedKey ?? '••••••••••••',
                            style: context.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: _providerColor(widget.provider),
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                          ),
                          const Spacer(),
                          // Delete button — only shown when key is valid
                          GestureDetector(
                            onTap: ()=> _handleDelete(widget.provider.displayName),
                            child: const ImageView(
                              image: ImageViewData.asset(
                               AppAssets.deleteIcon
                              ),
                              width: 18,
                              height: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helper Methods ──────────────────────────────────────────────────────────

  Color _borderColor(ApiKeyStatus status) {
    switch (status) {
      case ApiKeyStatus.valid:
        return AppColors.success;
      case ApiKeyStatus.invalid:
        return AppColors.error;
      case ApiKeyStatus.validating:
        return AppColors.warning;
      case ApiKeyStatus.notAdded:
        return context.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    }
  }

  Color _providerColor(AiProviderId provider) {
    switch (provider) {
      case AiProviderId.openAi:
        return AppColors.openAiBrand;
      case AiProviderId.gemini:
        return AppColors.geminiBrand;
      case AiProviderId.claude:
        return AppColors.claudeBrand;
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
        child: FaIcon(
          _providerIcon(provider),
          color: AppColors.white,
          size: size * 0.6
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

class _StatusChip extends StatelessWidget {
  final ApiKeyStatus status;
  final bool isTablet;

  const _StatusChip({required this.status, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ApiKeyStatus.valid => (
          context.l10n.keyValid,
          AppColors.success,
          Icons.check_circle_rounded
        ),
      ApiKeyStatus.invalid => (
          context.l10n.keyInvalid,
          AppColors.error,
          Icons.cancel_rounded
        ),
      ApiKeyStatus.validating => (
          context.l10n.keyValidating,
          AppColors.warning,
          Icons.hourglass_top_rounded
        ),
      ApiKeyStatus.notAdded => (
          context.l10n.noKeyAdded,
          AppColors.grey,
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
            style: context.textTheme.labelSmall?.copyWith(
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
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.isTablet,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return context.themedElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              if (isEnabled) {
                onTap();
              } else {
                MessageUtils.showWarning(
                  context,
                  context.l10n.noModelKey,
                );
              }
            },
      label: context.l10n.done,
    );
  }
}
