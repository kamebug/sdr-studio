/// Estado de um VFO (canal de sintonia independente). O core Rust não
/// guarda estado nenhum por VFO — cada chamada de FFI recebe frequência
/// e modo explicitamente — então dois VFOs simultâneos são só duas
/// instâncias desta classe do lado Dart, chamando o mesmo core duas
/// vezes por "tick" e misturando os resultados (áudio somado, espectros
/// combinados).
class VfoState {
  VfoState({
    required this.frequencyHz,
    required this.mode,
    this.muted = false,
  });

  double frequencyHz;
  String mode;
  bool muted;
}
