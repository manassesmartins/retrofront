import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:retrofront/core/app_dirs.dart';
import 'package:retrofront/data/settings/settings_service.dart';
import 'package:retrofront/data/themes/theme_service.dart';
import 'package:retrofront/models/theme_palette.dart';
import 'package:retrofront/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemePalette', () {
    test('parse de JSON completo e round-trip', () {
      final theme = ThemePalette.fromJson('meu_tema', {
        'name': 'Meu Tema',
        'author': 'Fulano',
        'version': '2.1.0',
        'dark': {
          'background': '#000000',
          'surface': '#101010',
          'accent': '#FF0000',
        },
        'light': {
          'background': '#FFFFFF',
          'accent': '#0000FF',
        },
      });

      expect(theme.id, 'meu_tema');
      expect(theme.name, 'Meu Tema');
      expect(theme.author, 'Fulano');
      expect(theme.version, '2.1.0');
      expect(theme.dark.background, const Color(0xFF000000));
      expect(theme.dark.accent, const Color(0xFFFF0000));
      expect(theme.light.accent, const Color(0xFF0000FF));

      final json = theme.toJson();
      expect(json['name'], 'Meu Tema');
      expect(json['dark']['accent'], '#ff0000');
      expect(json['light']['accent'], '#0000ff');
    });

    test('cores ausentes caem no padrao e id e derivado do nome', () {
      final theme = ThemePalette.fromJson('', {
        'name': 'Sem cores',
        'dark': {'accent': '#00FF00'},
      });

      expect(theme.id, 'sem_cores');
      expect(theme.dark.background, isNull);
      expect(theme.dark.accent, const Color(0xFF00FF00));
      expect(ThemeServiceId.isUsable(theme), isTrue);
    });

    test('hex com alpha de 8 digitos', () {
      final theme = ThemePalette.fromJson('x', {
        'name': 'x',
        'dark': {'accent': '#80FF0000'},
      });
      expect(theme.dark.accent, const Color(0x80FF0000));
    });

    test('JSON invalido nao produz tema utilizavel', () {
      final theme = ThemePalette.fromJson('', {
        'name': '  ',
        'dark': <String, dynamic>{},
        'light': <String, dynamic>{},
      });
      expect(ThemeServiceId.isUsable(theme), isFalse);
    });

    test('sanitiza id: acentos, espacos e repetidos', () {
      expect(ThemeServiceId.sanitize('  Tema   Épico!!  '), 'tema_epico');
      expect(ThemeServiceId.sanitize('Ação Total'), 'acao_total');
      expect(ThemeServiceId.sanitize(''), 'tema');
    });
  });

  group('AppTheme com tema custom', () {
    test('aplica paleta custom e volta ao padrao', () {
      final custom = ThemePalette.fromJson('custom', {
        'name': 'Custom',
        'dark': {'accent': '#FF00AA', 'background': '#101010'},
        'light': {'accent': '#AA00FF', 'background': '#F0F0F0'},
      });

      AppTheme.setPalette(custom);
      AppTheme.apply(dark: true);
      expect(AppTheme.accent, const Color(0xFFFF00AA));
      expect(AppTheme.background, const Color(0xFF101010));

      AppTheme.apply(dark: false);
      expect(AppTheme.accent, const Color(0xFFAA00FF));
      expect(AppTheme.background, const Color(0xFFF0F0F0));

      AppTheme.setPalette(null);
      AppTheme.apply(dark: true);
      expect(AppTheme.accent, const Color(0xFF8B5CF6));
    });
  });

  group('ThemeService', () {
    late Directory base;
    late SettingsService settings;
    late ThemeService service;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      base = await Directory.systemTemp.createTemp('retrofront_theme');
      final lib = p.join(base.path, 'Retrofront');
      await Directory(p.join(lib, 'ROMs')).create(recursive: true);
      AppDirs.useRomsOverride(p.join(lib, 'ROMs'));

      settings = SettingsService();
      await settings.init();
      service = ThemeService(settings);
      await service.init();
    });

    tearDown(() {
      AppDirs.useRomsOverride(null);
      AppTheme.setPalette(null);
      try {
        base.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('padrao ativo quando nada configurado', () {
      expect(service.current.id, 'default');
      expect(service.currentName, 'RetroFront Padrão');
    });

    test('cria, aplica, lista, exporta e exclui tema do usuario', () async {
      final theme = await service.createFromCurrent(name: 'Meu Tema Legal');
      expect(theme.id, 'meu_tema_legal');

      await service.applyPalette(theme);
      expect(service.current.id, 'meu_tema_legal');
      expect(settings.getTheme(), 'meu_tema_legal');
      expect(await service.isUserTheme(theme.id), isTrue);

      final themes = await service.list();
      expect(themes.map((t) => t.id), contains('meu_tema_legal'));

      final exportPath = await service.userThemeFilePath(theme.id);
      expect(exportPath, isNotNull);
      expect(await File(exportPath!).exists(), isTrue);

      final deleted = await service.delete(theme.id);
      expect(deleted, isTrue);
      final after = await service.list();
      expect(after.map((t) => t.id), isNot(contains('meu_tema_legal')));
      // Tema ativo excluido: volta ao padrao.
      expect(service.current.id, 'default');
      expect(settings.getTheme(), 'default');
    });

    test('importa JSON valido e rejeita invalido', () async {
      final imported = await service.importJson('''
        {
          "name": "Importado",
          "dark": {"accent": "#123456"}
        }
      ''');
      expect(imported, isNotNull);
      expect(imported!.id, 'importado');
      expect(await service.isUserTheme(imported.id), isTrue);

      final invalid = await service.importJson('{ nao é json }');
      expect(invalid, isNull);
    });

    test('tema bundled padrao nao pode ser excluido', () async {
      expect(await service.isUserTheme('default'), isFalse);
      expect(await service.delete('default'), isFalse);
    });
  });
}
