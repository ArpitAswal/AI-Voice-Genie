import 'package:ai_voice_genie/shared/model/image_model.dart';
import 'package:ai_voice_genie/shared/widgets/image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/app_colors.dart';
import '../extensions/build_context_extensions.dart';

/// Extension methods on [BuildContext] for creating themed, reusable widgets.
///
/// These eliminate boilerplate by providing consistent styling from the theme,
/// replacing inline widget builders scattered across screens.
extension WidgetExtensions on BuildContext {
  // ============================================================================
  // TEXT FIELDS
  // ============================================================================

  /// Creates a themed [TextFormField] with consistent border styling.
  ///
  /// Uses [Theme.of(context)] for all colors and text styles.
  /// Supports validation, prefix icons, and keyboard types.
  Widget themedTextField(
      {required TextEditingController controller,
      String? label,
      IconData? prefixIcon,
      String? hint,
      TextInputType keyboardType = TextInputType.text,
      String? Function(String?)? validator,
      void Function(String)? onChanged,
      int? maxLength,
      int? maxLines = 1,
      int? minLines,
      bool obscureText = false,
      Widget? suffixIcon,
      TextCapitalization textCapitalization = TextCapitalization.none,
      TextInputAction? inputAction = TextInputAction.done,
      List<TextInputFormatter>? inputFormatters,
      bool enabled = true,
      bool read = false,
      String? errorText,
      InputBorder? border,
      InputBorder? errorBorder,
      EdgeInsets? contentPad,
      ScrollController? scrollController,
      ScrollPhysics? scrollPhysics,
      FocusNode? focus}) {
    final theme = Theme.of(this);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      focusNode: focus,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: read,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: theme.textTheme.bodyLarge,
      textInputAction: inputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium,
        labelStyle: theme.textTheme.titleSmall,
        errorText: errorText,
        counterText: maxLength != null ? null : '',
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: iconStandard,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
            ),
        enabledBorder: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              ),
            ),
        focusedBorder: border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color:
                      isDark ? AppColors.primaryDark : AppColors.primaryLight),
            ),
        errorBorder: errorBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: isDark ? AppColors.darkError : AppColors.lightError),
            ),
        focusedErrorBorder: errorBorder ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: isDark ? AppColors.darkError : AppColors.lightError),
            ),
        contentPadding: contentPad ??
            const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
      ),
    );
  }

  // ============================================================================
  // BUTTONS
  // ============================================================================

  /// Creates a full-width themed [ElevatedButton] with optional loading state.
  ///
  /// Guarantees a minimum touch target height of 48.0dp (WCAG 2.1 AA & M3 compliant).
  Widget themedElevatedButton(
      {required String label,
      required VoidCallback? onPressed,
      IconData? icon,
      double? height,
      double? width,
      double? imgSize,
      EdgeInsets? padding,
      FaIconData? faIcon,
      Alignment? align,
      Color? background,
      Color? foreground,
      String? imgIcon,
      Color? imgColor,
      OutlinedBorder? shape,
      TextStyle? textStyle}) {
    final theme = Theme.of(this);
    final effectiveHeight =
        (height ?? (isTablet ? 56.0 : 48.0)).clamp(48.0, double.infinity);
    final double adaptiveImgSize = imgSize ??
        (textStyle?.fontSize != null
            ? (textStyle!.fontSize! + 6).clamp(18.0, 24.0)
            : 24.0);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? double.infinity,
        minHeight: effectiveHeight,
      ),
      child: SizedBox(
        width: width ?? double.infinity,
        height: effectiveHeight,
        child: ElevatedButton(
          onPressed: onPressed,
          style: (padding != null ||
                  align != null ||
                  background != null ||
                  foreground != null ||
                  textStyle != null)
              ? theme.elevatedButtonTheme.style?.copyWith(
                  alignment: align,
                  padding: WidgetStatePropertyAll(padding),
                  backgroundColor: WidgetStatePropertyAll(background),
                  foregroundColor: WidgetStatePropertyAll(foreground),
                  textStyle: WidgetStatePropertyAll(textStyle),
                  shape: WidgetStatePropertyAll(shape))
              : theme.elevatedButtonTheme.style,
          child: (icon == null && faIcon == null && imgIcon == null)
              ? Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: iconStandard),
                      SizedBox(width: horizontalPadding / 2),
                    ] else if (faIcon != null) ...[
                      FaIcon(faIcon, size: iconDense),
                      SizedBox(width: horizontalPadding / 2),
                    ] else if (imgIcon != null) ...[
                      ImageView(
                          image: ImageViewData.asset(imgIcon),
                          height: adaptiveImgSize,
                          width: adaptiveImgSize,
                          color: imgColor),
                      SizedBox(width: horizontalPadding / 2),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Creates a full-width themed [OutlinedButton].
  ///
  /// Guarantees a minimum touch target height of 48.0dp (WCAG 2.1 AA & M3 compliant).
  Widget themedOutlinedButton(
      {required String label,
      required VoidCallback? onPressed,
      IconData? icon,
      double? height,
      double? width,
      Color? color}) {
    final theme = Theme.of(this);
    final effectiveHeight =
        (height ?? (isTablet ? 56.0 : 48.0)).clamp(48.0, double.infinity);

    return SizedBox(
      width: width ?? double.infinity,
      height: effectiveHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? theme.colorScheme.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(
            color: color?.withValues(alpha: 0.4) ??
                theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.8 : 0.4,
                ),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconStandard),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a full-width danger/destructive button (e.g., Sign Out, Delete).
  ///
  /// Guarantees a minimum touch target height of 48.0dp (WCAG 2.1 AA & M3 compliant).
  Widget themedDangerButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    double? height,
    double? width,
  }) {
    final effectiveHeight =
        (height ?? (isTablet ? 56.0 : 48.0)).clamp(48.0, double.infinity);
    return SizedBox(
      width: width ?? double.infinity,
      height: effectiveHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: isDark
              ? AppColors.darkError.withValues(
                  alpha: 0.2,
                )
              : AppColors.lightError.withValues(
                  alpha: 0.1,
                ),
          foregroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconStandard),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(this).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightError,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a themed button for tab switching or segmented control.
  ///
  /// Guarantees a minimum touch target height of 48.0dp.
  Widget themedTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(this);
    final borderRadius = BorderRadius.circular(isTablet ? 36 : 24);

    if (isSelected) {
      return ElevatedButton(
        onPressed: onPressed,
        style: theme.elevatedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: borderRadius)),
        ),
        child: Text(label),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: theme.outlinedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: borderRadius)),
        ),
        child: Text(label),
      );
    }
  }
}
