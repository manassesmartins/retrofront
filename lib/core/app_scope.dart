import 'package:flutter/widgets.dart';

import '../data/gamelist/gamelist_repository.dart';
import '../data/launch/launch_service.dart';
import '../data/roms/rom_scanner.dart';
import '../data/scraping/libretro_thumbnails_provider.dart';
import '../data/scraping/scrape_service.dart';
import '../data/scraping/thegamesdb_provider.dart';
import '../data/settings/settings_service.dart';
import '../data/systems/system_definitions_repository.dart';
import '../gamepad/gamepad_manager.dart';

/// Agrupamento dos servicos do aplicativo (injetados via AppScope).
class AppServices {
  final SettingsService settings;
  final SystemDefinitionsRepository systems;
  final GamelistRepository gamelist;
  final RomScanner scanner;
  final ScrapeService scrape;
  final LaunchService launcher;
  final GamepadManager gamepad;
  final ValueNotifier<bool> darkMode;

  AppServices({
    required this.settings,
    required this.systems,
    required this.gamelist,
    required this.scanner,
    required this.scrape,
    required this.launcher,
    required this.gamepad,
    required this.darkMode,
  });

  /// Monta todos os servicos (chamado uma unica vez na inicializacao).
  static Future<AppServices> build() async {
    final settings = SettingsService();
    await settings.init();
    final systems = SystemDefinitionsRepository();
    final gamelist = GamelistRepository();
    final scanner = RomScanner(definitions: systems, gamelist: gamelist);

    final theGamesDb =
        TheGamesDbProvider(apiKey: () => settings.getTheGamesDbKey() ?? '');
    final libretro = LibretroThumbnailsProvider();
    final scrape = ScrapeService(
      theGamesDb: theGamesDb,
      libretro: libretro,
      gamelist: gamelist,
      scanner: scanner,
      settings: settings,
    );

    final launcher = LaunchService(settings: settings);
    final gamepad = GamepadManager()..start();
    gamepad.setRepeatInterval(
      Duration(milliseconds: settings.getGamepadRepeatMs()),
    );
    gamepad.setButtonScheme(settings.getButtonScheme());

    return AppServices(
      settings: settings,
      systems: systems,
      gamelist: gamelist,
      scanner: scanner,
      scrape: scrape,
      launcher: launcher,
      gamepad: gamepad,
      darkMode: ValueNotifier<bool>(settings.getDarkMode()),
    );
  }
}

/// Expõe os servicos para toda a arvore de widgets.
class AppScope extends InheritedWidget {
  final AppServices services;

  const AppScope({super.key, required this.services, required super.child});

  static AppServices of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<AppScope>()!)
          .services;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services != oldWidget.services;
}
