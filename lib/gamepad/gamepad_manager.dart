import 'dart:async';

import 'package:gamepads/gamepads.dart';

/// Acao logica gerada pelo controle, independente de plataforma/controle.
enum GamepadAction {
  up,
  down,
  left,
  right,
  confirm,
  back,
  start,
  select,
  pageUp,
  pageDown,
  home,
}

/// Traduz eventos normalizados de gamepad (USB ou Bluetooth) em acoes de
/// navegacao da interface. O mapeamento segue o layout padrao Xbox/Sony/Switch:
///  A=confirmar | B=voltar | Start=menu/opcoes | Select=ajuda
///  D-pad/analogico esquerdo = navegacao | LB/RB = troca de pagina.
class GamepadManager {
  final StreamController<GamepadAction> _actionsController =
      StreamController<GamepadAction>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<GamepadAction> get actions => _actionsController.stream;
  Stream<bool> get connections => _connectionController.stream;

  final Map<String, bool> _pressed = {};
  Timer? _repeatTimer;
  GamepadAction? _heldDirection;
  Duration _repeatInterval = const Duration(milliseconds: 300);

  static const double _axisThreshold = 0.5;

  bool get isAnyDirectional => _heldDirection != null;

  /// Inicia a escuta de gamepads.
  void start() {
    Gamepads.normalizedEvents.listen(_onEvent);
    _refreshConnection();
  }

  Future<void> _refreshConnection() async {
    try {
      final pads = await Gamepads.list();
      if (pads.isNotEmpty) {
        _connectionController.add(true);
      }
    } catch (_) {}
  }

  void _onEvent(NormalizedGamepadEvent event) {
    _connectionController.add(true);

    final button = event.button;
    if (button != null) {
      _handleInput('button:$button', _actionForButton(button), event.value > 0.5);
      return;
    }
    final axis = event.axis;
    if (axis != null) {
      _handleInput('axis:$axis', _actionForAxis(axis, event.value), event.value != 0);
    }
  }

  void _handleInput(String source, GamepadAction? action, bool pressed) {
    if (pressed) {
      if (action == null) return;
      if (_pressed[source] ?? false) return;
      _pressed[source] = true;
      _emit(action);
    } else {
      _pressed[source] = false;
    }
    _updateRepeat();
  }

  void _emit(GamepadAction action) {
    if (!_isDirectional(action)) {
      _actionsController.add(action);
      return;
    }
    _heldDirection = action;
    _actionsController.add(action);
  }

  void _updateRepeat() {
    final active = _heldDirection;
    if (active != null && _pressed.values.any((p) => p)) {
      _repeatTimer ??= Timer.periodic(_repeatInterval, (_) {
        final held = _heldDirection;
        if (held != null && _isDirectional(held)) {
          _actionsController.add(held);
        }
      });
    } else {
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _heldDirection = null;
    }
  }

  void setRepeatInterval(Duration interval) {
    _repeatInterval = interval;
  }

  bool _isDirectional(GamepadAction a) =>
      a == GamepadAction.up ||
      a == GamepadAction.down ||
      a == GamepadAction.left ||
      a == GamepadAction.right;

  GamepadAction? _actionForButton(GamepadButton b) {
    switch (b) {
      case GamepadButton.a:
        return GamepadAction.confirm;
      case GamepadButton.b:
        return GamepadAction.back;
      case GamepadButton.x:
        return GamepadAction.pageUp;
      case GamepadButton.y:
        return GamepadAction.pageDown;
      case GamepadButton.dpadUp:
        return GamepadAction.up;
      case GamepadButton.dpadDown:
        return GamepadAction.down;
      case GamepadButton.dpadLeft:
        return GamepadAction.left;
      case GamepadButton.dpadRight:
        return GamepadAction.right;
      case GamepadButton.start:
        return GamepadAction.start;
      case GamepadButton.back:
        return GamepadAction.select;
      case GamepadButton.home:
        return GamepadAction.home;
      case GamepadButton.leftBumper:
        return GamepadAction.pageUp;
      case GamepadButton.rightBumper:
        return GamepadAction.pageDown;
      default:
        return null;
    }
  }

  GamepadAction? _actionForAxis(GamepadAxis axis, double value) {
    switch (axis) {
      case GamepadAxis.leftStickY:
        if (value < -_axisThreshold) return GamepadAction.up;
        if (value > _axisThreshold) return GamepadAction.down;
        return null;
      case GamepadAxis.leftStickX:
        if (value < -_axisThreshold) return GamepadAction.left;
        if (value > _axisThreshold) return GamepadAction.right;
        return null;
      default:
        return null;
    }
  }

  void dispose() {
    _repeatTimer?.cancel();
    _actionsController.close();
    _connectionController.close();
  }
}
