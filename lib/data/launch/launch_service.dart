import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';
import '../../models/game_entry.dart';
import '../../models/system.dart';
import '../settings/settings_service.dart';

class LaunchResult {
  final bool ok;
  final String? error;

  const LaunchResult._(this.ok, this.error);

  const LaunchResult.success() : this._(true, null);
  const LaunchResult.failure(String error) : this._(false, error);
}

/// Responsavel por iniciar os jogos: no desktop executa o comando de
/// emulacao (estilo es_systems.xml); no Android tenta abrir o RetroArch.
class LaunchService {
  final SettingsService settings;

  LaunchService({required this.settings});

  Future<LaunchResult> launch(SystemDefinition system, GameEntry game) async {
    if (AppDirs.isAndroid) {
      return _launchAndroid(system, game);
    }
    return _launchDesktop(system, game);
  }

  Future<LaunchResult> _launchDesktop(SystemDefinition system, GameEntry game) async {
    final rawCommand = system.command;
    if (rawCommand == null || rawCommand.trim().isEmpty) {
      return const LaunchResult.failure(
        'Nenhum comando de emulador definido para este sistema.',
      );
    }

    final command = await _resolveCommand(rawCommand);
    if (command == null) {
      return const LaunchResult.failure(
        'RetroArch não encontrado. Configure o caminho do executável '
        'em Configurações -> Emulador, ou adicione retroarch ao PATH.',
      );
    }

    // Argumentos extras configurados pelo usuario (inseridos antes da ROM).
    var cmd = command;
    final extra = settings.getRetroArchArgs();
    if (extra != null && extra.trim().isNotEmpty) {
      cmd = cmd.replaceAll('%ROM%', '$extra %ROM%');
    }

    final tokens = _tokenize(cmd.replaceAll('%ROM%', _quote(game.path)));
    if (tokens.isEmpty) {
      return const LaunchResult.failure('Comando vazio.');
    }

    try {
      await Process.start(tokens.first, tokens.sublist(1));
      return const LaunchResult.success();
    } catch (e) {
      return LaunchResult.failure('Falha ao iniciar emulador: $e');
    }
  }

  Future<LaunchResult> _launchAndroid(SystemDefinition system, GameEntry game) async {
    const channel = MethodChannel('retrofront/launcher');
    try {
      final ok = await channel.invokeMethod<bool>('launchRetroArch', game.path);
      if (ok == true) return const LaunchResult.success();
      return const LaunchResult.failure(
        'RetroArch não está instalado ou não suporta este formato.',
      );
    } on PlatformException catch (e) {
      return LaunchResult.failure(e.message ?? 'Falha ao lançar emulador.');
    }
  }

  /// Substitui os placeholders do comando pelo caminho real do emulador.
  Future<String?> _resolveCommand(String raw) async {
    var cmd = raw;
    if (cmd.contains('%EMULATOR_RETROARCH%')) {
      final path = await findRetroArch();
      if (path == null) return null;
      cmd = cmd.replaceAll('%EMULATOR_RETROARCH%', _quote(path));
      cmd = cmd.replaceAll('%CORE_RETROARCH%', _quote(_coresDir(path)));
    }
    return cmd;
  }

  /// Detecta o RetroArch instalado automaticamente:
  ///   - override configurado pelo usuario tem prioridade;
  ///   - Android: pacote do RetroArch via PackageManager (qualquer versao);
  ///   - Windows: pastas comuns de instalacao + Steam + `where retroarch`;
  ///   - Linux: PATH, /usr, ~/.local, snap e exports do Flatpak;
  ///   - macOS: .app, Homebrew e `which retroarch`.
  /// Retorna o caminho do executavel (desktop) ou o nome do pacote (Android).
  Future<String?> findRetroArch() async {
    final override = settings.getRetroArchPath();
    if (override != null && override.trim().isNotEmpty) {
      final f = File(override.trim());
      if (f.existsSync()) return f.path;
    }

    if (Platform.isAndroid) {
      return _androidRetroArchPackage();
    }
    if (Platform.isIOS) return null;

    if (Platform.isWindows) {
      for (final c in _windowsCandidates) {
        if (File(c).existsSync()) return c;
      }
      return _which('retroarch');
    }
    if (Platform.isMacOS) {
      for (final c in _macCandidates) {
        if (File(c).existsSync()) return c;
      }
      return _which('retroarch');
    }

    // Linux e demais desktops.
    for (final c in _linuxCandidates) {
      if (File(c).existsSync()) return c;
    }
    return _which('retroarch');
  }

