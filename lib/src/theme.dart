import 'package:flutter/material.dart';

abstract final class AppColors {
  static const mintBackground = Color(0xFFF1FFF8);
  static const mintSoft = Color(0xFFD8F8E6);
  static const emerald = Color(0xFF079455);
  static const emeraldDark = Color(0xFF034D35);
  static const coral = Color(0xFFFF5B55);
  static const amber = Color(0xFFF5B82E);
  static const ink = Color(0xFF092E24);
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    brightness: brightness,
    error: AppColors.coral,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        brightness == Brightness.light ? AppColors.mintBackground : null,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: brightness == Brightness.light ? Colors.white : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppColors.mintSoft,
      backgroundColor: Colors.white,
    ),
  );
}
