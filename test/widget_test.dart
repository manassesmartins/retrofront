import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart' show GamepadAxis, GamepadButton;
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:retrofront/core/app_dirs.dart';
import 'package:retrofront/core/app_languages.dart';
import 'package:retrofront/data/gamelist/gamelist_repository.dart';
import 'package:retrofront/data/launch/launch_service.dart';
import 'package:retrofront/data/roms/rom_scanner.dart';
import 'package:retrofront/data/settings/settings_service.dart';
import 'package:retrofront/data/systems/system_definitions_repository.dart';
import 'package:retrofront/gamepad/gamepad_manager.dart';
import 'package:retrofront/models/game.dart';
import 'package:retrofront/models/game_name.dart';
import 'package:retrofront/models/system.dart';
import 'package:retrofront/models/system_override.dart';
import 'package:retrofront/ui/widgets/virtual_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SystemDefinition', () {
    test('parse de extensoes e match', () {
      final def = SystemDefinition.fromJson(const {
        'name': 'nes',
        'fullName': 'Nintendo Entertainment System',
        'extension': '.nes .NES .unf .7z .7Z .zip .ZIP',
      });

      expect(def.name, 'nes');
      expect(def.matchesExtension('.nes'), isTrue);
      expect(def.matchesExtension('.NES'), isTrue);
      expect(def.matchesExtension('.zip'), isTrue);
      expect(def.matchesExtension('.sms'), isFalse);
    });
  });

  group('RomScanner', () {
    test('arquivos a ignorar', () {
      expect(
        RomScanner.skipFiles.contains('systeminfo.txt'),
        isTrue,
      );
      expect(
        RomScanner.skipFiles.contains('noload.txt'),
        isTrue,
      );
      expect(
        RomScanner.skipFiles.contains('mario.nes'),
        isFalse,
      );
    });

    test('descobre sistemas e lista os jogos das pastas', () async {
      final dir = await Directory.systemTemp.createTemp('rf_roms');
      addTearDown(() => dir.delete(recursive: true));

      await Directory('${dir.path}/nes').create();
      await Directory('${dir.path}/nes/Sub Pasta').create();
      await Directory('${dir.path}/snes').create();
      await File('${dir.path}/nes/Contra.nes').writeAsString('rom');
      await File('${dir.path}/nes/Super Mario.zip').writeAsString('rom');
      await File('${dir.path}/nes/systeminfo.txt').writeAsString('skip');
      await File('${dir.path}/nes/Sub Pasta/inner.nes').writeAsString('rom');
      await File('${dir.path}/snes/README.md').writeAsString('ignore');
      await File('${dir.path}/ignored-folder/anything.nes').create(recursive: true);

      final defs = [
        SystemDefinition.fromJson(const {
          'name': 'nes',
          'fullName': 'NES',
          'extension': '.nes .zip',
        }),
        SystemDefinition.fromJson(const {
          'name': 'snes',
          'fullName': 'SNES',
          'extension': '.sfc .zip',
        }),
      ];

      final scanner = RomScanner(
        definitions: _FakeDefRepo(defs),
        gamelist: _StubGamelist(),
      );

      final systems = await scanner.scanSystems(romsOverride: dir.path);
      expect(systems.length, 2);

      final nes = systems.firstWhere((s) => s.name == 'nes');
      expect(nes.gameCount, 2); // Contra.nes + Super Mario.zip

      final games = await scanner.listGames(nes);
      final names = games.map((g) => g.name).toList();
      expect(names, contains('Contra.nes'));
      expect(names, contains('Super Mario.zip'));
      expect(names, isNot(contains('systeminfo.txt')));
      // Subpastas sao ocultadas (estilo EmulationStation).
      expect(names, isNot(contains('Sub Pasta')));
      expect(names, isNot(contains('inner.nes')));
    });
  });

  group('GameName', () {
    test('limpa nome de arquivo para exibicao', () {
      expect(GameName.cleanFileName('Super Mario Bros. (USA).nes'),
          'Super Mario Bros');
      expect(GameName.cleanFileName('Sonic_the_Hedgehog_[!].md'),
          'Sonic the Hedgehog');
      expect(GameName.cleanFileName('Pokemon - Red (Europe) (Rev 1).gb'),
          'Pokemon - Red');
      expect(GameName.cleanFileName('Contra.nes'), 'Contra');
    });

    test('usa titulo do gamelist quando disponivel', () {
      const meta = GameMetadata(name: 'Super Mario Bros. 3');
      expect(GameName.clean(meta, 'SMB3.nes'), 'Super Mario Bros. 3');
      expect(GameName.clean(null, 'SMB3.nes'), 'SMB3');
    });
  });

  group('VirtualKeyboard', () {
    test('layout pt-BR comeca pelo QWERTY e acentos ficam em simbolos', () {
      final layout = VkLayout.ofLanguage('pt-BR');
      final rows = vkRows(layout, symbols: false, shift: false);
      final letters = rows
          .map((r) => r.map((k) => k.char).join())
          .where((s) => s.isNotEmpty)
          .join();
      // Primeiro o QWERTY, sem acentos na pagina principal.
      expect(letters, startsWith('qwertyuiop'));
      expect(letters, isNot(contains('á')));
      expect(letters, isNot(contains('ç')));
      // Acentos disponíveis na pagina de simbolos.
      final symRows = vkRows(layout, symbols: true, shift: false);
      final symAll = symRows.map((r) => r.map((k) => k.char).join()).join();
      expect(symAll, contains('á'));
      expect(symAll, contains('ç'));
      // Ultima linha: acoes (shift, backspace, sym, espaço, ok).
      final last = rows.last;
      expect(last.every((k) => k.isAction), isTrue);
    });

    test('shift transforma letras em maiusculas', () {
      final layout = VkLayout.ofLanguage('en-US');
      final lower = vkRows(layout, symbols: false, shift: false);
      final upper = vkRows(layout, symbols: false, shift: true);
      expect(
        lower.firstWhere((r) => !r.every((k) => k.isAction)).first.char,
        'q',
      );
      expect(
        upper.firstWhere((r) => !r.every((k) => k.isAction)).first.char,
        'Q',
      );
    });

    test('pagina de simbolos traz digitos e pontuacao', () {
      final layout = VkLayout.ofLanguage('en-US');
      final rows = vkRows(layout, symbols: true, shift: false);
      final digits = rows.first.map((k) => k.char).join();
      expect(digits, '1234567890');
      final all = rows.map((r) => r.map((k) => k.char ?? '').join()).join();
      expect(all, contains('.'));
      expect(all, contains('_'));
    });

    test('idioma desconhecido usa fallback English', () {
      expect(VkLayout.ofLanguage('xx-XX').id, 'en-US');
      expect(appLanguageById('es-ES').label, 'Español');
      expect(appLanguageById('zz-ZZ').id, 'pt-BR');
    });
  });

  group('GamepadManager', () {
    test('acoes direcionais sao repetiveis e confirmar nao', () {
      final manager = GamepadManager();
      expect(manager.isAnyDirectional, isFalse);
      manager.dispose();
    });

    test('um toque direcional gera exatamente uma acao (cooldown)', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      // Simula botao + analogico reportando o mesmo direcional em sequencia.
      manager.handleForTest(GamepadAction.left);
      manager.handleForTest(GamepadAction.left);
      manager.handleForTest(GamepadAction.left);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(actions, [GamepadAction.left]);

      await sub.cancel();
      manager.dispose();
    });

    test('direcoes opostas seguidas geram as duas acoes', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleForTest(GamepadAction.left);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      manager.handleForTest(GamepadAction.right);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(actions, [GamepadAction.left, GamepadAction.right]);

      await sub.cancel();
      manager.dispose();
    });

    test('soltar o analogico interrompe a repeticao', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleForTest(GamepadAction.left);
      // Aguarda o delay inicial (450ms) + uma repeticao para comprovar que
      // a repeticao esta ativa antes de soltar.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      manager.handleForTest(GamepadAction.left, release: true);
      final beforeRelease = actions.length;
      expect(beforeRelease, greaterThan(1));

      // Se a fonte nao fosse limpa, repetiria em ~300ms.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(actions.length, beforeRelease);

      await sub.cancel();
      manager.dispose();
    });

    test('esquema de botoes Nintendo troca A/B', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.setButtonScheme('standard');
      manager.handleButtonForTest(GamepadButton.a);
      manager.handleButtonForTest(GamepadButton.a, release: true);
      manager.handleButtonForTest(GamepadButton.b);
      manager.handleButtonForTest(GamepadButton.b, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.confirm, GamepadAction.back]);

      // Aguarda o cooldown entre as fases.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      actions.clear();

      manager.setButtonScheme('nintendo');
      manager.handleButtonForTest(GamepadButton.a);
      manager.handleButtonForTest(GamepadButton.a, release: true);
      manager.handleButtonForTest(GamepadButton.b);
      manager.handleButtonForTest(GamepadButton.b, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.back, GamepadAction.confirm]);

      await sub.cancel();
      manager.dispose();
    });
  });

  group('GamepadManager button overrides', () {
    test('override muda a acao de um botao', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.setButtonOverrides({GamepadButton.a: GamepadAction.back});
      manager.handleButtonForTest(GamepadButton.a);
      manager.handleButtonForTest(GamepadButton.a, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.back]);

      await sub.cancel();
      manager.dispose();
    });

    test('serializeButtonMap/deserializeButtonMap round trip', () {
      final manager = GamepadManager();
      manager.setButtonOverrides({
        GamepadButton.a: GamepadAction.confirm,
        GamepadButton.back: GamepadAction.start,
      });
      final raw = manager.serializeButtonMap();
      expect(raw, 'a=confirm;back=start');

      final restored = GamepadManager.deserializeButtonMap(raw);
      expect(restored, {
        GamepadButton.a: GamepadAction.confirm,
        GamepadButton.back: GamepadAction.start,
      });

      manager.dispose();
    });

    test('deserializeButtonMap ignora itens invalidos', () {
      final restored =
          GamepadManager.deserializeButtonMap('a=confirm;bogus=x;x=y');
      expect(restored, {GamepadButton.a: GamepadAction.confirm});
    });

    test('clearButtonOverrides retorna ao padrao', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.setButtonOverrides({GamepadButton.a: GamepadAction.back});
      manager.clearButtonOverrides();
      manager.handleButtonForTest(GamepadButton.a);
      manager.handleButtonForTest(GamepadButton.a, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.confirm]);

      await sub.cancel();
      manager.dispose();
    });
  });

  group('GamepadManager multi-controle e combos', () {
    test('Select segurado + Start emite Home (e suprime Start)', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleButtonForTest(GamepadButton.back);
      manager.handleButtonForTest(GamepadButton.start);
      manager.handleButtonForTest(GamepadButton.start, release: true);
      manager.handleButtonForTest(GamepadButton.back, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(actions, contains(GamepadAction.select));
      expect(actions, contains(GamepadAction.home));
      expect(actions, isNot(contains(GamepadAction.start)));

      await sub.cancel();
      manager.dispose();
    });

    test('Start sozinho emite Start (combo exige Select segurado)', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleButtonForTest(GamepadButton.start);
      manager.handleButtonForTest(GamepadButton.start, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.start]);

      await sub.cancel();
      manager.dispose();
    });

    test('Select + LB/RB emite pagina anterior/proxima', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleButtonForTest(GamepadButton.back);
      manager.handleButtonForTest(GamepadButton.leftBumper);
      manager.handleButtonForTest(GamepadButton.leftBumper, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(actions, contains(GamepadAction.pageUp));

      actions.clear();
      manager.handleButtonForTest(GamepadButton.rightBumper);
      manager.handleButtonForTest(GamepadButton.rightBumper, release: true);
      manager.handleButtonForTest(GamepadButton.back, release: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, contains(GamepadAction.pageDown));

      await sub.cancel();
      manager.dispose();
    });

    test('analogicos direito e gatilhos geram acoes', () async {
      final manager = GamepadManager();
      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);

      manager.handleAxisForTest(GamepadAxis.rightStickX, 0.8);
      manager.handleAxisForTest(GamepadAxis.rightStickX, 0);
      manager.handleAxisForTest(GamepadAxis.leftTrigger, 0.9);
      manager.handleAxisForTest(GamepadAxis.leftTrigger, 0);
      manager.handleAxisForTest(GamepadAxis.rightTrigger, 0.9);
      manager.handleAxisForTest(GamepadAxis.rightTrigger, 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(actions,
          [GamepadAction.right, GamepadAction.pageUp, GamepadAction.pageDown]);

      await sub.cancel();
      manager.dispose();
    });

    test('suporta ate 4 controles e remap por controle', () async {
      final manager = GamepadManager();
      manager.registerPlayerForTest('p1', 'Xbox');
      manager.registerPlayerForTest('p2', 'PS5');
      manager.registerPlayerForTest('p3', 'Switch');
      manager.registerPlayerForTest('p4', 'Genérico');
      expect(manager.players.length, 4);
      // 5o controle nao ganha slot, mas continua navegando com o mapa padrao.
      expect(manager.registerPlayerForTest('p5', 'Extra'), isNull);
      expect(manager.players.length, 4);
      expect(manager.players.map((p) => p.playerNumber).toList(), [1, 2, 3, 4]);

      manager.applyOverridesFor('Xbox', {GamepadButton.a: GamepadAction.home});

      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);
      manager.handleButtonForTest(GamepadButton.a, gamepadId: 'p1');
      manager.handleButtonForTest(GamepadButton.a, release: true, gamepadId: 'p1');
      manager.handleButtonForTest(GamepadButton.a, gamepadId: 'p2');
      manager.handleButtonForTest(GamepadButton.a, release: true, gamepadId: 'p2');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // p1 (Xbox) usa o mapa proprio; p2 (PS5) cai no padrao (confirmar).
      expect(actions, [GamepadAction.home, GamepadAction.confirm]);

      await sub.cancel();
      manager.dispose();
    });

    test('setControllerButtonMaps aplica mapas a controles ja conectados',
        () async {
      final manager = GamepadManager();
      manager.registerPlayerForTest('x1', 'Xbox');
      manager.setControllerButtonMaps({'Xbox': 'a=home'});

      final actions = <GamepadAction>[];
      final sub = manager.actions.listen(actions.add);
      manager.handleButtonForTest(GamepadButton.a, gamepadId: 'x1');
      manager.handleButtonForTest(GamepadButton.a, release: true, gamepadId: 'x1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(actions, [GamepadAction.home]);

      await sub.cancel();
      manager.dispose();
    });

    test('serializeOverrides gera string no formato button=action', () {
      expect(
        GamepadManager.serializeOverrides({
          GamepadButton.a: GamepadAction.home,
        }),
        'a=home',
      );
    });
  });

  group('SystemOverride', () {
    test('serializa e desserializa JSON', () {
      const ov = SystemOverride(core: 'mesen', extraArgs: '--verbose');
      final restored = SystemOverride.fromJson(ov.toJson());
      expect(restored.core, 'mesen');
      expect(restored.extraArgs, '--verbose');
      expect(restored.isSet, isTrue);
    });

    test('vazio nao e considerado configurado', () {
      const empty = SystemOverride();
      expect(empty.isSet, isFalse);
    });
  });

  group('SettingsService', () {
    test('persiste override por sistema e credenciais RetroAchievements',
        () async {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      final settings = SettingsService();
      await settings.init();

      await settings.setSystemOverride(
        'nes',
        const SystemOverride(core: 'mesen', extraArgs: '--fullscreen'),
      );
      expect(settings.getSystemOverride('nes')?.core, 'mesen');
      expect(settings.getSystemOverride('nes')?.extraArgs, '--fullscreen');

      await settings.setSystemOverride('snes', const SystemOverride(core: 'snes9x'));
      expect(settings.getSystemOverrides().length, 2);

      await settings.setSystemOverride('nes', null);
      expect(settings.getSystemOverride('nes'), isNull);
      expect(settings.getSystemOverrides().length, 1);

      await settings.setRaEnabled(true);
      await settings.setRaUsername('player1');
      await settings.setRaPassword('segredo');
      expect(settings.getRaEnabled(), isTrue);
      expect(settings.getRaUsername(), 'player1');
      expect(settings.getRaPassword(), 'segredo');
    });
  });

  group('LaunchService.buildLaunchCommand', () {
    const base =
        '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%/nes_libretro.so %ROM%';

    test('aplica core por sistema, args globais e por sistema e config RA',
        () {
      final cmd = LaunchService.buildLaunchCommand(
        resolvedCommand: base,
        gamePath: '/roms/nes/Game.nes',
        override: const SystemOverride(core: 'mesen', extraArgs: '--fullscreen'),
        globalArgs: '--verbose',
        raAppendConfig: '/cfg/cheevos.cfg',
      );
      expect(cmd, contains('mesen_libretro.so'));
      expect(cmd, isNot(contains('nes_libretro.so')));
      expect(cmd, contains('--fullscreen'));
      expect(cmd, contains('--verbose'));
      expect(cmd, contains('--appendconfig "/cfg/cheevos.cfg"'));
      expect(cmd, endsWith('"/roms/nes/Game.nes"'));
    });

    test('sem override mantem o comando original', () {
      final cmd = LaunchService.buildLaunchCommand(
        resolvedCommand: base,
        gamePath: '/roms/nes/Game.nes',
      );
      expect(cmd, contains('nes_libretro.so'));
      expect(cmd, endsWith('"/roms/nes/Game.nes"'));
    });

    test('replaceCore com caminho completo usa como esta', () {
      expect(
        LaunchService.replaceCore(
          'ra -L /cores/x.so %ROM%',
          '/cores/y_libretro.so',
        ),
        'ra -L /cores/y_libretro.so %ROM%',
      );
    });

    test('replaceCore sem -L injeta antes da ROM', () {
      expect(LaunchService.replaceCore('ra %ROM%', 'mesen'),
          'ra -L mesen_libretro.so %ROM%');
    });
  });

  group('SystemArtPath', () {
    setUp(() => AppDirs.useRomsOverride(null));

    test('resolver a arte na pasta SYSTEMART da biblioteca', () {
      final base = Directory.systemTemp.createTempSync('retrofront_art');
      final lib = p.join(base.path, 'Retrofront');
      final artDir = Directory(p.join(lib, 'SYSTEMART'));
      artDir.createSync(recursive: true);
      File(p.join(artDir.path, 'nes.png')).writeAsStringSync('x');
      addTearDown(() => base.deleteSync(recursive: true));

      AppDirs.useRomsOverride(p.join(lib, 'ROMs'));

      final art = AppDirs.systemArtPath('nes');
      expect(art, isNotNull);
      expect(art!.endsWith('nes.png'), isTrue);
      expect(AppDirs.systemArtPath('snes'), isNull);
      expect(AppDirs.systemArtPath(''), isNull);
    });

    test('sem biblioteca retorna null', () {
      AppDirs.useRomsOverride('/caminho/que/nao/existe');

      expect(AppDirs.systemArtPath('nes'), isNull);
    });
  });
}

class _FakeDefRepo implements SystemDefinitionsRepository {
  final List<SystemDefinition> defs;
  _FakeDefRepo(this.defs);

  @override
  Future<List<SystemDefinition>> load() async => defs;

  @override
  SystemDefinition? byName(List<SystemDefinition> systems, String name) {
    for (final s in systems) {
      if (s.name.toLowerCase() == name.toLowerCase()) return s;
    }
    return null;
  }

  @override
  Future<String> ensureDefaultFolders(String baseDir) async => baseDir;
}

class _StubGamelist implements GamelistRepository {
  @override
  Future<Map<String, GameMetadata>> loadFor(String system) async => {};

  @override
  Future<void> preload(List<String> systems) async {}

  @override
  Future<void> save(String system, Map<String, GameMetadata> entries) async {}

  @override
  Future<void> upsert(
      String system, String path, GameMetadata metadata) async {}

  @override
  Future<void> remove(String system, String path) async {}

  @override
  void invalidate(String system) {}

  @override
  void invalidateAll() {}
}
