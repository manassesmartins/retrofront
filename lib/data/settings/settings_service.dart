import 'package:shared_preferences/shared_preferences.dart';

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
}
