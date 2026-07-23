// dsp — processamento de sinal real do core.
//
// Primeira peça de DSP de verdade do projeto: dado um bloco de amostras,
// calcula a FFT (Fast Fourier Transform) e encontra a frequência com maior
// energia — é exatamente o cálculo por trás de qualquer waterfall/espectro
// de SDR. Aqui ainda testamos com sinal sintético (do driver_ffi), mas a
// função em si é a mesma que será usada com amostras reais do RTL-SDR depois.

use rustfft::{num_complex::Complex, FftPlanner};

/// Recebe um bloco de amostras (sinal no domínio do tempo) e a taxa de
/// amostragem, e retorna a frequência (em Hz) com maior energia no espectro.
///
/// Resolução em frequência = sample_rate / samples.len() — quanto mais
/// amostras, mais preciso o resultado (e mais custoso computacionalmente).
pub fn find_peak_frequency(samples: &[f32], sample_rate: f32) -> f32 {
    let n = samples.len();

    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(n);

    let mut buffer: Vec<Complex<f32>> = samples
        .iter()
        .map(|&x| Complex { re: x, im: 0.0 })
        .collect();

    fft.process(&mut buffer);

    // Só a primeira metade importa (a segunda é espelho, por o sinal
    // de entrada ser real, não complexo) — frequências positivas.
    let mut max_magnitude = 0.0_f32;
    let mut max_index = 0_usize;

    for i in 1..n / 2 {
        let magnitude = buffer[i].norm();
        if magnitude > max_magnitude {
            max_magnitude = magnitude;
            max_index = i;
        }
    }

    max_index as f32 * sample_rate / n as f32
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f32::consts::PI;

    /// Gera uma senoide pura em Rust (sem depender do driver C),
    /// só para testar a FFT de forma isolada.
    fn sine_wave(len: usize, sample_rate: f32, freq: f32) -> Vec<f32> {
        (0..len)
            .map(|i| {
                let t = i as f32 / sample_rate;
                (2.0 * PI * freq * t).sin()
            })
            .collect()
    }

    #[test]
    fn detects_1000hz_tone() {
        let samples = sine_wave(4096, 48000.0, 1000.0);
        let detected = find_peak_frequency(&samples, 48000.0);
        // Resolução = 48000/4096 ≈ 11.7 Hz — tolerância generosa de 20 Hz.
        assert!((detected - 1000.0).abs() < 20.0, "detected = {detected}");
    }

    #[test]
    fn detects_different_tone() {
        let samples = sine_wave(4096, 48000.0, 5000.0);
        let detected = find_peak_frequency(&samples, 48000.0);
        assert!((detected - 5000.0).abs() < 20.0, "detected = {detected}");
    }
}
