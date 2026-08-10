import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_dirs.dart';
import '../../models/game_entry.dart';
import '../../models/system.dart';
import '../../models/system_override.dart';
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

  Future<LaunchResult> _launchDesktop(
    SystemDefinition system,
    GameEntry game,
  ) async {
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

    final override = settings.getSystemOverride(system.name);

    // RetroAchievements: injeta as credenciais via --appendconfig do RetroArch.
    String? raConfig;
    if (settings.getRaEnabled() && settings.getRaUsername().trim().isNotEmpty) {
      raConfig = await _writeRaConfig();
    }

    final cmd = buildLaunchCommand(
      resolvedCommand: command,
      gamePath: game.path,
      override: override,
      globalArgs: settings.getRetroArchArgs(),
      raAppendConfig: raConfig,
    );
    final tokens = _tokenize(cmd);
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

  /// Monta o comando final de lançamento (testável): aplica o core por sistema,
  /// insere os argumentos extras (globais + por sistema) e o config do
  /// RetroAchievements antes da ROM, e substitui %ROM% pelo caminho do jogo.
  static String buildLaunchCommand({
    required String resolvedCommand,
    required String gamePath,
    SystemOverride? override,
    String? globalArgs,
    String? raAppendConfig,
  }) {
    var cmd = resolvedCommand;

    if (override?.hasCore ?? false) {
      cmd = replaceCore(cmd, override!.core.trim());
    }

    final extra = <String>[
      if (globalArgs?.trim().isNotEmpty ?? false) globalArgs!.trim(),
      if (override?.hasArgs ?? false) override!.extraArgs.trim(),
      if (raAppendConfig != null) '--appendconfig ${_quote(raAppendConfig)}',
    ];
    if (extra.isNotEmpty) {
      cmd = cmd.replaceAll('%ROM%', '${extra.join(' ')} %ROM%');
    }
    return cmd.replaceAll('%ROM%', _quote(gamePath));
  }

  /// Troca o core do RetroArch no comando (apos `-L`) pelo core escolhido.
  /// Aceita nome curto ("mesen") ou caminho/arquivo completo.
  static String replaceCore(String cmd, String core) {
    final coreToken =
        core.contains('/') || core.contains(r'\') || core.contains('.')
        ? core
        : '${core}_libretro.so';
    final replaced = cmd.replaceAllMapped(
      RegExp(r'(-L\s+)\S+', caseSensitive: false),
      (m) => '${m[1]}$coreToken',
    );
    if (replaced == cmd) {
      return cmd.replaceFirst('%ROM%', '-L $coreToken %ROM%');
    }
    return replaced;
  }

  /// Escreve um config temporario do RetroArch com as credenciais do
  /// RetroAchievements e devolve o caminho (null em caso de erro).
  Future<String?> _writeRaConfig() async {
    try {
      final dir = Directory(
        p.join((await AppDirs.appDataDir()).path, 'retroachievements'),
      );
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'cheevos.cfg'));
      final username = settings.getRaUsername().trim();
      final password = settings.getRaPassword();
      final content = [
        'cheevos_enable = "true"',
        'cheevos_username = "${_escapeCfg(username)}"',
        if (password.isNotEmpty) 'cheevos_password = "${_escapeCfg(password)}"',
      ].join('\n');
      await file.writeAsString(content);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _escapeCfg(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  Future<LaunchResult> _launchAndroid(
    SystemDefinition system,
    GameEntry game,
  ) async {
    final pkg = await _androidRetroArchPackage();
    if (pkg == null) {
      return const LaunchResult.failure(
        'RetroArch não está instalado. Instale o RetroArch na Play Store '
        'ou em retroarch.com para jogar.',
      );
    }
    const channel = MethodChannel('retrofront/launcher');
    try {
      final ok = await channel.invokeMethod<bool>('launchRetroArch', game.path);
      if (ok == true) return const LaunchResult.success();
      return LaunchResult.failure(
        'Não foi possível abrir "${game.name}". O formato pode não ser '
        'suportado pelo RetroArch ou o arquivo não está acessível.',
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
  ///   - Linux: PATH, /usr, ~/.local, snap e exports do Flatpak.
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
    return '$dir/cores';
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
      final result = await Process.run('which', [name]);
      if (result.exitCode == 0) {
        final line = result.stdout.toString().trim().split('\n').first;
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}
    return null;
  }

  static String _quote(String s) => '"${s.replaceAll('"', '\\"')}"';

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
