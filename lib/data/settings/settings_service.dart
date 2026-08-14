import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/system_override.dart';

/// Preferencias do aplicativo com cache em memoria (SharedPreferencesWithCache),
/// permitindo leituras sincronas durante o scraping e lançamento de jogos.
class SettingsService {
  static const _kRomsPath = 'roms_path';
  static const _kTheGamesDbKey = 'thegamesdb_key';
  static const _kGridColumns = 'grid_columns';
  static const _kRetroArchPath = 'retroarch_path';
  static const _kRetroArchArgs = 'retroarch_args';
  static const _kDarkMode = 'dark_mode';
  static const _kGamepadRepeatMs = 'gamepad_repeat_ms';
  static const _kFullscreen = 'fullscreen';
  static const _kLandscapeLock = 'landscape_lock';
  static const _kShowHints = 'show_hints';
  static const _kScrapeProvider = 'scrape_provider';
  static const _kGameSort = 'game_sort';
  static const _kShowGameCount = 'show_game_count';
  static const _kShowRatings = 'show_ratings';
  static const _kButtonScheme = 'button_scheme';
  static const _kLanguage = 'language';
  static const _kButtonMap = 'button_map';
  static const _kControllerButtonMaps = 'controller_button_maps';
  static const _kScreenScraperUser = 'screenscraper_user';
  static const _kArcadeDbKey = 'arcadedb_key';
  static const _kMobyGamesKey = 'mobygames_key';
  static const _kCoverSystems = 'cover_systems';
  static const _kRaEnabled = 'ra_enabled';
  static const _kRaUsername = 'ra_username';
  static const _kRaPassword = 'ra_password';
  static const _kSystemOverrides = 'system_overrides';
  static const _kUiMode = 'ui_mode';
  static const _kScreensaverEnabled = 'screensaver_enabled';
  static const _kScreensaverDelay = 'screensaver_delay';
  static const _kNavSounds = 'nav_sounds';
  static const _kCheckUpdates = 'check_updates';
  static const _kIncludePrerelease = 'include_prerelease';
  static const _kTheme = 'theme';

  static const _allowList = {
    _kRomsPath,
    _kTheGamesDbKey,
    _kGridColumns,
    _kRetroArchPath,
    _kRetroArchArgs,
    _kDarkMode,
    _kGamepadRepeatMs,
    _kFullscreen,
    _kLandscapeLock,
    _kShowHints,
    _kScrapeProvider,
    _kGameSort,
    _kShowGameCount,
    _kShowRatings,
    _kButtonScheme,
    _kLanguage,
    _kButtonMap,
    _kControllerButtonMaps,
    _kScreenScraperUser,
    _kArcadeDbKey,
    _kMobyGamesKey,
    _kCoverSystems,
    _kRaEnabled,
    _kRaUsername,
    _kRaPassword,
    _kSystemOverrides,
    _kUiMode,
    _kScreensaverEnabled,
    _kScreensaverDelay,
    _kNavSounds,
    _kCheckUpdates,
    _kIncludePrerelease,
    _kTheme,
  };

