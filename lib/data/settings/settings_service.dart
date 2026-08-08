import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias do aplicativo com cache em memoria (SharedPreferencesWithCache),
/// permitindo leituras sincronas durante o scraping e lançamento de jogos.
class SettingsService {
  static const _kRomsPath = 'roms_path';
  static const _kTheGamesDbKey = 'thegamesdb_key';
  static const _kGridColumns = 'grid_columns';
  static const _kRetroArchPath = 'retroarch_path';
  static const _kDarkMode = 'dark_mode';
  static const _kGamepadRepeatMs = 'gamepad_repeat_ms';

  static const _allowList = {
    _kRomsPath,
    _kTheGamesDbKey,
    _kGridColumns,
    _kRetroArchPath,
    _kDarkMode,
    _kGamepadRepeatMs,
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

  bool getDarkMode() => _p.getBool(_kDarkMode) ?? true;

  Future<void> setDarkMode(bool value) => _p.setBool(_kDarkMode, value);

  int getGamepadRepeatMs() => _p.getInt(_kGamepadRepeatMs) ?? 300;

  Future<void> setGamepadRepeatMs(int value) =>
      _p.setInt(_kGamepadRepeatMs, value);
}
