import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFFE53935);
const kBackground = Color(0xFFFFFFFF);
const kCardBackground = Color(0xFFFAFAFA);
const kCardRadius = 12.0;
const kCardElevation = 2.0;
const kGreen = Color(0xFF2E7D32);
const kRed = Color(0xFFC62828);
const kGreenLight = Color(0xFFE8F5E9);
const kRedLight = Color(0xFFFFEBEE);

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      surface: kBackground,
    ),
    scaffoldBackgroundColor: kBackground,
    useMaterial3: true,
  );

  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: kBackground,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
    cardTheme: CardThemeData(
      color: kCardBackground,
      elevation: kCardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kBackground,
      indicatorColor: kPrimary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary);
        }
        return GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary);
        }
        return IconThemeData(color: Colors.grey[600]);
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
