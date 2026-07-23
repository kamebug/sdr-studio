// dsp — processamento de sinal real do core.

use rustfft::{num_complex::Complex, FftPlanner};

/// Recebe um bloco de amostras e retorna a frequência (em Hz) com maior
/// energia no espectro.
pub fn find_peak_frequency(samples: &[f32], sample_rate: f32) -> f32 {
    let n = samples.len();

    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(n);

    let mut buffer: Vec<Complex<f32>> = samples
        .iter()
        .map(|&x| Complex { re: x, im: 0.0 })
        .collect();

    fft.process(&mut buffer);

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

/// Calcula o espectro de magnitude completo (normalizado 0.0–1.0) de um
/// bloco de amostras — é o dado bruto usado para desenhar waterfall/espectro
/// na UI. Retorna metade do tamanho da FFT (só frequências positivas, já
/// que o sinal de entrada é real, não complexo).
pub fn compute_spectrum(samples: &[f32]) -> Vec<f32> {
    let n = samples.len();

    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(n);

    let mut buffer: Vec<Complex<f32>> = samples
        .iter()
        .map(|&x| Complex { re: x, im: 0.0 })
        .collect();

    fft.process(&mut buffer);

    let half = n / 2;
    let magnitudes: Vec<f32> = buffer[..half].iter().map(|c| c.norm()).collect();

    // Normaliza para 0.0–1.0 (o maior valor vira 1.0) — facilita desenhar
    // na UI sem a Dart precisar saber a escala absoluta da FFT.
    let max = magnitudes.iter().cloned().fold(0.0_f32, f32::max);
    if max > 0.0 {
        magnitudes.iter().map(|&m| m / max).collect()
    } else {
        magnitudes
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f32::consts::PI;

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
        assert!((detected - 1000.0).abs() < 20.0, "detected = {detected}");
    }

    #[test]
    fn detects_different_tone() {
        let samples = sine_wave(4096, 48000.0, 5000.0);
        let detected = find_peak_frequency(&samples, 48000.0);
        assert!((detected - 5000.0).abs() < 20.0, "detected = {detected}");
    }

    #[test]
    fn spectrum_is_normalized_between_zero_and_one() {
        let samples = sine_wave(1024, 48000.0, 2000.0);
        let spectrum = compute_spectrum(&samples);
        assert_eq!(spectrum.len(), 512);
        let max = spectrum.iter().cloned().fold(0.0_f32, f32::max);
        assert!((max - 1.0).abs() < 0.01);
        assert!(spectrum.iter().all(|&m| (0.0..=1.0).contains(&m)));
    }
}
