import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/extensions/string_extension.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../domain/message_model.dart';
import 'model_indicator_chip.dart';

/// Renders a single message bubble in the chat list.
///
/// User messages → right-aligned, primary color background
/// AI messages   → left-aligned, card background + model indicator chip
///
/// Supports:
///   - Long-press to copy text
///   - Sending status indicator (user messages)
///   - Model indicator chip (AI messages)
///   - Responsive sizing for phone and tablet
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isTablet;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isTablet,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // AI model chip — shown above AI responses
        if (!_isUser && message.modelRequest != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: ModelIndicatorChip(
              provider: message.modelRequest!,
              isTablet: isTablet,
            ),
          ),
        ],

        // Message bubble
        GestureDetector(
          onLongPress: () => _copyToClipboard(context),
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * (isTablet ? 0.65 : 0.85),
            ),
            padding: EdgeInsets.all(_hasMedia ? 10 : 16),
            decoration: BoxDecoration(
              color: _isUser
                  ? (context.isDark
                      ? AppColors.userBubbleDark
                      : AppColors.userBubbleLight)
                  : (context.isDark
                      ? AppColors.aiBubbleDark
                      : AppColors.aiBubbleLight),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_isUser ? 16 : 4),
                topRight: Radius.circular(_isUser ? 4 : 16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
            ),
            child: _MessageBubbleContent(
              message: message,
              isUser: _isUser,
              isTablet: isTablet,
            ),
          ),
        ),

        // Timestamp + status row displayed underneath the bubble
        _MessageTimestampRow(message: message),
      ],
    );
  }

  /// Determines if the message has media attached (images or pdf)
  /// This affects the padding inside the message bubble container.
  bool get _hasMedia =>
      (message.imageUrls != null && message.imageUrls!.isNotEmpty) ||
      (message.pdfName != null && message.pdfName!.isNotEmpty);

  /// Copies the text content to clipboard and shows a toast
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    context.showSuccessToast(
      AppLocalizations.of(context)!.translate('copied_to_clipboard'),
    );
  }
}

/// A private widget that renders the timestamp and status icon beneath a message.
class _MessageTimestampRow extends StatelessWidget {
  final MessageModel message;

  const _MessageTimestampRow({required this.message});

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display the localized time string (e.g. 10:42 AM)
          Text(
            message.timestamp.toTimeString,
            style: context.textTheme.bodySmall,
          ),
          // For user messages, display a status indicator (sending/delivered/failed)
          if (_isUser) ...[
            const SizedBox(width: 4),
            _StatusIcon(status: message.status),
          ],
        ],
      ),
    );
  }
}

class _MessageBubbleContent extends StatelessWidget {
  final MessageModel message;
  final bool isUser;
  final bool isTablet;

  const _MessageBubbleContent({
    required this.message,
    required this.isUser,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final text = _displayText(context).trim();
    final textWidget = text.isEmpty
        ? null
        : Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: isUser
                  ? AppColors.userBubbleTextLight
                  : (context.isDark
                      ? AppColors.aiBubbleTextDark
                      : AppColors.aiBubbleTextLight),
              height: 1.5,
              fontSize: isTablet ? 16 : 14,
            ),
          );

    // Compile the children based on what attachments the message has.
    final children = <Widget>[
      // 1. If images are present, render the image grid.
      if (message.imageUrls != null && message.imageUrls!.isNotEmpty)
        _ChatImage(
            images: message.imageUrls!,
            size: message.imageSize ?? AiImageSize.square),

      // 2. If PDFs are present, render the PDF cards.
      if ((message.pdfName != null && message.pdfName!.isNotEmpty) &&
          message.pdfName!.isNotEmpty)
        ...message.pdfName!.map((pdf) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: _PdfAttachmentCard(
                name: pdf,
                isUser: isUser,
              ),
            )),

      // 3. If there is text, render it below the attachments (with padding if media exists).
      if (textWidget != null) ...[
        if ((message.imageUrls != null && message.imageUrls!.isNotEmpty) ||
            (message.pdfName != null && message.pdfName!.isNotEmpty))
          const SizedBox(height: 10),
        textWidget,
      ],
    ];

    // If there's no media, just return the text widget directly to avoid an extra Column
    if (children.isEmpty) {
      return textWidget ?? const SizedBox.shrink();
    }

    // Wrap the content in a column so attachments sit above the text
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Gets the localized error text if the message failed to send, or the raw content.
  String _displayText(BuildContext context) {
    if (message.status == MessageStatus.failed) {
      // Try to translate the failure reason, fallback to raw message
      return AppLocalizations.of(context)?.translate(message.content) ??
          message.content;
    }
    return message.content;
  }
}

