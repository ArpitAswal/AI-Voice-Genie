import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ai_voice_genie/core/constants/app_assets.dart';
import 'package:ai_voice_genie/features/chat/domain/chat_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/extensions/string_extension.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../shared/model/image_model.dart';
import '../../../../shared/widgets/generated_image_download_button.dart';
import '../../../../shared/widgets/image_view.dart';
import '../../../voice_speech/presentation/widgets/tts_play_button.dart';
import 'package:provider/provider.dart';

import '../chat_provider.dart';
import '../../domain/message_model.dart';
import 'model_indicator_chip.dart';
import 'typewriter_text.dart';

/// Renders a single message bubble in the chat list.
///
/// User messages → right-aligned, primary color background
/// AI messages   → left-aligned, card background + model indicator chip
///
/// Supports:
///   - Long-press to copy text
///   - Sending status indicator (user messages)
///   - Model indicator chip (AI messages)
///   - TTS playback button (AI text-only responses)
///   - Responsive sizing for phone and tablet
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isTablet;

  /// Called on every character reveal during the typewriter animation.
  /// Wire this to the scroll controller to keep the latest text in view.
  final VoidCallback? onTypewriterTick;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isTablet,
    this.onTypewriterTick,
  });

  bool get _isUser => message.role == MessageRole.user;

  /// Whether this bubble is eligible for TTS playback.
  ///
  /// Conditions (all must be true):
  ///   1. Must be an AI (assistant) message
  ///   2. Message must not be in a failed/error state
  ///   3. Text content must not be empty (no point speaking an empty bubble)
  ///   4. Must not be an image-generation response (no imageUrls)
  ///   5. Must not be a PDF-attachment message (no pdfInfo)
  ///
  /// These rules prevent the speaker icon appearing on image cards, PDF
  /// previews, or broken/cancelled responses where there is nothing to read.
  bool get _canSpeakMessage =>
      !_isUser &&
      message.status != MessageStatus.failed &&
      message.content.trim().isNotEmpty &&
      (message.imageUrls == null || message.imageUrls!.isEmpty) &&
      (message.pdfInfo == null || message.pdfInfo!.isEmpty);

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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentGeometry.topLeft,
                  end: AlignmentGeometry.bottomRight,
                  colors: (context.isDark)
                      ? [
                          AppColors.messageBubbleDark,
                          AppColors.scaffoldDark,
                        ]
                      : [
                          AppColors.messageBubbleLight,
                          AppColors.primaryLight,
                        ]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(_isUser ? 24 : 4),
                topRight: Radius.circular(_isUser ? 4 : 24),
                bottomLeft: const Radius.circular(24),
                bottomRight: const Radius.circular(24),
              ),
            ),
            child: _MessageBubbleContent(
              message: message,
              isUser: _isUser,
              isTablet: isTablet,
              onTypewriterTick: onTypewriterTick,
            ),
          ),
        ),

        // Timestamp + status row displayed underneath the bubble
        _MessageTimestampRow(
          message: message,
          // Pass TTS button alongside the timestamp for eligible AI messages.
          // Placing it here keeps the action row compact and accessible.
          ttsButton: _canSpeakMessage
              ? TtsPlaybackButton(
                  messageId: message.id,
                  messageContent: message.content,
                  isTablet: isTablet,
                )
              : null,
        ),
        const SizedBox(height: 4)
      ],
    );
  }

  /// Copies the text content to clipboard and shows a toast
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    context.showSuccessToast(
      AppLocalizations.of(context)!.translate('copied_to_clipboard'),
    );
  }
}

/// A private widget that renders the timestamp and status icon beneath a message.
///
/// Optionally accepts a [ttsButton] widget that is displayed alongside the
/// timestamp, providing a compact speaker-icon action row for eligible AI
/// text responses without adding extra vertical spacing.
class _MessageTimestampRow extends StatelessWidget {
  final MessageModel message;

