// sdr_core — núcleo Rust do SDR Studio.

mod database;
mod driver_ffi;
mod dsp;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};

use rusqlite::Connection;

pub const SPECTRUM_BINS: usize = 256;

static DB: OnceLock<Mutex<Connection>> = OnceLock::new();

fn db() -> &'static Mutex<Connection> {
    DB.get()
        .expect("sdr_core_db_init precisa ser chamado antes de qualquer operação de banco")
}

unsafe fn read_c_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}

// ---------------------------------------------------------------------
// Diagnóstico / prototipagem
// ---------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sdr_core_add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn sdr_core_version() -> *const u8 {
    static VERSION: &[u8] = b"sdr_core 0.1.0 (history + settings prototype)\0";
    VERSION.as_ptr()
}

#[no_mangle]
pub extern "C" fn sdr_core_test_pipeline() -> f32 {
    let samples = driver_ffi::generate_test_signal(1000, 48000.0, 1000.0);
    let mean_abs: f32 = samples.iter().map(|x| x.abs()).sum::<f32>() / samples.len() as f32;
    mean_abs
}

#[no_mangle]
pub extern "C" fn sdr_core_detect_frequency() -> f32 {
    const SAMPLE_RATE: f32 = 48000.0;
    const TEST_TONE_HZ: f32 = 2500.0;
    const FFT_SIZE: usize = 4096;

    let samples = driver_ffi::generate_test_signal(FFT_SIZE, SAMPLE_RATE, TEST_TONE_HZ);
    dsp::find_peak_frequency(&samples, SAMPLE_RATE)
}

#[no_mangle]
pub extern "C" fn sdr_core_test_database() -> i32 {
    let conn = database::open_test_database();
    database::insert_and_count_frequencies(&conn) as i32
}

#[no_mangle]
pub extern "C" fn sdr_core_spectrum_bins() -> i32 {
    SPECTRUM_BINS as i32
}

#[no_mangle]
pub extern "C" fn sdr_core_generate_spectrum(freq_hz: f32) -> *mut f32 {
    const SAMPLE_RATE: f32 = 48000.0;
    let fft_size = SPECTRUM_BINS * 2;

    let samples = driver_ffi::generate_test_signal(fft_size, SAMPLE_RATE, freq_hz);
    let spectrum = dsp::compute_spectrum(&samples);

    let boxed_slice = spectrum.into_boxed_slice();
    Box::into_raw(boxed_slice) as *mut f32
}

#[no_mangle]
pub extern "C" fn sdr_core_free_spectrum(ptr: *mut f32) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(ptr, SPECTRUM_BINS));
    }
}

#[no_mangle]
pub extern "C" fn sdr_core_test_am_demod() -> f32 {
    const SAMPLE_RATE: f32 = 48000.0;
    const CARRIER_HZ: f32 = 5000.0;
    const MESSAGE_HZ: f32 = 200.0;
    const N: usize = 8192;

    let samples: Vec<f32> = (0..N)
        .map(|i| {
            let t = i as f32 / SAMPLE_RATE;
            let envelope = 1.0 + 0.5 * (2.0 * std::f32::consts::PI * MESSAGE_HZ * t).sin();
            envelope * (2.0 * std::f32::consts::PI * CARRIER_HZ * t).sin()
        })
        .collect();

    let demodulated = dsp::demodulate_am(&samples, 32);
    dsp::find_peak_frequency(&demodulated, SAMPLE_RATE)
}

#[no_mangle]
pub extern "C" fn sdr_core_test_fm_demod() -> f32 {
    const SAMPLE_RATE: f32 = 48000.0;
    const MESSAGE_HZ: f32 = 300.0;
    const FM_INDEX: f32 = 5.0;
    const N: usize = 8192;

    let mut i_samples = Vec::with_capacity(N);
    let mut q_samples = Vec::with_capacity(N);
    for k in 0..N {
        let t = k as f32 / SAMPLE_RATE;
        let phase = FM_INDEX * (2.0 * std::f32::consts::PI * MESSAGE_HZ * t).sin();
        i_samples.push(phase.cos());
        q_samples.push(phase.sin());
    }

    let demodulated = dsp::demodulate_fm(&i_samples, &q_samples);
    dsp::find_peak_frequency(&demodulated, SAMPLE_RATE)
}

