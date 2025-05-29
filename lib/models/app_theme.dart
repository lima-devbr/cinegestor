import 'package:flutter/material.dart';

class AppThemeModel {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color text;
  final Color textSecondary;

  const AppThemeModel({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.text,
    required this.textSecondary,
  });

  static const dark = AppThemeModel(
    primary: Colors.deepPurple,
    secondary: Colors.deepPurpleAccent,
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    error: Colors.redAccent,
    text: Colors.white,
    textSecondary: Colors.white70,
  );
} 