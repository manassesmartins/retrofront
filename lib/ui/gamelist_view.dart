import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/game_entry.dart';
import '../models/system.dart';
import 'game_detail_view.dart';
import 'widgets/game_tile.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/scrape_progress_dialog.dart';

/// Grade de jogos de um sistema, com capas, subpastas, busca e scraping.
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
  final Map<int, GlobalKey> _tileKeys = {};
  final TextEditingController _search = TextEditingController();

  List<GameEntry> _games = [];
  List<GameEntry> _filtered = [];
  int _selected = 0;
  bool _loading = true;
  bool _searching = false;
  int _columns = 1;
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
          .where((g) => g.name.toLowerCase().contains(q))
          .toList();
    }
    if (_selected >= _filtered.length && _filtered.isNotEmpty) {
      _selected = 0;
    }
  }

  void _onSearchChanged(String _) {
    setState(() {
      _applyFilter();
      _scrollToSelected();
    });
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
      case GamepadAction.back:
        _goBack();
      case GamepadAction.start:
        _openMenu();
      case GamepadAction.pageUp:
        _movePage(-1);
      case GamepadAction.pageDown:
        _movePage(1);
      case GamepadAction.home:
        Navigator.of(context).popUntil((r) => r.isFirst);
      case GamepadAction.select:
        break;
    }
  }

  void _moveGrid(int dx, int dy) {
    if (_filtered.isEmpty) return;
    final cols = _columns;
    final total = _filtered.length;
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
    index = index.clamp(0, total - 1);
    setState(() => _selected = index);
    _scrollToSelected();
  }

  void _movePage(int dir) {
    if (_filtered.isEmpty) return;
    final index = (_selected + dir * _columns).clamp(0, _filtered.length - 1);
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
    if (_filtered.isEmpty) return;
    final entry = _filtered[_selected];
    if (entry.isFolder) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamelistView(
            system: widget.system,
            subPath: entry.path,
            folderTitle: entry.name,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailView(
          system: widget.system,
          game: entry,
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171C26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Opções',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: Color(0xFF8B5CF6)),
                title: const Text('Baixar capas e informações',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Scraping em rede para todos os jogos',
                    style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(ctx);
                  _scrapeAll();
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Color(0xFF22D3EE)),
                title: const Text('Buscar',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _searching = true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white70),
                title: const Text('Atualizar lista',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _load();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
    ..onBack = _goBack
    ..onStart = _openMenu
    ..onPageUp = () {
      _movePage(-1);
    }
    ..onPageDown = () {
      _movePage(1);
    }
    ..onHome = () {
      Navigator.of(context).popUntil((r) => r.isFirst);
    };

  @override
  Widget build(BuildContext context) {
    final title = widget.folderTitle ?? widget.system.fullName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white70,
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => setState(() => _searching = !_searching),
            icon: const Icon(Icons.search),
            color: Colors.white70,
          ),
          IconButton(
            tooltip: 'Opções',
            onPressed: _openMenu,
            icon: const Icon(Icons.more_vert),
            color: Colors.white70,
          ),
        ],
        bottom: _searching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Buscar jogo...',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.white38),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: NavFocus(
        callbacks: _callbacks,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _search.text.isEmpty
                    ? Icons.inbox_outlined
                    : Icons.search_off,
                size: 56,
                color: Colors.white38,
              ),
              const SizedBox(height: 16),
              Text(
                _search.text.isEmpty
                    ? 'Nenhum jogo nesta pasta'
                    : 'Nada encontrado para "${_search.text}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (_search.text.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Coloque os arquivos de ROM nesta pasta e toque em Atualizar, '
                  'ou use "Baixar capas e informações" para enriquecer os jogos.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final forcedColumns = _svc.settings.getGridColumns();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTileWidth = 170.0;
        final autoColumns =
            (constraints.maxWidth / maxTileWidth).floor().clamp(1, 10);
        final columns = forcedColumns > 0 ? forcedColumns : autoColumns;
        if (columns != _columns) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _columns = columns);
          });
        }

        final tileKeys = <int, GlobalKey>{};
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxTileWidth,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: _filtered.length,
          itemBuilder: (context, index) {
            final key = GlobalKey();
            tileKeys[index] = key;
            _tileKeys[index] = key;
            final game = _filtered[index];
            return KeyedSubtree(
              key: key,
              child: GameTile(
                game: game,
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
