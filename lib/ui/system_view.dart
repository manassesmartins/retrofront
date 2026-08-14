import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/android_storage.dart';
import '../core/app_dirs.dart';
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
  bool _loadInFlight = false;
  bool _hasError = false;
  bool _androidAccess = true;
  bool _accessGateDismissed = false;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;
  bool _routeSubscribed = false;
  bool _updateChecked = false;
  bool _defaultStructureEnsured = false;
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
    if (_loadInFlight) return;
    _loadInFlight = true;
    final prevName = _systems.isEmpty ? null : _systems[_selected].name;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      // Apenas rele o estado do acesso. NUNCA solicita a permissao aqui:
      // abrir a tela do sistema a cada scan/retorno era o que causava o loop
      // infinito (didChangeAppLifecycleState chamava _load ao voltar).
      _androidAccess =
          !AndroidStorage.isNeeded || await AndroidStorage.hasAccess();
      // Cria a estrutura padrao quando o acesso ja esta concedido. Se a pasta
      // foi escolhida antes da permissao, garante a estrutura agora.
      if (await AndroidStorage.hasAccess()) {
        await _ensureLibraryStructure();
      }
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
    } finally {
      _loadInFlight = false;
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

  /// Abre a tela de "All files access" do sistema (Android 11+). Nao fica em
  /// loop: apenas abre a tela uma vez e rele o estado ao voltar (aqui e no
  /// didChangeAppLifecycleState). Em Android <= 10 pede a permissao de
  /// armazenamento em tempo de execucao.
  Future<void> _grantStorage() async {
    if (!AndroidStorage.isNeeded) return;
    final opened = await AndroidStorage.request();
    if (!opened) {
      // Fallback: alguns OEMs/Android 15 ignoram o intent especifico; abre as
      // configuracoes do app, onde o toggle fica em "Arquivos e midia".
      await AndroidStorage.openSettings();
    }
    if (await AndroidStorage.hasAccess()) {
      await _ensureLibraryStructure();
    }
    await _load();
  }

  /// Cria a estrutura padrão da biblioteca quando o acesso aos arquivos já
  /// foi concedido. Para pasta customizada escolhida antes da permissão (a
  /// criação na época falhou em silêncio), recria a estrutura agora.
  Future<void> _ensureLibraryStructure() async {
    final custom = _svc.settings.getRomsPath();
    if (custom != null) {
      final sep = p.separator;
      if (custom.toLowerCase().endsWith('${sep}retrofront${sep}roms')) {
        // getRomsPath() guarda a raiz de ROMs (base/Retrofront/ROMs); a base
        // escolhida pelo usuário é o pai do pai.
        final base = p.dirname(p.dirname(custom));
        await _svc.systems.ensureDefaultFolders(base);
      }
      return;
    }
    if (_defaultStructureEnsured) return;
    _defaultStructureEnsured = true;
    final base = await AppDirs.defaultBaseDir();
    await _svc.systems.ensureDefaultFolders(base.path);
  }

  Future<void> _pickRomsFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Pasta de ROMs',
    );
    if (path == null) return;
    // Cria a estrutura padrão (Retrofront/ROMs, BIOS, SAVES, CONFIGS,
    // COVERS, TEXTUREPACKS) dentro da pasta escolhida.
    final romsPath = await _svc.systems.ensureDefaultFolders(path);
    await _svc.settings.setRomsPath(romsPath);
    AppDirs.useRomsOverride(romsPath);
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
        title: Text(
          'Modo quiosque',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
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
    // Biblioteca ja configurada (o usuario ja escolheu a pasta de ROMs).
    final romsConfigured = _svc.settings.getRomsPath() != null;
    // Android 11+ sem "All files access": precisa conceder o acesso.
    final grantNeeded = AndroidStorage.isNeeded && !_androidAccess;

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
                artPath: _systems.isEmpty
                    ? null
                    : AppDirs.systemArtPath(_systems[_selected].name),
              ),
              if (_loading)
                Center(
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
                  title: romsConfigured
                      ? 'Biblioteca criada'
                      : 'Nenhum sistema encontrado',
                  message: romsConfigured
                      ? 'A estrutura RetroFront foi criada em:\n'
                          '${_svc.settings.getRomsPath()}\n'
                          'Coloque as ROMs nas pastas de cada sistema '
                          '(ex.: nes, snes, psx) e toque em "Atualizar" '
                          'para carregar os jogos.'
                      : 'Escolha onde criar a biblioteca e o app monta a '
                          'estrutura RetroFront automaticamente (ROMs por '
                          'console, BIOS, SAVES, CONFIGS, COVERS, SYSTEMART '
                          'e TEXTUREPACKS).\n'
                          'No Android 11+ o acesso aos arquivos fica em '
                          '"Arquivos e mídia > Acesso a todos os arquivos" '
                          'nas configurações do app (não aparece na lista de '
                          'permissões normal).',
                  actionLabel: !romsConfigured
                      ? 'Escolher pasta de ROMs'
                      : grantNeeded
                          ? 'Conceder acesso aos arquivos'
                          : 'Atualizar',
                  actionIcon: !romsConfigured
                      ? Icons.folder_open
                      : grantNeeded
                          ? Icons.perm_media
                          : Icons.refresh,
                  onAction: !romsConfigured
                      ? _pickRomsFolder
                      : grantNeeded
                          ? _grantStorage
                          : _load,
                  secondaryLabel: !romsConfigured && grantNeeded
                      ? 'Conceder acesso aos arquivos'
                      : romsConfigured
                          ? 'Trocar pasta'
                          : null,
                  secondaryIcon: !romsConfigured && grantNeeded
                      ? Icons.perm_media
                      : Icons.folder_open,
                  onSecondaryAction: !romsConfigured && grantNeeded
                      ? _grantStorage
                      : romsConfigured
                          ? _pickRomsFolder
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
              // Primeira execucao no Android: exige "All files access"
              // (MANAGE_EXTERNAL_STORAGE) antes de usar o app. Ao aparecer,
              // abre a tela do sistema automaticamente (uma vez); quando o
              // usuario ativa o toggle e volta, o onResume rele o estado e
              // dispensa o aviso sozinho.
              if (grantNeeded && !_accessGateDismissed)
                _StoragePermissionGate(
                  onGrant: _grantStorage,
                  onDismiss: () => setState(() => _accessGateDismissed = true),
                ),
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
                gradient: LinearGradient(
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
          Text(
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
            color: AppTheme.textSecondary,
          ),
          if (onSettings != null)
            IconButton(
              tooltip: 'Configurações',
              onPressed: onSettings,
              icon: const Icon(Icons.settings),
              color: AppTheme.textSecondary,
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
        color: AppTheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
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
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(color: AppTheme.border),
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
            Icon(icon, size: 56, color: AppTheme.textFaint),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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

/// Aviso de primeira execucao no Android: o app precisa de "All files access"
/// (MANAGE_EXTERNAL_STORAGE) para ler as ROMs. Abre a tela do sistema uma
/// unica vez ao aparecer; o estado real e relido ao voltar (onResume), que
/// dispensa o aviso automaticamente quando o acesso for concedido.
class _StoragePermissionGate extends StatefulWidget {
  final VoidCallback onGrant;
  final VoidCallback onDismiss;

  const _StoragePermissionGate({
    required this.onGrant,
    required this.onDismiss,
  });

  @override
  State<_StoragePermissionGate> createState() => _StoragePermissionGateState();
}

class _StoragePermissionGateState extends State<_StoragePermissionGate> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    // Abre a tela do sistema automaticamente na primeira vez em que o aviso
    // aparece (sem loop: so uma vez por instancia).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoOpened) return;
      _autoOpened = true;
      widget.onGrant();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.perm_media,
                    size: 48,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Permissão de acesso aos arquivos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Para ler as ROMs, o RetroFront precisa de acesso a todos '
                  'os arquivos do aparelho (permissão MANAGE_EXTERNAL_STORAGE).\n\n'
                  'Toque em "Permitir" e ative o toggle na tela do sistema. '
                  'Quando ativar, o app volta sozinho.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: widget.onGrant,
                  icon: const Icon(Icons.perm_media),
                  label: const Text('Permitir acesso aos arquivos'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Se a tela não abrir, ative manualmente em: Configurações > '
                  'Apps > RetroFront > Arquivos e mídia > Acesso a todos os '
                  'arquivos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textFaint,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Depois',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
