import 'package:flutter/material.dart';

class AppTokens {
  // Accent
  static const Color accentPink = Color(0xFFF472B6);
  static const Color accentPinkSoft = Color(0xFFF9A8D4);
  static const Color accentPinkTint = Color(0xFFFBCFE8);

  // Navy anchor
  static const Color navyInk = Color(0xFF1B2A41);
  static const Color navyInkHover = Color(0xFF162235);

  // LIGHT background gradient
  static const Color lightBgTop = Color(0xFFF4F7FB);
  static const Color lightBgMid = Color(0xFFEAF1F8);
  static const Color lightBgBottom = Color(0xFFE3ECF6);

  // LIGHT surfaces + borders + text
  static const Color lightSurface0 = Color(0xFFFFFFFF);
  static const Color lightSurface1 = Color(0xFFF7FAFD);
  static const Color lightBorder = Color(0xFFD6E0EC);
  static const Color lightBorderSoft = Color(0xFFE1E8F0);
  static const Color lightTextPrimary = Color(0xFF1B2A41);
  static const Color lightTextSecondary = Color(0xFF6B7C93);

  // DARK background gradient
  static const Color darkBgTop = Color(0xFF0E1624);
  static const Color darkBgMid = Color(0xFF111C2E);
  static const Color darkBgBottom = Color(0xFF0B1420);

  // DARK surfaces + borders + text
  static const Color darkSurface0 = Color(0xFF162338);
  static const Color darkSurface1 = Color(0xFF111C2E);
  static const Color darkBorder = Color(0xFF223552);
  static const Color darkBorderSoft = Color(0xFF1F324E);
  static const Color darkTextPrimary = Color(0xFFE6EDF7);
  static const Color darkTextSecondary = Color(0xFF8FA3BF);

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgTop, lightBgMid, lightBgBottom],
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgTop, darkBgMid, darkBgBottom],
  );
}
