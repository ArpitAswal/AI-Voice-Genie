import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/extensions/build_context_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/utils/status_message_utils.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../chat_prompt/presentation/widgets/model_indicator_chip.dart';
import '../../key_setup/presentation/api_key_provider.dart';
import '../presentation/pdf_provider.dart';
import 'widgets/pdf_upload_card.dart';

/// PDF Reader screen for AI Voice Genie.
///
/// Flow:
///   1. User taps "Upload PDF" — FilePicker opens
///   2. PDF text extracted locally via Syncfusion (background isolate)
///   3. PdfUploadCard shows file metadata
///   4. User types a question and taps Send
///   5. AiOrchestrator routes to any capable provider (all 3 support PDF)
///   6. Answer shown in message list
///   7. Each Q&A pair saved to Firestore as a pdfReader conversation
///
/// This screen has its own local Q&A message list — it is not connected
/// to ChatProvider. The Q&A messages are session-only in memory;
/// they are individually saved to Firestore by PdfRepository.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Upload PDF ─────────────────────────────────────────────────────────────

  Future<void> _handleUpload() async {
    context.read<PdfProvider>().clearError();
    final success = await context.read<PdfProvider>().pickAndLoadPdf();

    if (!mounted) return;
    if (!success) {
      final error = context.read<PdfProvider>().errorMessage;
      if (error != null) {
        context.showError(error);
        context.read<PdfProvider>().clearError();
      }
    }
  }

  // ── Ask Question ───────────────────────────────────────────────────────────

  Future<void> _handleSend() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final validProviders = context.read<ApiKeyProvider>().validProviders;
    final question = _questionController.text.trim();

    _questionController.clear();

    final success = await context.read<PdfProvider>().askQuestion(
      uid: uid,
      question: question,
      validProviders: validProviders,
    );

    if (!mounted) return;

    if (!success) {
      final error = context.read<PdfProvider>().errorMessage;
      if (error != null) {
        context.showError(error);
        context.read<PdfProvider>().clearError();
      }
    } else {
      // Scroll to bottom after answer arrives
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isTablet = context.isTablet;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('pdf_reader')),
      ),
      body: SafeArea(
        child: Consumer<PdfProvider>(
          builder: (context, pdfProvider, _) {
            return Column(
              children: [
                // ── Main content area ─────────────────────────────────────────
                Expanded(
                  child: pdfProvider.hasPdf
                      ? _ActivePdfView(
                    pdfProvider: pdfProvider,
                    scrollController: _scrollController,
                    isTablet: isTablet,
                  )
                      : _EmptyView(
                    isExtracting: pdfProvider.isExtracting,
                    isTablet: isTablet,
                    onUpload: _handleUpload,
                  ),
                ),

                // ── Input bar — shown only when PDF is loaded ─────────────────
                if (pdfProvider.hasPdf)
                  _PdfQaInputBar(
                    formKey: _formKey,
                    controller: _questionController,
                    isGenerating: pdfProvider.isGenerating,
                    isEnabled: pdfProvider.document?.hasText ?? false,
                    isTablet: isTablet,
                    onSend: _handleSend,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// EMPTY VIEW — before PDF is uploaded
// =============================================================================

class _EmptyView extends StatelessWidget {
  final bool isExtracting;
  final bool isTablet;
  final VoidCallback onUpload;

  const _EmptyView({
    required this.isExtracting,
    required this.isTablet,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upload icon
            Container(
              width: isTablet ? 88 : 72,
              height: isTablet ? 88 : 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(isTablet ? 22 : 18),
              ),
              child: isExtracting
                  ? Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.warning,
                ),
              )
                  : Icon(
                Icons.picture_as_pdf_outlined,
                size: isTablet ? 44 : 36,
                color: AppColors.warning,
              ),
            ),

            SizedBox(height: isTablet ? 24 : 20),

            Text(
              isExtracting
                  ? l10n.translate('reading_pdf')
                  : l10n.translate('no_pdf_uploaded'),
              style: context.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: isTablet ? 10 : 8),

            Text(
              l10n.translate('upload_pdf_subtitle'),
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),

            if (!isExtracting) ...[
              SizedBox(height: isTablet ? 32 : 24),
              SizedBox(
                height: isTablet ? 56 : 50,
                child: ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: Icon(
                    Icons.upload_file_rounded,
                    size: isTablet ? 22 : 18,
                  ),
                  label: Text(l10n.translate('upload_pdf')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 28 : 22,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ACTIVE PDF VIEW — PDF card + Q&A message list
// =============================================================================

class _ActivePdfView extends StatelessWidget {
  final PdfProvider pdfProvider;
  final ScrollController scrollController;
  final bool isTablet;

  const _ActivePdfView({
    required this.pdfProvider,
    required this.scrollController,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final messages = pdfProvider.messages;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── PDF metadata card at top ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.horizontalPadding,
              isTablet ? 20 : 16,
              context.horizontalPadding,
              isTablet ? 16 : 12,
            ),
            child: Column(
              children: [
                PdfUploadCard(
                  document: pdfProvider.document!,
                  isTablet: isTablet,
                  onRemove: pdfProvider.clearPdf,
                ),

                // Upload another PDF button
                SizedBox(height: isTablet ? 10 : 8),
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 42 : 38,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.read<PdfProvider>().pickAndLoadPdf(),
                    icon: Icon(
                        Icons.upload_file_rounded,
                        size: isTablet ? 18 : 16),
                    label: Text(AppLocalizations.of(context)!
                        .translate('upload_pdf')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(
                        color: AppColors.warning,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Empty Q&A state ──────────────────────────────────────────────────
        if (messages.isEmpty && !pdfProvider.isGenerating)
          SliverToBoxAdapter(
            child: _EmptyQaState(
              hasTextContent: pdfProvider.document?.hasText ?? false,
              isTablet: isTablet,
            ),
          ),

        // ── Q&A messages ─────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // Typing indicator at end when generating
              if (index == messages.length && pdfProvider.isGenerating) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                    vertical: 4,
                  ),
                  child: _PdfTypingIndicator(isTablet: isTablet),
                );
              }
              return _PdfMessageBubble(
                message: messages[index],
                isTablet: isTablet,
              );
            },
            childCount:
            messages.length + (pdfProvider.isGenerating ? 1 : 0),
          ),
        ),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(height: isTablet ? 16 : 12),
        ),
      ],
    );
  }
}

// =============================================================================
// EMPTY Q&A STATE
// =============================================================================

class _EmptyQaState extends StatelessWidget {
  final bool hasTextContent;
  final bool isTablet;

  const _EmptyQaState({
    required this.hasTextContent,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: isTablet ? 24 : 20,
      ),
      child: Text(
        hasTextContent
            ? l10n.translate('ask_about_pdf')
            : l10n.translate('pdf_read_failed'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// =============================================================================
// PDF MESSAGE BUBBLE
// =============================================================================

class _PdfMessageBubble extends StatelessWidget {
  final PdfQaMessage message;
  final bool isTablet;

  const _PdfMessageBubble({
    required this.message,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final isQuestion = message.isQuestion;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
        vertical: isTablet ? 6 : 4,
      ),
      child: Column(
        crossAxisAlignment: isQuestion
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Model chip above AI answers
          if (!isQuestion && message.provider != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: ModelIndicatorChip(
                provider: message.provider!,
                isTablet: isTablet,
              ),
            ),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
              MediaQuery.of(context).size.width * (isTablet ? 0.72 : 0.85),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 13 : 10,
              ),
              decoration: BoxDecoration(
                color: isQuestion
                    ? (context.isDark
                    ? AppColors.userBubbleDark
                    : AppColors.userBubbleLight)
                    : (context.isDark
                    ? AppColors.aiBubbleDark
                    : AppColors.aiBubbleLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isQuestion ? 16 : 4),
                  bottomRight: Radius.circular(isQuestion ? 4 : 16),
                ),
                border: isQuestion
                    ? null
                    : Border.all(
                  color: context.isDark
                      ? AppColors.darkDivider
                      : AppColors.lightDivider,
                  width: 1,
                ),
              ),
              child: Text(
                message.content,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: isTablet ? 15 : 14,
                  height: 1.5,
                  color: isQuestion
                      ? AppColors.white
                      : (context.isDark
                      ? AppColors.aiBubbleTextDark
                      : AppColors.aiBubbleTextLight),
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
// TYPING INDICATOR — while AI is generating PDF answer
// =============================================================================

class _PdfTypingIndicator extends StatefulWidget {
  final bool isTablet;
  const _PdfTypingIndicator({required this.isTablet});

  @override
  State<_PdfTypingIndicator> createState() => _PdfTypingIndicatorState();
}

class _PdfTypingIndicatorState extends State<_PdfTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
            (i) => AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final v = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = (v < 0.5 ? v * 2 : (1 - v) * 2).clamp(0.3, 1.0);
            return Container(
              width: widget.isTablet ? 10 : 8,
              height: widget.isTablet ? 10 : 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (context.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)
                    .withValues(alpha: opacity),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Q&A INPUT BAR
// =============================================================================

class _PdfQaInputBar extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isGenerating;
  final bool isEnabled;
  final bool isTablet;
  final VoidCallback onSend;

  const _PdfQaInputBar({
    required this.formKey,
    required this.controller,
    required this.isGenerating,
    required this.isEnabled,
    required this.isTablet,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        8,
        context.horizontalPadding,
        context.bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.cardDark
            : AppColors.cardLight,
        border: Border(
          top: BorderSide(
            color: context.isDark
                ? AppColors.darkDivider
                : AppColors.lightDivider,
            width: 1,
          ),
        ),
      ),
      child: Form(
        key: formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Question field
            Expanded(
              child: TextFormField(
                controller: controller,
                enabled: isEnabled && !isGenerating,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: context.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: isEnabled
                      ? l10n.translate('ask_about_pdf')
                      : l10n.translate('pdf_read_failed'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  // fillColor: context.isDark
                  //     ? AppColors.darkCardBackground
                  //     : AppColors.greyLight.withValues(alpha: 0.6),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 14 : 10,
                  ),
                ),
                validator: (v) => Validators.validatePrompt(v, context: context),
              ),
            ),

            SizedBox(width: isTablet ? 10 : 8),

            // Send button
            GestureDetector(
              onTap: (isEnabled && !isGenerating) ? onSend : null,
              child: Container(
                width: isTablet ? 48 : 42,
                height: isTablet ? 48 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isEnabled && !isGenerating)
                      ? AppColors.warning
                      : AppColors.warning.withValues(alpha: 0.4),
                ),
                child: isGenerating
                    ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
                    : Icon(
                  Icons.send_rounded,
                  color: AppColors.white,
                  size: isTablet ? 22 : 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}