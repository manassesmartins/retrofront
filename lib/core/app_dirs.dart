import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolucao de diretorios importantes por plataforma.
///  - ROMs:  Windows -> C:\Users\<user>\ROMs | Linux -> ~/ROMs | Android -> /storage/emulated/0/ROMs (se acessivel) | iOS -> Documents/ROMs
///  - AppData: diretorio de suporte do aplicativo (gamelists, mídia baixada, cache, custom_systems).
class AppDirs {
  AppDirs._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<Directory> appDataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'RetroFront'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Diretorio raiz de ROMs. Um override vazio indica usar o padrao da plataforma.
  /// A variavel de ambiente `RETROFRONT_ROMS_ROOT` tem prioridade e permite
  /// apontar para uma biblioteca externa.
  static Future<Directory> romsRoot({String? override}) async {
    final envRoms = Platform.environment['RETROFRONT_ROMS_ROOT'];
    final custom = (override ?? envRoms ?? '').trim();
    if (custom.isNotEmpty) {
      final d = Directory(custom);
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }

    if (isAndroid) {
      const legacyRoms = '/storage/emulated/0/ROMs';
      if (Directory(legacyRoms).existsSync()) {
        return Directory(legacyRoms);
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final d = Directory(p.join(ext.path, 'ROMs'));
        await d.create(recursive: true);
        return d;
      }
    }
    if (isIOS) {
      final doc = await getApplicationDocumentsDirectory();
      final d = Directory(p.join(doc.path, 'ROMs'));
      await d.create(recursive: true);
      return d;
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'] ?? '';
      return Directory(p.join(profile, 'ROMs'));
    }
    final home = Platform.environment['HOME'] ?? '';
    return Directory(p.join(home, 'ROMs'));
  }

  static Future<Directory> gamelistsDir() async =>
      Directory(p.join((await appDataDir()).path, 'gamelists'));

  static Future<Directory> mediaDir(String system) async =>
      Directory(p.join((await appDataDir()).path, 'downloaded_media', system));

  static Future<Directory> mediaTypeDir(String system, String type) async {
    final d = Directory(p.join((await mediaDir(system)).path, type));
    await d.create(recursive: true);
    return d;
  }

  static Future<Directory> customSystemsDir() async =>
      Directory(p.join((await appDataDir()).path, 'custom_systems'));

  static Future<String> gamelistPathFor(String system) async =>
      p.join((await gamelistsDir()).path, '$system.json');
}
