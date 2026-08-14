import 'dart:ui';

/// Paleta de cores de um modo (escuro ou claro) de um tema. Todos os campos
/// sao opcionais no JSON: quando ausentes, o tema cai na cor padrao do
/// RetroFront (ThemePalette.defaultDark/defaultLight).
class ColorPalette {
  final Color? background;
  final Color? surface;
  final Color? surfaceHigh;
  final Color? accent;
  final Color? accentAlt;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? textFaint;

  const ColorPalette({
    this.background,
    this.surface,
    this.surfaceHigh,
    this.accent,
    this.accentAlt,
    this.textPrimary,
    this.textSecondary,
    this.textFaint,
  });

  factory ColorPalette.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ColorPalette();
    return ColorPalette(
      background: _color(json['background']),
      surface: _color(json['surface']),
      surfaceHigh: _color(json['surfaceHigh']),
      accent: _color(json['accent']),
      accentAlt: _color(json['accentAlt']),
      textPrimary: _color(json['textPrimary']),
      textSecondary: _color(json['textSecondary']),
      textFaint: _color(json['textFaint']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    void put(String key, Color? c) {
      if (c != null) map[key] = '#${_hex(c)}';
    }

    put('background', background);
    put('surface', surface);
    put('surfaceHigh', surfaceHigh);
    put('accent', accent);
    put('accentAlt', accentAlt);
    put('textPrimary', textPrimary);
    put('textSecondary', textSecondary);
    put('textFaint', textFaint);
    return map;
  }

  static Color? _color(dynamic value) {
    if (value is! String) return null;
    final hex = value.trim().replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    if (hex.length == 6) return Color(0xFF000000 | parsed);
    return Color(parsed);
  }

  static String _hex(Color c) {
    final a = (c.a * 255).round();
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    if (a == 255) {
      return r.toRadixString(16).padLeft(2, '0') +
          g.toRadixString(16).padLeft(2, '0') +
          b.toRadixString(16).padLeft(2, '0');
    }
    return a.toRadixString(16).padLeft(2, '0') +
        r.toRadixString(16).padLeft(2, '0') +
        g.toRadixString(16).padLeft(2, '0') +
        b.toRadixString(16).padLeft(2, '0');
  }
}

/// Tema visual completo: metadados (nome, autor, versao) e uma paleta para o
/// modo escuro e outra para o modo claro.
class ThemePalette {
  final String id;
  final String name;
  final String? author;
  final String? version;
  final ColorPalette dark;
  final ColorPalette light;

  const ThemePalette({
    required this.id,
    required this.name,
    this.author,
    this.version,
    this.dark = const ColorPalette(),
    this.light = const ColorPalette(),
  });

  /// Constroi um tema a partir de um JSON (formato documentado no README).
  /// [id] e o identificador da pasta; quando vazio, e derivado do [name].
  factory ThemePalette.fromJson(String id, Map<String, dynamic>? json) {
    final name = (json?['name'] as String?)?.trim() ??
        (id.isNotEmpty ? id : 'Tema sem nome');
    final resolvedId = id.isNotEmpty ? id : ThemeServiceId.sanitize(name);
    return ThemePalette(
      id: resolvedId,
      name: name,
      author: (json?['author'] as String?)?.trim(),
      version: (json?['version'] as String?)?.trim(),
      dark: ColorPalette.fromJson(json?['dark'] as Map<String, dynamic>?),
      light: ColorPalette.fromJson(json?['light'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (author != null) 'author': author,
      if (version != null) 'version': version,
      'dark': dark.toJson(),
      'light': light.toJson(),
    };
  }

  /// Tema padrao oficial do RetroFront (escuro "console").
  static const ThemePalette builtIn = ThemePalette(
    id: 'default',
    name: 'RetroFront Padrão',
    author: 'RetroFront',
    version: '1.0.0',
    dark: ColorPalette(
      background: Color(0xFF0A0C12),
      surface: Color(0xFF141823),
      surfaceHigh: Color(0xFF1E2432),
      accent: Color(0xFF8B5CF6),
      accentAlt: Color(0xFF22D3EE),
      textPrimary: Color(0xFFF4F5F9),
      textSecondary: Color(0xFFB4BAC9),
      textFaint: Color(0xFF6E7687),
    ),
    light: ColorPalette(
      background: Color(0xFFF4F5F9),
      surface: Color(0xFFFFFFFF),
      surfaceHigh: Color(0xFFE8EAF1),
      accent: Color(0xFF6D3BF0),
      accentAlt: Color(0xFF0891B2),
      textPrimary: Color(0xFF171A23),
      textSecondary: Color(0xFF545C6E),
      textFaint: Color(0xFF8A91A1),
    ),
  );
}

/// Utilitarios de identificacao/validacao de temas (exposto separado para
/// testes e reuso sem depender do serviço).
class ThemeServiceId {
  ThemeServiceId._();

  /// Normaliza um nome em um id seguro para pasta: minusculas, sem acentos,
  /// espacos vira "underscore", somente [a-z0-9_-].
  static String sanitize(String name) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    final lower = name.toLowerCase();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      final idx = accents.indexOf(ch);
      final c = idx >= 0 ? plain[idx] : ch;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        buffer.write(c);
      } else if (c == ' ' || c == '-' || c == '_' || c == '.') {
        buffer.write('_');
      }
    }
    var id = buffer.toString().replaceAll(RegExp(r'_+'), '_');
    id = id.replaceAll(RegExp(r'^_+|_+$'), '');
    return id.isEmpty ? 'tema' : id;
  }

  /// Um tema precisa ter nome e pelo menos uma cor definida para ser util.
  static bool isUsable(ThemePalette theme) {
    final hasDark = theme.dark.toJson().isNotEmpty;
    final hasLight = theme.light.toJson().isNotEmpty;
    return theme.name.trim().isNotEmpty && (hasDark || hasLight);
  }
}
