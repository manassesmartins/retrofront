import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
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

/// Evento de botao fisico com a identidade do controle de origem, usado para
/// remapeamento por controle (e para filtrar em telas de configuracao).
class RawGamepadEvent {
  final GamepadButton button;
  final String gamepadId;

  const RawGamepadEvent({required this.button, required this.gamepadId});
}

/// Representa um controle conectado: sua identidade, o slot de jogador
/// (1..4) e o mapeamento de botoes proprio dele.
class GamepadPlayer {
  final String id;
  String name;
  int slot = 0;

  /// Mapeamento especifico deste controle (vazio = usar o padrao).
  Map<GamepadButton, GamepadAction> overrides = {};

  /// Estado do botao Select sendo segurado (modificador de combos).
  bool selectHeld = false;

  GamepadPlayer({required this.id, required this.name});

  /// Numero exibido do jogador (1-based).
  int get playerNumber => slot + 1;
}

/// Traduz eventos normalizados de gamepad (USB ou Bluetooth) em acoes de
/// navegacao da interface, com suporte a ate 4 controles simultaneos.
///
/// Cada controle conectado recebe um slot de jogador e seu proprio
/// mapeamento. Qualquer controle navega pela interface. O mapeamento segue
/// o layout padrao Xbox/Sony/Switch: A=confirmar | B=voltar |
/// Start=menu/opcoes | Select=ajuda; D-pad/analogicos (esquerdo e direito)
/// = navegacao; LB/RB e LT/RT = troca de pagina.
///
/// Atalhos combinados (Select como modificador, estilo ES-DE/RetroArch):
///  - Select + Start  -> Home (voltar ao inicio)
///  - Select + LB     -> pagina anterior
///  - Select + RB     -> proxima pagina
class GamepadManager {
  static const int maxPlayers = 4;

  final StreamController<GamepadAction> _actionsController =
      StreamController<GamepadAction>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<RawGamepadEvent> _rawButtonsController =
      StreamController<RawGamepadEvent>.broadcast();
  final StreamController<List<GamepadPlayer>> _playersController =
      StreamController<List<GamepadPlayer>>.broadcast();

  Stream<GamepadAction> get actions => _actionsController.stream;

  Stream<bool> get connections => _connectionController.stream;

  /// Eventos de botao fisico sem traducao (para remapeamento). Disparado na
  /// borda de subida de cada botao, com o id do controle de origem.
  Stream<RawGamepadEvent> get rawButtons => _rawButtonsController.stream;

  /// Alteracoes na lista de controles conectados (conexao/desconexao/slot).
  Stream<List<GamepadPlayer>> get controllers => _playersController.stream;

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
  static const double _triggerThreshold = 0.6;

  bool _connected = false;

  // ---- Multi-controle ------------------------------------------------------

  final Map<String, GamepadPlayer> _playersById = {};
  GamepadPlayer? _activePlayer;

  /// Mapeamento padrao, aplicado a controles sem mapa proprio.
  final Map<GamepadButton, GamepadAction> _defaultOverrides = {};

  /// Mapeamento padrao (apenas leitura), para a tela de remapeamento.
  Map<GamepadButton, GamepadAction> get defaultOverrides =>
      Map.unmodifiable(_defaultOverrides);

  /// Mapas por nome de controle, para persistencia (remap por controle).
  final Map<String, Map<GamepadButton, GamepadAction>> _savedOverrides = {};

  Timer? _reconcileTimer;

  /// Controles conectados, ordenados por slot (jogador 1..4).
  List<GamepadPlayer> get players =>
      List.unmodifiable(_playersById.values.toList()
        ..sort((a, b) => a.slot.compareTo(b.slot)));

  bool get isAnyDirectional => _heldDirection != null;

  /// Ha algum gamepad conectado (detectado na inicializacao ou por eventos).
  bool get isConnected => _connected;

  /// Inicia a escuta de gamepads.
  void start() {
    Gamepads.normalizedEvents.listen(_onEvent);
    _refreshConnection();
  }

  Future<void> _refreshConnection() async {
    try {
      final pads = await Gamepads.list();
      if (pads.isNotEmpty && !_connected) {
        _connected = true;
        _connectionController.add(true);
      }
      for (final pad in pads) {
        _registerPlayer(pad.id, name: pad.name);
      }
    } catch (_) {}
  }

