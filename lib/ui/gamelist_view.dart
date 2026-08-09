import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/game_entry.dart';
import '../models/system.dart';
import 'game_detail_view.dart';
import 'system_options_view.dart';
import 'theme.dart';
import 'widgets/console_route.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/cover_image.dart';
import 'widgets/game_list_row.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/option_menu_sheet.dart';
import 'widgets/scrape_progress_dialog.dart';
import 'widgets/star_rating.dart';
import 'widgets/virtual_keyboard.dart';

/// Lista de jogos de um sistema estilo console: menu a esquerda com o jogo
/// selecionado em destaque (capa grande + metadados) a direita/abaixo.
/// Navegavel por gamepad/teclado e por toque.
class GamelistView extends StatefulWidget {
  final SystemEntry system;
  final String? subPath;
  final String? folderTitle;

  const GamelistView({
    super.key,
    required this.system,
    this.subPath,
    this.folderTitle,
  });

  @override
  State<GamelistView> createState() => _GamelistViewState();
}

class _GamelistViewState extends State<GamelistView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  final Map<int, GlobalKey> _rowKeys = {};

  List<GameEntry> _games = [];
  List<GameEntry> _filtered = [];
  int _selected = 0;
  bool _loading = true;
  bool _searching = false;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  static const int _pageStep = 8;

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
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final games = await _svc.scanner.listGames(
        widget.system,
        subPath: widget.subPath,
      );
      if (!mounted) return;
      setState(() {
        _games = games;
        _selected = 0;
        _loading = false;
        _applyFilter();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.of(_games);
    } else {
      _filtered = _games
          .where((g) =>
              g.name.toLowerCase().contains(q) ||
              g.displayName.toLowerCase().contains(q))
          .toList();
    }
    _sort();
    if (_selected >= _filtered.length && _filtered.isNotEmpty) {
      _selected = 0;
    }
  }

  /// Aplica a ordenacao configurada pelo usuario ('name', 'name_desc', 'year',
  /// 'genre').
  void _sort() {
    int byName(GameEntry a, GameEntry b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    switch (_svc.settings.getGameSort()) {
      case 'name_desc':
        _filtered.sort((a, b) => byName(b, a));
      case 'year':
        _filtered.sort((a, b) {
          final ya = _yearOf(a);
          final yb = _yearOf(b);
          if (ya == null && yb == null) return byName(a, b);
          if (ya == null) return 1;
          if (yb == null) return -1;
          final c = yb.compareTo(ya);
          return c != 0 ? c : byName(a, b);
        });
      case 'genre':
        _filtered.sort((a, b) {
          final ga = a.metadata?.genre?.toLowerCase() ?? '';
          final gb = b.metadata?.genre?.toLowerCase() ?? '';
          if (ga == gb) return byName(a, b);
          if (ga.isEmpty) return 1;
          if (gb.isEmpty) return -1;
          return ga.compareTo(gb);
        });
      default:
        _filtered.sort(byName);
    }
  }

  int? _yearOf(GameEntry g) {
    final date = g.metadata?.releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    // Durante a busca, as direcoes ficam para o teclado virtual; select/start
    // encerram a busca e B (backspace) apaga caracteres no teclado.
    if (_searching) {
      if (action == GamepadAction.select ||
          action == GamepadAction.home ||
          action == GamepadAction.start) {
        _doneSearch();
      }
      return;
    }

    switch (action) {
      case GamepadAction.up:
        _move(-1);
      case GamepadAction.down:
        _move(1);
      case GamepadAction.pageUp:
        _move(-_pageStep);
      case GamepadAction.pageDown:
        _move(_pageStep);
      case GamepadAction.confirm:
        _openSelected();
      case GamepadAction.back:
        _goBack();
      case GamepadAction.start:
        _openMenu();
      case GamepadAction.home:
        Navigator.of(context).popUntil((r) => r.isFirst);
      case GamepadAction.left:
      case GamepadAction.right:
      case GamepadAction.select:
        break;
    }
  }

  void _exitSearch() {
    setState(() {
      _searching = false;
      _search.clear();
      _applyFilter();
    });
  }

  /// Sai da busca mantendo o filtro digitado.
  void _doneSearch() {
    setState(() => _searching = false);
    _scrollToSelected();
  }

  void _move(int delta) {
    if (_filtered.isEmpty) return;
    final index = (_selected + delta).clamp(0, _filtered.length - 1);
    _select(index);
  }

  void _select(int index) {
    setState(() => _selected = index);
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _rowKeys[_selected];
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
    if (_filtered.isEmpty) return;
    final entry = _filtered[_selected];
    if (entry.isFolder) {
      Navigator.of(context).push(
        consoleRoute(
          GamelistView(
            system: widget.system,
            subPath: entry.path,
            folderTitle: entry.name,
          ),
        ),
      );
      return;
    }
    _play(entry);
  }

  Future<void> _play(GameEntry game) async {
    final result =
        await _svc.launcher.launch(widget.system.definition, game);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Iniciando ${game.displayName}...'
              : (result.error ?? 'Erro ao iniciar'),
        ),
      ),
    );
  }

  void _openDetails() {
    if (_filtered.isEmpty) return;
    final entry = _filtered[_selected];
    if (entry.isFolder) return;
    Navigator.of(context).push(
      consoleRoute(
        GameDetailView(system: widget.system, game: entry),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _openMenu() {
    OptionMenuSheet.show(
      context,
      OptionMenuSheet(
        title: 'Opções',
        options: [
          MenuOption(
            label: 'Baixar capas e informações',
            subtitle: 'Scraping em rede para todos os jogos',
            icon: Icons.cloud_download,
            onTap: _scrapeAll,
          ),
          MenuOption(
            label: 'Buscar',
            icon: Icons.search,
            onTap: () => setState(() => _searching = true),
          ),
          MenuOption(
            label: 'Atualizar lista',
            icon: Icons.refresh,
            onTap: _load,
          ),
          MenuOption(
            label: 'Opções do sistema',
            subtitle: 'Core e argumentos extras deste console',
            icon: Icons.tune,
            onTap: () {
              Navigator.of(context).push(
                consoleRoute(
                  SystemOptionsView(system: widget.system.definition),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scrapeAll() async {
    final result = await showDialog<({int total, int success, int failed})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScrapeProgressDialog(
        runner: (onProgress) =>
            _svc.scrape.scrapSystem(widget.system, onProgress: onProgress),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scraping concluído: ${result.success}/${result.total} jogos '
            'atualizados'
            '${result.failed > 0 ? ', ${result.failed} falhas' : ''}.',
          ),
        ),
      );
      _load();
    }
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _move(-1);
    }
    ..onDown = () {
      _move(1);
    }
    ..onPageUp = () {
      _move(-_pageStep);
    }
    ..onPageDown = () {
      _move(_pageStep);
    }
    ..onConfirm = _openSelected
    ..onBack = _goBack
    ..onStart = _openMenu
    ..onHome = () {
      Navigator.of(context).popUntil((r) => r.isFirst);
    };

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final title = widget.folderTitle ?? widget.system.fullName;
    final selected = _filtered.isNotEmpty ? _filtered[_selected] : null;

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        enabled: !_searching,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(
              coverPath: selected?.metadata?.coverPath,
              color: AppTheme.systemColor(widget.system.name),
            ),
            SafeArea(
              child: Column(
                children: [
                  _Header(
                    title: title,
                    searching: _searching,
                    searchController: _search,
                    onBack: _goBack,
                    onToggleSearch: () {
                      if (_searching) {
                        _exitSearch();
                      } else {
                        setState(() => _searching = true);
                      }
                    },
                    onMenu: _openMenu,
                  ),
                  if (_searching)
                    VirtualKeyboard(
                      controller: _search,
                      language: _svc.settings.getLanguage(),
                      onChanged: (_) {
                        setState(() {
                          _applyFilter();
                          _scrollToSelected();
                        });
                      },
                      onDone: _doneSearch,
                      onCancel: _doneSearch,
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accent,
                            ),
                          )
                        : _filtered.isEmpty
                            ? _EmptyState(searching: _searching)
                            : isLandscape
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width *
                                            0.42,
                                        child: _buildList(),
                                      ),
                                      Expanded(
                                        child: _DetailPanel(
                                          entry: selected!,
                                          onPlay: () => _openSelected(),
                                          onOpenFolder: _openSelected,
                                          onDetails: _openDetails,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Expanded(child: _buildList()),
                                      SizedBox(
                                        height: 240,
                                        child: _DetailPanel(
                                          entry: selected!,
                                          onPlay: () => _openSelected(),
                                          onOpenFolder: _openSelected,
                                          onDetails: _openDetails,
                                        ),
                                      ),
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

  Widget _hints() {
    if (!_svc.settings.getShowHints()) return const SizedBox.shrink();
    final gp = _svc.gamepad;
    return HintBar(
      hints: [
        Hint('navegar', button: gp.currentButtonFor(GamepadAction.up)),
        Hint('jogar', button: gp.currentButtonFor(GamepadAction.confirm)),
        Hint('voltar', button: gp.currentButtonFor(GamepadAction.back)),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final key = GlobalKey();
        _rowKeys[index] = key;
        final game = _filtered[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: KeyedSubtree(
            key: key,
            child: GameListRow(
              game: game,
              selected: index == _selected,
              onTap: () {
                _select(index);
                if (game.isFolder) {
                  _openSelected();
                } else {
                  _play(game);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final bool searching;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final VoidCallback onMenu;

  const _Header({
    required this.title,
    required this.searching,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Buscar',
                onPressed: onToggleSearch,
                icon: Icon(
                  searching ? Icons.close : Icons.search,
                  color: Colors.white70,
                ),
              ),
              IconButton(
                tooltip: 'Opções',
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert),
                color: Colors.white70,
              ),
            ],
          ),
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      searchController.text.isEmpty
                          ? 'Digite para buscar...'
                          : searchController.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: searchController.text.isEmpty
                            ? Colors.white38
                            : Colors.white,
                        fontSize: 16,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final GameEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onOpenFolder;
  final VoidCallback onDetails;

  const _DetailPanel({
    required this.entry,
    required this.onPlay,
    required this.onOpenFolder,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: entry.isFolder ? _folderPanel() : _gamePanel(context),
    );
  }

  Widget _folderPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder, color: Colors.white54, size: 56),
          const SizedBox(height: 10),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Abrir pasta'),
          ),
        ],
      ),
    );
  }

  Widget _gamePanel(BuildContext context) {
    final meta = entry.metadata;
    final year = meta?.releaseDate != null && meta!.releaseDate!.length >= 4
        ? meta.releaseDate!.substring(0, 4)
        : null;
    final genre = meta?.genre;
    final players = meta?.players;
    final showRatings = AppScope.of(context).settings.getShowRatings();
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    final cover = Center(
      child: SizedBox(
        width: isLandscape ? 180 : 120,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: CoverImage(
            path: meta?.coverPath,
            width: isLandscape ? 180 : 120,
            borderRadius: BorderRadius.circular(14),
            fallbackLabel: entry.displayName,
          ),
        ),
      ),
    );

    final info = Column(
      mainAxisAlignment: isLandscape
          ? MainAxisAlignment.center
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isLandscape ? 24 : 16,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (year != null || genre != null || players != null) ...[
          const SizedBox(height: 8),
          Text(
            [genre, year, players].whereType<String>().join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
        if (showRatings && meta?.rating != null) ...[
          const SizedBox(height: 6),
          StarRating(rating: meta!.rating!, size: 16),
        ],
        if (meta?.description != null) ...[
          const SizedBox(height: 10),
          Text(
            meta!.description!,
            maxLines: isLandscape ? 4 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jogar'),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Mais informações',
              onPressed: onDetails,
              icon: const Icon(Icons.info_outline),
              color: Colors.white70,
            ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: isLandscape
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                cover,
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: info)),
              ],
            )
          : SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  cover,
                  const SizedBox(width: 14),
                  Expanded(child: info),
                ],
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;

  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.inbox_outlined,
              size: 56,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'Nada encontrado' : 'Nenhum jogo nesta pasta',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!searching) ...[
              const SizedBox(height: 8),
              const Text(
                'Coloque os arquivos de ROM nesta pasta e toque em Atualizar '
                '(menu ●●●), ou use "Baixar capas e informações".',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
