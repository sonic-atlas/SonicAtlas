import 'package:flutter/material.dart';

class _ThemeColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _ThemeColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class AppTheme {
  static const Color primaryColor = Color(0xFF1DB954);
  static const Color lightPrimaryColor = Color(0xFF36693E);

  static const Color secondaryColor = Color(0xFFB954DB);
  static const Color lightSecondaryColor = Color(0xFF784F83);

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);

  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF121212);

  static const Color textSecondaryColor = Color(0xFFB3B3B3);
  static const Color lightTextSecondaryColor = Color(0xFF616161);

  static _ThemeColors _colors(Brightness brightness) {
    switch (brightness) {
      case Brightness.dark:
        return const _ThemeColors(
          primary: primaryColor,
          secondary: secondaryColor,
          background: darkBackground,
          surface: darkSurface,
          textPrimary: darkTextPrimary,
          textSecondary: textSecondaryColor,
        );
      case Brightness.light:
        return const _ThemeColors(
          primary: primaryColor,
          secondary: secondaryColor,
          background: lightBackground,
          surface: lightSurface,
          textPrimary: lightTextPrimary,
          textSecondary: lightTextSecondaryColor,
        );
    }
  }

  static ThemeData fromBrightness(Brightness brightness) {
    final c = _colors(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: c.primary,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.25),
        selectionHandleColor: c.primary,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        secondary: c.secondary,
        surface: c.surface,
        surfaceContainerHighest: c.surface,
        surfaceTint: Colors.transparent,
        onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
        onSecondary: brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        outline: c.textSecondary,
        outlineVariant: c.textSecondary.withValues(alpha: 0.25),
        error: Color(0xFFFF5540),
        onError: Color(0xFF1F0A08),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: c.textPrimary),
        bodyMedium: TextStyle(color: c.textPrimary),
        bodySmall: TextStyle(color: c.textSecondary),
        titleLarge: TextStyle(color: c.textPrimary),
        titleMedium: TextStyle(color: c.textPrimary),
        titleSmall: TextStyle(color: c.textSecondary),
        headlineMedium: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        foregroundColor: c.textPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        subtitleTextStyle: TextStyle(color: c.textSecondary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.all(c.textPrimary),
        ),
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.textSecondary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: TextStyle(color: c.textPrimary),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.textSecondary),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.primary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        thumbColor: c.primary,
        inactiveTrackColor: c.textSecondary.withValues(alpha: 0.3),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: c.textSecondary, width: 2),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary;
          }
          return null;
        }),
        checkColor: WidgetStateProperty.all(
          brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary;
          }
          return c.textSecondary;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary;
          }
          return c.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.primary.withValues(alpha: 0.5);
          }
          return c.surface;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return c.textSecondary;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primary,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(c.primary.withValues(alpha: 0.1)),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        disabledColor: c.surface.withValues(alpha: 0.5),
        selectedColor: c.primary,
        secondarySelectedColor: c.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(color: c.textPrimary),
        secondaryLabelStyle: TextStyle(color: c.textPrimary),
        brightness: brightness,
      ),
    );
  }
}
