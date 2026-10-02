import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../../shared/widgets/chat_action_button.dart';
import '../../../key_setup/presentation/api_key_provider.dart';
import '../../../voice_speech/presentation/voice_speech_provider.dart';
import '../../../voice_speech/presentation/widgets/voice_input_button.dart';
import '../../../usage/presentation/usage_provider.dart';
import '../../domain/chat_attachment.dart';
import '../chat_provider.dart';

/// Imperative bridge used by parent screens to prepare the chat composer.
///
/// Keeps attachment picking, prompt insertion, focus behavior, and voice
/// auto-start inside [ChatInputBar] while letting parent screens trigger
/// those flows from outside the widget tree.
class ChatInputController {
  _ChatInputBarState? _state;

  void _attach(_ChatInputBarState state) => _state = state;

  void _detach(_ChatInputBarState state) {
    if (_state == state) _state = null;
  }

  /// Insert a reusable prompt template and optionally focus the composer.
  void setPrompt(String prompt, {bool focus = true}) {
    _state?._applyPromptTemplate(prompt, focus: focus);
  }

  /// Open the PDF picker, attach the selected document, and insert a template.
  Future<bool> pickPdfWithPrompt(String prompt) async {
    final state = _state;
    if (state == null) return false;
    return state._pickPdf(promptTemplate: prompt);
  }

  /// Open the image picker, attach the selected image, and insert a template.
  Future<bool> pickImageWithPrompt(
    String prompt, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final state = _state;
    if (state == null) return false;
    return state._pickImage(source, promptTemplate: prompt);
  }

  /// Programmatically trigger voice input as if the user tapped the mic button.
  ///
  /// Called by [ChatScreen] when the screen was opened via the Home voice button
  /// and [ChatStartMode.voice] was requested. The call is deferred to the first
  /// frame so the [VoiceInputButton] state is fully mounted before interaction.
  void startVoiceInput() {
    _state?._startVoiceInputProgrammatically();
  }
}

/// Chat input bar with text, media attachment preview, send, and voice actions.
class ChatInputBar extends StatefulWidget {
  final Future<void> Function(
    String prompt,
    List<ChatAttachment> attachments,
    AiProviderId selectedProvider,
  ) onSend;
  final ChatInputController? controller;
  final VoidCallback? onUserInteracted;
  final VoidCallback? onEmptyInput;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.controller,
    this.onUserInteracted,
    this.onEmptyInput,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  // Key used to imperatively call triggerTap on VoiceInputButton
  final GlobalKey<VoiceInputButtonState> _voiceMicKey =
      GlobalKey<VoiceInputButtonState>();

