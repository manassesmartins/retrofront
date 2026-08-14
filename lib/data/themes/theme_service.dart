import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';
import '../../models/theme_palette.dart';
import '../settings/settings_service.dart';

/// Gerencia os temas visuais do RetroFront.
///
/// Temas podem ser:
///   - **Bundled**: empacotados no app em `assets/themes/<id>/theme.json`
///     (incluindo o tema padrao oficial). Nao podem ser excluidos.
///   - **Do usuario**: criados ou importados na pasta
///     `<appData>/themes/<id>/theme.json`. Tem prioridade sobre um bundled
///     com o mesmo id e podem ser excluidos/exportados.
///
/// Aplicar um tema atualiza [active] (ValueNotifier) para a interface
/// reconstruir na hora e persiste o id em SettingsService.
class ThemeService {
  ThemeService(this._settings);

  static const _bundledPrefix = 'assets/themes/';

  final SettingsService _settings;

  /// Tema ativo. Aplicar um tema atualiza este notifier para a UI reconstruir.
  final ValueNotifier<ThemePalette> active =
      ValueNotifier<ThemePalette>(ThemePalette.builtIn);

  /// Carrega o tema salvo nas configuracoes e aplica na paleta ativa.
  Future<void> init() async {
    final id = _settings.getTheme();
    final themes = await list();
    for (final t in themes) {
      if (t.id == id) {
        active.value = t;
        return;
      }
    }
    active.value = ThemePalette.builtIn;
  }

  ThemePalette get current => active.value;

  String get currentName => active.value.name;

  /// Pasta onde ficam os temas criados/importados pelo usuario.
  Future<Directory> themesDir() async {
    final dir = Directory(p.join((await AppDirs.appDataDir()).path, 'themes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Todos os temas disponiveis (bundled + do usuario). Temas do usuario
  /// sobrescrevem bundled com o mesmo id.
  Future<List<ThemePalette>> list() async {
    final map = <String, ThemePalette>{};
    for (final t in await _listBundled()) {
      map[t.id] = t;
    }
    final dir = await themesDir();
    try {
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        final file = File(p.join(entry.path, 'theme.json'));
        if (!await file.exists()) continue;
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! Map<String, dynamic>) continue;
          final theme = ThemePalette.fromJson(p.basename(entry.path), decoded);
          if (ThemeServiceId.isUsable(theme)) map[theme.id] = theme;
        } catch (_) {
          // Tema com JSON invalido e ignorado silenciosamente.
        }
      }
    } catch (_) {
      // Pasta de temas indisponivel: retorna apenas os bundled.
    }
    return map.values.toList();
  }

  Future<List<ThemePalette>> _listBundled() async {
    final result = <ThemePalette>[];
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final key in manifest.listAssets()) {
        if (!key.startsWith(_bundledPrefix) ||
            !key.endsWith('theme.json')) {
          continue;
        }
        final folder = key.substring(_bundledPrefix.length).split('/').first;
        if (folder.isEmpty) continue;
        final decoded = jsonDecode(await rootBundle.loadString(key));
        if (decoded is! Map<String, dynamic>) continue;
        final theme = ThemePalette.fromJson(folder, decoded);
        if (ThemeServiceId.isUsable(theme)) result.add(theme);
      }
    } catch (_) {
      // AssetManifest indisponivel (ex.: testes): sem temas bundled.
    }
    return result;
  }

  /// Aplica um tema (bundled ou do usuario) pelo id e salva nas configuracoes.
  Future<bool> apply(String id) async {
    final themes = await list();
    for (final t in themes) {
      if (t.id == id) {
        await _settings.setTheme(id);
        active.value = t;
        return true;
      }
    }
    return false;
  }

  /// Aplica um tema ja carregado (ex.: logo apos importar/criar).
  Future<void> applyPalette(ThemePalette theme) async {
    await _settings.setTheme(theme.id);
    active.value = theme;
  }

  /// Salva um tema na pasta de temas do usuario. Retorna o id salvo.
  Future<String> save(ThemePalette theme) async {
    final dir = await themesDir();
    final folder = Directory(p.join(dir.path, theme.id));
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(p.join(folder.path, 'theme.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(theme.toJson()),
    );
    return theme.id;
  }

  /// Cria um novo tema a partir do tema ativo, com o nome informado.
  Future<ThemePalette> createFromCurrent({
    required String name,
    String? author,
  }) async {
    final base = active.value;
    final theme = ThemePalette(
      id: ThemeServiceId.sanitize(name),
      name: name.trim(),
      author: author,
      version: '1.0.0',
      dark: base.dark,
      light: base.light,
    );
    await save(theme);
    return theme;
  }

  /// Importa um tema a partir do conteudo de um arquivo JSON. Retorna o tema
  /// importado (e salvo) ou null se o JSON for invalido.
  Future<ThemePalette?> importJson(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final theme = ThemePalette.fromJson('', decoded);
      if (!ThemeServiceId.isUsable(theme)) return null;
      await save(theme);
      return theme;
    } catch (_) {
      return null;
    }
  }

  Future<ThemePalette?> importBytes(Uint8List bytes) =>
      importJson(utf8.decode(bytes, allowMalformed: true));

  /// Exclui um tema criado pelo usuario. Temas bundled nao sao afetados.
  /// Se o tema excluido era o ativo, volta para o tema padrao.
  Future<bool> delete(String id) async {
    final dir = await themesDir();
    final folder = Directory(p.join(dir.path, id));
    if (!await folder.exists()) return false;
    try {
      await folder.delete(recursive: true);
      if (_settings.getTheme() == id) {
        await _settings.setTheme(ThemePalette.builtIn.id);
        active.value = ThemePalette.builtIn;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Caminho do `theme.json` de um tema do usuario (para exportar/editar).
  Future<String?> userThemeFilePath(String id) async {
    final dir = await themesDir();
    final file = File(p.join(dir.path, id, 'theme.json'));
    if (!await file.exists()) return null;
    return file.path;
  }

  /// Se existe uma pasta de usuario com este id (ou seja, nao e bundled).
  Future<bool> isUserTheme(String id) async {
    final dir = await themesDir();
    return Directory(p.join(dir.path, id)).exists();
  }
}
