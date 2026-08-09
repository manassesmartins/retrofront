import 'dart:io';

import 'package:flutter/services.dart';

/// Versão do aplicativo (mantida em sincronia com o pubspec.yaml).
const String kAppVersion = '1.0.0';

/// Informações coletadas sobre o aparelho, exibidas nas Configurações.
class DeviceInfo {
  final String version;
  final String platform;
  final String? ip;
  final int? diskFreeBytes;
  final int? diskTotalBytes;

  const DeviceInfo({
    required this.version,
    required this.platform,
    this.ip,
    this.diskFreeBytes,
    this.diskTotalBytes,
  });

  String get diskLabel {
    if (diskTotalBytes == null || diskFreeBytes == null) return '—';
    final free = _mb(diskFreeBytes!);
    final total = _mb(diskTotalBytes!);
    return '$free livre de $total';
  }

  static String _mb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(1)} GB'
        : '${mb.round()} MB';
  }
}

/// Coleta informações de versão, armazenamento e rede do dispositivo.
/// No Android o espaço em disco vem de um canal nativo; nas demais
/// plataformas fica como '—'.
Future<DeviceInfo> collectDeviceInfo() async {
  final ip = await _localIp();

  var free = 0;
  var total = 0;
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('retrofront/system');
      final map =
          await channel.invokeMapMethod<String, int>('getStorage') ?? const {};
      free = map['free'] ?? 0;
      total = map['total'] ?? 0;
    } catch (_) {}
  }

  return DeviceInfo(
    version: kAppVersion,
    platform: _platformName,
    ip: ip,
    diskFreeBytes: (free > 0 && total > 0) ? free : null,
    diskTotalBytes: (free > 0 && total > 0) ? total : null,
  );
}

String get _platformName {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return 'Desconhecido';
}

/// Primeiro endereço IPv4 não loopback das interfaces de rede (null se falhar).
Future<String?> _localIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (!ip.startsWith('127.') && !ip.startsWith('::')) {
          return ip;
        }
      }
    }
  } catch (_) {}
  return null;
}
