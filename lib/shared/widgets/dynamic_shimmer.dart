import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/extensions/build_context_extensions.dart';

/// A premium, customizable shimmer effect widget.
///
/// Designed to follow the "Living Ether" aesthetic with smooth transitions
/// and theme-aware colors.
class DynamicShimmer extends StatelessWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;

  const DynamicShimmer({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  /// Factory for a circular shimmer (e.g. for avatars)
  factory DynamicShimmer.circular({
    required double size,
    EdgeInsetsGeometry? margin,
  }) {
    return DynamicShimmer(
      height: size,
      width: size,
      shape: BoxShape.circle,
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        context.isDark ? Colors.grey[500]! : Colors.grey[200]!;
    final Color highlightColor =
        context.isDark ? Colors.grey[300]! : Colors.grey[300]!;

    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white, // Color is required for Shimmer to work
            borderRadius: shape == BoxShape.circle
                ? null
                : BorderRadius.circular(borderRadius),
            shape: shape,
          ),
        ),
      ),
    );
  }
}
