import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:ai_voice_genie/core/constants/app_assets.dart';
import 'package:ai_voice_genie/features/chat/domain/chat_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/extensions/string_extension.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/pdf_document_service.dart';
import '../../../../core/utils/status_message_utils.dart';
import '../../../../core/utils/storage_permission_helper.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../shared/model/image_model.dart';
import '../../../../shared/widgets/full_screen_image_gallery.dart';
import '../../../../shared/widgets/full_screen_pdf_gallery.dart';
import '../../../../shared/widgets/generated_image_download_button.dart';
import '../../../../shared/widgets/image_view.dart';
import '../../../voice_speech/presentation/widgets/tts_play_button.dart';
import 'package:provider/provider.dart';

import '../chat_provider.dart';
import '../../domain/message_model.dart';
import 'model_indicator_chip.dart';
import 'typewriter_text.dart';
import '../../../../core/preferences/ai_preferences_provider.dart';
import '../../../voice_speech/presentation/voice_speech_provider.dart';

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
      !message.isUserCancelled &&
      message.lastPrompt.trim().isNotEmpty &&
      (message.imageUrls == null || message.imageUrls!.isEmpty) &&
      (message.pdfInfo == null || message.pdfInfo!.isEmpty);

  /// Resolves the human-readable text for a message (handles error messages, PDFs, stopped states).
  static String resolveDisplayText(BuildContext context, MessageModel message) {
    if (message.status == MessageStatus.failed) {
      // Try to translate the failure reason, fallback to raw message
      return AppLocalizations.of(context)?.translate(message.lastPrompt) ??
          message.lastPrompt;
    }
    // For generated PDF messages, ensure we never render the raw markdown document in the bubble.
    if (message.requestCapability == AiCapability.pdfGeneration &&
        message.pdfInfo != null &&
        message.pdfInfo!.isNotEmpty) {
      return AppLocalizations.of(context)?.hereIsYourPdf ??
          'Here is the document you requested.';
    }
    if (message.lastPrompt.trim().isEmpty &&
        (message.isUserCancelled || message.status == MessageStatus.partial)) {
      return AppLocalizations.of(context)?.stopResponse ?? 'Stopped';
    }
    return message.lastPrompt;
  }

  @override
  Widget build(BuildContext context) {
    final hasImages =
        message.imageUrls != null && message.imageUrls!.isNotEmpty;
    final hasPdfs = message.pdfInfo != null && message.pdfInfo!.isNotEmpty;
    final text = resolveDisplayText(context, message).trim();

    // Guard: Never render a collapsed empty bubble container if there is literally nothing to display.
    if (text.isEmpty && !hasImages && !hasPdfs) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // AI model chip — shown above AI responses
        if (!_isUser && message.modelRequest != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding / 2, vertical: 8.0),
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
              maxWidth: MediaQuery.sizeOf(context).width *
                  (context.isTablet
                      ? (MediaQuery.sizeOf(context).width > 1100 ? 0.6 : 0.65)
                      : 0.85),
            ),
            padding: (message.imageUrls?.isNotEmpty ?? false)
                ? EdgeInsets.symmetric(
                    horizontal: context.isCompact ? 4.0 : 8.0,
                    vertical: context.isCompact ? 4.0 : 6.0)
                : EdgeInsets.symmetric(
                    horizontal: isTablet ? 18.0 : 14.0,
                    vertical: isTablet ? 14.0 : 10.0,
                  ),
            margin: EdgeInsets.symmetric(
              horizontal: context.horizontalPadding / 2,
              // vertical: context.verticalSpacing
            ),
            decoration: BoxDecoration(
              gradient: _isUser
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: context.isDark
                          ? [
                              AppColors.primaryDark,
                              const Color(0xFF4358A4),
                            ]
                          : [
                              AppColors.primaryLight,
                              const Color(0xFF3B5BDB),
                            ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: context.isDark
                          ? [
                              AppColors.cardDark,
                              AppColors.surfaceDark,
                            ]
                          : [
                              AppColors.surfaceLight,
                              AppColors.cardLight,
                            ],
                    ),
              borderRadius: (message.imageUrls?.isNotEmpty ??
                      message.pdfInfo?.isEmpty ??
                      false)
                  ? BorderRadius.circular(12)
                  : BorderRadius.only(
                      topLeft: Radius.circular(_isUser ? 24 : 6),
                      topRight: Radius.circular(_isUser ? 6 : 24),
                      bottomLeft: const Radius.circular(24),
                      bottomRight: const Radius.circular(24),
                    ),
              border: Border.all(
                color: (context.isDark
                    ? AppColors.darkDivider
                    : AppColors.lightDivider),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isUser
                      ? AppColors.primaryLight.withValues(
                          alpha: context.isDark ? 0.30 : 0.20,
                        )
                      : Colors.black.withValues(
                          alpha: context.isDark ? 0.25 : 0.05,
                        ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
          isTablet: isTablet,
          // Pass TTS button alongside the timestamp for eligible AI messages.
          // Placing it here keeps the action row compact and accessible.
          ttsButton: _canSpeakMessage
              ? TtsPlaybackButton(
                  messageId: message.messageId,
                  messageContent: message.lastPrompt,
                  isTablet: isTablet,
                )
              : null,
        ),
      ],
    );
  }

  /// Copies the text content to clipboard and shows a toast
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.lastPrompt));
    context.showSuccessToast(
      context.l10n.copiedToClipboard,
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
  final bool isTablet;

  /// Optional TTS action widget rendered next to the timestamp.
  /// Null for user messages and non-speakable AI responses.
  final Widget? ttsButton;

  const _MessageTimestampRow({
    required this.message,
    this.ttsButton,
    this.isTablet = false,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 8, horizontal: context.horizontalPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display the localized time string (e.g. 10:42 AM)
          Text(
            message.timestamp.toTimeString,
            style: (context.isCompact
                    ? context.textTheme.labelSmall
                    : context.textTheme.labelMedium)
                ?.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          // For AI messages stopped by user, display a subtle Stopped badge
          if (!_isUser && message.isUserCancelled) ...[
            const SizedBox(width: 4),
            Text(
              '• ${AppLocalizations.of(context)?.responseStopped ?? "Stopped"}',
              style: (context.isCompact
                      ? context.textTheme.labelSmall
                      : context.textTheme.labelMedium)
                  ?.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
          ],
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
    final text = MessageBubble.resolveDisplayText(context, message).trim();

    // For AI messages, use TypewriterText which animates only the latest
    // response. For user messages, always use plain Text (no animation).
    Widget? textWidget;
    if (text.isNotEmpty) {
      final baseStyle = (isTablet
              ? context.textTheme.bodyLarge
              : context.textTheme.bodyMedium)
          ?.copyWith(
        height: 1.55,
        fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
        color: isUser
            ? AppColors.white
            : (context.isDark ? AppColors.white : AppColors.lightTextPrimary),
      );

      if (!isUser) {
        textWidget = Selector<ChatProvider, bool>(
          selector: (_, p) => p.shouldAnimateMessage(message.messageId),
          builder: (context, shouldAnimate, _) {
            if (!shouldAnimate) {
              return MarkdownBody(
                data: text,
                selectable: false,
                fitContent: true,
                onTapLink: (text, href, title) =>
                    TypewriterText.launchUrlSafely(href),
                styleSheet:
                    TypewriterText.buildMarkdownStyleSheet(context, baseStyle),
              );
            }
            return TypewriterText(
              key: ValueKey('typewriter_${message.messageId}'),
              text: text,
              animate: true,
              style: baseStyle,
              onTick: onTypewriterTick,
              onTickWithCount: (count) {
                context.read<ChatProvider>().updateRevealedLength(count);
              },
              onAnimationStart: () {
                final prefs = context.read<AiPreferencesProvider>();
                if (prefs.autoTextToSpeech) {
                  context
                      .read<VoiceProvider>()
                      .speak(text, messageId: message.messageId);
                }
              },
              onComplete: () {
                context
                    .read<ChatProvider>()
                    .markMessageAnimated(message.messageId);
                onTypewriterTick?.call();
              },
            );
          },
        );
      } else {
        // For user messages, wrap in LayoutBuilder to shrink-wrap the text box
        // to the exact width of the longest line. This prevents Flutter's
        // multi-line RenderParagraph from greedily expanding to constraints.maxWidth,
        // allowing the bubble container to tightly hug its largest child.
        textWidget = LayoutBuilder(
          builder: (context, constraints) {
            final tp = TextPainter(
              text: TextSpan(text: text, style: baseStyle),
              textDirection: Directionality.of(context),
            )..layout(maxWidth: constraints.maxWidth);

            final lines = tp.computeLineMetrics();
            final maxLineWidth = lines.isEmpty
                ? 0.0
                : lines.map((l) => l.width).reduce((a, b) => a > b ? a : b);

            return SizedBox(
              width: maxLineWidth.ceilToDouble(),
              child: Text(
                text,
                style: baseStyle,
              ),
            );
          },
        );
      }
    }

    // Compile the children based on what attachments the message has.
    final children = <Widget>[
      // 1. If images are present, render the image grid.
      // Both AI-generated images and user-attached images get the download button.
      if (message.imageUrls != null && message.imageUrls!.isNotEmpty)
        _ChatImage(
          images: message.imageUrls!,
          size: message.imageSize ?? AiImageSize.square,
          messageId: message.messageId,
          provider:
              message.modelRequest?.id ?? (isUser ? 'user_upload' : 'unknown'),
          isTablet: isTablet,
        ),

      // 2. If PDFs are present, render the adaptive PDF attachment collage.
      if (message.pdfInfo != null && message.pdfInfo!.isNotEmpty)
        _ChatPdf(
          pdfs: message.pdfInfo!,
          messageId: message.messageId,
          isTablet: isTablet,
        ),

      // 3. If there is text, render it below the attachments (with padding if media exists).
      if (textWidget != null) ...[
        if ((message.imageUrls != null && message.imageUrls!.isNotEmpty) ||
            (message.pdfInfo != null && message.pdfInfo!.isNotEmpty))
          const SizedBox(height: 12),
        textWidget,
      ],
    ];

    final hasImages =
        message.imageUrls != null && message.imageUrls!.isNotEmpty;
    final hasPdfs = message.pdfInfo != null && message.pdfInfo!.isNotEmpty;

    // If there's no media, just return the text widget directly to avoid an extra Column
    if (!hasImages && !hasPdfs) {
      return textWidget ?? const SizedBox.shrink();
    }

    // Wrap the content in a column so attachments sit above the text.
    // User bubble contents align to the right, AI response contents align to the left.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ChatImage extends StatelessWidget {
  final List<String> images;
  final AiImageSize size;

  /// Null for user-attached images — download button is not shown.
  final String? messageId;
  final String? provider;
  final bool isTablet;

  const _ChatImage({
    required this.images,
    required this.size,
    this.messageId,
    this.provider,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _OneAttachmentView(
        type: ChatAttachmentType.image,
        image: images.first,
        size: size,
        pdf: null,
        msgId: messageId,
        provider: provider,
        totalImages: images.length,
        isTablet: isTablet,
      );
    }

    final Widget collage;
    switch (images.length) {
      case 2:
        collage = _TwoAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          provider: provider,
          msgId: messageId,
          totalImages: images.length,
          isTablet: isTablet,
        );
        break;

      case 3:
        collage = _ThreeAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          msgId: messageId,
          provider: provider,
          totalImages: images.length,
          isTablet: isTablet,
        );
        break;

      default:
        // Handles 4 or more images gracefully (with +N overlay on cell 4)
        collage = _FourAttachmentView(
          type: ChatAttachmentType.image,
          images: images,
          size: size,
          pdfs: null,
          msgId: messageId,
          provider: provider,
          totalImages: images.length,
          isTablet: isTablet,
        );
        break;
    }

    // Pinned single circular download button for the entire multi-image collage
    if (messageId != null && provider != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          collage,
          Positioned(
            top: context.isCompact ? 0 : 4,
            right: context.isCompact ? 0 : 4,
            child: GeneratedImageDownloadButton(
              imageSources: images,
              imageKey: '${messageId}_all',
              provider: provider!,
            ),
          ),
        ],
      );
    }

    return collage;
  }
}

