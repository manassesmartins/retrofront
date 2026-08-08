import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:retrofront/data/gamelist/gamelist_repository.dart';
import 'package:retrofront/data/roms/rom_scanner.dart';
import 'package:retrofront/data/systems/system_definitions_repository.dart';
import 'package:retrofront/gamepad/gamepad_manager.dart';
import 'package:retrofront/models/game.dart';
import 'package:retrofront/models/game_name.dart';
import 'package:retrofront/models/system.dart';

void main() {
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
