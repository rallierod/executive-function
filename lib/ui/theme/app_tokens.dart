import 'package:flutter/material.dart';

class AppTokens {
  // Accent
  static const Color accentPink = Color(0xFFF48FB1);
  static const Color accentPinkSoft = Color(0xFFF8BBD0);
  static const Color accentPinkTint = Color(0xFFFCE4EC);

  // Navy/light-blue anchor
  static const Color navyInk = Color(0xFF022658);
  static const Color navyInkHover = Color(0xFF011D44);

  // LIGHT background gradient
  static const Color lightBgTop = Color(0xFFEEF1FC);
  static const Color lightBgMid = Color(0xFFE1E7F7);
  static const Color lightBgBottom = Color(0xFFD2DCF1);

  // LIGHT surfaces + borders + text
  static const Color lightSurface0 = Color(0xFFFFFFFF);
  static const Color lightSurface1 = Color(0xFFF3F5FC);
  static const Color lightBorder = Color(0xFFC1CCE8);
  static const Color lightBorderSoft = Color(0xFFD2DBF0);
  static const Color lightTextPrimary = navyInk;
  static const Color lightTextSecondary = Color(0xFF3A4A87);

  // DARK background gradient
  static const Color darkBgTop = Color(0xFF070A2A);
  static const Color darkBgMid = Color(0xFF0A1033);
  static const Color darkBgBottom = Color(0xFF050824);

  // DARK surfaces + borders + text
  static const Color darkSurface0 = Color(0xFF11184A);
  static const Color darkSurface1 = Color(0xFF0C123D);
  static const Color darkBorder = Color(0xFF273373);
  static const Color darkBorderSoft = Color(0xFF202D66);
  static const Color darkTextPrimary = Color(0xFFE8ECFF);
  static const Color darkTextSecondary = Color(0xFFADB7E3);

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
