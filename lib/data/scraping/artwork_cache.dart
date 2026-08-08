import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';

/// Cache de capas baixadas em disco: `<appData>/downloaded_media/<sistema>/box2d/`.
class ArtworkCache {
  static String _safeName(String name) => name
      .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '_')
      .trim();

  /// Salva bytes de imagem como capa do jogo. Retorna o caminho local.
  static Future<String> saveCover(
    String system,
    String gameName,
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    final dir = await AppDirs.mediaTypeDir(system, 'box2d');
    final file = File(p.join(dir.path, '${_safeName(gameName)}.$extension'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<bool> exists(String system, String gameName) async {
    final dir = await AppDirs.mediaTypeDir(system, 'box2d');
    if (!await dir.exists()) return false;
    await for (final e in dir.list()) {
      if (e is File && p.basenameWithoutExtension(e.path) == _safeName(gameName)) {
        return true;
      }
    }
    return false;
  }
}
