import 'package:flutter/material.dart';

/// Einheitliches Aussehen (passend zum Webpanel): blauer Akzent, Material 3, Hell/Dunkel nach Systemeinstellung.
class AppTheme {
  static const seed = Color(0xFF2563EB);
  static const ok = Color(0xFF16A34A);
  static const warn = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  static ThemeData build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF3F5F9) : const Color(0xFF10141B),
      appBarTheme: AppBarTheme(
        backgroundColor: b == Brightness.light ? Colors.white : const Color(0xFF1A212B),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: b == Brightness.light ? Colors.white : const Color(0xFF1A212B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 44)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 44)),
      ),
    );
  }

  /// Farbe für Plus-/Minuswerte.
  static Color? signColor(BuildContext c, num v) => v < 0 ? danger : (v > 0 ? ok : null);
}
