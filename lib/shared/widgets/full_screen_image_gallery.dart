import 'package:flutter/material.dart';

import 'generated_image_download_button.dart';
import 'image_view.dart';
import '../model/image_model.dart';

/// Full-screen interactive lightbox gallery for AI-generated and user images.
///
/// Features:
/// - Horizontal swipe between all images in the message ([PageView.builder]).
/// - Pinch-to-zoom and pan via [InteractiveViewer] (1x to 4x).
/// - Clean dark backdrop with semi-transparent frosted controls.
/// - Top bar: Close/back button, index counter (`2 / 4`), and per-image download button.
class FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String? messageId;
  final String? provider;

  const FullScreenImageGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.messageId,
    this.provider,
  });

  /// Opens the full-screen gallery with a smooth fade transition.
  static void open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String? messageId,
    String? provider,
  }) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => FullScreenImageGallery(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
          messageId: messageId,
          provider: provider,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildGalleryImage(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return ImageView(
        image: ImageViewData.network(trimmed),
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      );
    }
    return ImageView(
      image: ImageViewData.file(trimmed),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final currentUrl = widget.images[_currentIndex];
    final prov = widget.provider;
    final msgId = widget.messageId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Swipable & Zoomable Image PageView
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: total,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: _buildGalleryImage(widget.images[index]),
                ),
              );
            },
          ),

          // 2. Top Bar (Close, Counter, Download Active Image)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ),

                    // Counter badge (only when more than 1 image)
                    if (total > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Individual download button for the currently active image
                    if (msgId != null && prov != null)
                      GeneratedImageDownloadButton(
                        imageSource: currentUrl,
                        imageKey: '${msgId}_$_currentIndex',
                        provider: prov,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
