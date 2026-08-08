import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callbacks de navegacao unificados (teclado e gamepad).
class NavCallbacks {
  VoidCallback? onUp;
  VoidCallback? onDown;
  VoidCallback? onLeft;
  VoidCallback? onRight;
  VoidCallback? onConfirm;
  VoidCallback? onBack;
  VoidCallback? onStart;
  VoidCallback? onPageUp;
  VoidCallback? onPageDown;
  VoidCallback? onHome;

  NavCallbacks();
}

/// Traduz eventos de teclado em navegacao (setas, Enter, Backspace, etc.).
bool handleNavKey(KeyEvent event, NavCallbacks c) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return false;
  }
  switch (event.logicalKey) {
    case LogicalKeyboardKey.arrowUp:
      c.onUp?.call();
      return true;
    case LogicalKeyboardKey.arrowDown:
      c.onDown?.call();
      return true;
    case LogicalKeyboardKey.arrowLeft:
      c.onLeft?.call();
      return true;
    case LogicalKeyboardKey.arrowRight:
      c.onRight?.call();
      return true;
    case LogicalKeyboardKey.enter:
    case LogicalKeyboardKey.space:
    case LogicalKeyboardKey.numpadEnter:
      c.onConfirm?.call();
      return true;
    case LogicalKeyboardKey.backspace:
    case LogicalKeyboardKey.escape:
      c.onBack?.call();
      return true;
    case LogicalKeyboardKey.pageUp:
      c.onPageUp?.call();
      return true;
    case LogicalKeyboardKey.pageDown:
      c.onPageDown?.call();
      return true;
    case LogicalKeyboardKey.home:
      c.onHome?.call();
      return true;
    default:
      return false;
  }
}

/// Widget que captura foco e eventos de teclado, roteando para [callbacks].
class NavFocus extends StatefulWidget {
  final NavCallbacks callbacks;
  final Widget child;
  final bool enabled;

  const NavFocus({
    super.key,
    required this.callbacks,
    required this.child,
    this.enabled = true,
  });

  @override
  State<NavFocus> createState() => _NavFocusState();
}

class _NavFocusState extends State<NavFocus> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.enabled,
      onKeyEvent: (node, event) {
        if (!widget.enabled) return KeyEventResult.ignored;
        if (handleNavKey(event, widget.callbacks)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}
