// sdr_core — núcleo Rust do SDR Studio.
//
// Neste estágio de protótipo, o objetivo NÃO é DSP de verdade —
// é validar que Rust consegue expor funções que o Dart/Flutter
// conseguem enxergar e chamar através de FFI (Foreign Function Interface).
//
// Duas regras para qualquer função exposta:
//   1. `extern "C"` — usa a convenção de chamada C, que é o "idioma comum"
//      que Rust, C/C++ e Dart conseguem falar entre si.
//   2. `#[no_mangle]` — impede o compilador Rust de renomear a função
//      internamente, para que o nome `sdr_core_add` apareça exatamente
//      assim na biblioteca compilada, e o Dart consiga encontrá-lo pelo nome.

/// Soma dois números — função trivial só para provar que a chamada
/// Dart -> Rust funciona e retorna o valor corretamente.
#[no_mangle]
pub extern "C" fn sdr_core_add(a: i32, b: i32) -> i32 {
    a + b
}

/// Retorna a versão do core como string C (bytes terminados em \0).
/// Prova que também dá para trafegar texto através da ponte, não só números —
/// será necessário depois para nomes de dispositivo, mensagens de erro, etc.
#[no_mangle]
pub extern "C" fn sdr_core_version() -> *const u8 {
    static VERSION: &[u8] = b"sdr_core 0.1.0 (FFI bridge prototype)\0";
    VERSION.as_ptr()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_works() {
        assert_eq!(sdr_core_add(2, 3), 5);
    }
}
