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
  // Fonte -> direcao que ela mantem pressionada (botao e/ou eixo).
  final Map<String, GamepadAction> _directional = {};
  final List<String> _directionalOrder = [];
  Timer? _repeatTimer;
  GamepadAction? _repeatFor;
  GamepadAction? _heldDirection;
  Duration _repeatInterval = const Duration(milliseconds: 300);
  int _testCounter = 0;

  /// Antecipacao antes do primeiro repeticao (efeito console: um toque = um passo).
  static const Duration _repeatInitialDelay = Duration(milliseconds: 450);
  /// Cooldown para suprimir emissoes duplicadas da mesma acao (ex.: botao e
  /// analogico reportando o mesmo direcional, ou ruido no deadzone).
  static const Duration _cooldown = Duration(milliseconds: 140);

  final Stopwatch _clock = Stopwatch()..start();
  final Map<GamepadAction, int> _lastEmitMs = {};

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
    if (action == null) {
      // Eixo voltou ao centro: libera a fonte que segurava a direcao.
      _pressed[source] = false;
      _directional.remove(source);
      _directionalOrder.remove(source);
      _updateRepeat();
      return;
    }
    if (pressed) {
      if (_pressed[source] ?? false) return; // so conta na borda de subida
      _pressed[source] = true;
      if (_isDirectional(action)) {
        if (!_directional.containsKey(source)) {
          _directional[source] = action;
          _directionalOrder.add(source);
        }
        final effective = _effectiveDirection();
        if (_heldDirection != effective) {
          _heldDirection = effective;
          _emit(effective!);
        }
      } else {
        _emit(action);
      }
    } else {
      _pressed[source] = false;
      _directional.remove(source);
      _directionalOrder.remove(source);
    }
    _updateRepeat();
  }

  /// Direcao efetiva: a da fonte acionada mais recentemente (diagonal resolve
  /// para a ultima direcao pressionada).
  GamepadAction? _effectiveDirection() {
    if (_directionalOrder.isEmpty) return null;
    return _directional[_directionalOrder.last];
  }

  void _emit(GamepadAction action, {bool force = false}) {
    if (!force) {
      final now = _clock.elapsedMilliseconds;
      final last = _lastEmitMs[action] ?? -_cooldown.inMilliseconds * 2;
      if (now - last < _cooldown.inMilliseconds) return;
      _lastEmitMs[action] = now;
    }
    _actionsController.add(action);
  }

  void _updateRepeat() {
    final active = _effectiveDirection();
    if (active != null) {
      _heldDirection = active;
      // Reinicia o cronometro se a direcao segurada mudou.
      if (_repeatTimer == null || _repeatFor != active) {
        _stopRepeat();
        _repeatFor = active;
        _scheduleRepeat(_repeatInitialDelay);
      }
    } else {
      _stopRepeat();
      _repeatFor = null;
      _heldDirection = null;
    }
  }

  final Map<GamepadAction, String> _testSources = {};

  /// Hook de teste: simula um toque (press edge) de uma acao direcional.
  void handleForTest(GamepadAction action, {bool release = false}) {
    if (release) {
      final source = _testSources.remove(action);
      if (source != null) {
        // Simula o eixo voltando ao centro: acao nula, fonte liberada.
        _handleInput(source, null, false);
      }
      return;
    }
    final source = _testSources[action] ??= 'test:${_testCounter++}';
    _handleInput(source, action, true);
  }

  void _scheduleRepeat(Duration delay) {
    _repeatTimer = Timer(delay, () {
      _repeatTimer = null;
      final held = _heldDirection;
      if (held != null && _isDirectional(held)) {
        // Repeticao proposital de um botao segurado: ignora o cooldown.
        _emit(held, force: true);
        _scheduleRepeat(_repeatInterval);
      }
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
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
