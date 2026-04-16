import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';

abstract final class AppTheme {
  // ── Light color scheme ──────────────────────────────────────────────────
  static const _lightScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.primaryLight,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.primaryContainer,
    onTertiaryContainer: AppColors.onPrimaryContainer,
    error: AppColors.error,
    onError: Colors.white,
    surface: AppColors.surfaceLight,
    onSurface: Color(0xFF1B1B1F),
    onSurfaceVariant: Color(0xFF46464F),
    outline: Color(0xFFC0C1CC),
    outlineVariant: Color(0xFFDFE0EA),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF6F6FB),
    surfaceContainer: AppColors.surfaceContainerLight,
    surfaceContainerHigh: AppColors.surfaceContainerHighLight,
    surfaceContainerHighest: Color(0xFFE2E2E8),
  );

  // ── Dark color scheme ───────────────────────────────────────────────────
  static const _darkScheme = ColorScheme.dark(
    primary: Color(0xFFB4C4F0),
    onPrimary: AppColors.primaryDark,
    primaryContainer: AppColors.primary,
    onPrimaryContainer: Color(0xFFD9DDED),
    secondary: Color(0xFFC6C5D0),
    onSecondary: AppColors.secondaryDark,
    secondaryContainer: AppColors.secondary,
    onSecondaryContainer: AppColors.secondaryContainer,
    tertiary: Color(0xFFBBC6E8),
    onTertiary: Color(0xFF1A2040),
    tertiaryContainer: AppColors.primaryLight,
    onTertiaryContainer: Color(0xFFD9DDED),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: AppColors.surfaceDark,
    onSurface: Color(0xFFE4E2E6),
    onSurfaceVariant: Color(0xFFC7C6D0),
    outline: Color(0xFF91909A),
    outlineVariant: Color(0xFF46464F),
    surfaceContainerLowest: Color(0xFF16161A),
    surfaceContainerLow: Color(0xFF1F1F23),
    surfaceContainer: Color(0xFF242428),
    surfaceContainerHigh: Color(0xFF2E2E33),
    surfaceContainerHighest: Color(0xFF39393E),
  );

  // ── Sub-themes ──────────────────────────────────────────────────────────
  static final _cardLight = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFDFE0EA)),
    ),
  );

  static final _cardDark = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF39393E)),
    ),
  );

  static final _inputDecoration = InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static final _buttonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(220, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static const _appBar = AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 1,
  );

  static const _navBar = NavigationBarThemeData(
    height: 64,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  );

  static const _navRail = NavigationRailThemeData(
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );

  // ── Public theme getters ────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightScheme,
        scaffoldBackgroundColor: _lightScheme.surface,
        appBarTheme: _appBar,
        cardTheme: _cardLight,
        inputDecorationTheme: _inputDecoration,
        filledButtonTheme: _buttonTheme,
        navigationBarTheme: _navBar,
        navigationRailTheme: _navRail,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkScheme,
        scaffoldBackgroundColor: _darkScheme.surface,
        appBarTheme: _appBar,
        cardTheme: _cardDark,
        inputDecorationTheme: _inputDecoration,
        filledButtonTheme: _buttonTheme,
        navigationBarTheme: _navBar,
        navigationRailTheme: _navRail,
      );
}