  GamepadPlayer? _registerPlayer(String id, {String? name}) {
    final existing = _playersById[id];
    if (existing != null) {
      if (name != null && existing.name != name) existing.name = name;
      return existing;
    }
    if (_playersById.length >= maxPlayers) return null;
    final finalName = name ?? id;
    final player = GamepadPlayer(id: id, name: finalName)
      ..overrides = Map.of(_savedOverrides[finalName] ?? {});
    _playersById[id] = player;
    _reassignSlots();
    _notifyPlayers();
    return player;
  }

  void _reassignSlots() {
    final list = _playersById.values.toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    for (var i = 0; i < list.length; i++) {
      list[i].slot = i;
    }
  }

  void _notifyPlayers() {
    _playersController.add(players);
  }

  /// Reconcilia a lista com o plugin apos eventos, detectando desconexoes.
  void _scheduleReconcile() {
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(seconds: 2), _refreshPlayers);
  }

  Future<void> _refreshPlayers() async {
    try {
      final pads = await Gamepads.list();
      final ids = pads.map((p) => p.id).toSet();
      var removed = false;
      for (final key in _playersById.keys.toList()) {
        if (!ids.contains(key)) {
          _playersById.remove(key);
          removed = true;
        }
      }
      for (final pad in pads) {
        _registerPlayer(pad.id, name: pad.name);
      }
      if (removed) {
        _reassignSlots();
        _notifyPlayers();
      }
    } catch (_) {}
  }

  // ---- Entrada --------------------------------------------------------------

  void _onEvent(NormalizedGamepadEvent event) {
    final button = event.button;
    if (button != null) {
      _onButton(event.gamepadId, button, event.value);
      return;
    }
    final axis = event.axis;
    if (axis != null) {
      _onAxis(event.gamepadId, axis, event.value);
    }
  }

  void _onButton(String gamepadId, GamepadButton button, double value) {
    final player = _registerPlayer(gamepadId);
    if (!_connected) {
      _connected = true;
      _connectionController.add(true);
    }
    if (player != null) _activePlayer = player;
    _scheduleReconcile();

    final pressed = value > 0.5;
    final key = '$gamepadId:$button';
    if (pressed) {
      if (!(_buttonDown[key] ?? false)) {
        _buttonDown[key] = true;
        _rawButtonsController.add(RawGamepadEvent(button: button, gamepadId: gamepadId));
      }
    } else {
      _buttonDown[key] = false;
    }

    if (_handleCombo(player, button, pressed)) return;

    _handleInput('$gamepadId:button:$button', _actionForButton(button, player: player), pressed);
  }

  void _onAxis(String gamepadId, GamepadAxis axis, double value) {
    _registerPlayer(gamepadId);
    if (!_connected) {
      _connected = true;
      _connectionController.add(true);
    }
    _scheduleReconcile();

    _handleInput('$gamepadId:axis:$axis', _actionForAxis(axis, value), value != 0);
  }

  final Map<String, bool> _buttonDown = {};

  /// Atalhos combinados: com o Select segurado, Start -> Home e
  /// LB/RB -> pagina. Retorna true quando o evento foi consumido pelo combo.
  bool _handleCombo(GamepadPlayer? player, GamepadButton button, bool pressed) {
    if (player == null) return false;
    final selectBtn = _buttonFor(player, GamepadAction.select);
    if (pressed) {
      if (button == selectBtn) {
        player.selectHeld = true;
        return false;
      }
      if (player.selectHeld) {
        if (button == _buttonFor(player, GamepadAction.start)) {
          _emit(GamepadAction.home);
          return true;
        }
        if (button == _buttonFor(player, GamepadAction.pageUp)) {
          _emit(GamepadAction.pageUp);
          return true;
        }
        if (button == _buttonFor(player, GamepadAction.pageDown)) {
          _emit(GamepadAction.pageDown);
          return true;
        }
      }
      return false;
    }
    if (button == selectBtn) player.selectHeld = false;
    return false;
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
  @visibleForTesting
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

  /// Hook de teste: simula um toque de um botao fisico (usa o mapeamento real).
  @visibleForTesting
  void handleButtonForTest(GamepadButton button,
      {bool release = false, String gamepadId = 'test'}) {
    _onButton(gamepadId, button, release ? 0 : 1);
  }

  /// Hook de teste: simula um eixo (analogico/trigger) com valor em [-1, 1].
  @visibleForTesting
  void handleAxisForTest(GamepadAxis axis, double value,
      {String gamepadId = 'test'}) {
    _onAxis(gamepadId, axis, value);
  }

  /// Hook de teste: registra um controle com id/name para testes de multi-player.
  @visibleForTesting
  GamepadPlayer? registerPlayerForTest(String id, String name) =>
      _registerPlayer(id, name: name);

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

  bool _nintendoLayout = false;

  /// Define o esquema de botoes: 'standard' (Xbox/Sony: A=confirmar,
  /// B=voltar) ou 'nintendo' (estilo RetroArch: A/B trocados).
  void setButtonScheme(String scheme) {
    _nintendoLayout = scheme == 'nintendo';
  }

  /// Botao padrao (esquema 'standard') de uma acao, para exibicao no remap.
  static GamepadButton? defaultButtonFor(GamepadAction action) {
    return switch (action) {
      GamepadAction.confirm => GamepadButton.a,
      GamepadAction.back => GamepadButton.b,
      GamepadAction.start => GamepadButton.start,
      GamepadAction.select => GamepadButton.back,
      GamepadAction.home => GamepadButton.home,
      GamepadAction.pageUp => GamepadButton.leftBumper,
      GamepadAction.pageDown => GamepadButton.rightBumper,
      GamepadAction.up => GamepadButton.dpadUp,
      GamepadAction.down => GamepadButton.dpadDown,
      GamepadAction.left => GamepadButton.dpadLeft,
      GamepadAction.right => GamepadButton.dpadRight,
    };
  }

  /// Botao atualmente mapeado para uma acao, considerando o remap do controle
  /// ativo (ou o padrao), usado para exibir os atalhos corretos na interface.
  GamepadButton? currentButtonFor(GamepadAction action) {
    final player = _activePlayer;
    final overrides = (player != null && player.overrides.isNotEmpty)
        ? player.overrides
        : _defaultOverrides;
    for (final entry in overrides.entries) {
      if (entry.value == action) return entry.key;
    }
    return defaultButtonFor(action);
  }

  /// Botao mapeado para [action] considerando um controle especifico.
  GamepadButton? _buttonFor(GamepadPlayer player, GamepadAction action) {
    for (final entry in player.overrides.entries) {
      if (entry.value == action) return entry.key;
    }
    for (final entry in _defaultOverrides.entries) {
      if (entry.value == action) return entry.key;
    }
    return defaultButtonFor(action);
  }

  /// Rotulos amigaveis dos botoes para a tela de mapeamento.
  static String buttonLabel(GamepadButton b) {
    return switch (b) {
      GamepadButton.a => 'A',
      GamepadButton.b => 'B',
      GamepadButton.x => 'X',
      GamepadButton.y => 'Y',
      GamepadButton.dpadUp => 'D-Pad ↑',
      GamepadButton.dpadDown => 'D-Pad ↓',
      GamepadButton.dpadLeft => 'D-Pad ←',
      GamepadButton.dpadRight => 'D-Pad →',
      GamepadButton.start => 'Start',
      GamepadButton.back => 'Select',
      GamepadButton.home => 'Home',
      GamepadButton.leftBumper => 'LB',
      GamepadButton.rightBumper => 'RB',
      GamepadButton.leftTrigger => 'LT',
      GamepadButton.rightTrigger => 'RT',
      GamepadButton.leftStick => 'L3',
      GamepadButton.rightStick => 'R3',
      GamepadButton.touchpad => 'Touchpad',
    };
  }

  /// Rotulos amigaveis das acoes para a tela de mapeamento.
  static String actionLabel(GamepadAction a) {
    return switch (a) {
      GamepadAction.confirm => 'Confirmar',
      GamepadAction.back => 'Voltar',
      GamepadAction.start => 'Start (menu)',
      GamepadAction.select => 'Select (ajuda)',
      GamepadAction.home => 'Home',
      GamepadAction.pageUp => 'Página anterior',
      GamepadAction.pageDown => 'Próxima página',
      GamepadAction.up => 'Cima',
      GamepadAction.down => 'Baixo',
      GamepadAction.left => 'Esquerda',
      GamepadAction.right => 'Direita',
    };
  }

  /// Acoes remapeaveis (botoes de acao; o direcional nao e remapeado).
  static const List<GamepadAction> remappableActions = [
    GamepadAction.confirm,
    GamepadAction.back,
    GamepadAction.start,
    GamepadAction.select,
    GamepadAction.home,
    GamepadAction.pageUp,
    GamepadAction.pageDown,
  ];

  bool _isDirectional(GamepadAction a) =>
      a == GamepadAction.up ||
      a == GamepadAction.down ||
      a == GamepadAction.left ||
      a == GamepadAction.right;

  GamepadAction? _actionForButton(GamepadButton b, {GamepadPlayer? player}) {
    final overrides = (player != null && player.overrides.isNotEmpty)
        ? player.overrides
        : _defaultOverrides;
    if (overrides.containsKey(b)) return overrides[b]!;
    switch (b) {
      case GamepadButton.a:
        return _nintendoLayout ? GamepadAction.back : GamepadAction.confirm;
      case GamepadButton.b:
        return _nintendoLayout ? GamepadAction.confirm : GamepadAction.back;
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
      case GamepadButton.leftTrigger:
        return GamepadAction.pageUp;
      case GamepadButton.rightTrigger:
        return GamepadAction.pageDown;
      case GamepadButton.leftStick:
      case GamepadButton.rightStick:
      case GamepadButton.touchpad:
        return null;
    }
  }

  GamepadAction? _actionForAxis(GamepadAxis axis, double value) {
    switch (axis) {
      case GamepadAxis.leftStickY:
      case GamepadAxis.rightStickY:
        if (value < -_axisThreshold) return GamepadAction.up;
        if (value > _axisThreshold) return GamepadAction.down;
        return null;
      case GamepadAxis.leftStickX:
      case GamepadAxis.rightStickX:
        if (value < -_axisThreshold) return GamepadAction.left;
        if (value > _axisThreshold) return GamepadAction.right;
        return null;
      case GamepadAxis.leftTrigger:
        return value > _triggerThreshold ? GamepadAction.pageUp : null;
      case GamepadAxis.rightTrigger:
        return value > _triggerThreshold ? GamepadAction.pageDown : null;
    }
  }

  /// Define o mapeamento padrao de botoes (aplicado a controles sem mapa proprio).
  void setButtonOverrides(Map<GamepadButton, GamepadAction> overrides) {
    _defaultOverrides
      ..clear()
      ..addAll(overrides);
  }

  /// Limpa o mapeamento padrao, retornando ao padrao de fabrica.
  void clearButtonOverrides() {
    _defaultOverrides.clear();
  }

  /// Registra os mapas persistidos por nome de controle.
  void setControllerButtonMaps(Map<String, String> serialized) {
    _savedOverrides.clear();
    serialized.forEach((name, data) {
      _savedOverrides[name] = deserializeButtonMap(data);
    });
    for (final player in _playersById.values) {
      player.overrides = Map.of(_savedOverrides[player.name] ?? {});
    }
  }

  /// Aplica e persiste em memoria o mapeamento de um controle pelo nome.
  void applyOverridesFor(String name, Map<GamepadButton, GamepadAction> overrides) {
    _savedOverrides[name] = Map.of(overrides);
    for (final player in _playersById.values) {
      if (player.name == name) player.overrides = Map.of(overrides);
    }
  }

  /// Serializa um mapa de botoes para string (para persistencia).
  static String serializeOverrides(Map<GamepadButton, GamepadAction> overrides) {
    return overrides.entries
        .map((e) => '${e.key.name}=${e.value.name}')
        .join(';');
  }

  /// Serializa o mapeamento padrao para string (para persistencia).
  String serializeButtonMap() => serializeOverrides(_defaultOverrides);

  /// Deserializa string de mapeamento (formato: "button=action;...").
  /// Itens com valores invalidos/desconhecidos sao ignorados.
  static Map<GamepadButton, GamepadAction> deserializeButtonMap(String data) {
    final result = <GamepadButton, GamepadAction>{};
    if (data.trim().isEmpty) return result;
    final parts = data.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx <= 0 || idx >= part.length - 1) continue;
      final buttonName = part.substring(0, idx);
      final actionName = part.substring(idx + 1);
      final button = _byName(GamepadButton.values, buttonName);
      final action = _byName(GamepadAction.values, actionName);
      if (button != null && action != null) {
        result[button] = action;
      }
    }
    return result;
  }

  static T? _byName<T extends Enum>(List<T> values, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  void dispose() {
    _repeatTimer?.cancel();
    _reconcileTimer?.cancel();
    _actionsController.close();
    _connectionController.close();
    _rawButtonsController.close();
    _playersController.close();
  }
}
