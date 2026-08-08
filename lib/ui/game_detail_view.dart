import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/game.dart';
import '../models/game_entry.dart';
import '../models/system.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/cover_image.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/star_rating.dart';

/// Tela de detalhes de um jogo: capa grande, metadados, jogar e scraping.
class GameDetailView extends StatefulWidget {
  final SystemEntry system;
  final GameEntry game;

  const GameDetailView({super.key, required this.system, required this.game});

  @override
  State<GameDetailView> createState() => _GameDetailViewState();
}

class _GameDetailViewState extends State<GameDetailView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  late GameMetadata? _metadata;
  bool _scraping = false;
  StreamSubscription<GamepadAction>? _gamepadSub;

  @override
  void initState() {
    super.initState();
    _metadata = widget.game.metadata;
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) return;

    switch (action) {
      case GamepadAction.up:
        _scrollBy(-120);
      case GamepadAction.down:
        _scrollBy(120);
      case GamepadAction.pageUp:
        _scrollBy(-400);
      case GamepadAction.pageDown:
        _scrollBy(400);
      case GamepadAction.confirm:
        _play();
      case GamepadAction.back:
        Navigator.of(context).pop();
      case GamepadAction.start:
        _scrapeGame();
      default:
        break;
    }
  }

  void _scrollBy(double delta) {
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _scrollBy(-120);
    }
    ..onDown = () {
      _scrollBy(120);
    }
    ..onPageUp = () {
      _scrollBy(-400);
    }
    ..onPageDown = () {
      _scrollBy(400);
    }
    ..onConfirm = _play
    ..onBack = () {
      Navigator.of(context).pop();
    }
    ..onStart = _scrapeGame;

  Future<void> _play() async {
    final result = await _svc.launcher.launch(widget.system.definition, widget.game);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok ? 'Iniciando ${widget.game.displayName}...' : (result.error ?? 'Erro'),
        ),
      ),
    );
  }

  Future<void> _scrapeGame() async {
    if (_scraping) return;
    setState(() => _scraping = true);

    final gameName = p.basenameWithoutExtension(widget.game.name);
    final meta = await _svc.scrape.scrapGame(widget.system.definition, gameName);

    if (!mounted) return;

    if (meta == null) {
      setState(() => _scraping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum resultado encontrado.')),
      );
      return;
    }

    final merged = _svc.scrape.mergeMetadata(
      widget.game.metadata ?? const GameMetadata(),
      meta,
    );
    final rel = p.relative(widget.game.path, from: widget.system.path);
    await _svc.gamelist.upsert(widget.system.name, rel, merged);

    if (!mounted) return;
    setState(() {
      _metadata = merged;
      _scraping = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          meta.coverPath != null
              ? 'Capa e informações atualizadas.'
              : 'Informações atualizadas (sem capa).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metadata;
    final title = widget.game.displayName;
    final year = _yearFrom(meta?.releaseDate);
    final isWide = MediaQuery.of(context).size.width > 760;

    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(
              coverPath: meta?.coverPath,
              color: AppTheme.systemColor(widget.system.name),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
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
                        Expanded(
                          child: Text(
                            widget.system.fullName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _Cover(meta: meta, title: title, width: 260),
                                      const SizedBox(width: 32),
                                      Expanded(
                                        child: _Details(
                                          title: title,
                                          meta: meta,
                                          year: year,
                                          system: widget.system,
                                          scraping: _scraping,
                                          onPlay: _play,
                                          onScrape: _scrapeGame,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: _Cover(
                                            meta: meta, title: title, width: 200),
                                      ),
                                      const SizedBox(height: 24),
                                      _Details(
                                        title: title,
                                        meta: meta,
                                        year: year,
                                        system: widget.system,
                                        scraping: _scraping,
                                        onPlay: _play,
                                        onScrape: _scrapeGame,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _yearFrom(String? releaseDate) {
    if (releaseDate == null) return null;
    return RegExp(r'^(\d{4})').firstMatch(releaseDate)?.group(1);
  }
}

class _Cover extends StatelessWidget {
  final GameMetadata? meta;
  final String title;
  final double width;

  const _Cover({required this.meta, required this.title, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: CoverImage(
          path: meta?.coverPath,
          width: width,
          borderRadius: BorderRadius.circular(16),
          fallbackLabel: title,
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final String title;
  final GameMetadata? meta;
  final String? year;
  final SystemEntry system;
  final bool scraping;
  final VoidCallback onPlay;
  final VoidCallback onScrape;

  const _Details({
    required this.title,
    required this.meta,
    required this.year,
    required this.system,
    required this.scraping,
    required this.onPlay,
    required this.onScrape,
  });

  @override
  Widget build(BuildContext context) {
    final meta = this.meta;
    final genre = meta?.genre;
    final publisher = meta?.publisher ?? meta?.developer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(system.fullName),
            if (year != null) _chip('$year'),
            if (genre != null) _chip(genre),
            if (publisher != null) _chip(publisher),
            if (meta?.players != null) _chip('${meta!.players} jogadores'),
          ],
        ),
        if (meta?.rating != null) ...[
          const SizedBox(height: 12),
          StarRating(rating: meta!.rating!, size: 20),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed: scraping ? null : onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jogar'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: scraping ? null : onScrape,
              icon: scraping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: const Text('Baixar capa/infos'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (meta?.description != null) ...[
          const Text(
            'Descrição',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta!.description!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ] else
          const Text(
            'Nenhuma informação disponível. Use "Baixar capa/infos" '
            'para buscar dados e capas pela internet.',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2633),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
