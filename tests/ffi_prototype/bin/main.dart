// Harness mínimo para validar a ponte Rust -> Dart.
//
// Não usa Flutter nem pacotes externos de propósito — o objetivo aqui é
// isolar exatamente a parte arriscada (dart:ffi carregando uma lib nativa)
// sem misturar com nada mais que possa mascarar um problema.

import 'dart:ffi';
import 'dart:io';

// Assinaturas em duas versões: a "Native" (como o Rust enxerga: tipos C)
// e a "Dart" (como o Dart enxerga: tipos Dart normais). dart:ffi exige as duas.
typedef AddNative = Int32 Function(Int32 a, Int32 b);
typedef AddDart = int Function(int a, int b);

typedef VersionNative = Pointer<Uint8> Function();
typedef VersionDart = Pointer<Uint8> Function();

/// Lê uma string C (bytes terminados em \0) a partir de um ponteiro,
/// sem depender do pacote `ffi` — feito manualmente de propósito
/// para manter este protótipo com zero dependências externas.
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
  // Ajuste este caminho se você mover a pasta core/ de lugar.
  const relativeBase = '../../core/target/debug';
  if (Platform.isWindows) return '$relativeBase/sdr_core.dll';
  if (Platform.isMacOS) return '$relativeBase/libsdr_core.dylib';
  return '$relativeBase/libsdr_core.so'; // Linux
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

  final sum = add(2, 3);
  final versionText = readCString(version());

  stdout.writeln('');
  stdout.writeln('✅ Ponte FFI Rust -> Dart funcionando.');
  stdout.writeln('sdr_core_add(2, 3)     = $sum');
  stdout.writeln('sdr_core_version()     = $versionText');
}
