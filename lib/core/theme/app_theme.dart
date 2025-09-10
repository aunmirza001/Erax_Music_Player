import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(centerTitle: true),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}
