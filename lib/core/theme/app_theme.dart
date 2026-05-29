import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary — fresh green (food/nature)
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF4CAF50);
  static const primarySurface = Color(0xFFE8F5E9);
  static const primaryDark = Color(0xFF1B5E20);

  // Accent — warm orange (appetite)
  static const accent = Color(0xFFFF6F00);
  static const accentLight = Color(0xFFFFE0B2);

  // Status colors
  static const fresh = Color(0xFF43A047);
  static const freshSurface = Color(0xFFE8F5E9);
  static const expiringSoon = Color(0xFFF57C00);
  static const expiringSoonSurface = Color(0xFFFFF3E0);
  static const expired = Color(0xFFD32F2F);
  static const expiredSurface = Color(0xFFFFEBEE);

  // Neutrals
  static const ink = Color(0xFF1A1A1A);
  static const inkMuted = Color(0xFF6B6B6B);
  static const inkLight = Color(0xFFAAAAAA);
  static const surface = Color(0xFFF9FAF5);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAE0);

  // Dark mode
  static const darkBg = Color(0xFF0D1B0F);
  static const darkCard = Color(0xFF1A2E1C);
  static const darkBorder = Color(0xFF2A3D2C);
  static const darkInk = Color(0xFFEDF2ED);
  static const darkInkMuted = Color(0xFF8FAE91);

  // Category colors
  static const catDairy = Color(0xFF1976D2);
  static const catMeat = Color(0xFFC62828);
  static const catVeg = Color(0xFF388E3C);
  static const catFruit = Color(0xFFE65100);
  static const catGrain = Color(0xFF795548);
  static const catFrozen = Color(0xFF0288D1);
  static const catBeverage = Color(0xFF7B1FA2);
  static const catSnack = Color(0xFFF9A825);
  static const catCondiment = Color(0xFF00695C);
  static const catOther = Color(0xFF546E7A);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: GoogleFonts.nunito().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.nunito().fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.nunito().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.inkLight),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySurface,
        labelStyle: TextStyle(
          fontFamily: GoogleFonts.nunito().fontFamily,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.primaryLight,
        secondary: AppColors.accent,
        surface: AppColors.darkBg,
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      fontFamily: GoogleFonts.nunito().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
    );
  }
}
