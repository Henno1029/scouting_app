import 'package:flutter/material.dart';

class AppTheme {
  static const Color scoutingBlue = Color(0xFF003F87);
  static const Color scoutingDarkBlue = Color(0xFF003366);
  static const Color scoutingPaleBlue = Color(0xFF9AB3D5);
  static const Color scoutingRed = Color(0xFFCE1126);
  static const Color scoutingTan = Color(0xFFD6CEBD);
  static const Color scoutingLightTan = Color(0xFFE9E9E4);
  static const Color scoutingDarkTan = Color(0xFFAD9D7B);
  static const Color scoutingWarmGray = Color(0xFF515354);
  static const Color scoutingDarkGrey = Color(0xFF232528);
  static const Color scoutingOlive = Color(0xFF243E2C);
  static const Color scoutingYellow = Color(0xFFFFCC00);

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: scoutingBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: scoutingBlue,
      onPrimary: Colors.white,
      primaryContainer: scoutingPaleBlue,
      onPrimaryContainer: scoutingDarkBlue,
      secondary: scoutingRed,
      onSecondary: Colors.white,
      secondaryContainer: scoutingLightTan,
      onSecondaryContainer: scoutingDarkBlue,
      tertiary: scoutingOlive,
      onTertiary: Colors.white,
      surface: scoutingLightTan,
      onSurface: scoutingDarkGrey,
      outline: scoutingDarkTan,
      outlineVariant: scoutingTan,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scoutingLightTan,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: scoutingDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scoutingBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scoutingBlue,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scoutingBlue,
          side: const BorderSide(color: scoutingBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: scoutingRed,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: scoutingPaleBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: scoutingPaleBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: scoutingBlue, width: 2),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: scoutingDarkGrey,
        iconColor: scoutingBlue,
      ),
      dividerTheme: const DividerThemeData(color: scoutingTan),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: scoutingDarkBlue,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scoutingPaleBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: scoutingDarkBlue, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}