  SharedPreferencesWithCache? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: _allowList,
      ),
    );
  }

  SharedPreferencesWithCache get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('SettingsService.init() deve ser chamado antes do uso.');
    }
    return p;
  }

  String? getRomsPath() => _p.getString(_kRomsPath);

  Future<void> setRomsPath(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _p.remove(_kRomsPath);
    }
    return _p.setString(_kRomsPath, value.trim());
  }

  String? getTheGamesDbKey() => _p.getString(_kTheGamesDbKey);

  Future<void> setTheGamesDbKey(String value) =>
      _p.setString(_kTheGamesDbKey, value.trim());

  int getGridColumns() => _p.getInt(_kGridColumns) ?? 0;

  Future<void> setGridColumns(int value) => _p.setInt(_kGridColumns, value);

  String? getRetroArchPath() => _p.getString(_kRetroArchPath);

  Future<void> setRetroArchPath(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _p.remove(_kRetroArchPath);
    }
    return _p.setString(_kRetroArchPath, value.trim());
  }

  /// Argumentos extras passados ao RetroArch antes da ROM (ex.: "--fullscreen").
  String? getRetroArchArgs() => _p.getString(_kRetroArchArgs);

  Future<void> setRetroArchArgs(String value) =>
      _p.setString(_kRetroArchArgs, value.trim());

  bool getDarkMode() => _p.getBool(_kDarkMode) ?? true;

  Future<void> setDarkMode(bool value) => _p.setBool(_kDarkMode, value);

  int getGamepadRepeatMs() => _p.getInt(_kGamepadRepeatMs) ?? 300;

  Future<void> setGamepadRepeatMs(int value) =>
      _p.setInt(_kGamepadRepeatMs, value);

  bool getFullscreen() => _p.getBool(_kFullscreen) ?? true;

  Future<void> setFullscreen(bool value) => _p.setBool(_kFullscreen, value);

  bool getLandscapeLock() => _p.getBool(_kLandscapeLock) ?? true;

  Future<void> setLandscapeLock(bool value) =>
      _p.setBool(_kLandscapeLock, value);

  bool getShowHints() => _p.getBool(_kShowHints) ?? true;

  Future<void> setShowHints(bool value) => _p.setBool(_kShowHints, value);

  /// Provedor de scraping: 'auto' (todos em ordem), 'thegamesdb' ou 'libretro'.
  String getScrapeProvider() => _p.getString(_kScrapeProvider) ?? 'auto';

  Future<void> setScrapeProvider(String value) =>
      _p.setString(_kScrapeProvider, value);

  /// Ordenacao da lista de jogos: 'name', 'name_desc', 'year' ou 'genre'.
  String getGameSort() => _p.getString(_kGameSort) ?? 'name';

  Future<void> setGameSort(String value) => _p.setString(_kGameSort, value);

  bool getShowGameCount() => _p.getBool(_kShowGameCount) ?? true;

  Future<void> setShowGameCount(bool value) =>
      _p.setBool(_kShowGameCount, value);

  bool getShowRatings() => _p.getBool(_kShowRatings) ?? true;

  Future<void> setShowRatings(bool value) => _p.setBool(_kShowRatings, value);

  /// Esquema de botoes: 'standard' (Xbox/Sony) ou 'nintendo' (A/B trocados).
  String getButtonScheme() => _p.getString(_kButtonScheme) ?? 'standard';

  Future<void> setButtonScheme(String value) =>
      _p.setString(_kButtonScheme, value);

  /// Idioma do sistema: 'pt-BR', 'en-US', 'es-ES', 'fr-FR', 'de-DE' ou
  /// 'it-IT'. Usado pelo teclado virtual (e futuras traduções da interface).
  String getLanguage() => _p.getString(_kLanguage) ?? 'pt-BR';

  Future<void> setLanguage(String value) => _p.setString(_kLanguage, value);

  /// Mapeamento de botões em formato serializado ("a=confirm;b=back;...").
  /// Aplicado como padrao a controles sem mapa proprio.
  String getButtonMap() => _p.getString(_kButtonMap) ?? '';

  Future<void> setButtonMap(String value) => _p.setString(_kButtonMap, value);

  /// Mapeamentos por nome de controle (remap por controle, ate 4 controles):
  /// mapa "nome do controle" -> string serializada ("a=confirm;b=back;...").
  Map<String, String> getControllerButtonMaps() {
    final raw = _p.getString(_kControllerButtonMaps);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setControllerButtonMaps(Map<String, String> value) =>
      _p.setString(_kControllerButtonMaps, jsonEncode(value));

  /// Usuário ScreenScraper (para API pública).
  String getScreenScraperUser() => _p.getString(_kScreenScraperUser) ?? '';

  Future<void> setScreenScraperUser(String value) =>
      _p.setString(_kScreenScraperUser, value.trim());

  /// Chave API ArcadeDB.
  String getArcadeDbKey() => _p.getString(_kArcadeDbKey) ?? '';

  Future<void> setArcadeDbKey(String value) =>
      _p.setString(_kArcadeDbKey, value.trim());

  /// Chave API MobyGames.
  String getMobyGamesKey() => _p.getString(_kMobyGamesKey) ?? '';

  Future<void> setMobyGamesKey(String value) =>
      _p.setString(_kMobyGamesKey, value.trim());

  /// Sistemas para os quais baixar capas (lista de nomes, separados por vírgula).
  String getCoverSystems() => _p.getString(_kCoverSystems) ?? '';

  Future<void> setCoverSystems(String value) =>
      _p.setString(_kCoverSystems, value.trim());

  /// RetroAchievements habilitado (injeta credenciais no RetroArch ao jogar).
  bool getRaEnabled() => _p.getBool(_kRaEnabled) ?? false;

  Future<void> setRaEnabled(bool value) => _p.setBool(_kRaEnabled, value);

  /// Usuário RetroAchievements.
  String getRaUsername() => _p.getString(_kRaUsername) ?? '';

  Future<void> setRaUsername(String value) =>
      _p.setString(_kRaUsername, value.trim());

  /// Senha RetroAchievements (salva localmente para o RetroArch).
  String getRaPassword() => _p.getString(_kRaPassword) ?? '';

  Future<void> setRaPassword(String value) => _p.setString(_kRaPassword, value);

  /// Sobrescritas por sistema (core/args), persistidas em um único JSON.
  Map<String, SystemOverride> getSystemOverrides() {
    final raw = _p.getString(_kSystemOverrides);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, SystemOverride>{};
      for (final e in decoded.entries) {
        result[e.key] = SystemOverride.fromJson(
          e.value as Map<String, dynamic>,
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  SystemOverride? getSystemOverride(String systemName) =>
      getSystemOverrides()[systemName];

  Future<void> setSystemOverride(
    String systemName,
    SystemOverride? override,
  ) async {
    final map = getSystemOverrides();
    if (override == null || !override.isSet) {
      map.remove(systemName);
    } else {
      map[systemName] = override;
    }
    if (map.isEmpty) {
      await _p.remove(_kSystemOverrides);
    } else {
      final json = jsonEncode({
        for (final e in map.entries) e.key: e.value.toJson(),
      });
      await _p.setString(_kSystemOverrides, json);
    }
  }

  /// Modo de usuário: 'full' (configurações acessíveis) ou 'kiosk'
  /// (interface de quiosque, sem acesso às configurações).
  String getUiMode() => _p.getString(_kUiMode) ?? 'full';

  Future<void> setUiMode(String value) => _p.setString(_kUiMode, value);

  /// Protetor de tela: escurece a tela após um período sem interação.
  bool getScreensaverEnabled() => _p.getBool(_kScreensaverEnabled) ?? true;

  Future<void> setScreensaverEnabled(bool value) =>
      _p.setBool(_kScreensaverEnabled, value);

  /// Tempo de inatividade (em minutos) antes do protetor de tela aparecer.
  int getScreensaverDelay() => _p.getInt(_kScreensaverDelay) ?? 3;

  Future<void> setScreensaverDelay(int value) =>
      _p.setInt(_kScreensaverDelay, value);

  /// Sons de navegação na interface (clique ao navegar com o direcional).
  bool getNavSounds() => _p.getBool(_kNavSounds) ?? true;

  Future<void> setNavSounds(bool value) => _p.setBool(_kNavSounds, value);

  /// Auto-update: verifica novas releases do GitHub ao iniciar o app.
  bool getCheckUpdates() => _p.getBool(_kCheckUpdates) ?? true;

  Future<void> setCheckUpdates(bool value) =>
      _p.setBool(_kCheckUpdates, value);

  /// Auto-update: inclui pre-releases (Nightly/Beta) na verificacao.
  bool getIncludePrerelease() => _p.getBool(_kIncludePrerelease) ?? false;

  Future<void> setIncludePrerelease(bool value) =>
      _p.setBool(_kIncludePrerelease, value);

  /// Tema visual ativo (id do tema em `themes/` ou 'default').
  String getTheme() => _p.getString(_kTheme) ?? 'default';

  Future<void> setTheme(String value) => _p.setString(_kTheme, value);
}
