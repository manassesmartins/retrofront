import 'package:flutter/widgets.dart';

/// Observador global de rotas. Permite que telas reflitam mudanças de
/// configuração quando voltam ao topo (ex.: fechar Configurações atualiza a
/// tela inicial, incluindo a visibilidade do botão de configurações).
final RouteObserver<ModalRoute<Object?>> routeObserver =
    RouteObserver<ModalRoute<Object?>>();
