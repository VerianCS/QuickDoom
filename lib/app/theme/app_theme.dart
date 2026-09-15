import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// The app's Material theme.
///
/// Material is themed rather than replaced: dialogs, menus, text fields and
/// tooltips stay stock and inherit from here, while the surfaces users
/// actually look at are built from the primitives in `lib/app/widgets`.
/// Rebuilding form controls to match a visual style is where a project like
/// this quietly doubles in size.
class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      outline: AppColors.dividerColor,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppShape.radius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.dividerColor,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: shape.copyWith(
          side: const BorderSide(color: AppColors.dividerColor),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        space: 1,
        thickness: 1,
      ),

      // The display cut is applied where it is chosen — nav slots, section
      // rules, buttons, readouts — and never through the text theme. Material
      // resolves dropdown values and menu entries from titleMedium and
      // labelLarge, so putting the Doom face there rendered file paths and
      // saved-port names in a display face with no real lowercase.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.onSurface),
        bodyMedium: TextStyle(color: AppColors.onBackground),
        bodySmall: TextStyle(color: AppColors.onSurfaceFaint),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        border: _inputBorder(AppColors.dividerColor),
        enabledBorder: _inputBorder(AppColors.dividerColor),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.6),
        labelStyle: const TextStyle(color: AppColors.onBackground),
        hintStyle: const TextStyle(color: AppColors.onSurfaceFaint),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.onSurfaceFaint,
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: 14,
            letterSpacing: 1.4,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: 13,
            letterSpacing: 1.1,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: shape,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.onBackground,
          hoverColor: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),

      iconTheme: const IconThemeData(color: AppColors.onBackground),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(
          side: const BorderSide(color: AppColors.dividerColor),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: AppFonts.doomText,
          fontSize: 17,
          letterSpacing: 1.3,
          color: AppColors.onSurface,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(
          side: const BorderSide(color: AppColors.dividerColor),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            shape.copyWith(
              side: const BorderSide(color: AppColors.dividerColor),
            ),
          ),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.void_,
          border: Border.all(color: AppColors.dividerColor),
        ),
        textStyle: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 11.5,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.onSurface),
        actionTextColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: shape.copyWith(
          side: const BorderSide(color: AppColors.dividerColor),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent;
        }),
        side: const BorderSide(color: AppColors.dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.onSurfaceFaint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.surfaceHigh;
        }),
        trackOutlineColor:
            const WidgetStatePropertyAll(AppColors.dividerColor),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.dividerSoft,
        circularTrackColor: Colors.transparent,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.35),
        ),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppShape.radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
