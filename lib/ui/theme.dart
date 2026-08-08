import 'package:flutter/material.dart';

/// Tema "console" da interface: tela cheia, escura, alta contraste e capas em
/// destaque — estilo ES-DE/EmulationStation. Leve e com acentos vibrantes.
class AppTheme {
  static const Color background = Color(0xFF0A0C12);
  static const Color surface = Color(0xFF141823);
  static const Color surfaceHigh = Color(0xFF1E2432);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentAlt = Color(0xFF22D3EE);

  static const Color textPrimary = Color(0xFFF4F5F9);
  static const Color textSecondary = Color(0xFFB4BAC9);
  static const Color textFaint = Color(0xFF6E7687);

  /// Cor de destaque deterministica por sistema (nome) para o carrossel.
  static Color systemColor(String systemName) {
    var hash = 0;
    for (final c in systemName.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return tilePalette[hash % tilePalette.length];
  }

  /// Gradiente de fundo suave para um sistema sem capa.
  static LinearGradient systemGradient(Color base) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, const Color(0xFF0A0C12), 0.35)!,
        Color.lerp(base, const Color(0xFF0A0C12), 0.72)!,
        const Color(0xFF0A0C12),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  /// Escurece uma cor para overlays/gradientes.
  static Color darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0))
        .toColor();
  }

  static const List<Color> tilePalette = [
    Color(0xFF8B5CF6),
    Color(0xFF22D3EE),
    Color(0xFFF43F5E),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF3B82F6),
  ];

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      secondary: accentAlt,
      surface: surface,
      surfaceContainer: surfaceHigh,
      onSurface: Colors.white,
      outline: Colors.white24,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    final base = dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accentAlt,
        surface: Colors.white,
        surfaceContainer: const Color(0xFFF1F3F7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    );
  }
}