  Future<String?> _androidRetroArchPackage() async {
    const channel = MethodChannel('retrofront/launcher');
    try {
      final pkg = await channel.invokeMethod<String?>('detectRetroArch');
      return (pkg == null || pkg.isEmpty) ? null : pkg;
    } catch (_) {
      return null;
    }
  }

  List<String> get _windowsCandidates {
    String env(String key) => Platform.environment[key] ?? '';
    final local = env('LOCALAPPDATA');
    final pf = env('PROGRAMFILES');
    final pf86 = env('PROGRAMFILES(X86)');
    return [
      if (local.isNotEmpty) '$local\\RetroArch\\retroarch.exe',
      if (pf.isNotEmpty) '$pf\\RetroArch\\retroarch.exe',
      if (pf.isNotEmpty) '$pf\\RetroArch-Win64\\retroarch.exe',
      if (pf86.isNotEmpty) '$pf86\\RetroArch\\retroarch.exe',
      if (pf86.isNotEmpty)
        '$pf86\\Steam\\steamapps\\common\\RetroArch\\retroarch.exe',
      if (pf.isNotEmpty) '$pf\\Steam\\steamapps\\common\\RetroArch\\retroarch.exe',
      r'C:\RetroArch-Win64\retroarch.exe',
      r'C:\RetroArch\retroarch.exe',
    ];
  }

  List<String> get _macCandidates {
    final home = Platform.environment['HOME'] ?? '';
    return [
      '/Applications/RetroArch.app/Contents/MacOS/RetroArch',
      if (home.isNotEmpty)
        '$home/Applications/RetroArch.app/Contents/MacOS/RetroArch',
      '/opt/homebrew/bin/retroarch',
      '/usr/local/bin/retroarch',
    ];
  }

  List<String> get _linuxCandidates {
    final home = Platform.environment['HOME'] ?? '';
    return [
      if (home.isNotEmpty) '$home/.local/bin/retroarch',
      '/usr/local/bin/retroarch',
      '/usr/bin/retroarch',
      '/snap/bin/retroarch',
      if (home.isNotEmpty)
        '$home/.local/share/flatpak/exports/bin/org.libretro.RetroArch',
      '/var/lib/flatpak/exports/bin/org.libretro.RetroArch',
      if (home.isNotEmpty)
        '$home/.local/share/flatpak/exports/bin/com.libretro.RetroArch',
      '/var/lib/flatpak/exports/bin/com.libretro.RetroArch',
    ];
  }

  String _coresDir(String exe) {
    // RetroArch via Flatpak: os cores ficam na pasta de configuracao do app
    // (~/.var/app/<id>/config/retroarch/cores) ou empacotados no sandbox.
    final flatpakId = _flatpakIdOf(exe);
    if (flatpakId.isNotEmpty) {
      final home = Platform.environment['HOME'] ?? '';
      final varDir = p.join(
        home,
        '.var',
        'app',
        flatpakId,
        'config',
        'retroarch',
        'cores',
      );
      if (Directory(varDir).existsSync()) return varDir;
      return '/app/lib/retroarch/cores';
    }
    final dir = File(exe).parent.path;
    return '$dir${Platform.isWindows ? r'\cores' : '/cores'}';
  }

  /// Se [exe] e um launcher do Flatpak (ex.: ~/.local/share/flatpak/exports/
  /// bin/org.libretro.RetroArch), devolve o id do app (org.libretro.RetroArch).
  String _flatpakIdOf(String exe) {
    final name = p.basename(exe);
    if (name.startsWith('com.') ||
        name.startsWith('org.') ||
        name.startsWith('net.')) {
      if (exe.contains('/flatpak/exports/bin/')) return name;
    }
    return '';
  }

  Future<String?> _which(String name) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [name],
      );
      if (result.exitCode == 0) {
        final line = result.stdout.toString().trim().split('\n').first;
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}
    return null;
  }

  String _quote(String s) => '"${s.replaceAll('"', '\\"')}"';

  /// Tokenizacao simples de linha de comando respeitando aspas.
  List<String> _tokenize(String cmd) {
    final tokens = <String>[];
    final current = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < cmd.length; i++) {
      final ch = cmd[i];
      if (ch == '"') {
        inQuote = !inQuote;
      } else if (ch == ' ' && !inQuote) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
      } else {
        current.write(ch);
      }
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    return tokens;
  }
}
