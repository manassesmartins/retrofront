import 'dart:io';

import 'package:flutter/services.dart';

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

    final tokens = _tokenize(command.replaceAll('%ROM%', game.path));
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
      final path = await _findRetroArch();
      if (path == null) return null;
      cmd = cmd.replaceAll('%EMULATOR_RETROARCH%', _quote(path));
      cmd = cmd.replaceAll('%CORE_RETROARCH%', _quote(_coresDir(path)));
    }
    return cmd;
  }

  Future<String?> _findRetroArch() async {
    final override = settings.getRetroArchPath();
    if (override != null && override.trim().isNotEmpty) {
      final f = File(override.trim());
      if (f.existsSync()) return f.path;
    }

    if (Platform.isWindows) {
      const candidates = <String>[
        r'C:\RetroArch-Win64\retroarch.exe',
        r'C:\RetroArch\retroarch.exe',
        r'C:\Program Files\RetroArch\retroarch.exe',
      ];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        candidates.expand((e) => [e]);
        final la = File('$localAppData\\RetroArch\\retroarch.exe');
        if (la.existsSync()) return la.path;
      }
      for (final c in candidates) {
        final f = File(c);
        if (f.existsSync()) return f.path;
      }
      return _which('retroarch');
    }

    return _which('retroarch');
  }

  String _coresDir(String exe) {
    final dir = File(exe).parent.path;
    return '$dir${Platform.isWindows ? r'\cores' : '/cores'}';
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
