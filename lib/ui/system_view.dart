import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/android_storage.dart';
import '../core/app_scope.dart';
import '../core/route_observer.dart';
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

class _SystemViewState extends State<SystemView>
    with WidgetsBindingObserver, RouteAware {
  AppServices get _svc => AppScope.of(context);

  List<SystemEntry> _systems = [];
  int _selected = 0;
  bool _loading = true;
  bool _hasError = false;
  bool _androidAccess = true;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;
  bool _routeSubscribed = false;
  bool _updateChecked = false;
  DateTime _lastActivity = DateTime.now();
  bool _screensaverOn = false;
  Timer? _screensaverTimer;
  bool _appActive = true;

  bool get _kiosk => _svc.settings.getUiMode() == 'kiosk';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screensaverTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkScreensaver(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _screensaverTimer?.cancel();
    _gamepadSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) _poke();
    // Ao voltar da tela de permissao/configuracoes do Android (o pedido de
    // "All files access" nao bloqueia ate o usuario retornar), re-escaneia.
    if (state == AppLifecycleState.resumed && AndroidStorage.isNeeded) {
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      _routeSubscribed = true;
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    }
    if (_depsReady) return;
    _depsReady = true;
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
    _load();
    if (!_updateChecked) {
      _updateChecked = true;
      _checkForUpdatesOnStart();
    }
  }

  // Auto-update: verifica o GitHub uma vez por sessão e avisa se houver
  // versão mais recente (Nightly/Beta/Stable conforme as configurações).
  Future<void> _checkForUpdatesOnStart() async {
    final s = _svc.settings;
    if (!s.getCheckUpdates()) return;
    final result = await _svc.update.check(
      includePrerelease: s.getIncludePrerelease(),
    );
    if (!mounted || !result.hasUpdate || result.latest == null) return;
    final latest = result.latest!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Nova versão ${latest.version} disponível.'),
          action: SnackBarAction(
            label: 'Atualizar',
            onPressed: _openSettings,
          ),
        ),
      );
  }

  // Voltou ao topo (ex.: fechou Configurações): re-reflete as configurações,
  // incluindo a visibilidade do botão de configurações no modo quiosque.
  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    final prevName = _systems.isEmpty ? null : _systems[_selected].name;
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
      _androidAccess =
          !AndroidStorage.isNeeded || await AndroidStorage.hasAccess();
      final systems = await _svc.scanner.scanSystems(
        romsOverride: _svc.settings.getRomsPath(),
      );
      // Verificacao de inicializacao: carrega as configuracoes dos sistemas e
      // os gamelists (capas/informacoes ja salvas) em segundo plano.
      if (systems.isNotEmpty) {
        unawaited(_svc.gamelist.preload(systems.map((s) => s.name).toList()));
      }
      if (!mounted) return;
      setState(() {
        _systems = systems;
        final idx = prevName == null
            ? 0
            : systems.indexWhere((s) => s.name == prevName);
        _selected = idx < 0 ? 0 : idx;
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
    if (_screensaverOn) {
      _poke();
      return;
    }
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

  // Registra atividade do usuário e esconde o protetor de tela se ativo.
  void _poke() {
    _lastActivity = DateTime.now();
    if (_screensaverOn) setState(() => _screensaverOn = false);
  }

  void _checkScreensaver() {
    if (!_appActive || _screensaverOn) return;
    final s = _svc.settings;
    if (!s.getScreensaverEnabled()) return;
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= Duration(minutes: s.getScreensaverDelay())) {
      setState(() => _screensaverOn = true);
    }
  }

  // Abre a tela do sistema de "All files access" (via request no _load) e o
  // scan re-roda ao voltar do Android (didChangeAppLifecycleState) e aqui.
  Future<void> _grantStorage() async {
    final granted = await AndroidStorage.request();
    if (!granted) {
      // Fallback: alguns OEMs/Android 15 ignoram o intent especifico; abre as
      // configuracoes do app, onde fica o toggle de "All files access".
      await AndroidStorage.openSettings();
    }
    await _load();
  }

  Future<void> _pickRomsFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Pasta de ROMs',
    );
    if (path == null) return;
    await _svc.settings.setRomsPath(path);
    await _load();
  }

  void _moveCarousel(int dir) {
    if (_systems.isEmpty) return;
    final next = (_selected + dir).clamp(0, _systems.length - 1);
    _select(next);
  }

  void _select(int index) {
    _poke();
    if (index == _selected) return;
    setState(() => _selected = index);
  }

  void _openSelected() {
    _poke();
    if (_systems.isEmpty) return;
    final system = _systems[_selected];
    Navigator.of(context).push(consoleRoute(GamelistView(system: system)));
  }

  void _openSettings() {
    _poke();
    if (_kiosk) {
      _confirmExitKiosk();
      return;
    }
    Navigator.of(context).push(consoleRoute(const SettingsView()));
  }

  // No modo quiosque as configurações ficam ocultas; exige confirmação para
  // evitar que o usuário fique preso sem acesso às configurações.
  Future<void> _confirmExitKiosk() async {
    if (!mounted) return;
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Modo quiosque',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'As configurações estão ocultas no modo quiosque. '
          'Deseja sair do modo quiosque e abrir as configurações?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair e abrir'),
          ),
        ],
      ),
    );
    if (exit != true || !mounted) return;
    await _svc.settings.setUiMode('full');
    if (!mounted) return;
    setState(() {});
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
    final screenH = MediaQuery.of(context).size.height;
    final carouselH = (screenH * (isLandscape ? 0.42 : 0.30)).clamp(
      140.0,
      isLandscape ? 300.0 : 220.0,
    );
    final tileW = (carouselH * 1.0).clamp(0.0, 300.0);

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Listener(
          onPointerDown: (_) => _poke(),
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
                  message:
                      'Escolha a pasta onde ficam suas ROMs (uma subpasta '
                      'por console: nes, snes, psx, gba...) e o app monta a '
                      'biblioteca.\nNo Android é preciso também conceder acesso '
                      'aos arquivos para ler a pasta.',
                  actionLabel: 'Escolher pasta de ROMs',
                  actionIcon: Icons.folder_open,
                  onAction: _pickRomsFolder,
                  secondaryLabel: AndroidStorage.isNeeded && !_androidAccess
                      ? 'Conceder acesso aos arquivos'
                      : null,
                  secondaryIcon: Icons.perm_media,
                  onSecondaryAction: AndroidStorage.isNeeded && !_androidAccess
                      ? _grantStorage
                      : null,
                )
              else
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        onRefresh: _load,
                        onSettings: _kiosk ? null : _openSettings,
                        onLogoTap: _kiosk ? _confirmExitKiosk : null,
                      ),
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
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _SystemInfoBar(
                            system: _systems[_selected],
                          ),
                        ),
                      ),
                      if (_svc.settings.getShowHints())
                        HintBar(
                          hints: [
                            Hint(
                              'navegar',
                              button: _svc.gamepad.currentButtonFor(
                                GamepadAction.right,
                              ),
                            ),
                            Hint(
                              'entrar',
                              button: _svc.gamepad.currentButtonFor(
                                GamepadAction.confirm,
                              ),
                            ),
                            if (!_kiosk)
                              Hint(
                                'opções',
                                button: _svc.gamepad.currentButtonFor(
                                  GamepadAction.start,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (_screensaverOn) _ScreensaverOverlay(onDismiss: _poke),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onSettings;
  final VoidCallback? onLogoTap;

  const _TopBar({required this.onRefresh, this.onSettings, this.onLogoTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onLogoTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentAlt],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sports_esports,
                color: Colors.white,
                size: 22,
              ),
            ),
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
          if (onSettings != null)
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

/// Protetor de tela: fundo escuro com relógio; qualquer toque ou botão volta.
class _ScreensaverOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const _ScreensaverOverlay({required this.onDismiss});

  @override
  State<_ScreensaverOverlay> createState() => _ScreensaverOverlayState();
}

class _ScreensaverOverlayState extends State<_ScreensaverOverlay> {
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$h:$m',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 64,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'RetroFront',
              style: TextStyle(color: Colors.white24, fontSize: 15),
            ),
            const SizedBox(height: 44),
            Text(
              'Toque ou aperte qualquer botão',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel compacto no rodapé com pequenas informações do console selecionado
/// (plataforma, fabricante, ano e quantidade de jogos).
class _SystemInfoBar extends StatelessWidget {
  final SystemEntry system;

  const _SystemInfoBar({required this.system});

  @override
  Widget build(BuildContext context) {
    final def = system.definition;
    final showCount = AppScope.of(context).settings.getShowGameCount();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          if (def.platform != null && def.platform!.isNotEmpty)
            _InfoChip(icon: Icons.memory, label: def.platform!),
          if (def.manufacturer.isNotEmpty)
            _InfoChip(icon: Icons.business, label: def.manufacturer),
          if (def.releaseYear != null)
            _InfoChip(icon: Icons.event, label: '${def.releaseYear}'),
          if (showCount)
            _InfoChip(
              icon: Icons.videogame_asset,
              label:
                  '${system.gameCount} ${system.gameCount == 1 ? 'jogo' : 'jogos'}',
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.actionIcon = Icons.settings,
    required this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryLabel != null && onSecondaryAction != null
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: onSecondaryAction,
            icon: Icon(secondaryIcon ?? Icons.settings),
            label: Text(secondaryLabel!),
          )
        : null;
    return Center(
      child: SingleChildScrollView(
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
            if (secondary != null) ...[const SizedBox(height: 10), secondary],
          ],
        ),
      ),
    );
  }
}