/// Builds an image widget without a download button (for user-attached images).
Widget _buildImage(
  String url, {
  double? width,
  double? height,
}) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return ImageView(
      image: ImageViewData.network(trimmed),
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      borderRadius: BorderRadius.circular(10),
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const _ImageFallback(),
      loadingBuilder: (_, __, ___) => const ShimmerLoading(borderRadius: 10),
    );
  }
  return _SmartAsyncImageViewer(
    url: trimmed,
    width: width,
    height: height,
  );
}

/// Builds an image wrapped in a [Stack] with a download button overlay.
///
/// Used only for AI-generated images (non-user messages).
/// The [imageKey] uniquely identifies this image for per-image loading state.
Widget _buildImageWithDownload({
  required String url,
  required String imageKey,
  required String provider,
  int totalImages = 1,
}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: _buildImage(
          url,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: GeneratedImageDownloadButton(
          imageSource: url,
          imageKey: imageKey,
          provider: provider,
        ),
      ),
    ],
  );
}

class _SmartAsyncImageViewer extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;

  const _SmartAsyncImageViewer({
    required this.url,
    this.width,
    this.height,
  });

  @override
  State<_SmartAsyncImageViewer> createState() => _SmartAsyncImageViewerState();
}

class _SmartAsyncImageViewerState extends State<_SmartAsyncImageViewer> {
  static final Map<String, Uint8List> _base64Cache = {};
  Uint8List? _decodedBytes;
  bool _isLoading = true;
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
        url.length > 100) {
      isBase64 = true;
    }

    if (isBase64) {
      // Strip any whitespace for cache key and decoding consistency
      base64Data = base64Data.replaceAll(RegExp(r'\s+'), '');

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

  static Uint8List _decodeBase64(String data) {
    final cleaned = data.replaceAll(RegExp(r'\s+'), '');
    return base64Decode(base64.normalize(cleaned));
  }

  Future<void> _decodeAsync(String base64Data) async {
    try {
      final bytes = await compute(_decodeBase64, base64Data);
      if (!mounted) return;
      if (_base64Cache.length >= 25) {
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
        width: widget.width,
        height: widget.height,
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
          width: widget.width,
          height: widget.height,
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
      width: widget.width,
      height: widget.height,
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
              l10n?.failedToLoadImage ?? 'Failed to load image',
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
  bool isTablet = false,
}) {
  const spacing = 10.0;

  // Determine card container & text colors:
  // For user messages, the bubble background is always brand blue ([primaryLight, 0xFF3B5BDB]
  // or [primaryDark, 0xFF4358A4]). Therefore, the PDF card inside a user bubble must always
  // use a deep, high-contrast dark slate container (0xFF0F172A) with crisp white text to
  // guarantee WCAG AAA (> 14:1 contrast ratio) in BOTH light and dark mode.
  final Color cardBg;
  final Color borderColor;
  final Color pdfForeground;

  cardBg = context.isDark
      ? AppColors.pdfBackgroundDark
      : AppColors.pdfBackgroundLight;
  borderColor = (context.isDark ? Colors.white : Colors.black)
      .withValues(alpha: context.isDark ? 0.16 : 0.12);
  pdfForeground =
      (context.isDark ? Colors.white : Colors.black87).withValues(alpha: 0.90);

  final pdfView = Icon(
    Icons.picture_as_pdf_rounded,
    size: context.isCompact ? 24 : 32,
    color: (context.isDark) ? AppColors.darkError : AppColors.lightError,
  );

  final Widget shareButton = Material(
    color: Colors.transparent,
    child: Tooltip(
      message: 'Share PDF',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _sharePdf(context, pdfInfo),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            Icons.share_outlined,
            color: pdfForeground,
            size: isTablet ? 18 : 15,
          ),
        ),
      ),
    ),
  );

  final Widget downloadButton = Material(
    color: Colors.transparent,
    child: Tooltip(
      message: 'Download PDF',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _downloadPdfToDevice(context, pdfInfo),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            Icons.file_download_outlined,
            color: pdfForeground,
            size: isTablet ? 21 : 18,
          ),
        ),
      ),
    ),
  );

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _openOrDownloadPdf(context, pdfInfo),
      onLongPress: () => FullScreenPdfGallery.open(
        context,
        pdfs: [pdfInfo],
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            pdfView,
            const SizedBox(width: spacing),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pdfInfo.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (context.isCompact
                            ? context.textTheme.bodySmall
                            : context.textTheme.bodyMedium)
                        ?.copyWith(
                      color: pdfForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (pdfInfo.fileSizeLabel.isNotEmpty) ...[
                          Text(
                            pdfInfo.fileSizeLabel,
                            style: (context.isCompact
                                    ? context.textTheme.labelSmall
                                    : context.textTheme.labelMedium)
                                ?.copyWith(
                              color: pdfForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(width: spacing),
                        shareButton,
                        const SizedBox(width: spacing),
                        downloadButton,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openOrDownloadPdf(
    BuildContext context, PdfAttachmentInfo pdfInfo) async {
  final openResult = await PdfDocumentService.instance.openPdf(pdfInfo);
  if (openResult.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(openResult.message.isNotEmpty
            ? openResult.message
            : 'Cannot open ${pdfInfo.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

Future<void> _sharePdf(BuildContext context, PdfAttachmentInfo pdfInfo) async {
  try {
    final safeName =
        pdfInfo.name.endsWith('.pdf') ? pdfInfo.name : '${pdfInfo.name}.pdf';
    final docsDir = await getApplicationDocumentsDirectory();
    final cachedFile = File('${docsDir.path}/generated_pdfs/$safeName');
    String? localPath;

    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      localPath = cachedFile.path;
    } else {
      final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdfInfo);
      if (bytes != null && bytes.isNotEmpty) {
        localPath = await PdfDocumentService.instance.savePdfLocally(
          bytes: bytes,
          fileName: safeName,
        );
      }
    }

    if (localPath != null && await File(localPath).exists()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(localPath, mimeType: 'application/pdf', name: safeName)
          ],
          subject: pdfInfo.name,
        ),
      );
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot share ${pdfInfo.name}: file unavailable'),
          backgroundColor: AppColors.darkError,
        ),
      );
    }
  } catch (e) {
    debugPrint('⚠️ Error sharing PDF: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: AppColors.darkError,
        ),
      );
    }
  }
}

