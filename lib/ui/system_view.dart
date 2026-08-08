import 'dart:async';

import 'package:flutter/material.dart';

import '../core/android_storage.dart';
import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/system.dart';
import 'gamelist_view.dart';
import 'settings_view.dart';
import 'theme.dart';
import 'widgets/console_route.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/cover_carousel.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/system_cover.dart';

/// Tela inicial estilo console: carrossel horizontal de sistemas com destaque
/// central, navegavel por gamepad/teclado e por gestos de toque.
class SystemView extends StatefulWidget {
  const SystemView({super.key});

  @override
  State<SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends State<SystemView> {
  AppServices get _svc => AppScope.of(context);

  List<SystemEntry> _systems = [];
  int _selected = 0;
  bool _loading = true;
  bool _hasError = false;
  StreamSubscription<GamepadAction>? _gamepadSub;

  @override
  void initState() {
    super.initState();
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _load();
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      // No Android o acesso a pasta publica de ROMs exige permissao de
      // armazenamento; solicita antes do primeiro scan.
      if (AndroidStorage.isNeeded && !await AndroidStorage.hasAccess()) {
        await AndroidStorage.request();
      }
      final systems = await _svc.scanner
          .scanSystems(romsOverride: _svc.settings.getRomsPath());
      // Verificacao de inicializacao: carrega as configuracoes dos sistemas e
      // os gamelists (capas/informacoes ja salvas) em segundo plano.
      if (systems.isNotEmpty) {
        unawaited(_svc.gamelist.preload(systems.map((s) => s.name).toList()));
      }
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
      case GamepadAction.left:
        _moveCarousel(-1);
      case GamepadAction.right:
        _moveCarousel(1);
      case GamepadAction.confirm:
        _openSelected();
      case GamepadAction.up:
      case GamepadAction.down:
        break;
      case GamepadAction.start:
      case GamepadAction.home:
        _openSettings();
      case GamepadAction.pageUp:
      case GamepadAction.pageDown:
      case GamepadAction.back:
      case GamepadAction.select:
        break;
    }
  }

  Future<void> _grantStorage() async {
    await AndroidStorage.request();
    await _load();
  }

  void _moveCarousel(int dir) {
    if (_systems.isEmpty) return;
    final next = (_selected + dir).clamp(0, _systems.length - 1);
    _select(next);
  }

  void _select(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
  }

  void _openSelected() {
    if (_systems.isEmpty) return;
    final system = _systems[_selected];
    Navigator.of(context).push(consoleRoute(GamelistView(system: system)));
  }

  void _openSettings() {
    Navigator.of(context).push(consoleRoute(const SettingsView()));
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onLeft = () {
      _moveCarousel(-1);
    }
    ..onRight = () {
      _moveCarousel(1);
    }
    ..onConfirm = _openSelected
    ..onStart = _openSettings
    ..onHome = _openSettings;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final carouselH = isLandscape ? 300.0 : 220.0;
    final tileW = (carouselH * 0.72).clamp(0.0, 250.0);

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(
              color: _systems.isEmpty
                  ? AppTheme.accent
                  : AppTheme.systemColor(_systems[_selected].name),
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            else if (_hasError)
              _Message(
                icon: Icons.error_outline,
                title: 'Erro ao ler a biblioteca',
                message: 'Não foi possível acessar a pasta de ROMs.',
                actionLabel: 'Tentar novamente',
                onAction: _load,
              )
            else if (_systems.isEmpty)
              _Message(
                icon: Icons.folder_off_outlined,
                title: 'Nenhum sistema encontrado',
                message: 'Crie subpastas com o nome de cada console na sua '
                    'pasta de ROMs (ex.: nes, snes, psx, gba) e coloque os '
                    'jogos dentro.\nDepois toque em Atualizar ou configure a '
                    'pasta em Configurações.',
                actionLabel: AndroidStorage.isNeeded
                    ? 'Conceder acesso aos arquivos'
                    : 'Configurar pasta de ROMs',
                actionIcon:
                    AndroidStorage.isNeeded ? Icons.folder_open : Icons.settings,
                onAction:
                    AndroidStorage.isNeeded ? _grantStorage : _openSettings,
              )
            else
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(onRefresh: _load, onSettings: _openSettings),
                    Expanded(child: _InfoPanel(system: _systems[_selected])),
                    SizedBox(
                      height: carouselH,
                      child: CoverCarousel(
                        itemCount: _systems.length,
                        tileWidth: tileW,
                        tileHeight: carouselH,
                        selected: _selected,
                        onSelect: _select,
                        itemBuilder: (context, index, selected) {
                          final system = _systems[index];
                          return SystemCover(
                            name: system.name,
                            fullName: system.fullName,
                            color: AppTheme.systemColor(system.name),
                            gameCount: system.gameCount,
                            showGameCount: _svc.settings.getShowGameCount(),
                            selected: selected,
                            onTap: () {
                              if (selected) {
                                _openSelected();
                              } else {
                                _select(index);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    if (_svc.settings.getShowHints())
                      const HintBar(
                        hints: [
                          Hint('◄ ►  navegar'),
                          Hint('toque/A  entrar'),
                          Hint('Start  opções'),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onSettings;

  const _TopBar({required this.onRefresh, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentAlt],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'RetroFront',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            color: Colors.white70,
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: onSettings,
            icon: const Icon(Icons.settings),
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final SystemEntry system;

  const _InfoPanel({required this.system});

  @override
  Widget build(BuildContext context) {
    final def = system.definition;
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final showCount = AppScope.of(context).settings.getShowGameCount();

    return Padding(
      padding: EdgeInsets.fromLTRB(24, isLandscape ? 8 : 12, 24, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            child: Text(
              system.fullName,
              key: ValueKey(system.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isLandscape ? 52 : 34,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (def.manufacturer.isNotEmpty) ...[
                _MetaText(def.manufacturer),
                const _Dot(),
              ],
              if (def.releaseYear != null) ...[
                _MetaText('${def.releaseYear}'),
                const _Dot(),
              ],
              if (showCount)
                _MetaText(
                  '${system.gameCount} ${system.gameCount == 1 ? 'jogo' : 'jogos'}',
                ),
            ],
          ),
          if (!isLandscape) const SizedBox(height: 6),
          const Text(
            'Selecione um console e aperte para explorar sua biblioteca.',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;

  const _MetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text('•', style: TextStyle(color: AppTheme.accent, fontSize: 14)),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.actionIcon = Icons.settings,
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
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
