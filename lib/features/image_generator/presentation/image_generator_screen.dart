import 'package:ai_voice_genie/features/image_generator/presentation/widgets/image_generator_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../presentation/image_generator_provider.dart';
import 'widgets/image_size_selector.dart';

/// Image generation screen for AI Voice Genie.
///
/// Flow:
///   1. User types a description prompt
///   2. User selects image size (square / landscape / portrait)
///   3. User taps Generate
///   4. Provider checks capability gap (Claude-only → gap message shown)
///   5. AiOrchestrator routes to OpenAI (DALL-E) or Gemini (Flash Image)
///   6. On success → GeneratedImageCard shows result with save/share actions
///   7. On failure → inline error message shown, prompt stays populated
///
/// Capability gap handling:
///   If user only has a Claude key, the capability gap message is shown
///   IMMEDIATELY without any API call. The message tells the user which
///   providers support image generation and offers a link to add a key.
class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _promptController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Generate ───────────────────────────────────────────────────────────────

  Future<void> _handleGenerate() async {
    // Dismiss keyboard before generating
    _focusNode.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final validProviders = context.read<ApiKeyProvider>().validProviders;

    final success = await context.read<ImageGeneratorProvider>().generateImage(
          uid: uid,
          prompt: _promptController.text.trim(),
          validProviders: validProviders,
        );

    if (!mounted) return;

    // Show error if generation failed for a reason other than capability gap
    // (capability gap is shown inline on the screen — not as an overlay)
    if (!success) {
      final error = context.read<ImageGeneratorProvider>().errorMessage;
      if (error != null && error != 'capability_gap_image_gen') {
        context.showError(error);
        context.read<ImageGeneratorProvider>().clearError();
      }
    }
  }

  // ── Save to Gallery ────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    final success = await context
        .read<ImageGeneratorProvider>()
        .saveCurrentImageToGallery();

    if (!mounted) return;

    if (success) {
      context.showSuccessToast(
        AppLocalizations.of(context)!.translate('image_saved'),
      );
    } else {
      // Gallery saver is stubbed — inform user
      context.showWarning(
        AppLocalizations.of(context)!.translate('something_went_wrong'),
      );
    }
  }

  // ── Generate Another ───────────────────────────────────────────────────────

  void _handleGenerateAnother() {
    context.read<ImageGeneratorProvider>().clearImage();
    _promptController.clear();
    // Re-focus the prompt field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('image_generator')),
      ),
      body: SafeArea(
        child: Consumer<ImageGeneratorProvider>(
          builder: (context, imageProvider, _) {
            // ── Result state — show generated image ────────────────────────
            if (imageProvider.hasImage) {
              return _ResultView(
                imageProvider: imageProvider,
                isTablet: isTablet,
                onSave: _handleSave,
                onGenerateAnother: _handleGenerateAnother,
              );
            }

            // ── Input state — show prompt form ─────────────────────────────
            return _InputView(
              formKey: _formKey,
              promptController: _promptController,
              focusNode: _focusNode,
              imageProvider: imageProvider,
              isTablet: isTablet,
              onGenerate: _handleGenerate,
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// INPUT VIEW — prompt entry + size selector + generate button
// =============================================================================

class _InputView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController promptController;
  final FocusNode focusNode;
  final ImageGeneratorProvider imageProvider;
  final bool isTablet;
  final VoidCallback onGenerate;

  const _InputView({
    required this.formKey,
    required this.promptController,
    required this.focusNode,
    required this.imageProvider,
    required this.isTablet,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: isTablet ? 32 : 24,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page title ─────────────────────────────────────────────────
            _PageHeader(isTablet: isTablet),

            SizedBox(height: isTablet ? 28 : 22),

            // ── Capability gap warning ─────────────────────────────────────
            // Shown when user only has Claude key (no image gen support)
            if (imageProvider.errorMessage == 'capability_gap_image_gen') ...[
              _CapabilityGapBanner(isTablet: isTablet),
              SizedBox(height: isTablet ? 20 : 16),
            ],

            // ── Prompt input ───────────────────────────────────────────────
            Text(
              l10n.translate('describe_image'),
              style: context.textTheme.titleSmall,
            ),

            SizedBox(height: isTablet ? 10 : 8),

            TextFormField(
              controller: promptController,
              focusNode: focusNode,
              maxLines: isTablet ? 5 : 4,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              style: context.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.translate('describe_image'),
                counterText: '',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  Validators.validateImagePrompt(value, context: context),
              onChanged: (_) {
                // Clear capability gap error when user starts typing again
                if (imageProvider.errorMessage == 'capability_gap_image_gen') {
                  imageProvider.clearError();
                }
              },
            ),

            SizedBox(height: isTablet ? 24 : 20),

            // ── Image size selector ────────────────────────────────────────
            Text(
              l10n.translate('image_generator'),
              style: context.textTheme.titleSmall,
            ),

            SizedBox(height: isTablet ? 10 : 8),

            ImageSizeSelector(
              selected: imageProvider.selectedSize,
              isTablet: isTablet,
              onSelected: imageProvider.setImageSize,
            ),

            SizedBox(height: isTablet ? 32 : 28),

            // ── Generate button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: isTablet ? 58 : 52,
              child: ElevatedButton(
                onPressed: imageProvider.isGenerating ? null : onGenerate,
                child: imageProvider.isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: isTablet ? 14 : 10),
                          Text(l10n.translate('generating_image')),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: isTablet ? 22 : 18,
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
                          Text(l10n.translate('generate_image')),
                        ],
                      ),
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // ── Provider hint ──────────────────────────────────────────────
            _ProviderHint(isTablet: isTablet),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RESULT VIEW — generated image + action buttons
// =============================================================================

class _ResultView extends StatelessWidget {
  final ImageGeneratorProvider imageProvider;
  final bool isTablet;
  final VoidCallback onSave;
  final VoidCallback onGenerateAnother;

  const _ResultView({
    required this.imageProvider,
    required this.isTablet,
    required this.onSave,
    required this.onGenerateAnother,
  });

  @override
  Widget build(BuildContext context) {
    final image = imageProvider.currentImage!;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: isTablet ? 24 : 20,
      ),
      child: GeneratedImageCard(
        imageBytes: image.imageBytes,
        provider: image.provider,
        prompt: image.prompt,
        isSaving: false,
        onSave: onSave,
        onGenerateAnother: onGenerateAnother,
        isTablet: isTablet,
      ),
    );
  }
}

// =============================================================================
// PAGE HEADER
// =============================================================================

class _PageHeader extends StatelessWidget {
  final bool isTablet;
  const _PageHeader({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Container(
          width: isTablet ? 52 : 42,
          height: isTablet ? 52 : 42,
          decoration: BoxDecoration(
            gradient: context.isDark
                ? AppColors.primaryGradientDark
                : AppColors.primaryGradientLight,
            borderRadius: BorderRadius.circular(isTablet ? 14 : 11),
          ),
          child: Icon(
            Icons.image_outlined,
            size: isTablet ? 26 : 20,
            color: AppColors.white,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('image_generator'),
                style: context.textTheme.headlineMedium,
              ),
              Text(
                l10n.translate('describe_image'),
                style: context.textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// CAPABILITY GAP BANNER
// =============================================================================

/// Shown when the user has no provider capable of image generation.
/// Tells them which providers support it and offers a link to add a key.
class _CapabilityGapBanner extends StatelessWidget {
  final bool isTablet;
  const _CapabilityGapBanner({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: isTablet ? 22 : 18,
          ),
          SizedBox(width: isTablet ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('capability_gap_title'),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: AppColors.warning,
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  l10n.translate('capability_gap_image_gen'),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 8),
                // Providers that DO support image gen
                Text(
                  l10n.translate('available_models'),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Row(
                  children: [
                    _ProviderPill(
                      name: AiProviderId.openAi.displayName,
                      color: AppColors.openAiBrand,
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    _ProviderPill(
                      name: AiProviderId.gemini.displayName,
                      color: AppColors.geminiBrand,
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 10 : 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/api-keys'),
                  child: Text(
                    l10n.translate('add_key_for_model'),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderPill extends StatelessWidget {
  final String name;
  final Color color;

  const _ProviderPill({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// PROVIDER HINT — shown below the generate button
// =============================================================================

class _ProviderHint extends StatelessWidget {
  final bool isTablet;
  const _ProviderHint({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyProvider>(
      builder: (context, keyProvider, _) {
        // Find which of the user's valid providers support image generation
        final imageProviders = keyProvider.validProviders
            .where((p) => p == AiProviderId.openAi || p == AiProviderId.gemini)
            .toList();

        if (imageProviders.isEmpty) return const SizedBox.shrink();

        final names = imageProviders.map((p) => p.displayName).join(', ');

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: isTablet ? 14 : 12,
              color: context.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            SizedBox(width: isTablet ? 6 : 4),
            Flexible(
              child: Text(
                '${AppLocalizations.of(context)!.translate("available_models")}: $names',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontSize: isTablet ? 11 : 10,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
