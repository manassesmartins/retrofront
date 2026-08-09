import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Acesso amplo ao armazenamento no Android (pastas publicas como
/// /storage/emulated/0/ROMs).
///
///  - Android 11+ (API 30+): o scoped storage bloqueia arquivos arbitrarios e
///    o acesso amplo so e concedido pelo toggle "Allow all files access"
///    (MANAGE_EXTERNAL_STORAGE), via tela de configuracoes do sistema.
///    A permissao READ_EXTERNAL_STORAGE (storage) NAO da esse acesso, entao nao
///    conta como "concedido" nesta versao.
///  - Android <= 10: basta a permissao de leitura/escrita em tempo de execucao.
class AndroidStorage {
  static bool get isNeeded => !kIsWeb && Platform.isAndroid;

  static bool get _isAndroid11Plus {
    if (!isNeeded) return false;
    final m =
        RegExp(r'Android (\d+)').firstMatch(Platform.operatingSystemVersion);
    final major = m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);
    return major >= 11;
  }

  static Future<bool> hasAccess() async {
    if (!isNeeded) return true;
    if (_isAndroid11Plus) {
      return await Permission.manageExternalStorage.isGranted;
    }
    return await Permission.storage.isGranted;
  }

  /// Solicita o acesso: no Android 11+ abre a tela de "All files access" do
  /// sistema (so o usuario concede); em versoes antigas pede a permissao de
  /// armazenamento em tempo de execucao.
  static Future<bool> request() async {
    if (!isNeeded) return true;
    if (await hasAccess()) return true;

    if (_isAndroid11Plus) {
      await Permission.manageExternalStorage.request();
      return hasAccess();
    }

    await Permission.storage.request();
    return hasAccess();
  }
}