  /// Optional TTS action widget rendered next to the timestamp.
  /// Null for user messages and non-speakable AI responses.
  final Widget? ttsButton;

  const _MessageTimestampRow({required this.message, this.ttsButton});

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
          // For eligible AI messages, show the TTS speaker button
          if (ttsButton != null) ...[
            const SizedBox(width: 4),
            ttsButton!,
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
  final VoidCallback? onTypewriterTick;

  const _MessageBubbleContent({
    required this.message,
    required this.isUser,
    required this.isTablet,
    this.onTypewriterTick,
  });

  @override
  Widget build(BuildContext context) {
    final text = _displayText(context).trim();

    // For AI messages, use TypewriterText which animates only the latest
    // response. For user messages, always use plain Text (no animation).
    Widget? textWidget;
    if (text.isNotEmpty) {
      final baseStyle = context.textTheme.bodySmall?.copyWith(
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: context.isDark ? AppColors.white : AppColors.black,
      );

      if (!isUser) {
        textWidget = Selector<ChatProvider, String?>(
          selector: (_, p) => p.lastGeneratedMessageId,
          builder: (_, lastId, __) {
            return TypewriterText(
              text: text,
              animate: message.id == lastId,
              style: baseStyle,
              onTick: onTypewriterTick,
            );
          },
        );
      } else {
        textWidget = Text(text, style: baseStyle);
      }
    }

    // Compile the children based on what attachments the message has.
    final children = <Widget>[
      // 1. If images are present, render the image grid.
      // Only AI (non-user) image-generation responses get the download button.
      if (message.imageUrls != null && message.imageUrls!.isNotEmpty)
        _ChatImage(
          images: message.imageUrls!,
          size: message.imageSize ?? AiImageSize.square,
          // Pass metadata only for AI messages — user-attached images do not get the button.
          messageId: isUser ? null : message.id,
          provider: isUser ? null : (message.modelRequest?.id ?? 'unknown'),
        ),

      // 2. If PDFs are present, render the PDF cards.
      if (message.pdfInfo != null && message.pdfInfo!.isNotEmpty)
        _PdfAttachmentCard(
          pdfInfo: message.pdfInfo!,
          isUser: isUser,
        ),

      // 3. If there is text, render it below the attachments (with padding if media exists).
      if (textWidget != null) ...[
        if ((message.imageUrls != null && message.imageUrls!.isNotEmpty) ||
            (message.pdfInfo != null && message.pdfInfo!.isNotEmpty))
          const SizedBox(height: 12),
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

  /// Null for user-attached images — download button is not shown.
  final String? messageId;
  final String? provider;

  const _ChatImage({
    required this.images,
    required this.size,
    this.messageId,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    switch (images.length) {
      case 1:
        return _OneAttachmentView(
          type: ChatAttachmentType.image,
          image: images.first,
          size: size,
          pdf: null,
          msgId: messageId,
          provider: provider,
          totalImages: images.length,
        );

      case 2:
        return _TwoAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          provider: provider,
          msgId: messageId,
          totalImages: images.length,
        );

      case 3:
        return _ThreeAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          msgId: messageId,
          provider: provider,
          totalImages: images.length,
        );

      case 4:
        return _FourAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          msgId: messageId,
          provider: provider,
          totalImages: images.length,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// Builds an image widget without a download button (for user-attached images).
Widget _buildImage(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return ImageView(
      image: ImageViewData.network(trimmed),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      borderRadius: BorderRadius.circular(10),
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const _ImageFallback(),
      loadingBuilder: (_, __, ___) => const ShimmerLoading(borderRadius: 10),
    );
  }
  return _SmartAsyncImageViewer(url: trimmed);
}

/// Builds an image wrapped in a [Stack] with a download button overlay.
///
/// Used only for AI-generated images (non-user messages).
/// The [imageKey] uniquely identifies this image for per-image loading state.
Widget _buildImageWithDownload({
  required String url,
  required String imageKey,
  required String provider,
  required int totalImages,
}) {
  return Stack(
    children: [
      _buildImage(url),
      GeneratedImageDownloadButton(
        imageSource: url,
        imageKey: imageKey,
        provider: provider,
        imageCountInMessage: totalImages,
      ),
    ],
  );
}

class _SmartAsyncImageViewer extends StatefulWidget {
  final String url;
  const _SmartAsyncImageViewer({required this.url});

  @override
  State<_SmartAsyncImageViewer> createState() => _SmartAsyncImageViewerState();
}

class _SmartAsyncImageViewerState extends State<_SmartAsyncImageViewer> {
  static final Map<String, Uint8List> _base64Cache = {};
  Uint8List? _decodedBytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _SmartAsyncImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final url = widget.url.trim();
    if (url.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return;
    }

    bool isBase64 = url.startsWith('data:image');
    String base64Data = url;
    if (isBase64) {
      final commaIdx = url.indexOf(',');
      if (commaIdx != -1) {
        base64Data = url.substring(commaIdx + 1);
      }
    } else if (!url.startsWith('/') &&
        !url.startsWith('file:') &&
        url.length > 200) {
      isBase64 = true;
    }

    if (isBase64) {
      if (_base64Cache.containsKey(base64Data)) {
        setState(() {
          _decodedBytes = _base64Cache[base64Data];
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _decodeAsync(base64Data);
    } else {
      final filePath = url.replaceFirst('file://', '');
      final file = File(filePath);
      if (!file.existsSync()) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Future<void> _decodeAsync(String base64Data) async {
    try {
      final bytes = await Isolate.run(() => base64Decode(base64Data));
      if (!mounted) return;
      if (_base64Cache.length >= 50) {
        _base64Cache.remove(_base64Cache.keys.first);
      }
      _base64Cache[base64Data] = bytes;
      setState(() {
        _decodedBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ MessageBubble base64 decode error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const _ImageFallback();
    }

    final url = widget.url.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ImageView(
        image: ImageViewData.network(url),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        borderRadius: BorderRadius.circular(10),
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
        loadingBuilder: (_, __, ___) => const ShimmerLoading(borderRadius: 10),
      );
    }

    if (_isLoading || _decodedBytes == null) {
      if (!url.startsWith('data:image') &&
          (url.startsWith('/') || url.startsWith('file:'))) {
        final filePath = url.replaceFirst('file://', '');
        return ImageView(
          image: ImageViewData.file(filePath),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          borderRadius: BorderRadius.circular(10),
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const _ImageFallback(),
          loadingBuilder: (_, __, ___) =>
              const ShimmerLoading(borderRadius: 10),
        );
      }
      return const ShimmerLoading(borderRadius: 10);
    }

    return ImageView(
      image: ImageViewData.memory(_decodedBytes!),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      borderRadius: BorderRadius.circular(10),
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const _ImageFallback(),
      loadingBuilder: (_, __, ___) => const ShimmerLoading(borderRadius: 10),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // final shortestSide = constraints.biggest.shortestSide;
        // final fallbackSize = shortestSide.isFinite
        //     ? shortestSide.clamp(32.0, 120.0).toDouble()
        //     : 64.0;

        // Calculate proportional sizes based on available space
        final availableHeight = constraints.maxHeight;

        // Make the GIF take up 70% of the smaller dimension
        final gifSize = (availableHeight) * 0.7;

        return Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ImageView(
              image: const ImageViewData.asset(AppAssets.imageLoadError),
              width: gifSize - (gifSize * 0.2),
              height: gifSize,
              filterQuality: FilterQuality.high,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.translate('failed_to_load_image') ?? 'Failed to load image',
              style: context.textTheme.headlineSmall?.copyWith(
                  fontSize: (gifSize * 0.1), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

Widget _pdfView(
  BuildContext context,
  PdfAttachmentInfo pdfInfo, {
  bool squareView = false,
}) {
  const spacing = 8.0;
  final pdfView = Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: context.isDark
          ? AppColors.darkError.withValues(alpha: 0.2)
          : AppColors.lightError.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      size: 24,
      Icons.picture_as_pdf_rounded,
      color: context.isDark ? AppColors.lightError : AppColors.darkError,
    ),
  );

  return Container(
    constraints: BoxConstraints(
      minHeight: (squareView) ? 100 : 60,
    ),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    decoration: BoxDecoration(
      color: context.isDark
          ? AppColors.pdfBackgroundDark
          : AppColors.pdfBackgroundLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: context.isDark ? Colors.black54 : Colors.white70, width: 1),
    ),
    child: (squareView)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  pdfView,
                  const SizedBox(width: spacing),
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.isDark
                        ? AppColors.primaryLight
                        : AppColors.white,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: spacing / 2),
              Text(pdfInfo.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: spacing / 2),
              if (pdfInfo.fileSizeLabel.isNotEmpty)
                Text(pdfInfo.fileSizeLabel,
                    style: context.textTheme.bodySmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w500))
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              pdfView,
              const SizedBox(width: spacing),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pdfInfo.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    const SizedBox(height: spacing / 2),
                    if (pdfInfo.fileSizeLabel.isNotEmpty)
                      Text(pdfInfo.fileSizeLabel,
                          style: context.textTheme.bodySmall?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w500))
                  ],
                ),
              ),
              const SizedBox(width: spacing),
              Icon(
                Icons.check_circle_rounded,
                color:
                    context.isDark ? AppColors.primaryLight : AppColors.white,
                size: 20,
              ),
            ],
          ),
  );
}

class _OneAttachmentView extends StatelessWidget {
  const _OneAttachmentView({
    required this.type,
    this.image,
    this.size,
    this.pdf,
    this.provider,
    this.msgId,
    this.totalImages = 1,
  });

  final String? image;
  final AiImageSize? size;
  final PdfAttachmentInfo? pdf;
  final ChatAttachmentType type;
  final String? provider;
  final String? msgId;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    if (type == ChatAttachmentType.image) {
      final img = image;
      final sz = size;
      final prov = provider;
      if (img != null && sz != null) {
        return AspectRatio(
            aspectRatio: sz.aspectRatio,
            // Show download button only on AI-generated images (messageId is non-null)
            child: msgId != null && prov != null
                ? _buildImageWithDownload(
                    url: img,
                    imageKey: '${msgId}_0',
                    provider: prov,
                    totalImages: totalImages,
                  )
                : _buildImage(img));
      }
    } else {
      final p = pdf;
      if (p != null) {
        return _pdfView(context, p);
      }
    }
    return const SizedBox.shrink();
  }
}

class _TwoAttachmentView extends StatelessWidget {
  const _TwoAttachmentView({
    this.pdfs,
    this.images,
    this.size,
    required this.type,
    this.provider,
    this.msgId,
    this.totalImages = 2,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final sz = size;
    final landscape = sz == AiImageSize.landscape;
    final prov = provider;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 2 && sz != null) {
        // Helper to build image at index with optional download overlay
        Widget img(int i) => msgId != null && prov != null
            ? _buildImageWithDownload(
                url: imgs[i],
                imageKey: '${msgId}_$i',
                provider: prov,
                totalImages: totalImages,
              )
            : _buildImage(imgs[i]);

        if (landscape) {
          return Column(
            children: [
              AspectRatio(aspectRatio: sz.aspectRatio, child: img(0)),
              const SizedBox(height: spacing),
              AspectRatio(aspectRatio: sz.aspectRatio, child: img(1)),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
                child: AspectRatio(aspectRatio: sz.aspectRatio, child: img(0))),
            const SizedBox(width: spacing),
            Expanded(
                child: AspectRatio(aspectRatio: sz.aspectRatio, child: img(1))),
          ],
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 2) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _pdfView(context, p[0]),
            const SizedBox(height: spacing / 2),
            _pdfView(context, p[1]),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _ThreeAttachmentView extends StatelessWidget {
  const _ThreeAttachmentView({
    this.pdfs,
    this.images,
    this.size,
    required this.type,
    this.msgId,
    this.provider,
    this.totalImages = 3,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final sz = size;
    final prov = provider;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 3 && sz != null) {
        Widget img(int i) => msgId != null && prov != null
            ? _buildImageWithDownload(
                url: imgs[i],
                imageKey: '${msgId}_$i',
                provider: prov,
                totalImages: totalImages,
              )
            : _buildImage(imgs[i]);

        return Column(
          children: [
            AspectRatio(aspectRatio: sz.aspectRatio, child: img(0)),
            const SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(1))),
                const SizedBox(width: spacing),
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(2))),
              ],
            ),
          ],
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _pdfView(context, p[0]),
            const SizedBox(height: spacing / 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _pdfView(context, p[1], squareView: true)),
                const SizedBox(width: spacing),
                Expanded(child: _pdfView(context, p[2], squareView: true)),
              ],
            ),
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _FourAttachmentView extends StatelessWidget {
  const _FourAttachmentView({
    this.pdfs,
    this.images,
    this.size,
    required this.type,
    this.msgId,
    this.provider,
    this.totalImages = 4,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final sz = size;
    final prov = provider;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 4 && sz != null) {
        Widget img(int i) => msgId != null && prov != null
            ? _buildImageWithDownload(
                url: imgs[i],
                imageKey: '${msgId}_$i',
                provider: prov,
                totalImages: totalImages,
              )
            : _buildImage(imgs[i]);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(0))),
                const SizedBox(width: spacing),
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(1))),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(2))),
                const SizedBox(width: spacing),
                Expanded(
                    child: AspectRatio(
                        aspectRatio: sz.aspectRatio, child: img(3))),
              ],
            ),
          ],
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 4) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _pdfView(context, p[0], squareView: true),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  child: _pdfView(context, p[1], squareView: true),
                ),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _pdfView(context, p[2], squareView: true),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  child: _pdfView(context, p[3], squareView: true),
                ),
              ],
            )
          ],
        );
      }
    }
    return const SizedBox.shrink();
  }
}

