import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/android_storage.dart';
import '../core/app_dirs.dart';
import '../core/app_languages.dart';
import '../core/app_scope.dart';
import '../core/screen_mode.dart';
import '../gamepad/gamepad_manager.dart';
import 'settings_category_view.dart';
import 'settings_options.dart';
import 'cover_systems_view.dart';
import 'theme.dart';
import 'widgets/console_route.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/cover_carousel.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/virtual_keyboard.dart';
import 'button_map_view.dart';

/// Tela de Configurações estilo console: carrossel horizontal de categorias.
/// Cada categoria abre como uma janela própria (SettingsCategoryView), em vez
/// de mostrar as opções empilhadas na mesma tela. Navegação:
///   - esquerda/direita (ou LB/RB): categoria
///   - A: abrir a categoria selecionada
///   - B: voltar
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  AppServices get _svc => AppScope.of(context);

  List<SettingsCategory> _categories = [];
  int _selected = 0;
  bool _loading = true;
  String _defaultRoms = '';
  String? _retroArch;
  bool _androidAccess = true;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
  }

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
    final defaultRoms = (await AppDirs.romsRoot()).path;
    var androidAccess = true;
    if (AndroidStorage.isNeeded) androidAccess = await AndroidStorage.hasAccess();
    final retroArch = await _svc.launcher.findRetroArch();
    if (!mounted) return;
    setState(() {
      _defaultRoms = defaultRoms;
      _androidAccess = androidAccess;
      _retroArch = retroArch;
      _categories = _buildCategories();
      _loading = false;
    });
  }

  List<SettingsCategory> _buildCategories() {
    final s = _svc.settings;
    return [
      SettingsCategory(
        label: 'Biblioteca',
        description: 'Onde ficam os jogos, a ordenação da lista e como o app '
            'acessa o armazenamento.',
        icon: Icons.video_library_outlined,
        options: [
          SettingsOption(
            label: 'Pasta de ROMs',
            description: 'Pasta principal da biblioteca. Crie uma subpasta por '
                'console (nes, snes, gba, psx...). Se vazio, usa a pasta '
                'padrão da plataforma.',
            display: () {
              final custom = s.getRomsPath();
              return custom ?? _defaultRoms;
            },
            onConfirm: (ctx) async {
              final path = await FilePicker.getDirectoryPath();
              if (path != null) {
                await s.setRomsPath(path);
              }
            },
          ),
          if (AndroidStorage.isNeeded)
            SettingsOption(
              label: 'Acesso aos arquivos (Android)',
              description: 'Permite ler a pasta pública /storage/emulated/0/'
                  'ROMs. No Android 11+ você precisa ativar "Permitir acesso a '
                  'todos os arquivos" na tela do sistema.',
              display: () => _androidAccess ? 'concedido' : 'pendente',
              onConfirm: (ctx) async {
                final granted = await AndroidStorage.request();
                if (mounted) setState(() => _androidAccess = granted);
              },
            ),
          SettingsOption(
            label: 'Ordenar jogos por',
            description: 'Como os jogos aparecem na lista de cada console.',
            cycleValues: const [
              ('name', 'Nome (A–Z)'),
              ('name_desc', 'Nome (Z–A)'),
              ('year', 'Ano'),
              ('genre', 'Gênero'),
            ],
            currentIndex: () => _cycleIndex(
              const ['name', 'name_desc', 'year', 'genre'],
              s.getGameSort(),
            ),
            onCycle: (idx) => s.setGameSort(
              const ['name', 'name_desc', 'year', 'genre'][idx],
            ),
          ),
          SettingsOption(
            label: 'Mostrar contagem de jogos',
            description: 'Exibe o número de jogos nos tiles dos consoles.',
            toggle: () => s.getShowGameCount(),
            onToggle: (v) => s.setShowGameCount(v),
          ),
        ],
      ),
      SettingsCategory(
        label: 'Internet',
        description: 'De onde o app baixa capas e informações dos jogos.',
        icon: Icons.cloud_download_outlined,
        options: [
          SettingsOption(
            label: 'Provedor de scraping',
            description: 'De onde o app baixa capas e informações. '
                '"Automático" usa os provedores em ordem até encontrar os '
                'dados; as demais forçam um provedor (com fallback de capas).',
            cycleValues: const [
              ('auto', 'Automático'),
              ('thegamesdb', 'TheGamesDB'),
              ('screenscraper', 'ScreenScraper'),
              ('arcadedb', 'ArcadeDB'),
              ('mobygames', 'MobyGames'),
              ('libretro', 'Libretro (só capas)'),
            ],
            currentIndex: () => _cycleIndex(
              const [
                'auto',
                'thegamesdb',
                'screenscraper',
                'arcadedb',
                'mobygames',
                'libretro',
              ],
              s.getScrapeProvider(),
            ),
            onCycle: (idx) => s.setScrapeProvider(
              const [
                'auto',
                'thegamesdb',
                'screenscraper',
                'arcadedb',
                'mobygames',
                'libretro',
              ][idx],
            ),
          ),
          SettingsOption(
            label: 'Sistemas para capas',
            description: 'Quais sistemas baixam capas durante o scraping. '
                'Nenhum marcado = todos.',
            display: () {
              final list = s
                  .getCoverSystems()
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (list.isEmpty) return 'todos';
              return '${list.length} sistema${list.length == 1 ? '' : 's'}';
            },
            onConfirm: (ctx) async {
              await Navigator.of(ctx).push(
                consoleRoute(const CoverSystemsView()),
              );
              if (mounted) setState(() {});
            },
          ),
          SettingsOption(
            label: 'Chave TheGamesDB (opcional)',
            description: 'Sem chave: apenas capas via libretro-thumbnails. '
                'Com chave: descrição, gênero, ano e avaliação também.',
            display: () {
              final key = s.getTheGamesDbKey();
              return (key == null || key.isEmpty)
                  ? 'não configurada'
                  : '••••${key.substring(key.length > 4 ? key.length - 4 : key.length)}';
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Chave TheGamesDB',
                initial: s.getTheGamesDbKey() ?? '',
                obscure: true,
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setTheGamesDbKey(value);
                if (mounted) setState(() {});
              }
            },
          ),
          SettingsOption(
            label: 'Usuário ScreenScraper (opcional)',
            description: 'Conta pública do ScreenScraper.fr, usada para '
                'identificar o app e aumentar o limite de requisições.',
            display: () {
              final user = s.getScreenScraperUser();
              return user.isEmpty ? 'não configurado' : user;
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Usuário ScreenScraper',
                initial: s.getScreenScraperUser(),
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setScreenScraperUser(value);
                if (mounted) setState(() {});
              }
            },
          ),
          SettingsOption(
            label: 'Chave ArcadeDB (opcional)',
            description: 'API de jogos de arcade (MAME/FBA). Sem chave, este '
                'provedor é ignorado.',
            display: () {
              final key = s.getArcadeDbKey();
              return key.isEmpty
                  ? 'não configurada'
                  : '••••${key.substring(key.length > 4 ? key.length - 4 : key.length)}';
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Chave ArcadeDB',
                initial: s.getArcadeDbKey(),
                obscure: true,
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setArcadeDbKey(value);
                if (mounted) setState(() {});
              }
            },
          ),
          SettingsOption(
            label: 'Chave MobyGames (opcional)',
            description: 'API de metadados MobyGames. Sem chave, este '
                'provedor é ignorado.',
            display: () {
              final key = s.getMobyGamesKey();
              return key.isEmpty
                  ? 'não configurada'
                  : '••••${key.substring(key.length > 4 ? key.length - 4 : key.length)}';
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Chave MobyGames',
                initial: s.getMobyGamesKey(),
                obscure: true,
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setMobyGamesKey(value);
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      SettingsCategory(
        label: 'Emulador',
        description: 'Detecção do RetroArch instalado e opções de inicialização.',
        icon: Icons.memory,
        options: [
          if (AppDirs.isAndroid || AppDirs.isIOS)
            SettingsOption(
              label: 'RetroArch detectado',
              description: 'O app procura o RetroArch instalado em qualquer '
                  'versão do Android/iOS automaticamente. Use A para '
                  'verificar novamente.',
              display: () => _retroArch ?? 'não instalado',
              onConfirm: (ctx) async {
                final detected = await _svc.launcher.findRetroArch();
                if (mounted) setState(() => _retroArch = detected);
              },
            )
          else
            SettingsOption(
              label: 'Caminho do RetroArch',
              description: 'Executável do RetroArch usado para iniciar os '
                  'jogos. Se vazio, é procurado automaticamente no PATH, '
                  'em pastas comuns de instalação e no Flatpak/snap.',
              display: () {
                final override = s.getRetroArchPath();
                if (override != null && override.isNotEmpty) return override;
                return _retroArch ?? 'não encontrado';
              },
              onConfirm: (ctx) async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['exe', 'sh', 'bin'],
                );
                final path = result?.files.single.path;
                if (path != null) {
                  await s.setRetroArchPath(path);
                  if (mounted) setState(() => _retroArch = path);
                }
              },
            ),
          SettingsOption(
            label: 'Argumentos extras do RetroArch',
            description: 'Parâmetros adicionais passados ao RetroArch antes do '
                'jogo (ex.: --fullscreen). Se vazio, nenhum é adicionado.',
            display: () {
              final args = s.getRetroArchArgs();
              return (args == null || args.isEmpty)
                  ? 'nenhum'
                  : args;
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Argumentos extras',
                initial: s.getRetroArchArgs() ?? '',
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setRetroArchArgs(value);
                if (mounted) setState(() {});
              }
            },
          ),
          SettingsOption(
            label: 'Mapear botões',
            description: 'Redefina os botões do controle para ações do frontend. '
                'Pressione para atribuir.',
            display: () {
              final hasMap = s.getButtonMap().trim().isNotEmpty;
              return hasMap ? 'Personalizado' : 'Padrão';
            },
            onConfirm: (ctx) async {
              Navigator.of(ctx).push(
                consoleRoute(const ButtonMapView()),
              );
            },
          ),
        ],
      ),
      SettingsCategory(
        label: 'Aparência',
        description: 'Tema e elementos visuais da interface.',
        icon: Icons.palette_outlined,
        options: [
          SettingsOption(
            label: 'Tema escuro',
            description: 'Usa o tema escuro "console". Desligue para o tema '
                'claro.',
            toggle: () => s.getDarkMode(),
            onToggle: (v) {
              s.setDarkMode(v);
              _svc.darkMode.value = v;
            },
          ),
          SettingsOption(
            label: 'Mostrar dicas',
            description: 'Exibe a barra de atalhos (dicas) no rodapé das telas.',
            toggle: () => s.getShowHints(),
            onToggle: (v) => s.setShowHints(v),
          ),
          SettingsOption(
            label: 'Mostrar avaliações',
            description: 'Exibe as estrelas de avaliação (rating) na lista e '
                'nos detalhes dos jogos.',
            toggle: () => s.getShowRatings(),
            onToggle: (v) => s.setShowRatings(v),
          ),
        ],
      ),
      SettingsCategory(
        label: 'Sistema',
        description: 'Idioma e preferências globais do aplicativo.',
        icon: Icons.language,
        options: [
          SettingsOption(
            label: 'Idioma da interface',
            description: 'Idioma usado pelo teclado virtual e pela interface. '
                'Define também o layout de letras (acentos) do teclado.',
            cycleValues: [
              for (final l in appLanguages) (l.id, l.label),
            ],
            currentIndex: () => _cycleIndex(
              [for (final l in appLanguages) l.id],
              s.getLanguage(),
            ),
            onCycle: (idx) => s.setLanguage(appLanguages[idx].id),
          ),
        ],
      ),
      SettingsCategory(
        label: 'RetroAchievements',
        description: 'Login e integração com o serviço de conquistas '
            'RetroAchievements (via RetroArch).',
        icon: Icons.emoji_events_outlined,
        options: [
          SettingsOption(
            label: 'Habilitar conquistas',
            description: 'Quando ligado, o app passa suas credenciais ao '
                'RetroArch ao iniciar cada jogo (--appendconfig).',
            toggle: () => s.getRaEnabled(),
            onToggle: (v) => s.setRaEnabled(v),
          ),
          SettingsOption(
            label: 'Usuário',
            description: 'Seu nome de usuário em retroachievements.org.',
            display: () {
              final user = s.getRaUsername();
              return user.isEmpty ? 'não configurado' : user;
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Usuário RetroAchievements',
                initial: s.getRaUsername(),
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setRaUsername(value);
                if (mounted) setState(() {});
              }
            },
          ),
          SettingsOption(
            label: 'Senha',
            description: 'Senha da sua conta. Fica salva apenas no dispositivo '
                'e é passada ao RetroArch.',
            display: () {
              final pass = s.getRaPassword();
              return pass.isEmpty
                  ? 'não configurada'
                  : '••••••••';
            },
            onConfirm: (ctx) async {
              final value = await showVirtualKeyboardDialog(
                ctx,
                title: 'Senha RetroAchievements',
                initial: s.getRaPassword(),
                obscure: true,
                language: s.getLanguage(),
              );
              if (value != null) {
                await s.setRaPassword(value);
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      SettingsCategory(
        label: 'Tela',
        description: 'Como o app ocupa a tela do dispositivo.',
        icon: Icons.aspect_ratio,
        options: [
          SettingsOption(
            label: 'Tela cheia (imersiva)',
            description: 'Oculta as barras do sistema em dispositivos móveis '
                'para uma experiência de console.',
            toggle: () => s.getFullscreen(),
            onToggle: (v) {
              s.setFullscreen(v);
              ScreenMode.setFullscreen(v);
            },
          ),
          if (AppDirs.isAndroid || AppDirs.isIOS)
            SettingsOption(
              label: 'Travar paisagem',
              description: 'Mantém a interface sempre na horizontal.',
              toggle: () => s.getLandscapeLock(),
              onToggle: (v) {
                s.setLandscapeLock(v);
                if (v) {
                  ScreenMode.lockLandscape();
                } else {
                  // Sem preferencia forçada: acompanha o sensor.
                  SystemChrome.setPreferredOrientations([]);
                }
              },
            ),
        ],
      ),
      SettingsCategory(
        label: 'Controles',
        description: 'Comportamento do direcional e da navegação.',
        icon: Icons.sports_esports_outlined,
        options: [
          SettingsOption(
            label: 'Repetição da navegação',
            description: 'Tempo entre as repetições ao segurar o direcional. '
                'Valores menores repetem mais rápido.',
            cycleValues: const [
              (150, '150 ms'),
              (300, '300 ms'),
              (450, '450 ms'),
              (600, '600 ms'),
            ],
            currentIndex: () => _cycleIndex(
              const [150, 300, 450, 600],
              s.getGamepadRepeatMs(),
            ),
            onCycle: (idx) {
              final ms = const [150, 300, 450, 600][idx];
              s.setGamepadRepeatMs(ms);
              _svc.gamepad.setRepeatInterval(Duration(milliseconds: ms));
            },
          ),
          SettingsOption(
            label: 'Esquema de botões',
            description: 'Padrão usa A=confirmar e B=voltar (Xbox/Sony). '
                '"Nintendo" troca os dois, como no RetroArch.',
            cycleValues: const [
              ('standard', 'Padrão (A/B)'),
              ('nintendo', 'Nintendo (B/A)'),
            ],
            currentIndex: () => _cycleIndex(
              const ['standard', 'nintendo'],
              s.getButtonScheme(),
            ),
            onCycle: (idx) {
              final scheme = const ['standard', 'nintendo'][idx];
              s.setButtonScheme(scheme);
              _svc.gamepad.setButtonScheme(scheme);
            },
          ),
        ],
      ),
    ];
  }

  int _cycleIndex<T>(List<T> values, T current) {
    final i = values.indexOf(current);
    return i < 0 ? 0 : i;
  }

  Color _categoryColor(int index) {
    const keys = ['nes', 'snes', 'gba', 'psx'];
    return AppTheme.systemColor(keys[index % keys.length]);
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.left:
        _move(-1);
      case GamepadAction.right:
        _move(1);
      case GamepadAction.confirm:
        _openSelected();
      case GamepadAction.up:
      case GamepadAction.down:
        break;
      case GamepadAction.start:
      case GamepadAction.home:
        Navigator.of(context).pop();
      case GamepadAction.pageUp:
        _move(-1);
      case GamepadAction.pageDown:
        _move(1);
      case GamepadAction.back:
        Navigator.of(context).pop();
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    if (_categories.isEmpty) return;
    final next = (_selected + delta).clamp(0, _categories.length - 1);
    if (next == _selected) return;
    setState(() => _selected = next);
  }

  void _openSelected() {
    if (_categories.isEmpty) return;
    Navigator.of(context).push(
      consoleRoute(
        SettingsCategoryView(
          category: _categories[_selected],
          accent: _categoryColor(_selected),
        ),
      ),
    );
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onLeft = () {
      _move(-1);
    }
    ..onRight = () {
      _move(1);
    }
    ..onConfirm = _openSelected
    ..onBack = () {
      Navigator.of(context).pop();
    }
    ..onStart = () {
      Navigator.of(context).pop();
    }
    ..onHome = () {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    ..onPageUp = () {
      _move(-1);
    }
    ..onPageDown = () {
      _move(1);
    };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final carouselH = isLandscape ? 260.0 : 200.0;
    final tileW = (carouselH * 0.95).clamp(0.0, 250.0);
    final accent = _categoryColor(_selected);

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(color: accent, darken: isLandscape ? 0.45 : 0.65),
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _InfoPanel(category: _categories[_selected])),
                  SizedBox(
                    height: carouselH,
                    child: CoverCarousel(
                      itemCount: _categories.length,
                      tileWidth: tileW,
                      tileHeight: carouselH,
                      selected: _selected,
                      onSelect: (i) {
                        if (i != _selected) _move(i - _selected);
                      },
                      itemBuilder: (context, index, selected) {
                        final cat = _categories[index];
                        final color = _categoryColor(index);
                        return _CategoryCover(
                          label: cat.label,
                          icon: cat.icon,
                          color: color,
                          selected: selected,
                          onTap: () {
                            if (selected) {
                              _openSelected();
                            } else {
                              _move(index - _selected);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  _hints(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          const Text(
            'Configurações',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            'RetroFront 0.1.0',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _hints() {
    if (!_svc.settings.getShowHints()) return const SizedBox.shrink();
    final gp = _svc.gamepad;
    return HintBar(
      hints: [
        Hint('categoria', button: gp.currentButtonFor(GamepadAction.right)),
        Hint('abrir', button: gp.currentButtonFor(GamepadAction.confirm)),
        Hint('voltar', button: gp.currentButtonFor(GamepadAction.back)),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final SettingsCategory category;

  const _InfoPanel({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            category.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            category.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aperte para abrir as opções desta categoria',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Tile de categoria para o carrossel de configurações.
class _CategoryCover extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCover({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return AnimatedScale(
      scale: selected ? 1.0 : 0.84,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: selected ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 220),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, AppTheme.darken(color, 0.45)],
              ),
              border: Border.all(
                color: selected ? Colors.white : Colors.white12,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 24),
                    const Spacer(),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

