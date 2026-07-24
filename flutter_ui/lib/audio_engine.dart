import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Encapsula o motor de áudio (SoLoud) para tocar os blocos de áudio
/// gerados pelo core Rust em tempo real. Isolar isso aqui evita que o
/// resto do app precise conhecer detalhes do SoLoud — mesmo princípio
/// do [SdrCoreBridge] para o FFI: um único ponto de contato.
///
/// IMPORTANTE: por enquanto isso toca a demodulação de um TOM SINTÉTICO
/// gerado pelo core, não RF real — é a prova de que a cadeia
/// DSP (Rust) -> áudio (Dart/SoLoud) funciona de ponta a ponta, algo
/// para validar antes do RTL-SDR fornecer amostras de verdade.
class AudioEngine {
  AudioSource? _stream;
  SoundHandle? _handle;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await SoLoud.instance.init();
    _initialized = true;
  }

  /// Inicia uma nova sessão de streaming de áudio. Chame [feed]
  /// repetidamente depois disso para tocar os blocos gerados, e [stop]
  /// quando terminar.
  Future<void> start({required int sampleRate}) async {
    await _ensureInitialized();

    final stream = SoLoud.instance.setBufferStream(
      bufferingType: BufferingType.released,
      sampleRate: sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );

    _stream = stream;
    _handle = SoLoud.instance.play(stream);
  }

  /// Converte amostras float (-1.0 a 1.0, vindas do core Rust) para PCM
  /// 16-bit little-endian e alimenta o stream de áudio já em reprodução.
  void feed(List<double> samples) {
    final stream = _stream;
    if (stream == null || samples.isEmpty) return;

    final bytes = Uint8List(samples.length * 2);
    final byteData = ByteData.view(bytes.buffer);

    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final intSample = (clamped * 32767).round();
      byteData.setInt16(i * 2, intSample, Endian.little);
    }

    SoLoud.instance.addAudioDataStream(stream, bytes);
  }

  /// Ajusta o volume geral (0.0 a 1.0). Pode ser chamado a qualquer
  /// momento, mesmo antes de [start] — o valor fica valendo assim que
  /// o áudio começar a tocar.
  void setVolume(double volume) {
    SoLoud.instance.setGlobalVolume(volume.clamp(0.0, 1.0));
  }

  /// Encerra a sessão de streaming atual. Seguro chamar mesmo se nunca
  /// foi iniciado (não faz nada nesse caso).
  Future<void> stop() async {
    final stream = _stream;
    if (stream == null) return;

    SoLoud.instance.setDataIsEnded(stream);

    final handle = _handle;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }

    _stream = null;
    _handle = null;
  }
}
