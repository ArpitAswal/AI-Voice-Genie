import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../extensions/build_context_extensions.dart';

/// Centralized theme system for AI Voice Genie.
///
/// All theme configuration lives here.
/// Both light and dark themes are fully defined.
/// Never reference colors or text styles directly in widgets — use theme.
class AppTheme {
  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData getLightTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTextStyles.fontFamily,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight, // primary light brand color
        // primaryContainer: AppColors.primaryContainerLight, // Common theme brand color
        // onPrimary: AppColors.onPrimaryLight, // light color for widgets on top of primary
        surface: AppColors
            .surfaceLight, // For the BottomSheet/DialogBox background color
        surfaceContainer: AppColors
            .cardLight, // For any Card/Container on the BottomSheet/DialogBox/Widget when color not define
        // surfaceTint: AppColors.iconLightColor, // Icon color for the BottomSheet/DialogBox/FormField
        onSurface: AppColors
            .lightTextPrimary, // For the BottomSheet/DialogBox foreground (light) color and Text theme default colors
        onSurfaceVariant: AppColors.mutedText, // For text variant theme color
        outline: AppColors
            .lightDivider, // For borders specially for text fields and divider
        error: AppColors.lightError, // For error or warning or remove texts
        // secondary: AppColors.secondaryLight, // Common theme brand label color
        tertiary: AppColors
            .lightTextTertiary, // Common text colors for both light and dark theme
      ),

      scaffoldBackgroundColor: AppColors.scaffoldLight,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldLight,
        surfaceTintColor: AppColors.surfaceLight,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(
          color: AppColors.lightTextPrimary,
          size: context.isTablet ? 32 : 28,
        ),
        titleTextStyle: AppTextStyles.lightTextTheme.headlineMedium,
      ),

      // Text Theme
      textTheme: AppTextStyles.lightTextTheme,

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardLight,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.lightDivider,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.lightDivider,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 2),
        ),
        labelStyle: AppTextStyles.lightTextTheme.labelLarge,
        hintStyle: AppTextStyles.lightTextTheme.bodyMedium,
        errorStyle: AppTextStyles.lightTextTheme.labelSmall?.copyWith(
          color: AppColors.lightError,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.white,
            disabledBackgroundColor:
                AppColors.primaryLight.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: const BorderSide(color: Colors.transparent)),
            alignment: Alignment.center),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: AppColors.primaryLight,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          textStyle: AppTextStyles.lightTextTheme.titleMedium,
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          minimumSize: const Size(48, 48),
          textStyle: AppTextStyles.lightTextTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // Date Picker Theme
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceLight,
        headerBackgroundColor: AppColors.primaryLight,
        headerForegroundColor: AppColors.white,
        surfaceTintColor: AppColors.transparent,
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primaryLight),
          textStyle:
              WidgetStateProperty.all(AppTextStyles.lightTextTheme.titleMedium),
        ),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primaryLight),
          textStyle:
              WidgetStateProperty.all(AppTextStyles.lightTextTheme.titleMedium),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.isTablet ? 30 : 20),
          side: const BorderSide(color: AppColors.lightDivider, width: 1),
        ),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return AppColors.white;
        }),
        side: const BorderSide(color: AppColors.lightDivider, width: 1.5),
        checkColor: WidgetStateProperty.all(AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Icon
      iconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
        size: context.isTablet ? 32 : 24,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.lightTextTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardLight,
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.15),
        labelStyle: AppTextStyles.lightTextTheme.labelMedium,
        side: const BorderSide(color: AppColors.lightDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.lightTextTheme.titleLarge,
        contentTextStyle: AppTextStyles.lightTextTheme.bodyMedium,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData getDarkTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark, // primary dark brand color
        // primaryContainer: AppColors.primaryContainerDark, // Common theme brand color
        // onPrimary: AppColors.onPrimaryDark, // dark color for widgets on top of primary
        surface: AppColors
            .surfaceDark, // For the BottomSheet/DialogBox background color
        surfaceContainer: AppColors
            .cardDark, // For any Card/Container on the BottomSheet/DialogBox
        // surfaceTint: AppColors.iconDarkColor, // Icon color for the BottomSheet/DialogBox/FormField
        onSurface: AppColors
            .darkTextPrimary, // For the BottomSheet/DialogBox foreground (light) color and Text default colors
        onSurfaceVariant: AppColors.mutedText, // For text variant theme color
        outline: AppColors
            .darkDivider, // For borders specially for text fields and divider
        error: AppColors.darkError, // For error or warning or remove texts
        // secondary: AppColors.secondaryDark, // Common theme brand label color
        tertiary: AppColors
            .darkTextTertiary, // Common text colors for both light and dark theme
      ),
      scaffoldBackgroundColor: AppColors.scaffoldDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldDark,
        surfaceTintColor: AppColors.surfaceDark,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(
          color: AppColors.darkTextPrimary,
          size: context.isTablet ? 28 : 24,
        ),
        titleTextStyle: AppTextStyles.darkTextTheme.headlineMedium,
      ),
      textTheme: AppTextStyles.darkTextTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.darkDivider, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.darkDivider, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 2),
        ),
        labelStyle: AppTextStyles.darkTextTheme.labelLarge,
        hintStyle: AppTextStyles.darkTextTheme.bodyMedium,
        errorStyle: AppTextStyles.darkTextTheme.labelSmall?.copyWith(
          color: AppColors.lightError,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.white,
          disabledBackgroundColor:
              AppColors.primaryDark.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.white.withValues(alpha: 0.7),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Colors.transparent)),
          alignment: Alignment.center,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(36),
          ),
          side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
          textStyle: AppTextStyles.darkTextTheme.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size(48, 48),
          textStyle: AppTextStyles.darkTextTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceDark,
        headerBackgroundColor: AppColors.primaryDark,
        headerForegroundColor: AppColors.white,
        surfaceTintColor: AppColors.transparent,
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primaryDark),
          textStyle:
              WidgetStateProperty.all(AppTextStyles.darkTextTheme.titleMedium),
        ),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primaryDark),
          textStyle:
              WidgetStateProperty.all(AppTextStyles.darkTextTheme.titleMedium),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.isTablet ? 30 : 20),
          side: const BorderSide(color: AppColors.darkDivider, width: 1),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDark;
          }
          return AppColors.cardDark;
        }),
        side: const BorderSide(color: AppColors.darkDivider, width: 1.5),
        checkColor: WidgetStateProperty.all(AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      iconTheme: IconThemeData(
        color: AppColors.darkTextPrimary,
        size: context.isTablet ? 32 : 24,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.darkTextTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardDark,
        selectedColor: AppColors.primaryDark.withValues(alpha: 0.25),
        labelStyle: AppTextStyles.darkTextTheme.labelMedium,
        side: const BorderSide(color: AppColors.darkDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.darkTextTheme.titleLarge,
        contentTextStyle: AppTextStyles.darkTextTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}
