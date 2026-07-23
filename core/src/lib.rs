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
    static VERSION: &[u8] = b"sdr_core 0.1.0 (AM/FM demod + settings prototype)\0";
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

/// Testa a demodulação AM de ponta a ponta: gera um sinal AM sintético
/// (portadora 5000Hz modulada por uma mensagem de 200Hz), demodula, e
/// retorna a frequência detectada no resultado — deve ficar perto de
/// 200Hz se a demodulação funcionou (não 5000Hz, que seria sinal de que
/// a demodulação não removeu a portadora).
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

/// Testa a demodulação FM de ponta a ponta: gera um sinal FM sintético
/// (mensagem de 300Hz modulando a fase), demodula, e retorna a frequência
/// detectada — deve ficar perto de 300Hz.
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
// Configurações (settings) — chave/valor simples, ex: idioma escolhido
// ---------------------------------------------------------------------

/// Salva (ou atualiza) uma configuração. Retorna 0 em sucesso.
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

/// Lê uma configuração salva. Retorna string vazia (não nulo) se a chave
/// não existir — mais simples de tratar do lado Dart do que checar nulo.
/// Memória alocada aqui — chamar `sdr_core_free_string` depois.
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
    fn persistent_db_crud_and_settings_roundtrip() {
        let path = CString::new(":memory:").unwrap();
        let init_result = sdr_core_db_init(path.as_ptr());
        assert!(init_result == 0 || init_result == -4, "init_result = {init_result}");

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

        // Settings
        let key = CString::new("locale").unwrap();
        let value = CString::new("ja").unwrap();
        assert_eq!(sdr_core_set_setting(key.as_ptr(), value.as_ptr()), 0);

        let read_ptr = sdr_core_get_setting(key.as_ptr());
        let read_value = unsafe { CStr::from_ptr(read_ptr) }.to_str().unwrap();
        assert_eq!(read_value, "ja");
        sdr_core_free_string(read_ptr);
    }
}
