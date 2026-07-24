import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _AddNative = Int32 Function(Int32 a, Int32 b);
typedef _AddDart = int Function(int a, int b);

typedef _VersionNative = Pointer<Uint8> Function();
typedef _VersionDart = Pointer<Uint8> Function();

typedef _SpectrumBinsNative = Int32 Function();
typedef _SpectrumBinsDart = int Function();

typedef _GenSpectrumNative = Pointer<Float> Function(Float freqHz);
typedef _GenSpectrumDart = Pointer<Float> Function(double freqHz);

typedef _FreeSpectrumNative = Void Function(Pointer<Float> ptr);
typedef _FreeSpectrumDart = void Function(Pointer<Float> ptr);

typedef _DbInitNative = Int32 Function(Pointer<Utf8> path);
typedef _DbInitDart = int Function(Pointer<Utf8> path);

typedef _AddFreqNative = Int64 Function(
    Double freqHz, Pointer<Utf8> mode, Pointer<Utf8> name);
typedef _AddFreqDart = int Function(
    double freqHz, Pointer<Utf8> mode, Pointer<Utf8> name);

typedef _ToggleFavNative = Int32 Function(Int64 id);
typedef _ToggleFavDart = int Function(int id);

typedef _DeleteFreqNative = Int32 Function(Int64 id);
typedef _DeleteFreqDart = int Function(int id);

typedef _ListFreqNative = Pointer<Utf8> Function();
typedef _ListFreqDart = Pointer<Utf8> Function();

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef _SetSettingNative = Int32 Function(
    Pointer<Utf8> key, Pointer<Utf8> value);
typedef _SetSettingDart = int Function(Pointer<Utf8> key, Pointer<Utf8> value);

typedef _GetSettingNative = Pointer<Utf8> Function(Pointer<Utf8> key);
typedef _GetSettingDart = Pointer<Utf8> Function(Pointer<Utf8> key);

typedef _AddHistoryNative = Int64 Function(
    Double freqHz, Pointer<Utf8> mode, Int64 durationSeconds);
typedef _AddHistoryDart = int Function(
    double freqHz, Pointer<Utf8> mode, int durationSeconds);

typedef _ListHistoryNative = Pointer<Utf8> Function();
typedef _ListHistoryDart = Pointer<Utf8> Function();

typedef _AudioSampleRateNative = Int32 Function();
typedef _AudioSampleRateDart = int Function();

typedef _AudioChunkSamplesNative = Int32 Function();
typedef _AudioChunkSamplesDart = int Function();

typedef _GenAudioChunkNative = Pointer<Float> Function(
    Float freqHz, Pointer<Utf8> mode);
typedef _GenAudioChunkDart = Pointer<Float> Function(
    double freqHz, Pointer<Utf8> mode);

typedef _FreeAudioChunkNative = Void Function(Pointer<Float> ptr);
typedef _FreeAudioChunkDart = void Function(Pointer<Float> ptr);

String resolveDatabasePath() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? Directory.current.path;
    final dir = Directory('$appData\\SDRStudio');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return '${dir.path}\\sdr_studio.db';
  }

  final home = Platform.environment['HOME'] ?? Directory.current.path;
  final dir = Directory('$home/.sdr_studio');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return '${dir.path}/sdr_studio.db';
}

