import 'package:flutter/material.dart';

import 'app_theme_ext.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    const cs = ColorScheme.light(
      primary: AppTokens.navyInk,
      secondary: AppTokens.accentPink,
      surface: AppTokens.lightSurface0,
      onSurface: AppTokens.lightTextPrimary,
      onPrimary: AppTokens.lightSurface0,
      onSecondary: AppTokens.navyInk,
      outline: AppTokens.lightBorder,
      shadow: AppTokens.navyInk,
      scrim: AppTokens.navyInk,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: const [AppThemeExt.light],
      cardTheme: CardThemeData(
        color: AppTokens.lightSurface0,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTokens.lightBorder),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppTokens.lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppTokens.lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: AppTokens.lightTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.lightSurface1,
        hintStyle: const TextStyle(color: AppTokens.lightTextSecondary),
        labelStyle: const TextStyle(color: AppTokens.lightTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTokens.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTokens.accentPink),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.navyInk,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.lightSurface1,
        indicatorColor: AppTokens.accentPinkTint,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppTokens.navyInk : AppTokens.lightTextSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppTokens.navyInk : AppTokens.lightTextSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppTokens.lightSurface0,
      ),
    );
  }

  static ThemeData dark() {
    const cs = ColorScheme.dark(
      primary: AppTokens.navyInk,
      secondary: AppTokens.accentPink,
      surface: AppTokens.darkSurface0,
      onSurface: AppTokens.darkTextPrimary,
      onPrimary: AppTokens.darkTextPrimary,
      onSecondary: AppTokens.navyInk,
      outline: AppTokens.darkBorder,
      shadow: AppTokens.navyInk,
      scrim: AppTokens.navyInk,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: Colors.transparent,
      extensions: const [AppThemeExt.dark],
      cardTheme: CardThemeData(
        color: AppTokens.darkSurface0,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTokens.darkBorder),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppTokens.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppTokens.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: AppTokens.darkTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.darkSurface1,
        hintStyle: const TextStyle(color: AppTokens.darkTextSecondary),
        labelStyle: const TextStyle(color: AppTokens.darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTokens.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTokens.accentPink),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.navyInk,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.darkSurface1,
        indicatorColor: AppTokens.darkBorderSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppTokens.accentPink
                : AppTokens.darkTextSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected
                ? AppTokens.accentPink
                : AppTokens.darkTextSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppTokens.darkSurface0,
      ),
    );
  }
}
