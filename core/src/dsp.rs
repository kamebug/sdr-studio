// dsp — processamento de sinal real do core.

use rustfft::{num_complex::Complex, FftPlanner};

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

    let max = magnitudes.iter().cloned().fold(0.0_f32, f32::max);
    if max > 0.0 {
        magnitudes.iter().map(|&m| m / max).collect()
    } else {
        magnitudes
    }
}

/// Média móvel simples — usada como filtro passa-baixa na demodulação AM,
/// pra suavizar a oscilação da portadora e sobrar só o envelope (a mensagem).
fn moving_average(samples: &[f32], window: usize) -> Vec<f32> {
    if window <= 1 {
        return samples.to_vec();
    }
    let mut result = Vec::with_capacity(samples.len());
    let mut sum = 0.0_f32;
    for (i, &s) in samples.iter().enumerate() {
        sum += s;
        if i >= window {
            sum -= samples[i - window];
        }
        let count = (i + 1).min(window) as f32;
        result.push(sum / count);
    }
    result
}

/// Demodulação AM: retificação (valor absoluto) seguida de um filtro
/// passa-baixa (média móvel) — o método clássico de "detecção de envelope".
/// A portadora oscila rápido demais para o filtro acompanhar e é suavizada
/// para fora; a mensagem original (que varia mais devagar) é o que sobra.
///
/// `smoothing_window` deve ser grande o bastante para suavizar a portadora
/// mas pequeno o bastante para não apagar a mensagem — normalmente uns
/// poucos ciclos da portadora, bem menos que um ciclo da mensagem.
pub fn demodulate_am(samples: &[f32], smoothing_window: usize) -> Vec<f32> {
    let rectified: Vec<f32> = samples.iter().map(|s| s.abs()).collect();
    moving_average(&rectified, smoothing_window)
}

/// Demodulação FM a partir de amostras IQ (banda base complexa): calcula
/// a diferença de fase entre amostras consecutivas — matematicamente,
/// o produto s[n] * conjugado(s[n-1]) tem como fase exatamente essa
/// diferença. Essa diferença de fase é proporcional ao desvio de
/// frequência instantâneo, que é o sinal original antes de modular.
///
/// Isso é o mesmo princípio usado por qualquer receptor FM real — a
/// diferença é que aqui `i_samples`/`q_samples` vêm de um sinal sintético
/// gerado matematicamente, não de uma captura de RF de verdade.
pub fn demodulate_fm(i_samples: &[f32], q_samples: &[f32]) -> Vec<f32> {
    let n = i_samples.len().min(q_samples.len());
    let mut output = Vec::with_capacity(n.saturating_sub(1));

    for k in 1..n {
        let (i0, q0) = (i_samples[k - 1], q_samples[k - 1]);
        let (i1, q1) = (i_samples[k], q_samples[k]);

        // s[k] * conj(s[k-1]):
        //   parte real = i1*i0 + q1*q0
        //   parte imaginária = q1*i0 - i1*q0
        let re = i1 * i0 + q1 * q0;
        let im = q1 * i0 - i1 * q0;

        output.push(im.atan2(re));
    }

    output
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

    #[test]
    fn am_demod_recovers_message_frequency() {
        let sample_rate = 48000.0;
        let carrier_freq = 5000.0;
        let message_freq = 200.0;
        let n = 8192;

        // Sinal AM clássico: portadora cuja amplitude varia conforme a
        // mensagem — envelope = 1.0 + 0.5*sin(mensagem).
        let samples: Vec<f32> = (0..n)
            .map(|i| {
                let t = i as f32 / sample_rate;
                let envelope = 1.0 + 0.5 * (2.0 * PI * message_freq * t).sin();
                envelope * (2.0 * PI * carrier_freq * t).sin()
            })
            .collect();

        let demodulated = demodulate_am(&samples, 32);
        let detected = find_peak_frequency(&demodulated, sample_rate);

        assert!(
            (detected - message_freq).abs() < 30.0,
            "detected = {detected}, esperado ~{message_freq}"
        );
    }

    #[test]
    fn fm_demod_recovers_message_frequency() {
        let sample_rate = 48000.0;
        let message_freq = 300.0;
        let fm_index = 5.0; // índice de modulação — quanto a fase "balança"

        let n = 8192;
        let mut i_samples = Vec::with_capacity(n);
        let mut q_samples = Vec::with_capacity(n);

        for k in 0..n {
            let t = k as f32 / sample_rate;
            let phase = fm_index * (2.0 * PI * message_freq * t).sin();
            i_samples.push(phase.cos());
            q_samples.push(phase.sin());
        }

        let demodulated = demodulate_fm(&i_samples, &q_samples);
        let detected = find_peak_frequency(&demodulated, sample_rate);

        assert!(
            (detected - message_freq).abs() < 30.0,
            "detected = {detected}, esperado ~{message_freq}"
        );
    }
}