// ---------------------------------------------------------------------
// Biblioteca de frequências (banco persistente)
// ---------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sdr_core_db_init(path_ptr: *const c_char) -> i32 {
    let path = unsafe { read_c_string(path_ptr) };
    if path.is_empty() {
        return -1;
    }

    let conn = match Connection::open(&path) {
        Ok(c) => c,
        Err(_) => return -2,
    };

    if conn.execute_batch(database::SCHEMA).is_err() {
        return -3;
    }

    if DB.set(Mutex::new(conn)).is_err() {
        return -4;
    }

    0
}

#[no_mangle]
pub extern "C" fn sdr_core_add_frequency(
    freq_hz: f64,
    mode_ptr: *const c_char,
    name_ptr: *const c_char,
) -> i64 {
    let mode = unsafe { read_c_string(mode_ptr) };
    let name = unsafe { read_c_string(name_ptr) };

    let conn = db().lock().expect("mutex poisoned");
    let result = conn.execute(
        "INSERT INTO frequencies (frequency_hz, mode, name) VALUES (?1, ?2, ?3)",
        rusqlite::params![freq_hz, mode, name],
    );

    match result {
        Ok(_) => conn.last_insert_rowid(),
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn sdr_core_toggle_favorite(id: i64) -> i32 {
    let conn = db().lock().expect("mutex poisoned");
    let result = conn.execute(
        "UPDATE frequencies SET is_favorite = 1 - is_favorite WHERE id = ?1",
        rusqlite::params![id],
    );
    match result {
        Ok(rows) if rows > 0 => 0,
        _ => -1,
    }
}

#[no_mangle]
pub extern "C" fn sdr_core_delete_frequency(id: i64) -> i32 {
    let conn = db().lock().expect("mutex poisoned");
    let result = conn.execute("DELETE FROM frequencies WHERE id = ?1", rusqlite::params![id]);
    match result {
        Ok(rows) if rows > 0 => 0,
        _ => -1,
    }
}

#[derive(serde::Serialize)]
struct FrequencyRow {
    id: i64,
    frequency_hz: f64,
    mode: String,
    name: String,
    is_favorite: bool,
}

#[no_mangle]
pub extern "C" fn sdr_core_list_frequencies() -> *mut c_char {
    let conn = db().lock().expect("mutex poisoned");

    let mut stmt = conn
        .prepare("SELECT id, frequency_hz, mode, name, is_favorite FROM frequencies ORDER BY id DESC")
        .expect("prepare failed");

    let rows: Vec<FrequencyRow> = stmt
        .query_map([], |row| {
            Ok(FrequencyRow {
                id: row.get(0)?,
                frequency_hz: row.get(1)?,
                mode: row.get(2)?,
                name: row.get::<_, Option<String>>(3)?.unwrap_or_default(),
                is_favorite: row.get::<_, i64>(4)? != 0,
            })
        })
        .expect("query failed")
        .filter_map(Result::ok)
        .collect();

    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string());
    CString::new(json).unwrap_or_default().into_raw()
}

#[no_mangle]
pub extern "C" fn sdr_core_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

// ---------------------------------------------------------------------
// Histórico de escuta
// ---------------------------------------------------------------------

/// Registra uma sessão de escuta (frequência, modo, duração em segundos).
/// Retorna o id criado, ou -1 em erro.
#[no_mangle]
pub extern "C" fn sdr_core_add_history(
    freq_hz: f64,
    mode_ptr: *const c_char,
    duration_seconds: i64,
) -> i64 {
    let mode = unsafe { read_c_string(mode_ptr) };

    let conn = db().lock().expect("mutex poisoned");
    let result = conn.execute(
        "INSERT INTO history (frequency_hz, mode, duration_seconds) VALUES (?1, ?2, ?3)",
        rusqlite::params![freq_hz, mode, duration_seconds],
    );

    match result {
        Ok(_) => conn.last_insert_rowid(),
        Err(_) => -1,
    }
}

#[derive(serde::Serialize)]
struct HistoryRow {
    id: i64,
    frequency_hz: f64,
    mode: String,
    listened_at: String,
    duration_seconds: i64,
}

/// Retorna as últimas 100 sessões de escuta, mais recentes primeiro,
/// como JSON.
#[no_mangle]
pub extern "C" fn sdr_core_list_history() -> *mut c_char {
    let conn = db().lock().expect("mutex poisoned");

    let mut stmt = conn
        .prepare(
            "SELECT id, frequency_hz, mode, listened_at, duration_seconds \
             FROM history ORDER BY id DESC LIMIT 100",
        )
        .expect("prepare failed");

    let rows: Vec<HistoryRow> = stmt
        .query_map([], |row| {
            Ok(HistoryRow {
                id: row.get(0)?,
                frequency_hz: row.get(1)?,
                mode: row.get(2)?,
                listened_at: row.get(3)?,
                duration_seconds: row.get::<_, Option<i64>>(4)?.unwrap_or_default(),
            })
        })
        .expect("query failed")
        .filter_map(Result::ok)
        .collect();

    let json = serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string());
    CString::new(json).unwrap_or_default().into_raw()
}