class _ChatImage extends StatelessWidget {
  final List<String> images;
  final AiImageSize size;

  const _ChatImage({required this.images, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (images.length) {
      case 1:
        return _OneImage(image: images.first, size: size);

      case 2:
        return _TwoImages(
          images: images,
          size: size,
        );

      case 3:
        return _ThreeImages(
          images: images,
          size: size,
        );

      case 4:
        return _FourImages(
          images: images,
          size: size,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

Widget _buildImage(String url) {
  if (url.startsWith('data:image')) {
    final base64Data = url.substring(url.indexOf(',') + 1);
    return Image.memory(
      base64Decode(base64Data),
      fit: BoxFit.cover,
    );
  }

  if (url.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadiusGeometry.circular(16),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        alignment: AlignmentGeometry.center,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const _ImageFallback(isLoading: true),
      ),
    );
  }

  return Image.file(
    File(url),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const _ImageFallback(),
  );
}

class _ImageFallback extends StatelessWidget {
  final bool isLoading;

  const _ImageFallback({this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: isLoading
          ? const CircularProgressIndicator(strokeWidth: 2)
          : const Icon(Icons.broken_image_rounded, color: AppColors.grey),
    );
  }
}

class _OneImage extends StatelessWidget {
  const _OneImage({
    required this.image,
    required this.size,
  });

  final String image;
  final AiImageSize size;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: size.aspectRatio,
      child: _buildImage(image),
    );
  }
}

class _TwoImages extends StatelessWidget {
  const _TwoImages({required this.images, required this.size});

  final List<String> images;
  final AiImageSize size;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;

    final landscape = size == AiImageSize.landscape;

    if (landscape) {
      return Column(
        children: [
          AspectRatio(
            aspectRatio: size.aspectRatio,
            child: _buildImage(images[0]),
          ),
          const SizedBox(height: spacing),
          AspectRatio(
            aspectRatio: size.aspectRatio,
            child: _buildImage(images[1]),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: size.aspectRatio,
            child: _buildImage(images[0]),
          ),
        ),
        const SizedBox(width: spacing),
        Expanded(
          child: AspectRatio(
            aspectRatio: size.aspectRatio,
            child: _buildImage(images[1]),
          ),
        ),
      ],
    );
  }
}

class _ThreeImages extends StatelessWidget {
  const _ThreeImages({required this.images, required this.size});

  final List<String> images;
  final AiImageSize size;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: size.aspectRatio,
          child: _buildImage(images[0]),
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[1]),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[2]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FourImages extends StatelessWidget {
  const _FourImages({required this.images, required this.size});

  final List<String> images;
  final AiImageSize size;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[0]),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[2]),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: AspectRatio(
                aspectRatio: size.aspectRatio,
                child: _buildImage(images[3]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PdfAttachmentCard extends StatelessWidget {
  final String name;
  final bool isUser;

  const _PdfAttachmentCard({
    required this.name,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.white.withValues(alpha: 0.08)
            : AppColors.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? AppColors.userBubbleTextLight
                    : (context.isDark
                        ? AppColors.aiBubbleTextDark
                        : AppColors.aiBubbleTextLight),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle_rounded,
            color: isUser
                ? AppColors.userBubbleTextLight.withValues(alpha: 0.72)
                : AppColors.primaryLight,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS ICON — sending / delivered / failed indicators
// =============================================================================

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.theme.primaryColor,
          ),
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_rounded,
          size: 16,
          color: AppColors.success,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.error,
        );
      case MessageStatus.partial:
        return const Icon(
          Icons.schedule_rounded,
          size: 16,
          color: AppColors.warning,
        );
    }
  }
}

// =============================================================================
// TYPING INDICATOR — shown while AI is generating
// =============================================================================

class TypingIndicator extends StatefulWidget {

  const TypingIndicator({
    super.key,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.isTablet ? 18 : 14,
            vertical: context.isTablet ? 14 : 10,
          ),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.aiBubbleDark
                : AppColors.aiBubbleLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: context.isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (index) => _AnimatedDot(
                controller: _controller,
                delay: index * 0.2,
                isTablet: context.isTablet,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final bool isTablet;

  const _AnimatedDot({
    required this.controller,
    required this.delay,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = (controller.value - delay).clamp(0.0, 1.0);
        final opacity =
            (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
        return Container(
          width: isTablet ? 10 : 8,
          height: isTablet ? 10 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (context.isDark
                    ? AppColors.primaryDark
                    : AppColors.primaryLight)
                .withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