  final List<ChatAttachment> _attachments = [];
  bool _canSend = false;
  bool _hasText = false;
  bool _isApplyingTemplate = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Attach this state instance to the controller so parent can command it
    widget.controller?._attach(this);
    // Listen to text changes to toggle the send button visibility
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebind the controller if the parent widget swapped it during a rebuild
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    // Also stop voice listening so audio resources are released on screen exit
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    // Update the send button state based on whether there's input
    _syncCanSend();
    // Notify parent to reset idle timers or hide UI overlays when user types
    if (!_isApplyingTemplate) {
      if (_controller.text.trim().isNotEmpty) {
        widget.onUserInteracted?.call();
      } else {
        widget.onEmptyInput?.call();
      }
    }
  }

  /// Enables sending if there's text OR an attachment, and tracks text presence for switcher.
  void _syncCanSend() {
    final canSend =
        _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
    final hasText = _controller.text.trim().isNotEmpty;
    if (canSend != _canSend || hasText != _hasText) {
      setState(() {
        _canSend = canSend;
        _hasText = hasText;
      });
    }
  }

  Future<void> _handleSend() async {
    // Drop rapid-tap or duplicate events immediately if generating or submitting
    if (_isSubmitting || context.read<ChatProvider>().isGenerating) return;

    _isSubmitting = true;
    try {
      _focusNode.unfocus();

      // Stop any active voice listening before sending so mic is released
      if (context.read<VoiceProvider>().isListening) {
        await context.read<VoiceProvider>().stopListening();
        if (!mounted) return;
      }

      final prompt = _controller.text.trim();
      final attachments = List<ChatAttachment>.from(_attachments);

      final error = Validators.validatePrompt(prompt, context: context);
      if (error != null) {
        context.showError(error);
        return;
      }

      // Verify API key is configured before clearing input
      final provider = context.read<AiPreferencesProvider>().preferredProvider;
      final apiKeyProvider = context.read<ApiKeyProvider>();
      if (!apiKeyProvider.validProviders.contains(provider)) {
        MessageUtils.showErrorToast(context, context.l10n.noKeyForModel);
        return;
      }

      // Verify usage budget limits
      final usageProvider = context.read<UsageProvider>();
      final summary = usageProvider.summaryFor(provider);

      if (summary != null && summary.isExceeded()) {
        MessageUtils.showErrorToast(
          context,
          context.l10n.chatProviderLimitReached(provider.displayName),
        );
        return;
      }

      await widget.onSend(prompt, attachments, provider);

      _controller.clear();
      setState(() {
        _attachments.clear();
        _canSend = false;
        _hasText = false;
      });
    } finally {
      if (mounted) {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _showAttachmentSheet() async {
    if (context.read<ChatProvider>().isGenerating) return;
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(l10n.choosePdf),
              onTap: () {
                Navigator.pop(context);
                _pickPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canAddAttachmentType(ChatAttachmentType newType) {
    if (_attachments.isEmpty) return true;
    if (_attachments.first.type != newType) {
      if (mounted) {
        context.showError(
          context.l10n.cannotMixImagesAndPdfs,
        );
      }
      return false;
    }
    final prefs = context.read<AiPreferencesProvider>();
    final maxLimit = newType == ChatAttachmentType.image
        ? prefs.preferredVisionImageCount
        : prefs.preferredVisionPdfCount;
    if (_attachments.length >= maxLimit) {
      if (mounted) {
        context.showError(
          newType == ChatAttachmentType.image
              ? context.l10n.maxImageAttachments(maxLimit)
              : context.l10n.maxPdfAttachments(maxLimit),
        );
      }
      return false;
    }
    return true;
  }

  Future<bool> _pickImage(
    ImageSource source, {
    String? promptTemplate,
  }) async {
    try {
      final List<XFile> images;
      if (source == ImageSource.gallery) {
        images = await _imagePicker.pickMultiImage();
      } else {
        final image = await _imagePicker.pickImage(source: source);
        images = image != null ? [image] : [];
      }

      if (images.isEmpty) return false;

      if (!mounted) return false;
      bool addedAny = false;

      for (final image in images) {
        if (!_canAddAttachmentType(ChatAttachmentType.image)) break;

        if (_attachments.any((a) => a.name == image.name)) {
          if (mounted) context.showError('file_already_attached');
          continue;
        }

        final bytes = await image.readAsBytes();
        if (!mounted) return false;
        final fileBytesLen = bytes.lengthInBytes;

        // 1. Single image file limit check (Max 5 MB)
        if (fileBytesLen > AppConstants.maxImageSizeBytes) {
          debugPrint('⚠️ Image file too large — '
              '${(fileBytesLen / (1024 * 1024)).toStringAsFixed(1)} MB');
          if (mounted) context.showError('error_image_too_large');
          continue;
        }

        // 2. Combined image payload limit check (Max 15 MB total across all attachments)
        final currentTotalBytes = _attachments.fold<int>(
          0,
          (sum, a) => sum + (a.fileSizeBytes ?? a.bytes.lengthInBytes),
        );
        if (currentTotalBytes + fileBytesLen >
            AppConstants.maxImageCombinedSizeBytes) {
          final totalMB = ((currentTotalBytes + fileBytesLen) / (1024 * 1024))
              .toStringAsFixed(1);
          debugPrint('⚠️ Combined image payload too large: $totalMB MB');
          if (mounted) {
            context.showError(
              context.l10n.imagePayloadTooLargeDetail(totalMB),
            );
          }
          continue;
        }

        setState(() {
          _attachments.add(ChatAttachment(
            type: ChatAttachmentType.image,
            name: image.name,
            bytes: bytes,
            path: image.path,
            mimeType: _imageMimeType(image.name),
            fileSizeBytes: bytes.lengthInBytes,
          ));
          _canSend = true;
        });
        addedAny = true;
      }

      if (addedAny) {
        if (promptTemplate != null) {
          _applyPromptTemplate(promptTemplate);
        } else {
          widget.onUserInteracted?.call();
        }
      }
      return addedAny;
    } catch (_) {
      if (mounted) context.showError(context.l10n.somethingWentWrong);
      return false;
    }
  }

  Future<bool> _pickPdf({String? promptTemplate}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
          allowMultiple: true);
      if (result == null || result.files.isEmpty) return false;

      final files = result.files;
      if (files.isEmpty) {
        if (mounted) context.showError('pdf_read_failed');
        return false;
      }

      if (!mounted) return false;
      bool addedAny = false;

      for (final file in files) {
        if (!_canAddAttachmentType(ChatAttachmentType.pdf)) return false;

        if (_attachments
            .any((a) => a.name == file.name && a.fileSizeBytes == file.size)) {
          if (mounted) context.showError('file_already_attached');
          continue;
        }

        final bytes = file.bytes;
        if (bytes == null) {
          if (mounted) context.showError('pdf_read_failed');
          continue;
        }
        final fileBytesLen = bytes.lengthInBytes;
        final fileSizeMB = (fileBytesLen / (1024 * 1024)).toStringAsFixed(1);

        // 1. Single PDF file limit check (Max 10 MB)
        if (fileBytesLen > AppConstants.maxPdfSizeBytes) {
          debugPrint('⚠️ PDF file too large: ${file.name} ($fileSizeMB MB)');
          if (mounted) {
            context.showError(
              context.l10n.pdfFileTooLargeDetail(
                name: file.name,
                sizeMB: fileSizeMB,
              ),
            );
          }
          continue;
        }

        // 2. Combined PDF payload limit check (Max 15 MB total across all attachments)
        final currentTotalBytes = _attachments.fold<int>(
          0,
          (sum, a) => sum + (a.fileSizeBytes ?? a.bytes.lengthInBytes),
        );
        if (currentTotalBytes + fileBytesLen >
            AppConstants.maxPdfCombinedSizeBytes) {
          final totalMB = ((currentTotalBytes + fileBytesLen) / (1024 * 1024))
              .toStringAsFixed(1);
          debugPrint('⚠️ Combined PDF payload too large: $totalMB MB');
          if (mounted) {
            context.showError(
              context.l10n.pdfPayloadTooLargeDetail(totalMB),
            );
          }
          continue;
        }
        setState(() {
          _attachments.add(ChatAttachment(
            type: ChatAttachmentType.pdf,
            name: file.name,
            bytes: bytes,
            path: file.path,
            mimeType: 'application/pdf',
            fileSizeBytes: bytes.lengthInBytes,
          ));
          _canSend = true;
        });
        addedAny = true;
      }
      if (addedAny) {
        if (promptTemplate != null) {
          _applyPromptTemplate(promptTemplate);
        } else {
          widget.onUserInteracted?.call();
        }
      }
      return addedAny;
    } catch (_) {
      if (mounted) context.showError('pdf_read_failed');
      return false;
    }
  }

  String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _onTranscriptReady(String transcript) {
    if (transcript.isEmpty) return;

    // Replace whatever partial text was showing with the confirmed final result.
    // Voice input behaves like manual composition once the transcript is final.
    _controller.text = transcript;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: transcript.length),
    );
    _focusNode.requestFocus();
    widget.onUserInteracted?.call();
  }

  /// Called on every partial STT result while the user is still speaking.
  ///
  /// Updates the text field in real time so the user can see what has been
  /// recognized so far. The cursor is placed at the end of the partial text.
  /// When the final transcript arrives, [_onTranscriptReady] replaces it.
  void _onPartialTranscript(String partial) {
    if (!mounted) return;
    _controller.text = partial;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: partial.length),
    );
    // Ensure the send button state is in sync with live text
    _syncCanSend();

    // Automatically scroll to the bottom as text increases beyond height limit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Programmatically start voice input — called via [ChatInputController.startVoiceInput()].
  ///
  /// Simulates the user tapping the mic button. Guards ensure we only start
  /// if the mic key is mounted and voice is not already active.
  void _startVoiceInputProgrammatically() {
    _voiceMicKey.currentState?.triggerTap();
  }

  void _applyPromptTemplate(String prompt, {bool focus = true}) {
    _isApplyingTemplate = true;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    _isApplyingTemplate = false;
    _syncCanSend();
    if (focus) _focusNode.requestFocus();
    widget.onUserInteracted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isListening = context.watch<VoiceProvider>().isListening;
    final isGenerating =
        context.select<ChatProvider, bool>((p) => p.isGenerating);
    final isTablet = context.isTablet;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachments.isNotEmpty) ...[
          SizedBox(
            height: isTablet ? 112 : 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
                vertical: 4,
              ),
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final att = _attachments[index];
                return _AttachmentPreview(
                  attachment: att,
                  onRemove: isGenerating
                      ? null
                      : () {
                          setState(() => _attachments.removeAt(index));
                          _syncCanSend();
                        },
                );
              },
            ),
          ),
        ],
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ChatActionButton(
              icon: Icons.attach_file_rounded,
              onTap: isGenerating ? null : _showAttachmentSheet,
              color: AppColors.primaryLight,
              tooltip: l10n.attachFile,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: context.screenHeight * 0.25),
                child: context.themedTextField(
                  controller: _controller,
                  focus: _focusNode,
                  scrollController: _scrollController,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  inputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  enabled: !isGenerating,
                  hint: l10n.askGenie,
                  border: InputBorder.none,
                  contentPad: const EdgeInsets.all(8),
                ),
              ),
            ),
            // Shows VoiceInputButton when empty or while actively listening,
            // and SendButton once text/attachments are ready and listening has stopped.
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: (_hasText && !isListening)
                  ? ChatActionButton(
                      key: const ValueKey('send'),
                      icon: Icons.send_rounded,
                      onTap: isGenerating ? null : _handleSend,
                      isLoading: isGenerating,
                    )
                  : VoiceInputButton(
                      key: _voiceMicKey,
                      isTablet: isTablet,
                      tooltip: l10n.tapToSpeak,
                      // Called with confirmed final text when speech ends
                      onTranscriptReady: _onTranscriptReady,
                      // Called live on every partial result while speaking
                      onPartialTranscript: _onPartialTranscript,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback? onRemove;

  const _AttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = context.isTablet ? 96.0 : 48.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: attachment.isImage
                    ? Image.memory(
                        attachment.bytes,
                        width: previewSize,
                        height: previewSize,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: previewSize,
                        height: previewSize,
                        color: AppColors.lightError.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.lightError,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attachment.fileSizeLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 21,
                ),
                tooltip: context.l10n.removeFile,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
