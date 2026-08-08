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

/// Configuracoes no estilo EmulationStation: lista de opcoes navegavel por
/// gamepad/teclado com o valor atualizado a esquerda/direita e confirmacao
/// para acoes. Em paisagem mostra a descricao da opcao selecionada.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  int _selected = 0;
  String _defaultRoms = '';
  bool _androidAccess = true;
  bool _loading = true;
  StreamSubscription<GamepadAction>? _gamepadSub;

  List<_Option> _options = [];

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
      _options = _buildOptions();
      _rowKeys.addAll(List.generate(_options.length, (_) => GlobalKey()));
      _loading = false;
    });
  }

  List<_Option> _buildOptions() {
    final s = _svc.settings;
    return [
      _Option(label: 'Biblioteca', isHeader: true),
      _Option(
        label: 'Pasta de ROMs',
        description: 'Pasta principal da biblioteca. Crie uma subpasta por '
            'console (nes, snes, gba, psx...). Se vazio, usa a pasta padrão '
            'da plataforma.',
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
          description: 'Permite ler a pasta pública /storage/emulated/0/ROMs. '
              'No Android 11+ você precisa ativar "Permitir acesso a todos os '
              'arquivos" na tela do sistema.',
          display: () => _androidAccess ? 'concedido' : 'pendente',
          onConfirm: () async {
            final granted = await AndroidStorage.request();
            if (!mounted) return;
            setState(() => _androidAccess = granted);
          },
        ),
      _Option(label: 'Internet / Scraping', isHeader: true),
      _Option(
        label: 'Provedor de scraping',
        description: 'De onde o app baixa capas e informações. "Automático" '
            'usa TheGamesDB (com chave) e libretro-thumbnails; as demais '
            'forçam um provedor.',
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
      if (!AppDirs.isAndroid && !AppDirs.isIOS) ...[
        _Option(label: 'Emulador', isHeader: true),
        _Option(
          label: 'Caminho do RetroArch',
          description: 'Executável do RetroArch usado para iniciar os jogos. '
              'Se vazio, é procurado automaticamente no PATH.',
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
      _Option(label: 'Aparência', isHeader: true),
      _Option(
        label: 'Tema escuro',
        description: 'Usa o tema escuro "console". Desligue para o tema claro.',
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
      _Option(label: 'Tela', isHeader: true),
      _Option(
        label: 'Tela cheia (imersiva)',
        description: 'Oculta as barras do sistema em dispositivos móveis para '
            'uma experiência de console.',
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
      _Option(label: 'Controles', isHeader: true),
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
    ];
  }

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
      case GamepadAction.pageDown:
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    if (_options.isEmpty) return;
    var next = _selected;
    // Anda na direcao pedida pulando cabecalhos de secao.
    for (var steps = 0; steps < _options.length; steps++) {
      next += delta;
      if (next < 0 || next >= _options.length) return;
      if (_options[next].isHeader) continue;
      break;
    }
    _select(next);
  }

  void _select(int index) {
    setState(() => _selected = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[index].currentContext;
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
    final opt = _options[_selected];
    if (opt.isHeader) return;
    final count = opt.count;
    if (count == 0) return;
    final next = (opt.index + dir) % count;
    opt.onCycle?.call(next);
    setState(() {});
  }

  Future<void> _activate() async {
    final opt = _options[_selected];
    if (opt.isHeader) return;
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
    final current = _options[_selected];

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CoverBackdrop(color: AppTheme.surface),
            SafeArea(
              child: Column(
                children: [
                  _topBar(onBack: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: isWide
                              ? MediaQuery.of(context).size.width * 0.52
                              : double.infinity,
                          child: _optionsList(),
                        ),
                        if (isWide)
                          Expanded(child: _detailPanel(current)),
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

  Widget _optionsList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final opt = _options[index];
        final isHeader = opt.isHeader;
        final selected = index == _selected;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: KeyedSubtree(
            key: _rowKeys[index],
            child: isHeader
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                    child: Text(
                      opt.label.toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                : InkWell(
                    onTap: () => _select(index),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.systemColor(
                                const ['nes', 'snes', 'gba'][index % 3],
                              ).withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.accent.withValues(alpha: 0.7)
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
    );
  }

  Widget _detailPanel(_Option opt) {
    if (opt.isHeader) {
      return Center(
        child: Text(
          'Selecione uma opção.',
          style: TextStyle(color: AppTheme.textFaint, fontSize: 14),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opt.label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            opt.description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'Valor atual',
                  style: TextStyle(color: AppTheme.textFaint, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  opt.valueText,
                  style: const TextStyle(
                    color: AppTheme.accentAlt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              if (opt.onConfirm != null) {
                await opt.onConfirm!();
              } else {
                _activate();
              }
            },
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
        Hint('▲▼  escolher opção'),
        Hint('◄ ►  mudar valor'),
        Hint('A  ativar'),
        Hint('B  voltar'),
      ],
    );
  }
}

/// Opcao da lista de configuracoes. Se [isHeader] for true, e apenas um
/// rotulo de secao (nao navegavel); caso contrario, pode ter ciclo de valores,
/// liga/desliga, confirmacao ou tudo isso.
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
  final bool isHeader;

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
    this.isHeader = false,
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
