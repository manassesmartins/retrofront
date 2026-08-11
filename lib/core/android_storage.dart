import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Canal nativo (MainActivity) para gerenciar o "All files access" direto pelo
/// sistema, mais confiavel que o plugin em alguns OEMs/versoes.
const _channel = MethodChannel('retrofront/storage');

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
  static bool get isNeeded => Platform.isAndroid;

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
      // Prefere o check nativo (Environment.isExternalStorageManager); se o
      // canal nao estiver disponivel (ex.: testes), cai no plugin.
      return await _invoke<bool>('isAllFilesAccess') ??
          await Permission.manageExternalStorage.isGranted;
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
      // 1) Tela especifica do sistema via canal nativo.
      if (await _openAllFilesAccess()) return hasAccess();
      // 2) Fallback: plugin (mesmo intent de "All files access").
      await Permission.manageExternalStorage.request();
      if (await hasAccess()) return true;
      // 3) Ultimo recurso: configuracoes do app (toggle manual).
      await openSettings();
      return hasAccess();
    }

    await Permission.storage.request();
    return hasAccess();
  }

  /// Abre as configuracoes do app no sistema (onde fica o toggle de
  /// "All files access"). Usado como fallback quando o intent especifico do
  /// MANAGE_EXTERNAL_STORAGE nao abre em alguns OEMs/Android 15.
  static Future<bool> openSettings() async {
    if (!isNeeded) return true;
    return await _invoke<bool>('openAppSettings') ?? openAppSettings();
  }

  static Future<bool> _openAllFilesAccess() async {
    final opened = await _invoke<bool>('openAllFilesAccess');
    if (opened == true) return true;
    // Fallback: o plugin tenta o mesmo intent; true indica que a tela foi
    // aberta (o estado real e verificado depois, ao voltar do sistema).
    try {
      await Permission.manageExternalStorage.request();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
