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
      bool obscureText = false,
      Widget? suffixIcon,
      TextCapitalization textCapitalization = TextCapitalization.none,
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
      obscureText: obscureText,
      enabled: enabled,
      readOnly: read,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium,
        labelStyle: theme.textTheme.titleSmall,
        errorText: errorText,
        counterText: maxLength != null ? null : '',
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
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
              borderSide: BorderSide(color: theme.colorScheme.primary),
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
            ),
      ),
    );
  }

  // ============================================================================
  // BUTTONS
  // ============================================================================

  /// Creates a full-width themed [ElevatedButton] with optional loading state.
  ///
  /// Primary action button — uses theme primary color.
  Widget themedElevatedButton(
      {required String label,
      required VoidCallback? onPressed,
      bool isLoading = false,
      IconData? icon,
      double? height,
      double? width,
      EdgeInsets? padding,
      FaIconData? faIcon,
      Alignment? align,
      Color? background,
      Color? foreground,
      String? imgIcon,
      Color? imgColor}) {
    final theme = Theme.of(this);

    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: (padding != null ||
                align != null ||
                background != null ||
                foreground != null)
            ? theme.elevatedButtonTheme.style?.copyWith(
                alignment: align,
                padding: WidgetStatePropertyAll(padding),
                backgroundColor: WidgetStatePropertyAll(background),
                foregroundColor: WidgetStatePropertyAll(foreground))
            : theme.elevatedButtonTheme.style,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon),
              SizedBox(width: horizontalPadding),
            ] else if (faIcon != null) ...[
              FaIcon(faIcon),
              SizedBox(width: horizontalPadding),
            ] else if (imgIcon != null) ...[
              ImageView(
                  image: ImageViewData.asset(imgIcon),
                  height: isTablet ? 32 : 28,
                  width: isTablet ? 32 : 28,
                  color: imgColor),
              SizedBox(width: horizontalPadding),
            ],
            Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a full-width themed [OutlinedButton].
  ///
  /// Secondary action button — uses theme primary color outline.
  Widget themedOutlinedButton(
      {required String label,
      required VoidCallback? onPressed,
      IconData? icon,
      double? height,
      double? width,
      Color? color}) {
    final theme = Theme.of(this);
    height = isTablet ? 62 : 44;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? theme.colorScheme.primary,
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
          children: [
            if (icon != null) ...[
              Icon(icon, size: isTablet ? 32 : 21),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color ?? theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a full-width danger/destructive button (e.g., Sign Out, Delete).
  ///
  /// Uses error color palette.
  Widget themedDangerButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    double? height,
    double? width,
  }) {
    height = isTablet ? 62 : 44;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
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
          children: [
            if (icon != null) ...[
              Icon(icon, size: isTablet ? 32 : 21),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: Theme.of(this).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightError,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a themed button for tab switching or segmented control.
  ///
  /// [isSelected] - Toggles between Elevated (selected) and Outlined (unselected) styles.
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
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: borderRadius)),
        ),
        child: Text(label),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: theme.outlinedButtonTheme.style?.copyWith(
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: borderRadius)),
        ),
        child: Text(label),
      );
    }
  }
}
