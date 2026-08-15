import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../data/downloads/libretro_downloader.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/system.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/download_progress_dialog.dart';
import 'widgets/nav_key_handler.dart';

/// Seleção de consoles para baixar os núcleos (cores) do libretro. Cada
/// sistema marcado tem o core do seu comando baixado do buildbot (por sistema,
/// pois o buildbot publica um arquivo por core). Aperte [GamepadAction.confirm]
/// para marcar/desmarcar e B/Start para baixar os selecionados.
class CoreDownloadsView extends StatefulWidget {
  const CoreDownloadsView({super.key});

  @override
  State<CoreDownloadsView> createState() => _CoreDownloadsViewState();
}

class _CoreDownloadsViewState extends State<CoreDownloadsView> {
  AppServices get _svc => AppScope.of(context);

  List<SystemDefinition> _systems = [];
  Set<String> _selected = {};
  bool _loading = true;
  int _selectedIndex = 0;
  bool _downloading = false;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _load();
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final systems = await _svc.systems.load();
    if (!mounted) return;
    setState(() {
      _systems = systems;
      _selected = {
        for (final s in systems)
          if (LibretroDownloader.coreBaseName(s.command) != null)
            s.name.toLowerCase(),
      };
      _loading = false;
    });
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.up:
        _move(-1);
      case GamepadAction.down:
        _move(1);
      case GamepadAction.pageUp:
        _move(-6);
      case GamepadAction.pageDown:
        _move(6);
      case GamepadAction.confirm:
        _toggleSelected();
      case GamepadAction.back:
        _download();
      case GamepadAction.start:
      case GamepadAction.home:
        _download();
      case GamepadAction.left:
      case GamepadAction.right:
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    if (_systems.isEmpty) return;
    final next = (_selectedIndex + delta).clamp(0, _systems.length - 1);
    if (next != _selectedIndex) setState(() => _selectedIndex = next);
  }

  void _toggleSelected() {
    if (_systems.isEmpty) return;
    final name = _systems[_selectedIndex].name.toLowerCase();
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  /// Baixa os cores dos consoles marcados, um a um, com progresso geral.
  Future<void> _download() async {
    if (_downloading) return;
    final targets = _systems.where(
      (s) => _selected.contains(s.name.toLowerCase()),
    );
    final items = <(SystemDefinition, String)>[];
    for (final s in targets) {
      final base = LibretroDownloader.coreBaseName(s.command);
      if (base != null) items.add((s, base));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum console selecionado ou com core definido.'),
        ),
      );
      return;
    }

    setState(() => _downloading = true);
    final errors = <String>[];
    for (var i = 0; i < items.length; i++) {
      final (system, base) = items[i];
      if (!mounted) return;
      final error = await showDownloadProgressDialog(
        context,
        title: 'Baixando cores ($i de ${items.length})',
        itemName: base,
        task: (onProgress) => _svc.downloads.downloadCore(
          coreBase: base,
          platform: LibretroDownloader.platform,
          arch: _svc.settings.getCoreArch(),
          onProgress: onProgress,
        ),
      );
      if (error != null) errors.add('$base ($system.fullName)');
    }
    if (!mounted) return;
    setState(() => _downloading = false);

    final msg = errors.isEmpty
        ? '${items.length} core${items.length == 1 ? '' : 's'} baixado${items.length == 1 ? '' : 's'} em DOWNLOADS/cores.'
        : 'Concluído com ${errors.length} falha${errors.length == 1 ? '' : 's'}: ${errors.join(', ')}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _move(-1);
    }
    ..onDown = () {
      _move(1);
    }
    ..onPageUp = () {
      _move(-6);
    }
    ..onPageDown = () {
      _move(6);
    }
    ..onConfirm = _toggleSelected
    ..onBack = _download
    ..onStart = _download
    ..onHome = _download;

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cores por console'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() => _selected.clear()),
            child: const Text('Nenhum'),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _selected = {
                        for (final s in _systems)
                          if (LibretroDownloader.coreBaseName(s.command) != null)
                            s.name.toLowerCase(),
                      };
                    });
                  },
            child: const Text('Todos'),
          ),
        ],
      ),
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(color: AppTheme.accent, darken: 0.62),
            if (_loading)
              Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '$selectedCount console${selectedCount == 1 ? '' : 's'} '
                      'selecionado${selectedCount == 1 ? '' : 's'} — '
                      'A/B baixa os cores em DOWNLOADS/cores',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _systems.length,
                      itemBuilder: (context, index) {
                        final system = _systems[index];
                        final base = LibretroDownloader.coreBaseName(
                          system.command,
                        );
                        final selected = index == _selectedIndex;
                        final checked = _selected.contains(
                          system.name.toLowerCase(),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: selected
                                ? AppTheme.accent.withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              selected: selected,
                              enabled: base != null,
                              onTap: () {
                                if (base == null) return;
                                setState(() => _selectedIndex = index);
                                _toggleSelected();
                              },
                              leading: Icon(
                                checked
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: checked
                                    ? AppTheme.accent
                                    : AppTheme.textFaint,
                              ),
                              title: Text(
                                system.fullName,
                                style: TextStyle(
                                  color: selected
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                base ?? 'sem core definido',
                                style: TextStyle(
                                  color: base == null
                                      ? AppTheme.textFaint
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.download,
                                size: 18,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
