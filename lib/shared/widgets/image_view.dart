import 'dart:io';
import 'package:flutter/material.dart';

import '../model/image_model.dart';


class ImageView extends StatelessWidget {
  final ImageViewData image;

  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Color? color;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final BorderRadius? borderRadius;

  final Widget Function(BuildContext, Widget, int?, bool)? frameBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext)? placeholderBuilder;

  const ImageView({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.color,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.frameBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.placeholderBuilder,
    this.borderRadius
  });

  Widget _placeholder(BuildContext c) =>
      placeholderBuilder?.call(c) ?? ImageBuilders.placeholder(c);

  Widget _loading(BuildContext c) =>
      loadingBuilder?.call(c, const SizedBox(), null) ??
          ImageBuilders.loading(c);

  Widget _error(BuildContext c) =>
      errorBuilder?.call(c, '', null) ?? ImageBuilders.error(c);

  Widget Function(BuildContext, Widget, int?, bool) _frame() =>
      frameBuilder ?? ImageBuilders.fadeFrame;

  @override
  Widget build(BuildContext context) {
    switch (image.source) {
      case AppImageSource.asset:
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.asset(
            image.path!,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            color: color,
            filterQuality: filterQuality,
            isAntiAlias: isAntiAlias,
            frameBuilder: _frame(),
            errorBuilder: (c, e, s) => _error(c),
          ),
        );

      case AppImageSource.network:
        return Image.network(
          image.path!,
          headers: image.headers,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          color: color,
          filterQuality: filterQuality,
          isAntiAlias: isAntiAlias,
          frameBuilder: _frame(),
          errorBuilder: (c, e, s) => _error(c),
          loadingBuilder: (c, child, progress) {
            if (progress == null) return _loading(c);
            return _placeholder(c);
          },
        );

      case AppImageSource.file:
        return Image.file(
          File(image.path!),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          color: color,
          filterQuality: filterQuality,
          isAntiAlias: isAntiAlias,
          frameBuilder: _frame(),
          errorBuilder: (c, e, s) => _error(c),
        );

      case AppImageSource.memory:
        return Image.memory(
          image.bytes!,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          color: color,
          filterQuality: filterQuality,
          isAntiAlias: isAntiAlias,
          frameBuilder: _frame(),
          errorBuilder: (c, e, s) => _error(c),
        );
    }
  }
}

class ImageBuilders {
  static Widget placeholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image, color: Colors.grey, size: 28),
    );
  }

  static Widget loading(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 1.4));
  }

  static Widget error(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
    );
  }

  static Widget fadeFrame(
      BuildContext context,
      Widget child,
      int? frame,
      bool wasSynchronouslyLoaded,
      ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}