import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Acesso amplo ao armazenamento no Android (pastas publicas como
/// /storage/emulated/0/ROMs).
///
///  - Android 11+: exige o toggle "Allow all files access"
///    (MANAGE_EXTERNAL_STORAGE), concedido via tela de configuracoes.
///  - Android <= 10: basta a permissao de leitura/escrita em tempo de execucao.
class AndroidStorage {
  static bool get isNeeded => !kIsWeb && Platform.isAndroid;

  static Future<bool> hasAccess() async {
    if (!isNeeded) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    return false;
  }

  /// Solicita o acesso: tenta a permissao simples primeiro e, se o dispositivo
  /// exigir, abre a tela de "All files access" do sistema.
  static Future<bool> request() async {
    if (!isNeeded) return true;
    if (await hasAccess()) return true;

    if (await Permission.storage.request().isGranted) return true;

    // Android 11+: a permissao ampla so pode ser concedida pelo usuario na tela
    // de configuracoes do sistema.
    await Permission.manageExternalStorage.request();
    return hasAccess();
  }
}
