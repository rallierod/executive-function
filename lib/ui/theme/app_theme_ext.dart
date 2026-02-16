import 'package:flutter/material.dart';

import 'app_tokens.dart';

@immutable
class AppThemeExt extends ThemeExtension<AppThemeExt> {
  final LinearGradient backgroundGradient;
  final Color surface0;
  final Color surface1;
  final Color border;
  final Color borderSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color navy;
  final Color navyHover;
  final Color pink;
  final Color pinkSoft;
  final Color pinkTint;

  const AppThemeExt({
    required this.backgroundGradient,
    required this.surface0,
    required this.surface1,
    required this.border,
    required this.borderSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.navy,
    required this.navyHover,
    required this.pink,
    required this.pinkSoft,
    required this.pinkTint,
  });

  static const light = AppThemeExt(
    backgroundGradient: AppTokens.lightBackgroundGradient,
    surface0: AppTokens.lightSurface0,
    surface1: AppTokens.lightSurface1,
    border: AppTokens.lightBorder,
    borderSoft: AppTokens.lightBorderSoft,
    textPrimary: AppTokens.lightTextPrimary,
    textSecondary: AppTokens.lightTextSecondary,
    navy: AppTokens.navyInk,
    navyHover: AppTokens.navyInkHover,
    pink: AppTokens.accentPink,
    pinkSoft: AppTokens.accentPinkSoft,
    pinkTint: AppTokens.accentPinkTint,
  );

  static const dark = AppThemeExt(
    backgroundGradient: AppTokens.darkBackgroundGradient,
    surface0: AppTokens.darkSurface0,
    surface1: AppTokens.darkSurface1,
    border: AppTokens.darkBorder,
    borderSoft: AppTokens.darkBorderSoft,
    textPrimary: AppTokens.darkTextPrimary,
    textSecondary: AppTokens.darkTextSecondary,
    navy: AppTokens.navyInk,
    navyHover: AppTokens.navyInkHover,
    pink: AppTokens.accentPink,
    pinkSoft: AppTokens.accentPinkSoft,
    pinkTint: AppTokens.accentPinkTint,
  );

  @override
  AppThemeExt copyWith({
    LinearGradient? backgroundGradient,
    Color? surface0,
    Color? surface1,
    Color? border,
    Color? borderSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? navy,
    Color? navyHover,
    Color? pink,
    Color? pinkSoft,
    Color? pinkTint,
  }) {
    return AppThemeExt(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      navy: navy ?? this.navy,
      navyHover: navyHover ?? this.navyHover,
      pink: pink ?? this.pink,
      pinkSoft: pinkSoft ?? this.pinkSoft,
      pinkTint: pinkTint ?? this.pinkTint,
    );
  }

  @override
  AppThemeExt lerp(ThemeExtension<AppThemeExt>? other, double t) {
    if (other is! AppThemeExt) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeX on BuildContext {
  AppThemeExt get appTheme => Theme.of(this).extension<AppThemeExt>()!;
}