Future<void> _downloadPdfToDevice(
    BuildContext context, PdfAttachmentInfo pdfInfo) async {
  // 1. Request / check storage permission before proceeding
  final hasPermission = await StoragePermissionHelper.requestDownloadPermission(
    context,
    isImage: false,
  );
  if (!hasPermission || !context.mounted) return;

  // 2. Display localized high-contrast downloading SnackBar
  context.showDownloadingSnackBar(
    context.l10n.downloadingPdfFile(pdfInfo.name),
  );

  // 3. Await bytes resolution
  final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdfInfo);
  if (bytes == null || bytes.isEmpty) {
    unawaited(AnalyticsService.instance.logPdfDownload(
      result: 'failure',
      fileSizeBytes: pdfInfo.fileSizeBytes,
      failureReason: 'empty_bytes',
    ));
    if (context.mounted) {
      context.cancelDownloadingSnackBar();
      context.showErrorToast(context.l10n.pdfSaveFailed);
    }
    return;
  }

  // 4. Await saving file to public Downloads
  final saved = await PdfDocumentService.instance.savePdfToPublicDownloads(
    bytes: bytes,
    fileName: pdfInfo.name,
  );

  unawaited(AnalyticsService.instance.logPdfDownload(
    result: saved ? 'success' : 'failure',
    fileSizeBytes: bytes.length,
    failureReason: saved ? '' : 'save_failed',
  ));

  // 5. Cancel SnackBar and show completion Toast
  if (context.mounted) {
    context.cancelDownloadingSnackBar();
    if (saved) {
      context.showSuccessToast(context.l10n.pdfSavedToDownloads(pdfInfo.name));
    } else {
      context.showErrorToast(context.l10n.pdfSaveFailed);
    }
  }
}

