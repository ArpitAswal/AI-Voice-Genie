import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../extensions/build_context_extensions.dart';

class ShimmerLoading extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 16.0,
    this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // Default colors based on theme, similar to AppColors structure
    final defaultBaseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final defaultHighlightColor =
        isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor ?? defaultBaseColor,
      highlightColor: highlightColor ?? defaultHighlightColor,
      child: child ??
          Container(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, // Color is required for shimmer to work
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
    );
  }
}
