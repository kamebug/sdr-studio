// driver_ffi — camada de ponte entre o core Rust e os drivers C/C++.
//
// O bloco `extern "C"` abaixo declara ao Rust "essa função existe em algum
// lugar, compilada em C, confie em mim" — é o compilador C (via build.rs)
// que efetivamente a implementa; aqui só declaramos a assinatura.
//
// Repare que este módulo é privado (não tem `pub extern "C"` nem `#[no_mangle]`)
// — ele existe só para uso interno do core Rust. Quem conversa com o Dart
// é o lib.rs, através de funções Rust seguras como `generate_test_signal`.

extern "C" {
    fn stub_device_generate(buffer: *mut f32, len: i32, sample_rate: f32, freq: f32);
}

/// Wrapper seguro em Rust ao redor da função C insegura (unsafe).
/// É essa a fronteira onde "unsafe" do C vira uma API Rust normal e segura
/// para o resto do core usar.
pub fn generate_test_signal(len: usize, sample_rate: f32, freq: f32) -> Vec<f32> {
    let mut buffer = vec![0f32; len];
    unsafe {
        stub_device_generate(buffer.as_mut_ptr(), len as i32, sample_rate, freq);
    }
    buffer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generates_expected_length() {
        let samples = generate_test_signal(100, 48000.0, 1000.0);
        assert_eq!(samples.len(), 100);
    }

    #[test]
    fn generates_non_trivial_signal() {
        let samples = generate_test_signal(1000, 48000.0, 1000.0);
        // Uma senoide de verdade não deve ser tudo zero.
        let has_variation = samples.iter().any(|&x| x.abs() > 0.01);
        assert!(has_variation);
    }
}
