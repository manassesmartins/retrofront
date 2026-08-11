import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_dirs.dart';

/// Instala as artes de fundo padrão por console (bundled em
/// `assets/systems/art`) na pasta `SYSTEMART` da biblioteca no primeiro uso.
///
/// Imagens já existentes em SYSTEMART (colocadas pelo usuário) nunca são
/// sobrescritas. Falhas de permissão de escrita são silenciosas.
class SystemArtInstaller {
  SystemArtInstaller._();

  static const _prefix = 'assets/systems/art/';

  /// Copia as artes bundled para a pasta SYSTEMART do dispositivo.
  static Future<void> install() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final keys = manifest.listAssets().toList();
      final dir = await AppDirs.systemArtDir();

      for (final key in keys) {
        if (!key.startsWith(_prefix) || !key.toLowerCase().endsWith('.jpg')) {
          continue;
        }
        final name = key.substring(_prefix.length);
        final target = File('${dir.path}/$name');
        try {
          if (await target.exists()) continue;
          final data = await rootBundle.load(key);
          await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
        } catch (_) {
          // Sem permissao de escrita: mantem a arte ausente (gradiente).
        }
      }
    } catch (_) {
      // AssetManifest indisponivel: nao instala nada.
    }
  }
}
