/// Centralised design-tokens file for your project.
/// Add or tweak colors / text styles here and the whole
/// app will update automatically.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 1. Color scheme  ────────────────────────────────────────────
const _primary700 = Color(0xFF0E4334); // brand dark
const _primary400 = Color(0xFF1F6C53); // lighter brand
const _background = Color(0xFF00D861);
const _error600   = Color(0xFFE54B4B);
const _gray700    = Color(0xFF4A4A4A);

final ColorScheme colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _primary700,
  onPrimary: Colors.white,
  primaryContainer: _primary400,
  onPrimaryContainer: Colors.white,
  secondary: _primary400,
  onSecondary: Colors.white,
  secondaryContainer: _primary400.withOpacity(.15),
  onSecondaryContainer: _primary700,
  background: _background,
  onBackground: _gray700,
  surface: Colors.white,
  onSurface: _gray700,
  error: _error600,
  onError: Colors.white,
  surfaceVariant: const Color(0xFFF1F1F1),
  onSurfaceVariant: _gray700,
  outline: const Color(0xFFDADADA),
  shadow: Colors.black12,
  inverseSurface: _primary700,
  onInverseSurface: Colors.white,
  tertiary: const Color(0xFF79D88E),
  onTertiary: _gray700,
);

// 2. Text theme  ──────────────────────────────────────────────
final TextTheme textTheme = TextTheme(
  headlineSmall: GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: colorScheme.onBackground,
  ),
  bodyMedium: GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: colorScheme.onBackground,
  ),
  labelLarge: GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: colorScheme.onPrimary,
  ),
  labelSmall: GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: colorScheme.primary,
  ),
);

// 3. App-wide theme  ──────────────────────────────────────────
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: colorScheme,
  textTheme: textTheme,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: colorScheme.surfaceVariant,
    hintStyle: textTheme.bodyMedium!.copyWith(color: _gray700.withOpacity(.6)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
  ),
);
