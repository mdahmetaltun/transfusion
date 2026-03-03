import 'package:flutter/material.dart';

class AppTheme {
  // Define colors suited for ER environment: High contrast, dark background, vivid alerts
  static const Color primaryColor = Color(0xFFD32F2F); // ER Red
  static const Color backgroundColor = Color(
    0xFF121212,
  ); // Dark grey/black for low light glare
  static const Color surfaceColor = Color(0xFF1E1E1E); // Inputs/cards

  static const Color alertRed = Color(0xFFFF5252);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color okGreen = Color(0xFF4CAF50);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFB0B0B0);

  static const Color lightBackgroundColor = Color(0xFFF4F6F8);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightSurfaceAltColor = Color(0xFFEFF3F8);
  static const Color lightTextColor = Color(0xFF1C2430);
  static const Color lightSubTextColor = Color(0xFF5C6878);
  static const Color lightBorderColor = Color(0xFFD7DEE7);

  // Blood Product Colors
  static const Color prbcColor = Color(0xFFE53935); // Red
  static const Color ffpColor = Color(0xFFFFB300); // Yellow/Amber
  static const Color pltColor = Color(0xFFFDD835); // Light Yellow

  static ThemeData get darkTheme {
    final darkColorScheme = const ColorScheme.dark().copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: surfaceColor,
      onSurface: textLight,
      error: alertRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textLight,
        ),
        iconTheme: IconThemeData(color: textLight),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF222222),
        labelStyle: const TextStyle(color: textGrey),
        helperStyle: const TextStyle(color: textGrey),
        prefixIconColor: textGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: Colors.grey[700],
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white70),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2B3138),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textLight,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textLight,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textLight,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textLight),
        bodyMedium: TextStyle(fontSize: 14, color: textGrey),
      ),
    );
  }

  static ThemeData get lightTheme {
    final lightColorScheme = const ColorScheme.light().copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: lightSurfaceColor,
      onSurface: lightTextColor,
      error: alertRed,
      onError: Colors.white,
      outline: lightBorderColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: lightBackgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurfaceColor,
        foregroundColor: lightTextColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        iconTheme: IconThemeData(color: lightTextColor),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: Colors.black12,
      ),
      dividerTheme: const DividerThemeData(color: lightBorderColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceAltColor,
        labelStyle: const TextStyle(color: lightSubTextColor),
        helperStyle: const TextStyle(color: lightSubTextColor),
        prefixIconColor: lightSubTextColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: Colors.grey[400],
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF202833),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: lightTextColor),
        bodyMedium: TextStyle(fontSize: 14, color: lightSubTextColor),
      ),
    );
  }
}
