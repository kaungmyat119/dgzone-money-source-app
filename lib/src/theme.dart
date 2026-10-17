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
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    brightness: brightness,
    error: AppColors.coral,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0D1F19) : AppColors.mintBackground,
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      bodyLarge: TextStyle(color: scheme.onSurface),
      bodyMedium: TextStyle(color: scheme.onSurface),
      bodySmall: TextStyle(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF173128) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: dark ? const Color(0xFF24513E) : AppColors.mintSoft,
      backgroundColor: dark ? const Color(0xFF132A22) : Colors.white,
    ),
    dividerColor: scheme.outlineVariant,
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}
