import 'package:flutter/widgets.dart';

import '../data/gamelist/gamelist_repository.dart';
import '../data/launch/launch_service.dart';
import '../data/roms/rom_scanner.dart';
import '../data/scraping/arcadedb_provider.dart';
import '../data/scraping/libretro_thumbnails_provider.dart';
import '../data/scraping/mobygames_provider.dart';
import '../data/scraping/scrape_service.dart';
import '../data/scraping/screenscraper_provider.dart';
import '../data/scraping/thegamesdb_provider.dart';
import '../data/settings/settings_service.dart';
import '../data/systems/system_definitions_repository.dart';
import '../data/themes/theme_service.dart';
import '../gamepad/gamepad_manager.dart';
import 'update_checker.dart';

/// Progresso da inicializacao dos servicos, exibido na tela de loading.
class StartupProgress {
  /// Valor de 0.0 a 1.0.
  final double value;

  /// Descricao em pt-BR do passo sendo carregado.
  final String label;

  const StartupProgress(this.value, this.label);
}

/// Agrupamento dos servicos do aplicativo (injetados via AppScope).
class AppServices {
  final SettingsService settings;
  final SystemDefinitionsRepository systems;
  final GamelistRepository gamelist;
  final RomScanner scanner;
  final ScrapeService scrape;
  final LaunchService launcher;
  final GamepadManager gamepad;
  final UpdateService update;
  final ThemeService themes;
  final ValueNotifier<bool> darkMode;

  AppServices({
    required this.settings,
    required this.systems,
    required this.gamelist,
    required this.scanner,
    required this.scrape,
    required this.launcher,
    required this.gamepad,
    required this.update,
    required this.themes,
    required this.darkMode,
  });

  /// Monta todos os servicos (chamado uma unica vez na inicializacao).
  /// [onProgress] reporta cada etapa da carga para a tela de loading.
  static Future<AppServices> build({
    void Function(StartupProgress progress)? onProgress,
  }) async {
    onProgress?.call(const StartupProgress(0.05, 'Carregando configurações...'));
    final settings = SettingsService();
    await settings.init();

    onProgress?.call(const StartupProgress(0.30, 'Preparando biblioteca de jogos...'));
    final systems = SystemDefinitionsRepository();
    final gamelist = GamelistRepository();
    final scanner = RomScanner(definitions: systems, gamelist: gamelist);

    onProgress?.call(const StartupProgress(0.45, 'Configurando emuladores...'));
    final theGamesDb =
        TheGamesDbProvider(apiKey: () => settings.getTheGamesDbKey() ?? '');
    final libretro = LibretroThumbnailsProvider();
    final screenScraper = ScreenScraperDbProvider(
      username: () => settings.getScreenScraperUser(),
    );
    final arcadeDb = ArcadeDbProvider(
      apikey: () => settings.getArcadeDbKey(),
    );
    final mobyGames = MobyGamesProvider(
      apiKey: () => settings.getMobyGamesKey(),
    );
    final scrape = ScrapeService(
      theGamesDb: theGamesDb,
      libretro: libretro,
      screenScraper: screenScraper,
      arcadeDb: arcadeDb,
      mobyGames: mobyGames,
      gamelist: gamelist,
      scanner: scanner,
      settings: settings,
    );

    final launcher = LaunchService(settings: settings);

    onProgress?.call(const StartupProgress(0.60, 'Iniciando controles...'));
    final gamepad = GamepadManager()..start();
    gamepad.setRepeatInterval(
      Duration(milliseconds: settings.getGamepadRepeatMs()),
    );
    gamepad.setButtonScheme(settings.getButtonScheme());
    gamepad.setButtonOverrides(
      GamepadManager.deserializeButtonMap(settings.getButtonMap()),
    );
    gamepad.setControllerButtonMaps(settings.getControllerButtonMaps());

    onProgress?.call(const StartupProgress(0.80, 'Carregando tema...'));
    final themes = ThemeService(settings);
    await themes.init();

    onProgress?.call(const StartupProgress(1.0, 'Pronto!'));
    return AppServices(
      settings: settings,
      systems: systems,
      gamelist: gamelist,
      scanner: scanner,
      scrape: scrape,
      launcher: launcher,
      gamepad: gamepad,
      update: UpdateService(),
      themes: themes,
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
