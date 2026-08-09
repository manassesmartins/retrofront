import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../gamepad/gamepad_manager.dart';
import '../models/system.dart';
import '../models/system_override.dart';
import 'theme.dart';
import 'widgets/nav_key_handler.dart';
import 'widgets/virtual_keyboard.dart';

/// Configurações por sistema: core do RetroArch e argumentos extras que
/// sobrescrevem os valores padrão do comando deste console.
class SystemOptionsView extends StatefulWidget {
  final SystemDefinition system;

  const SystemOptionsView({super.key, required this.system});

  @override
  State<SystemOptionsView> createState() => _SystemOptionsViewState();
}

class _SystemOptionsViewState extends State<SystemOptionsView> {
  AppServices get _svc => AppScope.of(context);

  late SystemOverride _override;
  int _selected = 0;
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
    _override = _svc.settings.getSystemOverride(widget.system.name) ??
        const SystemOverride();
    _gamepadSub = _svc.gamepad.actions.listen(_onGamepad);
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    super.dispose();
  }

  String get _defaultCore {
    final cmd = widget.system.command ?? '';
    final match = RegExp(r'-L\s+([^\s]+)', caseSensitive: false).firstMatch(cmd);
    if (match == null) return '';
    final core = match.group(1)!.split('/').last;
    return core.replaceFirst('_libretro.so', '');
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
      case GamepadAction.confirm:
        _activate();
      case GamepadAction.back:
      case GamepadAction.start:
      case GamepadAction.home:
        _goBack();
      case GamepadAction.pageUp:
      case GamepadAction.pageDown:
      case GamepadAction.left:
      case GamepadAction.right:
      case GamepadAction.select:
        break;
    }
  }

  void _move(int delta) {
    final next = (_selected + delta).clamp(0, 2);
    if (next != _selected) setState(() => _selected = next);
  }

  Future<void> _activate() async {
    switch (_selected) {
      case 0:
        final core = await showVirtualKeyboardDialog(
          context,
          title: 'Core (${widget.system.name})',
          initial: _override.core.isEmpty ? _defaultCore : _override.core,
          language: _svc.settings.getLanguage(),
        );
        if (core != null && mounted) {
          _override = SystemOverride(core: core, extraArgs: _override.extraArgs);
          await _save();
        }
      case 1:
        final args = await showVirtualKeyboardDialog(
          context,
          title: 'Argumentos extras (${widget.system.name})',
          initial: _override.extraArgs,
          language: _svc.settings.getLanguage(),
        );
        if (args != null && mounted) {
          _override = SystemOverride(core: _override.core, extraArgs: args);
          await _save();
        }
      case 2:
        setState(() => _override = const SystemOverride());
        await _save();
    }
  }

  Future<void> _save() async {
    await _svc.settings.setSystemOverride(widget.system.name, _override);
    if (mounted) setState(() {});
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
    ..onConfirm = _activate
    ..onBack = _goBack
    ..onStart = _goBack
    ..onHome = _goBack;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.systemColor(widget.system.name);
    final items = <(String, String, String)>[
      (
        'Core',
        _override.hasCore
            ? _override.core
            : 'padrão (${_defaultCore.isEmpty ? '—' : _defaultCore})',
        'Nome do core do RetroArch (ex.: "mesen"). Vazio usa o core '
            'padrão deste sistema.',
      ),
      (
        'Argumentos extras',
        _override.hasArgs ? _override.extraArgs : 'nenhum',
        'Parâmetros adicionais passados ao RetroArch antes da ROM, junto '
            'com os argumentos globais.',
      ),
      (
        'Restaurar padrão',
        '',
        'Remove o core e os argumentos extras deste sistema.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Opções · ${widget.system.fullName}'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: NavFocus(
        callbacks: _callbacks,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final (label, value, desc) = items[index];
            final selected = index == _selected;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: selected
                    ? accent.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  selected: selected,
                  onTap: () {
                    setState(() => _selected = index);
                    _activate();
                  },
                  title: Text(
                    label,
                    style: TextStyle(
                      color: selected ? accent : AppTheme.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    value.isEmpty ? desc : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
