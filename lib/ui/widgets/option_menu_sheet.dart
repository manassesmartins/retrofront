import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../gamepad/gamepad_manager.dart';
import '../theme.dart';
import 'nav_key_handler.dart';

class MenuOption {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const MenuOption({
    required this.label,
    required this.icon,
    this.subtitle,
    required this.onTap,
  });
}

/// Menu de opcoes estilo console (bottom sheet) navegavel por gamepad,
/// teclado e toque. Confirmar executa a acao; B/back fecha o menu.
class OptionMenuSheet extends StatefulWidget {
  final String title;
  final List<MenuOption> options;

  const OptionMenuSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<void> show(BuildContext context, OptionMenuSheet sheet) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: false,
      builder: (_) => sheet,
    );
  }

  @override
  State<OptionMenuSheet> createState() => _OptionMenuSheetState();
}

class _OptionMenuSheetState extends State<OptionMenuSheet> {
  int _selected = 0;
  StreamSubscription<GamepadAction>? _gamepadSub;

  @override
  void initState() {
    super.initState();
    _gamepadSub = AppScope.of(context).gamepad.actions.listen(_onGamepad);
  }

  @override
  void dispose() {
    _gamepadSub?.cancel();
    super.dispose();
  }

  void _onGamepad(GamepadAction action) {
    if (!mounted) return;
    switch (action) {
      case GamepadAction.up:
        setState(() => _selected =
            _selected <= 0 ? _selected : _selected - 1);
      case GamepadAction.down:
        setState(() => _selected =
            _selected >= widget.options.length - 1 ? _selected : _selected + 1);
      case GamepadAction.confirm:
        _run(_selected);
      case GamepadAction.back:
        Navigator.of(context).pop();
      case GamepadAction.home:
        Navigator.of(context).pop();
      default:
        break;
    }
  }

  void _run(int index) {
    final opt = widget.options[index];
    Navigator.of(context).pop();
    opt.onTap();
  }

  NavCallbacks get _callbacks => NavCallbacks()
    ..onUp = () {
      _onGamepad(GamepadAction.up);
    }
    ..onDown = () {
      _onGamepad(GamepadAction.down);
    }
    ..onConfirm = () {
      _onGamepad(GamepadAction.confirm);
    }
    ..onBack = () {
      _onGamepad(GamepadAction.back);
    };

  @override
  Widget build(BuildContext context) {
    return NavFocus(
      callbacks: _callbacks,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '▲▼ + A  escolher',
                    style: TextStyle(
                      color: AppTheme.textFaint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final opt = widget.options[index];
                  final selected = index == _selected;
                  return InkWell(
                    onTap: () => _run(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      color: selected
                          ? AppTheme.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      child: ListTile(
                        leading: Icon(opt.icon,
                            color: selected
                                ? AppTheme.accentAlt
                                : AppTheme.accent),
                        title: Text(
                          opt.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: opt.subtitle == null
                            ? null
                            : Text(
                                opt.subtitle!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                ),
                              ),
                        trailing: selected
                            ? const Icon(Icons.play_arrow,
                                color: AppTheme.accentAlt, size: 20)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
