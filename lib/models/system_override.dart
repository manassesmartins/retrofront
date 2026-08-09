/// Sobrescrita de inicializacao por sistema (definida pelo usuario):
/// core do RetroArch e argumentos extras, aplicados ao comando do sistema.
class SystemOverride {
  final String core;
  final String extraArgs;

  const SystemOverride({this.core = '', this.extraArgs = ''});

  bool get hasCore => core.trim().isNotEmpty;
  bool get hasArgs => extraArgs.trim().isNotEmpty;
  bool get isSet => hasCore || hasArgs;

  factory SystemOverride.fromJson(Map<String, dynamic> json) => SystemOverride(
        core: json['core'] as String? ?? '',
        extraArgs: json['extraArgs'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        if (core.isNotEmpty) 'core': core,
        if (extraArgs.isNotEmpty) 'extraArgs': extraArgs,
      };
}
