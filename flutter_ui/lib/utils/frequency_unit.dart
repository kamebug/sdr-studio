/// Unidade usada para DIGITAR a frequência no campo de texto — não
/// afeta o display grande de dígitos (esse sempre mostra Hz agrupado,
/// convenção clássica de SDR#/HDSDR/SDRuno).
///
/// Existe separado porque digitar "112.123" selecionando MHz é mais
/// natural do que digitar "112123000" em Hz cru — a unidade só
/// controla como o texto digitado é interpretado/convertido.
enum FrequencyUnit { hz, khz, mhz, ghz }

extension FrequencyUnitX on FrequencyUnit {
  /// Multiplicador para converter um valor NESSA unidade para Hz.
  double get factor {
    switch (this) {
      case FrequencyUnit.hz:
        return 1;
      case FrequencyUnit.khz:
        return 1e3;
      case FrequencyUnit.mhz:
        return 1e6;
      case FrequencyUnit.ghz:
        return 1e9;
    }
  }

  String get label {
    switch (this) {
      case FrequencyUnit.hz:
        return 'Hz';
      case FrequencyUnit.khz:
        return 'kHz';
      case FrequencyUnit.mhz:
        return 'MHz';
      case FrequencyUnit.ghz:
        return 'GHz';
    }
  }

  /// Quantas casas decimais mostrar nessa unidade para não perder
  /// precisão de Hz ao converter (ex: em MHz, 6 casas decimais ainda
  /// representam Hz exatos: 112.123456 MHz = 112123456 Hz).
  int get decimalDigits {
    switch (this) {
      case FrequencyUnit.hz:
        return 0;
      case FrequencyUnit.khz:
        return 3;
      case FrequencyUnit.mhz:
        return 6;
      case FrequencyUnit.ghz:
        return 9;
    }
  }

  /// Converte um valor em Hz para esta unidade, como string pronta
  /// para exibir no campo de texto.
  String fromHz(double hz) {
    return (hz / factor).toStringAsFixed(decimalDigits);
  }

  /// Converte um texto digitado NESTA unidade de volta para Hz.
  /// Retorna null se não conseguir interpretar o texto.
  double? toHz(String text) {
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return null;
    return parsed * factor;
  }
}
