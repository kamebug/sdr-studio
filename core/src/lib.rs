// sdr_core — núcleo Rust do SDR Studio.
//
// Estágio atual: arquitetura polyglot completa (C -> Rust -> Dart),
// DSP real (FFT), e biblioteca de frequências (SQLite) validados.

mod database;
mod driver_ffi;
mod dsp;

/// Soma dois números — função trivial só para provar que a chamada
/// Dart -> Rust funciona e retorna o valor corretamente.
#[no_mangle]
pub extern "C" fn sdr_core_add(a: i32, b: i32) -> i32 {
    a + b
}

/// Retorna a versão do core como string C (bytes terminados em \0).
#[no_mangle]
pub extern "C" fn sdr_core_version() -> *const u8 {
    static VERSION: &[u8] = b"sdr_core 0.1.0 (DSP + database prototype)\0";
    VERSION.as_ptr()
}

/// Valida a cadeia completa com um cálculo simples (amplitude média).
#[no_mangle]
pub extern "C" fn sdr_core_test_pipeline() -> f32 {
    let samples = driver_ffi::generate_test_signal(1000, 48000.0, 1000.0);
    let mean_abs: f32 = samples.iter().map(|x| x.abs()).sum::<f32>() / samples.len() as f32;
    mean_abs
}

/// DSP real: gera sinal sintético via driver C, roda FFT em Rust,
/// retorna a frequência de pico detectada.
#[no_mangle]
pub extern "C" fn sdr_core_detect_frequency() -> f32 {
    const SAMPLE_RATE: f32 = 48000.0;
    const TEST_TONE_HZ: f32 = 2500.0;
    const FFT_SIZE: usize = 4096;

    let samples = driver_ffi::generate_test_signal(FFT_SIZE, SAMPLE_RATE, TEST_TONE_HZ);
    dsp::find_peak_frequency(&samples, SAMPLE_RATE)
}

/// Biblioteca de frequências: abre um banco SQLite em memória, aplica o
/// schema, insere uma frequência de teste, e retorna quantas existem —
/// prova que escrita e leitura no banco funcionam corretamente.
#[no_mangle]
pub extern "C" fn sdr_core_test_database() -> i32 {
    let conn = database::open_test_database();
    database::insert_and_count_frequencies(&conn) as i32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_works() {
        assert_eq!(sdr_core_add(2, 3), 5);
    }

    #[test]
    fn pipeline_returns_expected_amplitude() {
        let result = sdr_core_test_pipeline();
        assert!((result - 0.6366).abs() < 0.05);
    }

    #[test]
    fn full_chain_detects_frequency() {
        let result = sdr_core_detect_frequency();
        assert!((result - 2500.0).abs() < 20.0, "detected = {result}");
    }

    #[test]
    fn database_roundtrip_works() {
        let count = sdr_core_test_database();
        assert_eq!(count, 1);
    }
}
