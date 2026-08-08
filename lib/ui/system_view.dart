import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/system.dart';
import 'gamelist_view.dart';
import 'settings_view.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/system_tile.dart';

/// Tela inicial: grade de sistemas/consoles (System view do ES-DE).
class SystemView extends StatefulWidget {
  const SystemView({super.key});

  @override
  State<SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends State<SystemView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _tileKeys = {};

  List<SystemEntry> _systems = [];
  int _selected = 0;
  bool _loading = true;
  bool _hasError = false;
  StreamSubscription<GamepadAction>? _gamepadSub;
  int _columns = 1;

  @override
  void initState() {
    super.initState();
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _load();
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final systems = await _svc.scanner
          .scanSystems(romsOverride: _svc.settings.getRomsPath());
      if (!mounted) return;
      setState(() {
        _systems = systems;
        _selected = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.up:
        _moveGrid(0, -1);
      case GamepadAction.down:
        _moveGrid(0, 1);
      case GamepadAction.left:
        _moveGrid(-1, 0);
      case GamepadAction.right:
        _moveGrid(1, 0);
      case GamepadAction.confirm:
        _openSelected();
      case GamepadAction.pageUp:
        _movePage(-1);
      case GamepadAction.pageDown:
        _movePage(1);
      case GamepadAction.start:
      case GamepadAction.home:
        _openSettings();
      case GamepadAction.back:
      case GamepadAction.select:
        break;
    }
  }

  void _moveGrid(int dx, int dy) {
    if (_systems.isEmpty) return;
    final cols = _columns;
    final total = _systems.length;
    final rows = (total / cols).ceil();

    var col = _selected % cols;
    var row = (_selected / cols).floor();

    if (dx != 0) {
      col = (col + dx) % cols;
      if (col < 0) col += cols;
    }
    if (dy != 0) {
      row = (row + dy) % rows;
      if (row < 0) row += rows;
    }

    var index = row * cols + col;
    if (index >= total) index = total - 1;
    if (index < 0) index = 0;
    _select(index);
  }

  void _movePage(int dir) {
    if (_systems.isEmpty) return;
    final page = _columns;
    _select((_selected + dir * page).clamp(0, _systems.length - 1));
  }

  void _select(int index) {
    setState(() => _selected = index);
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _tileKeys[_selected];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _openSelected() {
    if (_systems.isEmpty) return;
    final system = _systems[_selected];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamelistView(system: system),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsView()),
    );
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _moveGrid(0, -1);
    }
    ..onDown = () {
      _moveGrid(0, 1);
    }
    ..onLeft = () {
      _moveGrid(-1, 0);
    }
    ..onRight = () {
      _moveGrid(1, 0);
    }
    ..onConfirm = _openSelected
    ..onPageUp = () {
      _movePage(-1);
    }
    ..onPageDown = () {
      _movePage(1);
    }
    ..onStart = _openSettings
    ..onHome = _openSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFF22D3EE),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.sports_esports,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RetroFront',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Sua biblioteca retrô',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      color: Colors.white70,
                    ),
                    IconButton(
                      tooltip: 'Configurações',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }
    if (_hasError) {
      return _Message(
        icon: Icons.error_outline,
        title: 'Erro ao ler a biblioteca',
        message: 'Não foi possível acessar a pasta de ROMs.',
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    if (_systems.isEmpty) {
      return _Message(
        icon: Icons.folder_off_outlined,
        title: 'Nenhum sistema encontrado',
        message: 'Crie subpastas com o nome de cada console em sua pasta de '
            'ROMs (ex.: nes, snes, psx, gba) e coloque os jogos dentro.\n'
            'Depois toque em Atualizar ou configure a pasta em Configurações.',
        actionLabel: 'Configurar pasta de ROMs',
        onAction: _openSettings,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTileWidth = 220.0;
        final columns = (constraints.maxWidth / maxTileWidth).floor().clamp(1, 8);
        if (columns != _columns) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _columns = columns);
          });
        }

        final total = _systems.length;
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxTileWidth,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.55,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            final key = GlobalKey();
            _tileKeys[index] = key;
            return KeyedSubtree(
              key: key,
              child: SystemTile(
                system: _systems[index],
                selected: index == _selected,
                onTap: () {
                  setState(() => _selected = index);
                  _openSelected();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.settings),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
