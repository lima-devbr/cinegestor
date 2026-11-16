import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color background =
        isDark ? const Color(0xFF090A0F) : const Color(0xFFF2F2F7);
    final Color surface =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final Color surfaceElevated =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
    final Color glassBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
    final Color accentBlue =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final Color accentIndigo =
        isDark ? const Color(0xFF5E5CE6) : const Color(0xFF5856D6);
    final Color systemRed =
        isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
    final Color textPrimary =
        isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
    final Color textSecondary =
        isDark ? const Color(0xFFA1A1A6) : const Color(0xFF636366);
    final Color textTertiary =
        isDark ? const Color(0xFF6E6E73) : const Color(0xFF8E8E93);
    final Color inputFill = isDark
        ? surfaceElevated.withValues(alpha: 0.75)
        : const Color(0xFFFFFFFF);
    final Color dividerColor =
        isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000);

    final baseTextTheme =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: (isDark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        primary: accentBlue,
        secondary: accentIndigo,
        surface: surface,
        error: systemRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.08,
          letterSpacing: -0.8,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.12,
          letterSpacing: -0.6,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: -0.4,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.25,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.45,
          letterSpacing: -0.1,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          height: 1.45,
          letterSpacing: -0.05,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
          letterSpacing: 0.15,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.3,
          color: textTertiary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? surface.withValues(alpha: 0.85)
            : surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary, size: 21),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentBlue, width: 1.6),
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 13.5,
          letterSpacing: -0.05,
        ),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: 13.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: glassBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: glassBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: glassBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: glassBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: glassBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
    );
  }
}
