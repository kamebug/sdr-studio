/// Formata uma frequência em Hz para uma string com a unidade mais
/// apropriada (Hz, kHz, MHz, GHz) — mesma convenção usada por qualquer
/// software de SDR de verdade, já que a faixa de sintonia real vai de
/// centenas de kHz a quase 2 GHz (ex: RTL-SDR Blog V4: 500 kHz–1.766 GHz).
String formatFrequency(double hz) {
  if (hz >= 1e9) {
    return '${(hz / 1e9).toStringAsFixed(3)} GHz';
  }
  if (hz >= 1e6) {
    return '${(hz / 1e6).toStringAsFixed(3)} MHz';
  }
  if (hz >= 1e3) {
    return '${(hz / 1e3).toStringAsFixed(3)} kHz';
  }
  return '${hz.toStringAsFixed(0)} Hz';
}