Future<void> _downloadAllPdfsToDevice(
    BuildContext context, List<PdfAttachmentInfo> pdfs) async {
  if (pdfs.isEmpty) return;
  if (pdfs.length == 1) {
    return _downloadPdfToDevice(context, pdfs.first);
  }

  // 1. Request / check storage permission before proceeding
  final hasPermission = await StoragePermissionHelper.requestDownloadPermission(
    context,
    isImage: false,
  );
  if (!hasPermission || !context.mounted) return;

  // 2. Display localized high-contrast downloading SnackBar
  context.showDownloadingSnackBar(
    context.l10n.downloadingPdfsCount(pdfs.length.toString()),
  );

  // 3. Await saving all PDFs
  int savedCount = 0;
  for (final pdf in pdfs) {
    try {
      final bytes = await PdfDocumentService.instance.resolvePdfBytes(pdf);
      if (bytes != null && bytes.isNotEmpty) {
        final saved =
            await PdfDocumentService.instance.savePdfToPublicDownloads(
          bytes: bytes,
          fileName: pdf.name,
        );
        if (saved) savedCount++;
      }
    } catch (e) {
      debugPrint('⚠️ Error downloading PDF ${pdf.name}: $e');
    }
  }

  // 4. Cancel SnackBar and show completion Toast
  if (context.mounted) {
    context.cancelDownloadingSnackBar();
    if (savedCount > 0) {
      context.showSuccessToast(
        context.l10n.pdfsSavedToDownloads(savedCount.toString()),
      );
    } else {
      context.showErrorToast(context.l10n.pdfsSaveFailed);
    }
  }
}