/// Camada única de acesso ao core Rust (sdr_core.dll/.so/.dylib).
class SdrCoreBridge {
  SdrCoreBridge._(this._lib) {
    _add = _lib.lookupFunction<_AddNative, _AddDart>('sdr_core_add');
    _version = _lib
        .lookupFunction<_VersionNative, _VersionDart>('sdr_core_version');
    _spectrumBins = _lib.lookupFunction<_SpectrumBinsNative,
        _SpectrumBinsDart>('sdr_core_spectrum_bins');
    _generateSpectrum = _lib.lookupFunction<_GenSpectrumNative,
        _GenSpectrumDart>('sdr_core_generate_spectrum');
    _freeSpectrum = _lib.lookupFunction<_FreeSpectrumNative,
        _FreeSpectrumDart>('sdr_core_free_spectrum');
    _dbInit =
        _lib.lookupFunction<_DbInitNative, _DbInitDart>('sdr_core_db_init');
    _addFrequency = _lib.lookupFunction<_AddFreqNative, _AddFreqDart>(
        'sdr_core_add_frequency');
    _toggleFavorite = _lib.lookupFunction<_ToggleFavNative, _ToggleFavDart>(
        'sdr_core_toggle_favorite');
    _deleteFrequency = _lib.lookupFunction<_DeleteFreqNative,
        _DeleteFreqDart>('sdr_core_delete_frequency');
    _listFrequencies = _lib.lookupFunction<_ListFreqNative, _ListFreqDart>(
        'sdr_core_list_frequencies');
    _freeString = _lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
        'sdr_core_free_string');
    _setSetting = _lib.lookupFunction<_SetSettingNative, _SetSettingDart>(
        'sdr_core_set_setting');
    _getSetting = _lib.lookupFunction<_GetSettingNative, _GetSettingDart>(
        'sdr_core_get_setting');
    _addHistory = _lib.lookupFunction<_AddHistoryNative, _AddHistoryDart>(
        'sdr_core_add_history');
    _listHistory = _lib.lookupFunction<_ListHistoryNative, _ListHistoryDart>(
        'sdr_core_list_history');
    _audioSampleRate = _lib.lookupFunction<_AudioSampleRateNative,
        _AudioSampleRateDart>('sdr_core_audio_sample_rate');
    _audioChunkSamples = _lib.lookupFunction<_AudioChunkSamplesNative,
        _AudioChunkSamplesDart>('sdr_core_audio_chunk_samples');
    _generateAudioChunk = _lib.lookupFunction<_GenAudioChunkNative,
        _GenAudioChunkDart>('sdr_core_generate_audio_chunk');
    _freeAudioChunk = _lib.lookupFunction<_FreeAudioChunkNative,
        _FreeAudioChunkDart>('sdr_core_free_audio_chunk');
  }

  final DynamicLibrary _lib;
  late final _AddDart _add;
  late final _VersionDart _version;
  late final _SpectrumBinsDart _spectrumBins;
  late final _GenSpectrumDart _generateSpectrum;
  late final _FreeSpectrumDart _freeSpectrum;
  late final _DbInitDart _dbInit;
  late final _AddFreqDart _addFrequency;
  late final _ToggleFavDart _toggleFavorite;
  late final _DeleteFreqDart _deleteFrequency;
  late final _ListFreqDart _listFrequencies;
  late final _FreeStringDart _freeString;
  late final _SetSettingDart _setSetting;
  late final _GetSettingDart _getSetting;
  late final _AddHistoryDart _addHistory;
  late final _ListHistoryDart _listHistory;
  late final _AudioSampleRateDart _audioSampleRate;
  late final _AudioChunkSamplesDart _audioChunkSamples;
  late final _GenAudioChunkDart _generateAudioChunk;
  late final _FreeAudioChunkDart _freeAudioChunk;

  static SdrCoreBridge? _instance;

  factory SdrCoreBridge.load() {
    if (_instance != null) return _instance!;

    final fileName = Platform.isWindows
        ? 'sdr_core.dll'
        : Platform.isMacOS
            ? 'libsdr_core.dylib'
            : 'libsdr_core.so';

    final candidates = <String>[
      fileName,
      '../../core/target/debug/$fileName',
      '../../../core/target/debug/$fileName',
      '../../../../core/target/debug/$fileName',
      'core/target/debug/$fileName',
    ];

    DynamicLibrary? lib;
    final attempted = <String>[];
    for (final path in candidates) {
      try {
        lib = DynamicLibrary.open(path);
        break;
      } catch (_) {
        attempted.add(path);
      }
    }

    if (lib == null) {
      throw StateError(
        'Não foi possível carregar $fileName.\n'
        'Caminhos tentados: ${attempted.join(", ")}\n\n'
        'Solução: copie core/target/debug/$fileName para a raiz da '
        'pasta flutter_ui/.',
      );
    }

    _instance = SdrCoreBridge._(lib);
    return _instance!;
  }

  int add(int a, int b) => _add(a, b);

  String version() {
    final ptr = _version();
    final bytes = <int>[];
    var i = 0;
    while (ptr[i] != 0) {
      bytes.add(ptr[i]);
      i++;
    }
    return String.fromCharCodes(bytes);
  }

  int get spectrumBins => _spectrumBins();

  List<double> generateSpectrum(double freqHz) {
    final ptr = _generateSpectrum(freqHz);
    final bins = spectrumBins;
    final result = List<double>.generate(bins, (i) => ptr[i]);
    _freeSpectrum(ptr);
    return result;
  }

  void initDatabase([String? path]) {
    final dbPath = path ?? resolveDatabasePath();
    final pathPtr = dbPath.toNativeUtf8();
    try {
      final result = _dbInit(pathPtr);
      if (result != 0 && result != -4) {
        throw StateError('Falha ao inicializar o banco (código $result)');
      }
    } finally {
      calloc.free(pathPtr);
    }
  }

  int addFrequency({
    required double freqHz,
    required String mode,
    required String name,
  }) {
    final modePtr = mode.toNativeUtf8();
    final namePtr = name.toNativeUtf8();
    try {
      return _addFrequency(freqHz, modePtr, namePtr);
    } finally {
      calloc.free(modePtr);
      calloc.free(namePtr);
    }
  }

  bool toggleFavorite(int id) => _toggleFavorite(id) == 0;

  bool deleteFrequency(int id) => _deleteFrequency(id) == 0;

  List<Map<String, dynamic>> listFrequencies() {
    final ptr = _listFrequencies();
    final jsonStr = ptr.toDartString();
    _freeString(ptr);
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  void setSetting(String key, String value) {
    final keyPtr = key.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    try {
      _setSetting(keyPtr, valuePtr);
    } finally {
      calloc.free(keyPtr);
      calloc.free(valuePtr);
    }
  }

  String getSetting(String key, {String fallback = ''}) {
    final keyPtr = key.toNativeUtf8();
    try {
      final ptr = _getSetting(keyPtr);
      final value = ptr.toDartString();
      _freeString(ptr);
      return value.isEmpty ? fallback : value;
    } finally {
      calloc.free(keyPtr);
    }
  }

  /// Registra uma sessão de escuta no histórico.
  int addHistory({
    required double freqHz,
    required String mode,
    required int durationSeconds,
  }) {
    final modePtr = mode.toNativeUtf8();
    try {
      return _addHistory(freqHz, modePtr, durationSeconds);
    } finally {
      calloc.free(modePtr);
    }
  }

  /// Retorna as últimas sessões de escuta, mais recentes primeiro.
  List<Map<String, dynamic>> listHistory() {
    final ptr = _listHistory();
    final jsonStr = ptr.toDartString();
    _freeString(ptr);
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Taxa de amostragem do áudio gerado (Hz) — usar ao configurar o
  /// motor de áudio, para casar exatamente com o que o Rust produz.
  int get audioSampleRate => _audioSampleRate();

  /// Quantidade fixa de amostras por bloco de áudio gerado.
  int get audioChunkSamples => _audioChunkSamples();

  /// Gera um bloco de áudio demodulado (AM ou FM) a partir de um tom
  /// sintético — ainda não é RF real, mas já é a demodulação de verdade
  /// rodando e tocável. Retorna amostras float (-1.0 a 1.0).
  List<double> generateAudioChunk(double freqHz, String mode) {
    final modePtr = mode.toNativeUtf8();
    try {
      final ptr = _generateAudioChunk(freqHz, modePtr);
      final n = audioChunkSamples;
      final result = List<double>.generate(n, (i) => ptr[i]);
      _freeAudioChunk(ptr);
      return result;
    } finally {
      calloc.free(modePtr);
    }
  }
}
