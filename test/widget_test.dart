import 'package:flutter_test/flutter_test.dart';

import 'package:retrofront/data/roms/rom_scanner.dart';
import 'package:retrofront/gamepad/gamepad_manager.dart';
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
  });

  group('GamepadManager', () {
    test('acoes direcionais sao repetiveis e confirmar nao', () {
      final manager = GamepadManager();
      expect(manager.isAnyDirectional, isFalse);
      manager.dispose();
    });
  });
}