class _PdfBatchDownloadButton extends StatefulWidget {
  final List<PdfAttachmentInfo> pdfs;

  const _PdfBatchDownloadButton({required this.pdfs});

  @override
  State<_PdfBatchDownloadButton> createState() =>
      _PdfBatchDownloadButtonState();
}

class _PdfBatchDownloadButtonState extends State<_PdfBatchDownloadButton> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await _downloadAllPdfsToDevice(context, widget.pdfs);
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? Colors.black54 : Colors.white70;
    final iconColor = isDark ? AppColors.white : context.primaryColor;

    return Tooltip(
      message: 'Download all ${widget.pdfs.length} PDFs',
      child: IconButton(
        constraints: BoxConstraints(
          minWidth: context.isTablet ? 40 : 30,
          minHeight: context.isTablet ? 40 : 30,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: bg,
          shape: const CircleBorder(),
        ),
        icon: _isDownloading
            ? SizedBox(
                width: context.isCompact ? 15 : 20,
                height: context.isCompact ? 15 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(
                Icons.download_rounded,
                color: iconColor,
                size: context.isCompact ? 18 : 22,
              ),
        onPressed: _handleDownload,
      ),
    );
  }
}

Widget _buildOverflowPdfCard({
  required BuildContext context,
  required PdfAttachmentInfo pdfInfo,
  required int extraCount,
  required List<PdfAttachmentInfo> allPdfs,
  required bool isTablet,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => FullScreenPdfGallery.open(
        context,
        pdfs: allPdfs,
        initialIndex: 3,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Underlying 4th PDF card — maintains the exact same shape, borders, and layout
          IgnorePointer(
            child: _pdfView(
              context,
              pdfInfo,
              isTablet: isTablet,
            ),
          ),

          // Translucent black shade overlay matching the image attachment view
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.black.withValues(alpha: 0.65)
                    : Colors.black.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: context.isDark ? 0.16 : 0.24,
                  ),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.60),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChatPdf extends StatelessWidget {
  final List<PdfAttachmentInfo> pdfs;
  final String? messageId;
  final bool isTablet;

  const _ChatPdf({
    required this.pdfs,
    this.messageId,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (pdfs.isEmpty) return const SizedBox.shrink();

    final Widget collage;

    switch (pdfs.length) {
      case 1:
        collage = _OneAttachmentView(
          type: ChatAttachmentType.pdf,
          pdf: pdfs.first,
          msgId: messageId,
          isTablet: isTablet,
        );
        break;

      case 2:
        collage = _TwoAttachmentView(
          type: ChatAttachmentType.pdf,
          pdfs: pdfs,
          msgId: messageId,
          isTablet: isTablet,
        );
        break;

      case 3:
        collage = _ThreeAttachmentView(
          type: ChatAttachmentType.pdf,
          pdfs: pdfs,
          msgId: messageId,
          isTablet: isTablet,
        );
        break;

      default:
        collage = _FourAttachmentView(
          type: ChatAttachmentType.pdf,
          pdfs: pdfs,
          msgId: messageId,
          isTablet: isTablet,
        );
        break;
    }

    return collage;
  }
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
    this.isTablet = false,
  });

  final String? image;
  final AiImageSize? size;
  final PdfAttachmentInfo? pdf;
  final ChatAttachmentType type;
  final String? provider;
  final String? msgId;
  final int totalImages;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    if (type == ChatAttachmentType.image) {
      final img = image;
      final sz = size ?? AiImageSize.square;
      final prov = provider;
      if (img != null) {
        final isShortHeight = context.screenHeight <= 550.0;
        final double maxWidth;
        final double maxHeight;
        switch (sz) {
          case AiImageSize.portrait:
            maxWidth = isTablet ? 360.0 : 240.0;
            maxHeight = isTablet ? 580.0 : (isShortHeight ? 220.0 : 400.0);
            break;
          case AiImageSize.square:
            maxWidth = isTablet ? 440.0 : 280.0;
            maxHeight = isTablet ? 440.0 : (isShortHeight ? 200.0 : 280.0);
            break;
          case AiImageSize.landscape:
            maxWidth = isTablet ? 580.0 : 300.0;
            maxHeight = isTablet ? 360.0 : (isShortHeight ? 180.0 : 200.0);
            break;
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: AspectRatio(
            aspectRatio: sz.aspectRatio,
            child: GestureDetector(
              onTap: () => FullScreenImageGallery.open(
                context,
                images: [img],
                initialIndex: 0,
                messageId: msgId,
                provider: prov,
              ),
              // Show download button only on AI-generated images (messageId is non-null)
              child: msgId != null && prov != null
                  ? _buildImageWithDownload(
                      url: img,
                      imageKey: '${msgId}_0',
                      provider: prov,
                      totalImages: totalImages,
                    )
                  : SizedBox.expand(
                      child: _buildImage(
                        img,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),
        );
      }
    } else {
      final p = pdf;
      if (p != null) {
        return _pdfView(
          context,
          p,
          isTablet: isTablet,
        );
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
    this.isTablet = false,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final sz = size ?? AiImageSize.square;
    final landscape = sz == AiImageSize.landscape;
    final prov = provider;
    final isShortHeight = context.screenHeight <= 550.0;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 2) {
        // Clean image tile that opens the full-screen interactive gallery on tap
        Widget img(int i) => GestureDetector(
              onTap: () => FullScreenImageGallery.open(
                context,
                images: imgs,
                initialIndex: i,
                messageId: msgId,
                provider: prov,
              ),
              child: _buildImage(imgs[i]),
            );

        if (landscape && !isTablet && !isShortHeight) {
          // Mobile Portrait phone (normal height): 2 rows x 1 column vertical stack
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(aspectRatio: sz.aspectRatio, child: img(0)),
                const SizedBox(height: spacing),
                AspectRatio(aspectRatio: sz.aspectRatio, child: img(1)),
              ],
            ),
          );
        }

        // Tablet Landscape, Mobile Landscape (short height), OR Portrait & Square:
        // 1 row x 2 columns side-by-side
        final double maxWidth;
        if (isTablet) {
          maxWidth = landscape ? 680.0 : 560.0;
        } else if (isShortHeight) {
          maxWidth = landscape ? 420.0 : 240.0;
        } else {
          maxWidth = 300.0;
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              Expanded(
                child: AspectRatio(aspectRatio: sz.aspectRatio, child: img(0)),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: AspectRatio(aspectRatio: sz.aspectRatio, child: img(1)),
              ),
            ],
          ),
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 2) {
        final isShortHeight = context.screenHeight <= 550.0;

        if (isTablet && !isShortHeight) {
          return SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: _pdfView(
                    context,
                    p[0],
                    isTablet: isTablet,
                  ),
                ),
                const SizedBox(width: spacing),
                Flexible(
                  child: _pdfView(
                    context,
                    p[1],
                    isTablet: isTablet,
                  ),
                ),
              ],
            ),
          );
        }

        // Phone vertical column
        return SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pdfView(
                context,
                p[0],
                isTablet: isTablet,
              ),
              const SizedBox(height: spacing),
              _pdfView(
                context,
                p[1],
                isTablet: isTablet,
              ),
            ],
          ),
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
    this.isTablet = false,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final sz = size ?? AiImageSize.square;
    final prov = provider;
    final isShortHeight = context.screenHeight <= 550.0;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 3) {
        // Clean image tile that opens the full-screen interactive gallery on tap
        Widget img(int i) => GestureDetector(
              onTap: () => FullScreenImageGallery.open(
                context,
                images: imgs,
                initialIndex: i,
                messageId: msgId,
                provider: prov,
              ),
              child: _buildImage(imgs[i]),
            );

        // 1 Row x 3 Columns strip for Portrait (both mobile & tablet)
        final isThreeStrip = sz == AiImageSize.portrait;

        if (isThreeStrip) {
          final double maxWidth =
              isTablet ? 600.0 : (isShortHeight ? 240.0 : 320.0);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              children: [
                Expanded(
                  child:
                      AspectRatio(aspectRatio: sz.aspectRatio, child: img(0)),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  child:
                      AspectRatio(aspectRatio: sz.aspectRatio, child: img(1)),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  child:
                      AspectRatio(aspectRatio: sz.aspectRatio, child: img(2)),
                ),
              ],
            ),
          );
        }

        // Hero top (16:9) + 2 sub items bottom (for Landscape and Square)
        final bottomAspectRatio =
            sz == AiImageSize.landscape ? sz.aspectRatio : 1.0;
        final double collageWidth;
        if (isTablet) {
          collageWidth = sz == AiImageSize.landscape ? 480.0 : 440.0;
        } else if (isShortHeight) {
          collageWidth = 220.0;
        } else {
          collageWidth = 300.0;
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: collageWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: img(0),
              ),
              const SizedBox(height: spacing),
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: bottomAspectRatio,
                      child: img(1),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: bottomAspectRatio,
                      child: img(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 3) {
        final isShortHeight = context.screenHeight <= 550.0;

        if (isTablet && !isShortHeight) {
          return SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _pdfView(
                        context,
                        p[0],
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    Flexible(
                      child: _pdfView(
                        context,
                        p[1],
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: spacing),
                _pdfView(
                  context,
                  p[2],
                  isTablet: isTablet,
                ),
              ],
            ),
          );
        }

        // Phone vertical column
        return SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: spacing),
                _pdfView(
                  context,
                  p[i],
                  isTablet: isTablet,
                ),
              ],
            ],
          ),
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
    this.isTablet = false,
  });

  final List<String>? images;
  final AiImageSize? size;
  final ChatAttachmentType type;
  final List<PdfAttachmentInfo>? pdfs;
  final String? provider;
  final String? msgId;
  final int totalImages;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    final prov = provider;
    final isShortHeight = context.screenHeight <= 550.0;

    if (type == ChatAttachmentType.image) {
      final imgs = images;
      if (imgs != null && imgs.length >= 4) {
        // Clean image tile that opens the full-screen interactive gallery on tap
        Widget img(int i) => GestureDetector(
              onTap: () => FullScreenImageGallery.open(
                context,
                images: imgs,
                initialIndex: i,
                messageId: msgId,
                provider: prov,
              ),
              child: _buildImage(imgs[i]),
            );

        final hasMore = imgs.length > 4;
        final extraCount = imgs.length - 3;
        final sz = size ?? AiImageSize.square;
        final cellAspectRatio = sz.aspectRatio;

        // Tablet Portrait 4-strip when exactly 4 images are present (no overflow badge)
        if (isTablet && sz == AiImageSize.portrait && !hasMore) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: Row(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: spacing),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cellAspectRatio,
                      child: img(i),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final double maxWidth;
        if (isTablet) {
          switch (sz) {
            case AiImageSize.portrait:
              maxWidth = 540.0;
              break;
            case AiImageSize.square:
              maxWidth = 600.0;
              break;
            case AiImageSize.landscape:
              maxWidth = 680.0;
              break;
          }
        } else if (isShortHeight) {
          switch (sz) {
            case AiImageSize.portrait:
              maxWidth = 200.0;
              break;
            case AiImageSize.square:
            case AiImageSize.landscape:
              maxWidth = 240.0;
              break;
          }
        } else {
          switch (sz) {
            case AiImageSize.portrait:
              maxWidth = 280.0;
              break;
            case AiImageSize.square:
            case AiImageSize.landscape:
              maxWidth = 300.0;
              break;
          }
        }

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cellAspectRatio,
                      child: img(0),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cellAspectRatio,
                      child: img(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cellAspectRatio,
                      child: img(2),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cellAspectRatio,
                      child: hasMore
                          ? GestureDetector(
                              onTap: () => FullScreenImageGallery.open(
                                context,
                                images: imgs,
                                initialIndex: 3,
                                messageId: msgId,
                                provider: prov,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildImage(imgs[3]),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: context.isDark
                                          ? Colors.black.withValues(alpha: 0.55)
                                          : Colors.white
                                              .withValues(alpha: 0.62),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+$extraCount',
                                        style: TextStyle(
                                          color: context.isDark
                                              ? Colors.white
                                              : context.primaryColor
                                                  .withValues(alpha: 0.6),
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : img(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } else {
      final p = pdfs;
      if (p != null && p.length >= 4) {
        final isShortHeight = context.screenHeight <= 550.0;
        final hasMore = p.length > 4;
        final extraCount = p.length - 3;

        final card4 = hasMore
            ? _buildOverflowPdfCard(
                context: context,
                pdfInfo: p[3],
                extraCount: extraCount,
                allPdfs: p,
                isTablet: isTablet,
              )
            : _pdfView(
                context,
                p[3],
                isTablet: isTablet,
              );

        if (isTablet && !isShortHeight) {
          return SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _pdfView(
                        context,
                        p[0],
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    Expanded(
                      child: _pdfView(
                        context,
                        p[1],
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: spacing),
                Row(
                  children: [
                    Expanded(
                      child: _pdfView(
                        context,
                        p[2],
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: spacing),
                    Expanded(
                      child: card4,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Phone vertical column (exactly 4 uniform cards)
        return SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: spacing),
                _pdfView(
                  context,
                  p[i],
                  isTablet: isTablet,
                ),
              ],
              const SizedBox(height: spacing),
              card4,
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}

// =============================================================================
// STATUS ICON — sending / delivered / failed indicators
// =============================================================================

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  double _statusIconSize(BuildContext context) {
    if (context.isCompact) {
      return 14.0;
    } else if (context.isTablet && context.isExpanded) {
      return 21.0;
    } else {
      return 16.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: _statusIconSize(context),
          height: _statusIconSize(context),
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.theme.primaryColor,
          ),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: _statusIconSize(context),
          color:
              context.isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: _statusIconSize(context),
          color: context.isDark ? AppColors.darkError : AppColors.lightError,
        );
      case MessageStatus.partial:
        return Icon(
          Icons.schedule_rounded,
          size: _statusIconSize(context),
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
            color: context.isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: context.isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider.withValues(alpha: 0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.25 : 0.05,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                    ? AppColors.primaryLight
                    : AppColors.primaryDark)
                .withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
