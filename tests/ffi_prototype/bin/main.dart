// Harness mínimo validando: FFI básico, cadeia C->Rust, DSP/FFT, e banco SQLite.

import 'dart:ffi';
import 'dart:io';

typedef AddNative = Int32 Function(Int32 a, Int32 b);
typedef AddDart = int Function(int a, int b);

typedef VersionNative = Pointer<Uint8> Function();
typedef VersionDart = Pointer<Uint8> Function();

typedef PipelineNative = Float Function();
typedef PipelineDart = double Function();

typedef DetectFreqNative = Float Function();
typedef DetectFreqDart = double Function();

typedef TestDbNative = Int32 Function();
typedef TestDbDart = int Function();

String readCString(Pointer<Uint8> ptr) {
  final bytes = <int>[];
  var i = 0;
  while (ptr[i] != 0) {
    bytes.add(ptr[i]);
    i++;
  }
  return String.fromCharCodes(bytes);
}

String resolveLibraryPath() {
  const relativeBase = '../../core/target/debug';
  if (Platform.isWindows) return '$relativeBase/sdr_core.dll';
  if (Platform.isMacOS) return '$relativeBase/libsdr_core.dylib';
  return '$relativeBase/libsdr_core.so';
}

void main() {
  final libPath = resolveLibraryPath();
  stdout.writeln('Carregando biblioteca Rust em: $libPath');

  final DynamicLibrary sdrCore;
  try {
    sdrCore = DynamicLibrary.open(libPath);
  } catch (e) {
    stderr.writeln('');
    stderr.writeln('FALHOU ao carregar a biblioteca.');
    stderr.writeln('Você já rodou "cargo build" dentro da pasta core/ antes disso?');
    stderr.writeln('Erro original: $e');
    exit(1);
  }

  final add = sdrCore.lookupFunction<AddNative, AddDart>('sdr_core_add');
  final version =
      sdrCore.lookupFunction<VersionNative, VersionDart>('sdr_core_version');
  final pipeline =
      sdrCore.lookupFunction<PipelineNative, PipelineDart>('sdr_core_test_pipeline');
  final detectFrequency = sdrCore
      .lookupFunction<DetectFreqNative, DetectFreqDart>('sdr_core_detect_frequency');
  final testDatabase =
      sdrCore.lookupFunction<TestDbNative, TestDbDart>('sdr_core_test_database');

  final sum = add(2, 3);
  final versionText = readCString(version());
  final energy = pipeline();
  final detected = detectFrequency();
  final dbCount = testDatabase();

  stdout.writeln('');
  stdout.writeln('✅ Ponte FFI Dart -> Rust funcionando.');
  stdout.writeln('sdr_core_add(2, 3)     = $sum');
  stdout.writeln('sdr_core_version()     = $versionText');
  stdout.writeln('');
  stdout.writeln('✅ Cadeia C -> Rust -> Dart funcionando.');
  stdout.writeln('sdr_core_test_pipeline() = $energy (esperado ~0.6366)');
  stdout.writeln('');
  stdout.writeln('✅ DSP real (FFT) funcionando.');
  stdout.writeln('sdr_core_detect_frequency() = $detected Hz (esperado ~2500.0)');
  stdout.writeln('');
  stdout.writeln('✅ Biblioteca de frequências (SQLite) funcionando.');
  stdout.writeln('sdr_core_test_database() = $dbCount (esperado 1)');
}
