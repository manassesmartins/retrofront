import 'package:flutter/material.dart';

/// Tema "console" da interface com suporte a claro e escuro, estilo
/// ES-DE/EmulationStation. As cores da paleta ativa sao atualizadas por
/// [apply]/[build] antes da construcao da arvore; os widgets leem [AppTheme]
/// diretamente, sem precisar de plumb de contexto.
class AppTheme {
  // ---------- Paleta ativa (atualizada por [apply]) ----------
  static Color background = const Color(0xFF0A0C12);
  static Color surface = const Color(0xFF141823);
  static Color surfaceHigh = const Color(0xFF1E2432);
  static Color accent = const Color(0xFF8B5CF6);
  static Color accentAlt = const Color(0xFF22D3EE);
  static Color textPrimary = const Color(0xFFF4F5F9);
  static Color textSecondary = const Color(0xFFB4BAC9);
  static Color textFaint = const Color(0xFF6E7687);
  static Color onAccent = Colors.white;
  static Color border = Colors.white24;
  static Color scrim = const Color(0x66000000);
  static bool _dark = true;

  static bool get isDark => _dark;

  // ---------- Paletas fixas ----------
  static const Color _darkBackground = Color(0xFF0A0C12);
  static const Color _darkSurface = Color(0xFF141823);
  static const Color _darkSurfaceHigh = Color(0xFF1E2432);
  static const Color _darkAccent = Color(0xFF8B5CF6);
  static const Color _darkAccentAlt = Color(0xFF22D3EE);
  static const Color _darkTextPrimary = Color(0xFFF4F5F9);
  static const Color _darkTextSecondary = Color(0xFFB4BAC9);
  static const Color _darkTextFaint = Color(0xFF6E7687);

  static const Color _lightBackground = Color(0xFFF4F5F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceHigh = Color(0xFFE8EAF1);
  static const Color _lightAccent = Color(0xFF6D3BF0);
  static const Color _lightAccentAlt = Color(0xFF0891B2);
  static const Color _lightTextPrimary = Color(0xFF171A23);
  static const Color _lightTextSecondary = Color(0xFF545C6E);
  static const Color _lightTextFaint = Color(0xFF8A91A1);

  /// Atualiza a paleta ativa para o modo [dark]. Chamado por [build] e pode
  /// ser invocado antes de montar telas que leem [AppTheme] fora do MaterialApp.
  static void apply({required bool dark}) {
    _dark = dark;
    background = dark ? _darkBackground : _lightBackground;
    surface = dark ? _darkSurface : _lightSurface;
    surfaceHigh = dark ? _darkSurfaceHigh : _lightSurfaceHigh;
    accent = dark ? _darkAccent : _lightAccent;
    accentAlt = dark ? _darkAccentAlt : _lightAccentAlt;
    textPrimary = dark ? _darkTextPrimary : _lightTextPrimary;
    textSecondary = dark ? _darkTextSecondary : _lightTextSecondary;
    textFaint = dark ? _darkTextFaint : _lightTextFaint;
    onAccent = Colors.white;
    border = dark ? Colors.white24 : Colors.black26;
    scrim = dark ? const Color(0x66000000) : const Color(0x1A000000);
  }

  /// Cor de destaque deterministica por sistema (nome) para o carrossel.
  static Color systemColor(String systemName) {
    var hash = 0;
    for (final c in systemName.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return tilePalette[hash % tilePalette.length];
  }

  /// Gradiente de fundo suave para um sistema sem arte, no tom da paleta ativa.
  static LinearGradient systemGradient(Color base) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, background, 0.30)!,
        Color.lerp(base, background, 0.62)!,
        background,
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

  /// Constroi o [ThemeData] para o modo [dark] e atualiza a paleta ativa.
  static ThemeData build({required bool dark}) {
    apply(dark: dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: accent,
      secondary: accentAlt,
      surface: surface,
      surfaceContainer: surfaceHigh,
      onSurface: textPrimary,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
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
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
        hintStyle: TextStyle(color: textFaint),
        labelStyle: TextStyle(color: textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
    );
  }

  /// Tema escuro (mantido por compatibilidade com chamadas existentes).
  static ThemeData dark() => build(dark: true);

  /// Tema claro.
  static ThemeData light() => build(dark: false);

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
}
