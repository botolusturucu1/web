import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── RENK PALETİ ──────────────────────────────────────────────
  static const Color black      = Color(0xFF000000); // OLED siyah
  static const Color cardColor  = Color(0xFF121212); // Kart arkaplanı
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color white      = Color(0xFFFFFFFF);
  static const Color neonGreen  = Color(0xFF00E676); // Ana vurgu
  static const Color neonBlue   = Color(0xFF448AFF);
  static const Color neonRed    = Color(0xFFFF1744);
  static const Color neonOrange = Color(0xFFFF6D00);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color textDim    = Color(0xFF9E9E9E);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonBlue,
        surface: cardColor,
        background: black,
        error: neonRed,
        onPrimary: black,
        onSecondary: white,
        onSurface: white,
        onBackground: white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(
          color: white, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(
          color: white, fontSize: 22, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(
          color: white, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
          color: white, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: white, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: white, fontSize: 13),
        bodySmall: GoogleFonts.inter(color: textDim, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: white, fontSize: 18, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: white),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonGreen, width: 1.5),
        ),
        hintStyle: TextStyle(color: white.withOpacity(0.3)),
        labelStyle: const TextStyle(color: neonGreen),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: neonGreen,
        labelStyle: const TextStyle(color: white, fontSize: 13),
        side: BorderSide(color: white.withOpacity(0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: neonGreen,
        unselectedItemColor: textDim,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: white.withOpacity(0.08),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: const TextStyle(color: white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