// ---------------------------------------------------------------------
// Configurações (settings)
// ---------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sdr_core_set_setting(
    key_ptr: *const c_char,
    value_ptr: *const c_char,
) -> i32 {
    let key = unsafe { read_c_string(key_ptr) };
    let value = unsafe { read_c_string(value_ptr) };

    let conn = db().lock().expect("mutex poisoned");
    let result = conn.execute(
        "INSERT INTO settings (key, value) VALUES (?1, ?2)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        rusqlite::params![key, value],
    );

    match result {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn sdr_core_get_setting(key_ptr: *const c_char) -> *mut c_char {
    let key = unsafe { read_c_string(key_ptr) };

    let conn = db().lock().expect("mutex poisoned");
    let value: String = conn
        .query_row(
            "SELECT value FROM settings WHERE key = ?1",
            rusqlite::params![key],
            |row| row.get(0),
        )
        .unwrap_or_default();

    CString::new(value).unwrap_or_default().into_raw()
}

// ---------------------------------------------------------------------
// Áudio em tempo real (demodulação sintética, tocável)
// ---------------------------------------------------------------------

pub const AUDIO_SAMPLE_RATE: u32 = 44100;
/// 100ms de áudio por bloco — casa com o intervalo do timer de UI (Dart),
/// mantendo a geração de áudio e a atualização visual no mesmo ritmo.
pub const AUDIO_CHUNK_SAMPLES: usize = 4410;

#[no_mangle]
pub extern "C" fn sdr_core_audio_sample_rate() -> i32 {
    AUDIO_SAMPLE_RATE as i32
}

#[no_mangle]
pub extern "C" fn sdr_core_audio_chunk_samples() -> i32 {
    AUDIO_CHUNK_SAMPLES as i32
}

/// Centraliza e normaliza a amplitude de um sinal demodulado para faixa
/// de áudio segura (-0.6 a 0.6, evitando saturação/estouro).
fn normalize_audio(samples: &[f32]) -> Vec<f32> {
    if samples.is_empty() {
        return Vec::new();
    }
    let mean: f32 = samples.iter().sum::<f32>() / samples.len() as f32;
    let centered: Vec<f32> = samples.iter().map(|s| s - mean).collect();
    let max = centered.iter().map(|s| s.abs()).fold(0.0_f32, f32::max);
    if max > 0.0001 {
        centered.iter().map(|s| (s / max) * 0.6).collect()
    } else {
        centered
    }
}

/// Gera um bloco de áudio demodulado (AM ou FM) pronto para tocar —
/// ainda a partir de um tom sintético, não de RF real. `mode_ptr` deve
/// ser "AM" ou "FM" (qualquer outra coisa cai no comportamento de FM).
///
/// Retorna um ponteiro para `AUDIO_CHUNK_SAMPLES` floats (-1.0 a 1.0).
/// ATENÇÃO: memória alocada aqui — chamar `sdr_core_free_audio_chunk`
/// depois de copiar os dados, ou vaza memória.
#[no_mangle]
pub extern "C" fn sdr_core_generate_audio_chunk(
    message_freq_hz: f32,
    mode_ptr: *const c_char,
) -> *mut f32 {
    let mode = unsafe { read_c_string(mode_ptr) };
    let sample_rate = AUDIO_SAMPLE_RATE as f32;
    let n = AUDIO_CHUNK_SAMPLES;

    let demodulated = if mode.eq_ignore_ascii_case("AM") {
        const CARRIER_HZ: f32 = 8000.0;
        let samples: Vec<f32> = (0..n)
            .map(|i| {
                let t = i as f32 / sample_rate;
                let envelope =
                    1.0 + 0.5 * (2.0 * std::f32::consts::PI * message_freq_hz * t).sin();
                envelope * (2.0 * std::f32::consts::PI * CARRIER_HZ * t).sin()
            })
            .collect();
        dsp::demodulate_am(&samples, 8)
    } else {
        const FM_INDEX: f32 = 3.0;
        let mut i_samples = Vec::with_capacity(n + 1);
        let mut q_samples = Vec::with_capacity(n + 1);
        for k in 0..=n {
            let t = k as f32 / sample_rate;
            let phase = FM_INDEX * (2.0 * std::f32::consts::PI * message_freq_hz * t).sin();
            i_samples.push(phase.cos());
            q_samples.push(phase.sin());
        }
        dsp::demodulate_fm(&i_samples, &q_samples)
    };

    let audio = normalize_audio(&demodulated);
    let boxed_slice = audio.into_boxed_slice();
    Box::into_raw(boxed_slice) as *mut f32
}

#[no_mangle]
pub extern "C" fn sdr_core_free_audio_chunk(ptr: *mut f32) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(ptr, AUDIO_CHUNK_SAMPLES));
    }
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

    #[test]
    fn spectrum_has_expected_length_and_is_normalized() {
        let ptr = sdr_core_generate_spectrum(1000.0);
        assert!(!ptr.is_null());
        let slice = unsafe { std::slice::from_raw_parts(ptr, SPECTRUM_BINS) };
        let max = slice.iter().cloned().fold(0.0_f32, f32::max);
        assert!((max - 1.0).abs() < 0.01);
        sdr_core_free_spectrum(ptr);
    }

    #[test]
    fn am_demod_pipeline_detects_message_frequency() {
        let result = sdr_core_test_am_demod();
        assert!((result - 200.0).abs() < 30.0, "result = {result}");
    }

    #[test]
    fn fm_demod_pipeline_detects_message_frequency() {
        let result = sdr_core_test_fm_demod();
        assert!((result - 300.0).abs() < 30.0, "result = {result}");
    }

    #[test]
    fn persistent_db_full_roundtrip() {
        let path = CString::new(":memory:").unwrap();
        let init_result = sdr_core_db_init(path.as_ptr());
        assert!(init_result == 0 || init_result == -4, "init_result = {init_result}");

        // Frequências
        let mode = CString::new("FM").unwrap();
        let name = CString::new("Teste CRUD").unwrap();
        let id = sdr_core_add_frequency(144_000_000.0, mode.as_ptr(), name.as_ptr());
        assert!(id >= 1, "id = {id}");
        assert_eq!(sdr_core_toggle_favorite(id), 0);

        let list_ptr = sdr_core_list_frequencies();
        let json = unsafe { CStr::from_ptr(list_ptr) }.to_str().unwrap();
        assert!(json.contains("Teste CRUD"));
        sdr_core_free_string(list_ptr);

        assert_eq!(sdr_core_delete_frequency(id), 0);

        // Configurações
        let key = CString::new("locale").unwrap();
        let value = CString::new("ja").unwrap();
        assert_eq!(sdr_core_set_setting(key.as_ptr(), value.as_ptr()), 0);
        let read_ptr = sdr_core_get_setting(key.as_ptr());
        let read_value = unsafe { CStr::from_ptr(read_ptr) }.to_str().unwrap();
        assert_eq!(read_value, "ja");
        sdr_core_free_string(read_ptr);

        // Histórico
        let hist_mode = CString::new("AM").unwrap();
        let hist_id = sdr_core_add_history(7_200_000.0, hist_mode.as_ptr(), 90);
        assert!(hist_id >= 1, "hist_id = {hist_id}");

        let hist_list_ptr = sdr_core_list_history();
        let hist_json = unsafe { CStr::from_ptr(hist_list_ptr) }.to_str().unwrap();
        assert!(hist_json.contains("7200000"));
        sdr_core_free_string(hist_list_ptr);
    }

    #[test]
    fn audio_chunk_fm_has_expected_length_and_safe_amplitude() {
        let mode = CString::new("FM").unwrap();
        let ptr = sdr_core_generate_audio_chunk(440.0, mode.as_ptr());
        assert!(!ptr.is_null());
        let slice = unsafe { std::slice::from_raw_parts(ptr, AUDIO_CHUNK_SAMPLES) };
        let max = slice.iter().map(|s| s.abs()).fold(0.0_f32, f32::max);
        assert!(max <= 0.61, "max amplitude = {max}");
        sdr_core_free_audio_chunk(ptr);
    }

    #[test]
    fn audio_chunk_am_has_expected_length_and_safe_amplitude() {
        let mode = CString::new("AM").unwrap();
        let ptr = sdr_core_generate_audio_chunk(440.0, mode.as_ptr());
        assert!(!ptr.is_null());
        let slice = unsafe { std::slice::from_raw_parts(ptr, AUDIO_CHUNK_SAMPLES) };
        let max = slice.iter().map(|s| s.abs()).fold(0.0_f32, f32::max);
        assert!(max <= 0.61, "max amplitude = {max}");
        sdr_core_free_audio_chunk(ptr);
    }
}
