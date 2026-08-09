import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import 'settings_options.dart';
import 'theme.dart';
import 'widgets/cover_backdrop.dart';
import 'widgets/hint_bar.dart';
import 'widgets/nav_key_handler.dart';

/// Tela de opções de uma única categoria de configurações (aberta a partir do
/// carrossel da tela de Configurações). Cada categoria é uma janela própria,
/// evitando informação empilhada na mesma tela.
class SettingsCategoryView extends StatefulWidget {
  final SettingsCategory category;
  final Color accent;

  const SettingsCategoryView({
    super.key,
    required this.category,
    required this.accent,
  });

  @override
  State<SettingsCategoryView> createState() => _SettingsCategoryViewState();
}

class _SettingsCategoryViewState extends State<SettingsCategoryView> {
  AppServices get _svc => AppScope.of(context);

  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  int _selected = 0;
  StreamSubscription<GamepadAction>? _gamepadSub;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
    _rowKeys.addAll(
      List.generate(widget.category.options.length, (_) => GlobalKey()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
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
        _move(-1);
      case GamepadAction.down:
        _move(1);
      case GamepadAction.pageUp:
        _move(-5);
      case GamepadAction.pageDown:
        _move(5);
      case GamepadAction.confirm:
        _activate();
      case GamepadAction.back:
        _goBack();
      case GamepadAction.start:
      case GamepadAction.home:
        _goBack();
      case GamepadAction.left:
      case GamepadAction.right:
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    final options = widget.category.options;
    if (options.isEmpty) return;
    final next = (_selected + delta).clamp(0, options.length - 1);
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

  Future<void> _activate() async {
    final options = widget.category.options;
    if (options.isEmpty) return;
    final opt = options[_selected.clamp(0, options.length - 1)];

    if (opt.onConfirm != null) {
      await opt.onConfirm!(context);
      if (mounted) setState(() {});
      return;
    }
    if (opt.count > 0) {
      final next = (opt.index + 1) % opt.count;
      opt.onCycle?.call(next);
      if (mounted) setState(() {});
      return;
    }
    if (opt.onToggle != null) {
      opt.onToggle!(!opt.toggleValue);
      if (mounted) setState(() {});
    }
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
      _move(-5);
    }
    ..onPageDown = () {
      _move(5);
    }
    ..onConfirm = _activate
    ..onBack = _goBack
    ..onStart = _goBack
    ..onHome = () {
      Navigator.of(context).popUntil((r) => r.isFirst);
    };

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
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
                  Expanded(child: _optionsList(accent)),
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
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          Icon(widget.category.icon, size: 20, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_selected + 1}/${widget.category.options.length}',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _optionsList(Color accent) {
    final options = widget.category.options;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
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
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.8)
                        : Colors.white10,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (opt.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              opt.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (opt.valueText.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              opt.valueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? accent
                                    : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(
                      opt.count > 0
                          ? Icons.swap_horiz
                          : opt.toggle != null
                              ? (opt.toggleValue
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked)
                              : Icons.chevron_right,
                      size: 18,
                      color: selected ? accent : Colors.white24,
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

  Widget _hints() {
    if (!_svc.settings.getShowHints()) return const SizedBox.shrink();
    final gp = _svc.gamepad;
    return HintBar(
      hints: [
        Hint('opção', button: gp.currentButtonFor(GamepadAction.up)),
        Hint('ativar', button: gp.currentButtonFor(GamepadAction.confirm)),
        Hint('voltar', button: gp.currentButtonFor(GamepadAction.back)),
      ],
    );
  }
}
