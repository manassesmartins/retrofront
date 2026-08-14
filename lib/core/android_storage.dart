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
///    (MANAGE_EXTERNAL_STORAGE). Importante: esse toggle NAO aparece na lista
///    de permissoes normal do app — fica em "Arquivos e midia" / "Acesso a
///    todos os arquivos" nas configuracoes do sistema. A permissao
///    READ_EXTERNAL_STORAGE (storage) NAO da esse acesso, entao nao conta
///    como "concedido" nesta versao.
///  - Android <= 10: basta a permissao de leitura/escrita em tempo de execucao.
///
/// A deteccao da versao usa o canal nativo (Build.VERSION.SDK_INT), a fonte da
/// verdade — mais confiavel que parsear Platform.operatingSystemVersion, cujo
/// formato varia entre releases do Flutter/Android.
class AndroidStorage {
  static bool get isNeeded => Platform.isAndroid;

  /// API level (Build.VERSION.SDK_INT) pelo canal nativo; 0 se indisponivel.
  static Future<int> sdkInt() async {
    return await _invoke<int>('getSdkInt') ?? 0;
  }

  /// Estado atual (sem efeitos colaterais): o acesso aos arquivos esta
  /// concedido? Deve ser relido ao voltar para o app (onResume).
  static Future<bool> hasAccess() async {
    if (!isNeeded) return true;
    // Prefere o check nativo (Environment.isExternalStorageManager). Se o
    // canal nao responder (ex.: testes), cai no plugin.
    final native = await _invoke<bool>('isAllFilesAccess');
    if (native != null) return native;
    if (await sdkInt() >= 30) {
      return await Permission.manageExternalStorage.isGranted;
    }
    return await Permission.storage.isGranted;
  }

  /// Abre a tela do sistema que concede o acesso aos arquivos. No Android 11+
  /// abre a tela "All files access" (o toggle fica em "Arquivos e midia" /
  /// "Acesso especial", NAO na lista de permissoes normal do app); em versoes
  /// antigas pede a permissao de armazenamento em tempo de execucao.
  ///
  /// NAO bloqueia e NAO aguarda a decisao do usuario: retorna true quando
  /// alguma tela foi aberta. O estado real deve ser relido com [hasAccess]
  /// quando o app voltar ao primeiro plano (didChangeAppLifecycleState).
  static Future<bool> request() async {
    if (!isNeeded) return true;
    if (await hasAccess()) return true;
    if (await sdkInt() >= 30) {
      return _openAllFilesAccess();
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Abre direto a tela de "All files access" do Android 11+. Se o intent
  /// especifico nao abrir (alguns OEMs/Android 15), cai nas configuracoes do
  /// app, onde fica o mesmo toggle em "Arquivos e midia".
  static Future<bool> openFilesAccessScreen() async {
    if (!isNeeded || await sdkInt() < 30) return false;
    if (await _openAllFilesAccess()) return true;
    return openSettings();
  }

  /// Abre as configuracoes do app no sistema (onde fica o toggle de
  /// "All files access" em "Arquivos e midia"). Usado como fallback quando o
  /// intent especifico do MANAGE_EXTERNAL_STORAGE nao abre em alguns
  /// OEMs/Android 15.
  static Future<bool> openSettings() async {
    if (!isNeeded) return true;
    return await _invoke<bool>('openAppSettings') ?? false;
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
