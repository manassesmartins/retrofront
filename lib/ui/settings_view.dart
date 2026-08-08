import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/android_storage.dart';
import '../core/app_dirs.dart';
import '../core/app_scope.dart';
import '../core/screen_mode.dart';
import '../gamepad/gamepad_manager.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';

/// Configuracoes no estilo EmulationStation, categorizadas: trilho lateral de
/// categorias, lista de opcoes da categoria ativa e painel de descricao.
/// Navegacao por gamepad/teclado:
///   - cima/baixo: opcao   - esquerda/direita: valor
///   - LB/RB (PageUp/Down): categoria   - A: ativar   - B: voltar
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  List<GlobalKey> _rowKeys = [];

  int _category = 0;
  int _selected = 0;
  String _defaultRoms = '';
  bool _androidAccess = true;
  bool _loading = true;
  StreamSubscription<GamepadAction>? _gamepadSub;

  List<_Category> _categories = [];

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
    final defaultRoms = (await AppDirs.romsRoot()).path;
    var androidAccess = true;
    if (AndroidStorage.isNeeded) androidAccess = await AndroidStorage.hasAccess();
    if (!mounted) return;
    setState(() {
      _defaultRoms = defaultRoms;
      _androidAccess = androidAccess;
      _categories = _buildCategories();
      _rowKeys = List.generate(_currentOptions().length, (_) => GlobalKey());
      _loading = false;
    });
  }

  List<_Category> _buildCategories() {
    final s = _svc.settings;
    return [
      _Category(
        label: 'Biblioteca',
        description: 'Onde ficam os jogos e como o app acessa o armazenamento.',
        icon: Icons.video_library_outlined,
        options: [
          _Option(
            label: 'Pasta de ROMs',
            description: 'Pasta principal da biblioteca. Crie uma subpasta por '
                'console (nes, snes, gba, psx...). Se vazio, usa a pasta '
                'padrão da plataforma.',
            display: () {
              final custom = s.getRomsPath();
              return custom ?? _defaultRoms;
            },
            onConfirm: () async {
              final path = await FilePicker.getDirectoryPath();
              if (path != null) {
                await s.setRomsPath(path);
                setState(() {});
              }
            },
          ),
          if (AndroidStorage.isNeeded)
            _Option(
              label: 'Acesso aos arquivos (Android)',
              description: 'Permite ler a pasta pública /storage/emulated/0/'
                  'ROMs. No Android 11+ você precisa ativar "Permitir acesso a '
                  'todos os arquivos" na tela do sistema.',
              display: () => _androidAccess ? 'concedido' : 'pendente',
              onConfirm: () async {
                final granted = await AndroidStorage.request();
                if (!mounted) return;
                setState(() => _androidAccess = granted);
              },
            ),
        ],
      ),
      _Category(
        label: 'Internet',
        description: 'De onde o app baixa capas e informações dos jogos.',
        icon: Icons.cloud_download_outlined,
        options: [
          _Option(
            label: 'Provedor de scraping',
            description: 'De onde o app baixa capas e informações. '
                '"Automático" usa TheGamesDB (com chave) e '
                'libretro-thumbnails; as demais forçam um provedor.',
            cycleValues: const [
              ('auto', 'Automático'),
              ('thegamesdb', 'TheGamesDB'),
              ('libretro', 'Libretro (só capas)'),
            ],
            currentIndex: () => _cycleIndex(
              const ['auto', 'thegamesdb', 'libretro'],
              s.getScrapeProvider(),
            ),
            onCycle: (idx) => s.setScrapeProvider(
              const ['auto', 'thegamesdb', 'libretro'][idx],
            ),
          ),
          _Option(
            label: 'Chave TheGamesDB (opcional)',
            description: 'Sem chave: apenas capas via libretro-thumbnails. '
                'Com chave: descrição, gênero, ano e avaliação também.',
            display: () {
              final key = s.getTheGamesDbKey();
              return (key == null || key.isEmpty)
                  ? 'não configurada'
                  : '••••${key.substring(key.length > 4 ? key.length - 4 : key.length)}';
            },
            onConfirm: () async {
              final controller =
                  TextEditingController(text: s.getTheGamesDbKey() ?? '');
              final value = await showDialog<String>(
                context: context,
                builder: (ctx) => _TextPromptDialog(
                  title: 'Chave TheGamesDB',
                  controller: controller,
                  obscure: true,
                  onSave: () => s.setTheGamesDbKey(controller.text),
                ),
              );
              if (value != null) setState(() {});
            },
          ),
        ],
      ),
      if (!AppDirs.isAndroid && !AppDirs.isIOS)
        _Category(
          label: 'Emulador',
          description: 'Como os jogos são iniciados no desktop.',
          icon: Icons.memory,
          options: [
            _Option(
              label: 'Caminho do RetroArch',
              description: 'Executável do RetroArch usado para iniciar os '
                  'jogos. Se vazio, é procurado automaticamente no PATH.',
              display: () => s.getRetroArchPath() ?? 'auto-detectado',
              onConfirm: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['exe', 'sh', 'bin'],
                );
                final path = result?.files.single.path;
                if (path != null) {
                  await s.setRetroArchPath(path);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      _Category(
        label: 'Aparência',
        description: 'Tema e elementos visuais da interface.',
        icon: Icons.palette_outlined,
        options: [
          _Option(
            label: 'Tema escuro',
            description: 'Usa o tema escuro "console". Desligue para o tema '
                'claro.',
            toggle: () => s.getDarkMode(),
            onToggle: (v) {
              s.setDarkMode(v);
              _svc.darkMode.value = v;
            },
          ),
          _Option(
            label: 'Mostrar dicas',
            description: 'Exibe a barra de atalhos (dicas) no rodapé das telas.',
            toggle: () => s.getShowHints(),
            onToggle: (v) => s.setShowHints(v),
          ),
        ],
      ),
      _Category(
        label: 'Tela',
        description: 'Como o app ocupa a tela do dispositivo.',
        icon: Icons.aspect_ratio,
        options: [
          _Option(
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
            _Option(
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
      _Category(
        label: 'Controles',
        description: 'Comportamento do direcional e da navegação.',
        icon: Icons.sports_esports_outlined,
        options: [
          _Option(
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
        ],
      ),
    ];
  }

  List<_Option> _currentOptions() =>
      _categories.isEmpty ? const [] : _categories[_category].options;

  int _cycleIndex<T>(List<T> values, T current) {
    final i = values.indexOf(current);
    return i < 0 ? 0 : i;
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
      case GamepadAction.left:
        _adjust(-1);
      case GamepadAction.right:
        _adjust(1);
      case GamepadAction.confirm:
        _activate();
      case GamepadAction.back:
        Navigator.of(context).pop();
      case GamepadAction.start:
      case GamepadAction.home:
        Navigator.of(context).pop();
      case GamepadAction.pageUp:
        _switchCategory(-1);
      case GamepadAction.pageDown:
        _switchCategory(1);
      case GamepadAction.select:
        break;
    }
  }

  /// Anda na opcao; ao ultrapassar o fim, muda para a categoria vizinha.
  void _move(int delta) {
    final options = _currentOptions();
    if (options.isEmpty) return;
    var next = _selected + delta;
    if (next < 0 || next >= options.length) {
      final dir = next < 0 ? -1 : 1;
      _switchCategory(dir);
      return;
    }
    _select(next);
  }

  void _switchCategory(int delta) {
    if (_categories.isEmpty) return;
    final next = (_category + delta).clamp(0, _categories.length - 1);
    if (next == _category) return;
    setState(() {
      _category = next;
      _selected = _selected.clamp(0, _currentOptions().length - 1);
      _rowKeys = List.generate(_currentOptions().length, (_) => GlobalKey());
    });
    _scrollToSelected();
  }

  void _select(int index) {
    setState(() => _selected = index);
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selected >= _rowKeys.length) return;
      final ctx = _rowKeys[_selected].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _adjust(int dir) {
    final opt = _selectedOption();
    if (opt == null) return;
    final count = opt.count;
    if (count == 0) return;
    final next = (opt.index + dir) % count;
    opt.onCycle?.call(next);
    setState(() {});
  }

  Future<void> _activate() async {
    final opt = _selectedOption();
    if (opt == null) return;
    if (opt.onConfirm != null) {
      await opt.onConfirm!();
      return;
    }
    if (opt.count > 0) {
      final next = (opt.index + 1) % opt.count;
      opt.onCycle?.call(next);
      setState(() {});
      return;
    }
    if (opt.onToggle != null) {
      opt.onToggle!(!opt.toggleValue);
      setState(() {});
    }
  }

  _Option? _selectedOption() {
    final options = _currentOptions();
    if (options.isEmpty) return null;
    return options[_selected.clamp(0, options.length - 1)];
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _move(-1);
    }
    ..onDown = () {
      _move(1);
    }
    ..onLeft = () {
      _adjust(-1);
    }
    ..onRight = () {
      _adjust(1);
    }
    ..onConfirm = _activate
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
      _switchCategory(-1);
    }
    ..onPageDown = () {
      _switchCategory(1);
    };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    final isWide =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final hasRail = isWide && _categories.length > 1;
    final accent = _categoryAccent();

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(
              color: accent,
              darken: isWide ? 0.35 : 0.6,
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasRail)
                          _categoryRail(accent),
                        SizedBox(
                          width: isWide
                              ? MediaQuery.of(context).size.width * (hasRail ? 0.42 : 0.52)
                              : double.infinity,
                          child: _optionsList(accent),
                        ),
                        if (isWide)
                          Expanded(child: _detailPanel(accent)),
                      ],
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

  Color _categoryAccent() {
    if (_categories.isEmpty) return AppTheme.accent;
    const keys = ['nes', 'snes', 'gba', 'psx'];
    return AppTheme.systemColor(keys[_category % keys.length]);
  }

  Widget _topBar({required VoidCallback onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: onBack,
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

  Widget _categoryRail(Color accent) {
    return Container(
      width: 176,
      margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final active = index == _category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: InkWell(
              onTap: () {
                if (index != _category) _switchCategory(index - _category);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.85),
                            AppTheme.accentAlt.withValues(alpha: 0.75),
                          ],
                        )
                      : null,
                  color: active ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat.icon,
                      size: 20,
                      color: active ? Colors.white : Colors.white54,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (active)
                      const Icon(Icons.chevron_left,
                          size: 16, color: Colors.white70),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _optionsList(Color accent) {
    final cat = _categories[_category];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(cat.icon, size: 18, color: AppTheme.accentAlt),
              const SizedBox(width: 8),
              Text(
                cat.label.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: cat.options.length,
            itemBuilder: (context, index) {
              final opt = cat.options[index];
              final selected = index == _selected;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: KeyedSubtree(
                  key: _rowKeys[index],
                  child: InkWell(
                    onTap: () => _select(index),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? accent.withValues(alpha: 0.75)
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (opt.valueText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                opt.valueText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: selected
                                ? AppTheme.accentAlt
                                : Colors.white24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _detailPanel(Color accent) {
    final cat = _categories[_category];
    final opt = _selectedOption();
    if (opt == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.85),
                  AppTheme.accentAlt.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            opt.label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            opt.description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Text(
                  'Valor atual',
                  style: TextStyle(color: AppTheme.textFaint, fontSize: 13),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    opt.valueText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.accentAlt,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _activate(),
            icon: const Icon(Icons.touch_app),
            label: const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  Widget _hints() {
    if (!_svc.settings.getShowHints()) return const SizedBox.shrink();
    return const HintBar(
      hints: [
        Hint('▲▼  opção'),
        Hint('◄ ►  valor'),
        Hint('LB/RB  categoria'),
        Hint('A  ativar'),
        Hint('B  voltar'),
      ],
    );
  }
}

/// Categoria de configuracoes (trilho lateral).
class _Category {
  final String label;
  final String description;
  final IconData icon;
  final List<_Option> options;

  const _Category({
    required this.label,
    required this.description,
    required this.icon,
    required this.options,
  });
}

/// Opcao de uma categoria: pode ter ciclo de valores, liga/desliga,
/// confirmacao ou tudo isso.
class _Option {
  final String label;
  final String description;
  final String Function() display;
  final List<(dynamic, String)>? cycleValues;
  final int Function()? currentIndex;
  final void Function(int)? onCycle;
  final bool Function()? toggle;
  final void Function(bool)? onToggle;
  final Future<void> Function()? onConfirm;

  const _Option({
    required this.label,
    this.description = '',
    this.display = _emptyText,
    this.cycleValues,
    this.currentIndex,
    this.onCycle,
    this.toggle,
    this.onToggle,
    this.onConfirm,
  });

  static String _emptyText() => '';

  int get count => cycleValues?.length ?? 0;
  int get index => currentIndex?.call() ?? 0;
  bool get toggleValue => toggle?.call() ?? false;
  String get valueText => display();
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final bool obscure;
  final Future<void> Function() onSave;

  const _TextPromptDialog({
    required this.title,
    required this.controller,
    required this.obscure,
    required this.onSave,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.obscure,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Valor',
          labelStyle: TextStyle(color: Colors.white54),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            widget.controller.text = _controller.text;
            await widget.onSave();
            if (context.mounted) Navigator.pop(context, 'ok');
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
