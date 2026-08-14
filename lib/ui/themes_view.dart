import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/theme_palette.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/option_menu_sheet.dart';
import 'widgets/virtual_keyboard.dart';

/// Tela de Temas: lista todos os temas disponiveis (oficiais + do usuario),
/// permite aplicar com um toque, importar temas criados pela comunidade
/// (arquivo JSON) e criar o proprio tema a partir do visual atual.
///
/// Navegacao:
///   - cima/baixo: selecionar
///   - A (confirmar): aplicar o tema / executar a acao
///   - Select (menu): opcoes do tema (exportar, excluir)
///   - B: voltar
class ThemesView extends StatefulWidget {
  const ThemesView({super.key});

  @override
  State<ThemesView> createState() => _ThemesViewState();
}

class _ThemesViewState extends State<ThemesView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  List<ThemePalette> _themes = [];
  int _selected = 0;
  bool _loading = true;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  /// Quantidade de itens de acao antes da lista de temas (importar + novo).
  static const _actionCount = 2;

  @override
  void initState() {
    super.initState();
    // Mantem o selo "Em uso" sincronizado com o tema ativo (ex.: ao excluir).
    _svc.themes.active.addListener(_onActiveChanged);
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
    _svc.themes.active.removeListener(_onActiveChanged);
    _gamepadSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final themes = await _svc.themes.list();
    _rowKeys
      ..clear()
      ..addAll(List.generate(themes.length + _actionCount, (_) => GlobalKey()));
    if (!mounted) return;
    setState(() {
      _themes = themes;
      _loading = false;
      _selected = 0;
    });
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
      case GamepadAction.pageUp:
        _move(-5);
      case GamepadAction.pageDown:
        _move(5);
      case GamepadAction.confirm:
        _activate();
      case GamepadAction.select:
        _openMenu();
      case GamepadAction.back:
      case GamepadAction.start:
      case GamepadAction.home:
        Navigator.of(context).pop();
      case GamepadAction.left:
      case GamepadAction.right:
        break;
    }
  }

  void _move(int delta) {
    if (_loading) return;
    final total = _themes.length + _actionCount;
    if (total == 0) return;
    final next = (_selected + delta).clamp(0, total - 1);
    if (next == _selected) return;
    setState(() => _selected = next);
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

  bool get _isOnAction => _selected < _actionCount;

  ThemePalette? get _selectedTheme {
    final i = _selected - _actionCount;
    if (i < 0 || i >= _themes.length) return null;
    return _themes[i];
  }

  Future<void> _activate() async {
    if (_loading) return;
    if (_isOnAction) {
      if (_selected == 0) {
        await _importTheme();
      } else {
        await _createTheme();
      }
      return;
    }
    final theme = _selectedTheme;
    if (theme == null) return;
    final ok = await _svc.themes.apply(theme.id);
    if (!mounted) return;
    if (ok) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tema "${theme.name}" aplicado.')),
      );
    }
  }

  Future<void> _importTheme() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final theme = await _svc.themes.importBytes(bytes);
    if (!mounted) return;
    if (theme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arquivo inválido: não é um tema RetroFront.'),
        ),
      );
      return;
    }
    await _svc.themes.applyPalette(theme);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema "${theme.name}" importado e aplicado.')),
    );
  }

  Future<void> _createTheme() async {
    final language = _svc.settings.getLanguage();
    final name = await showVirtualKeyboardDialog(
      context,
      title: 'Novo tema',
      initial: 'Meu tema',
      language: language,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final theme = await _svc.themes.createFromCurrent(name: name.trim());
    await _svc.themes.applyPalette(theme);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tema "${theme.name}" criado a partir do visual atual e aplicado.',
        ),
      ),
    );
  }

  Future<void> _openMenu() async {
    final theme = _selectedTheme;
    if (theme == null) return;
    final isUser = await _svc.themes.isUserTheme(theme.id);
    if (!mounted) return;
    OptionMenuSheet.show(
      context,
      OptionMenuSheet(
        title: theme.name,
        options: [
          MenuOption(
            label: 'Aplicar',
            icon: Icons.check_circle_outline,
            onTap: () => _activate(),
          ),
          MenuOption(
            label: 'Exportar JSON',
            subtitle: 'Compartilhe este tema com a comunidade.',
            icon: Icons.ios_share,
            onTap: () => _exportTheme(theme),
          ),
          if (isUser)
            MenuOption(
              label: 'Excluir',
              subtitle: 'Remove este tema do dispositivo.',
              icon: Icons.delete_outline,
              onTap: () => _deleteTheme(theme),
            ),
        ],
      ),
    );
  }

  Future<void> _exportTheme(ThemePalette theme) async {
    final json = const JsonEncoder.withIndent('  ').convert(theme.toJson());
    await FilePicker.saveFile(
      dialogTitle: 'Exportar tema',
      fileName: '${theme.id}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
  }

  Future<void> _deleteTheme(ThemePalette theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Excluir tema?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '"${theme.name}" será removido do dispositivo. Essa ação não '
          'pode ser desfeita.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _svc.themes.delete(theme.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tema "${theme.name}" excluído.')),
    );
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _move(-1);
    }
    ..onDown = () {
      _move(1);
    }
    ..onPageUp = () {
      _move(-5);
    }
    ..onPageDown = () {
      _move(5);
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
    final accent = AppTheme.systemColor('themes');
    return Scaffold(
      body: NavFocus(
        callbacks: _callbacks,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverBackdrop(color: accent, darken: 0.62),
            SafeArea(
              child: Column(
                children: [
                  _topBar(accent),
                  Expanded(child: _body(accent)),
                  _hints(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Icon(Icons.palette_outlined, size: 20, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Temas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _loading ? '' : '${_themes.length} tema${_themes.length == 1 ? '' : 's'}',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _body(Color accent) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      itemCount: _themes.length + _actionCount,
      itemBuilder: (context, index) {
        final selected = index == _selected;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: KeyedSubtree(
            key: _rowKeys[index],
            child: InkWell(
              onTap: () {
                setState(() => _selected = index);
                _activate();
              },
              onLongPress: index >= _actionCount
                  ? () {
                      setState(() => _selected = index);
                      _openMenu();
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.8)
                        : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: index < _actionCount
                    ? _actionRow(index, selected, accent)
                    : _themeRow(_themes[index - _actionCount], selected, accent),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionRow(int index, bool selected, Color accent) {
    final import = index == 0;
    return Row(
      children: [
        Container(
          width: 84,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            import ? Icons.download_outlined : Icons.add,
            color: accent,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                import ? 'Importar tema' : 'Novo tema',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                import
                    ? 'Arquivo JSON criado pela comunidade'
                    : 'Cria um tema a partir do visual atual',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textFaint, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, size: 20, color: selected ? accent : AppTheme.textFaint),
      ],
    );
  }

  Widget _themeRow(ThemePalette theme, bool selected, Color accent) {
    final active = _svc.themes.active.value.id == theme.id;
    return Row(
      children: [
        _ThemePreview(palette: theme),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (theme.author != null && theme.author!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'por ${theme.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textFaint,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                theme.version != null
                    ? 'v${theme.version}'
                    : 'Tema oficial do RetroFront',
                style: TextStyle(color: AppTheme.textFaint, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'EM USO',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          )
        else
          Icon(Icons.chevron_right,
              size: 20, color: selected ? accent : AppTheme.textFaint),
      ],
    );
  }

  Widget _hints() {
    if (!_svc.settings.getShowHints()) return const SizedBox.shrink();
    final gp = _svc.gamepad;
    return HintBar(
      hints: [
        Hint('opção', button: gp.currentButtonFor(GamepadAction.up)),
        Hint('aplicar', button: gp.currentButtonFor(GamepadAction.confirm)),
        Hint('opções', button: gp.currentButtonFor(GamepadAction.select)),
        Hint('voltar', button: gp.currentButtonFor(GamepadAction.back)),
      ],
    );
  }
}

/// Miniatura de um tema: gradiente com as cores principais da paleta escura.
class _ThemePreview extends StatelessWidget {
  final ThemePalette palette;

  const _ThemePreview({required this.palette});

  List<Color> _colors() {
    final d = palette.dark;
    final def = ThemePalette.builtIn.dark;
    return [
      d.background ?? def.background!,
      d.surface ?? def.surface!,
      d.accent ?? def.accent!,
      d.accentAlt ?? def.accentAlt!,
      d.textPrimary ?? def.textPrimary!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors(),
        ),
      ),
    );
  }
}
