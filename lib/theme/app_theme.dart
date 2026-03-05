import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF3D5A8A);
  static const Color primaryPink = Color(0xFFE8748A);
  static const Color lightPink = Color(0xFFFFF0F3);
  static const Color softPink = Color(0xFFFFD6DF);
  static const Color backgroundGradientStart = Color(0xFFFFF5F7);
  static const Color backgroundGradientEnd = Color(0xFFF0F4FF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3561);
  static const Color textGrey = Color(0xFFADB5BD);
  static const Color buttonBlue = Color(0xFF4A7FD4);
  static const Color inputBorder = Color(0xFFE8D5DA);
  static const Color iconPink = Color(0xFFE8748A);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: AppColors.backgroundGradientStart,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryPink,
      ),
    );
  }
}
