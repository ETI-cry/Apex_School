import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apex_colors.dart';

/// ═══════════════════════════════════════════════════════════
/// APEX DESIGN SYSTEM — Theme Data (Material 3)
/// ═══════════════════════════════════════════════════════════

class ApexTheme {
  // ── Dark Theme (default) ──
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ApexColors.background,
    colorScheme: const ColorScheme.dark(
      primary: ApexColors.primary,
      onPrimary: ApexColors.background,
      secondary: ApexColors.accent,
      onSecondary: ApexColors.background,
      surface: ApexColors.surface,
      onSurface: ApexColors.textPrimary,
      error: ApexColors.error,
      onError: Colors.white,
    ),

    // ── Typography ──
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36, fontWeight: FontWeight.w800,
        color: ApexColors.textPrimary, letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: ApexColors.textPrimary, letterSpacing: -0.3,
      ),
      headlineLarge: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: ApexColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: ApexColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: ApexColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500,
        color: ApexColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: ApexColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: ApexColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: ApexColors.textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: ApexColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: ApexColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: ApexColors.textMuted,
      ),
    ),

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: ApexColors.background,
      foregroundColor: ApexColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),

    // ── Card ──
    cardTheme: CardThemeData(
      color: ApexColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        side: const BorderSide(color: ApexColors.border, width: 1),
      ),
    ),

    // ── Input ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ApexColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: ApexColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: ApexColors.textMuted),
    ),

    // ── Elevated Button ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ApexColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.3,
        ),
      ),
    ),

    // ── Chip ──
    chipTheme: ChipThemeData(
      backgroundColor: ApexColors.surfaceElev,
      labelStyle: const TextStyle(color: ApexColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusSm),
      ),
    ),

    // ── Bottom Sheet ──
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ApexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ApexColors.radiusXl)),
      ),
    ),

    // ── Dialog ─
    dialogTheme: DialogThemeData(
      backgroundColor: ApexColors.surfaceElev,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusXl),
      ),
    ),

    // ── Snackbar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ApexColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: ApexColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Icons ──
    iconTheme: const IconThemeData(color: ApexColors.textSecondary),

    // ── FAB ──
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ApexColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
      ),
    ),
  );

  // ── Light Theme ──
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ApexColors.backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: ApexColors.primary,
      onPrimary: Colors.white,
      secondary: ApexColors.accent,
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      error: ApexColors.error,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        side: const BorderSide(color: ApexColors.borderLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        borderSide: const BorderSide(color: ApexColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: ApexColors.textMuted),
      hintStyle: const TextStyle(color: ApexColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ApexColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ApexColors.radiusMd),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}
