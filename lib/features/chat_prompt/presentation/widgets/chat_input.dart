import 'dart:typed_data';

import 'package:ai_voice_genie/core/extensions/build_context_extensions.dart';
import 'package:ai_voice_genie/core/utils/widget_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../pdf_reader/data/pdf_repository_impl.dart';
import '../../domain/chat_attachment.dart';

/// Chat input bar with text, media attachment preview, send, and voice actions.
class ChatInputBar extends StatefulWidget {
  final bool isGenerating;
  final bool isTablet;
  final Future<void> Function(String prompt, ChatAttachment? attachment) onSend;

  /// Optional callback for voice input — null until Phase 7
  final VoidCallback? onVoiceTap;

  const ChatInputBar({
    super.key,
    required this.isGenerating,
    required this.isTablet,
    required this.onSend,
    this.onVoiceTap,
    VoidCallback? onAttachTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final PdfRepositoryImpl _pdfRepository = PdfRepositoryImpl();

  ChatAttachment? _attachment;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncCanSend);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncCanSend)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncCanSend() {
    final canSend = _controller.text.trim().isNotEmpty || _attachment != null;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  Future<void> _handleSend() async {
    final prompt = _controller.text.trim();
    final error = _attachment == null
        ? Validators.validatePrompt(prompt, context: context)
        : prompt.length > 10000
            ? AppLocalizations.of(context)!.promptTooLong
            : null;
    if (error != null) {
      context.showError(error);
      return;
    }

    final attachment = _attachment;
    _controller.clear();
    setState(() {
      _attachment = null;
      _canSend = false;
    });

    await widget.onSend(prompt, attachment);
  }

  Future<void> _showAttachmentSheet() async {
    if (widget.isGenerating) return;
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
              title: Text(l10n.translate('choose_from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l10n.translate('take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(l10n.translate('choose_pdf')),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > AppConstants.maxImageSizeBytes) {
        if (mounted) context.showError('error_image_too_large');
        return;
      }

      if (!mounted) return;
      setState(() {
        _attachment = ChatAttachment(
          type: ChatAttachmentType.image,
          name: image.name,
          bytes: bytes,
          path: image.path,
          mimeType: _imageMimeType(image.name),
          fileSizeBytes: bytes.lengthInBytes,
        );
        _canSend = true;
      });
    } catch (_) {
      if (mounted) context.showError('something_went_wrong');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) context.showError('pdf_read_failed');
        return;
      }

      final sizeError = _pdfRepository.validateFileSize(bytes.lengthInBytes);
      if (sizeError != null) {
        if (mounted) context.showError(sizeError);
        return;
      }

      final doc = await _pdfRepository.extractText(
        pdfBytes: bytes,
        fileName: file.name,
        fileSizeBytes: bytes.lengthInBytes,
      );
      if (!doc.hasText) {
        if (mounted) context.showError('pdf_read_failed');
        return;
      }

      if (!mounted) return;
      setState(() {
        _attachment = ChatAttachment(
          type: ChatAttachmentType.pdf,
          name: doc.fileName,
          bytes: Uint8List.fromList(bytes),
          path: file.path,
          mimeType: 'application/pdf',
          fileSizeBytes: doc.fileSizeBytes,
          extractedText: doc.extractedText,
        );
        _canSend = true;
      });
    } catch (_) {
      if (mounted) context.showError('pdf_read_failed');
    }
  }

  String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachment != null) ...[
          Flexible(
            flex: 1,
            child: _AttachmentPreview(
              attachment: _attachment!,
              isTablet: widget.isTablet,
              onRemove: widget.isGenerating
                  ? null
                  : () {
                      setState(() => _attachment = null);
                      _syncCanSend();
                    },
            ),
          ),
        ],
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.attach_file_rounded,
                onTap: widget.isGenerating ? null : _showAttachmentSheet,
                tooltip: l10n.translate('attach_file'),
                isTablet: widget.isTablet,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  child: context.themedTextField(
                    controller: _controller,
                    scrollController: _scrollController,
                    enabled: !widget.isGenerating,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    hint: l10n.translate('type_message'),
                    border: InputBorder.none,
                    contentPad: const EdgeInsets.all(8),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _canSend
                    ? _SendButton(
                        key: const ValueKey('send'),
                        onTap: widget.isGenerating ? null : _handleSend,
                        isGenerating: widget.isGenerating,
                        isTablet: widget.isTablet,
                      )
                    : _ActionButton(
                        key: const ValueKey('voice'),
                        icon: Icons.mic_rounded,
                        onTap: widget.onVoiceTap,
                        tooltip: l10n.translate('tap_to_speak'),
                        isTablet: widget.isTablet,
                        color: AppColors.primaryLight,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final ChatAttachment attachment;
  final bool isTablet;
  final VoidCallback? onRemove;

  const _AttachmentPreview({
    required this.attachment,
    required this.isTablet,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = isTablet ? 96.0 : 48.0;

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
                        color: AppColors.error.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.error,
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
                icon: const Icon(Icons.close_rounded),
                tooltip: AppLocalizations.of(context)!.translate('remove_file'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SEND BUTTON
// =============================================================================

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isGenerating;
  final bool isTablet;

  const _SendButton({
    super.key,
    required this.onTap,
    required this.isGenerating,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 48.0 : 42.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isGenerating
              ? AppColors.primaryLight.withValues(alpha: 0.5)
              : AppColors.primaryLight,
        ),
        child: isGenerating
            ? const Padding(
                padding: EdgeInsets.all(12),
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
    );
  }
}

// =============================================================================
// ACTION BUTTON — for attach and voice
// =============================================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isTablet;
  final Color? color;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.isTablet,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 48.0 : 42.0;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null
                ? AppColors.primaryLight.withValues(alpha: 0.18)
                : AppColors.primaryLight.withValues(alpha: 0.5),
          ),
          child: Icon(
            icon,
            color: color ?? AppColors.white,
          ),
        ),
      ),
    );
  }
}