class _PdfAttachmentCard extends StatelessWidget {
  final List<PdfAttachmentInfo> pdfInfo;
  final bool isUser;

  const _PdfAttachmentCard({
    required this.pdfInfo,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    switch (pdfInfo.length) {
      case 1:
        return _OneAttachmentView(
            type: ChatAttachmentType.pdf,
            pdf: pdfInfo.first,
            image: null,
            size: null);

      case 2:
        return _TwoAttachmentView(
            type: ChatAttachmentType.pdf,
            pdfs: pdfInfo,
            images: null,
            size: null);

      case 3:
        return _ThreeAttachmentView(
            type: ChatAttachmentType.pdf,
            pdfs: pdfInfo,
            images: null,
            size: null);

      case 4:
        return _FourAttachmentView(
            type: ChatAttachmentType.pdf,
            pdfs: pdfInfo,
            images: null,
            size: null);

      default:
        return const SizedBox.shrink();
    }
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
        return Icon(
          Icons.done_all_rounded,
          size: 16,
          color:
              context.isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: context.isDark ? AppColors.darkError : AppColors.lightError,
        );
      case MessageStatus.partial:
        return Icon(
          Icons.schedule_rounded,
          size: 16,
          color:
              context.isDark ? AppColors.darkWarning : AppColors.lightWarning,
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
                ? AppColors.messageBubbleDark
                : AppColors.messageBubbleLight,
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
                    ? AppColors.messageBubbleLight
                    : AppColors.messageBubbleDark)
                .withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
