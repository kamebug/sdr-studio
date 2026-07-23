// sdr_core — núcleo Rust do SDR Studio.

mod database;
mod driver_ffi;
mod dsp;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};

use rusqlite::Connection;

pub const SPECTRUM_BINS: usize = 256;

// Conexão persistente com o banco "de verdade" (arquivo em disco).
// Inicializada uma vez via `sdr_core_db_init`, usada por todas as
// funções de CRUD depois disso. Um `Mutex` porque, em teoria, chamadas
// FFI poderiam vir de threads diferentes — na prática hoje é só uma
// thread, mas é mais seguro já deixar protegido.
static DB: OnceLock<Mutex<Connection>> = OnceLock::new();

fn db() -> &'static Mutex<Connection> {
    DB.get()
        .expect("sdr_core_db_init precisa ser chamado antes de qualquer operação de banco")
}

/// Lê uma string C (ponteiro vindo do Dart) como String Rust.
/// Retorna string vazia se o ponteiro for nulo, em vez de crashar.
unsafe fn read_c_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}

// ---------------------------------------------------------------------
// Funções de diagnóstico / prototipagem (já existentes, mantidas)
// ---------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn sdr_core_add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn sdr_core_version() -> *const u8 {
    static VERSION: &[u8] = b"sdr_core 0.1.0 (frequency library prototype)\0";
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

// ---------------------------------------------------------------------
// Biblioteca de frequências (banco persistente) — a parte nova
// ---------------------------------------------------------------------

/// Abre (ou cria) o arquivo de banco no caminho informado pelo Dart, e
/// aplica o schema. Precisa ser chamada uma única vez, antes de qualquer
/// outra função de banco abaixo. Retorna 0 em sucesso, código negativo
/// em erro.
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
        // já tinha sido inicializado antes — não é um erro grave,
        // só avisa com um código diferente.
        return -4;
    }

    0
}

/// Insere uma nova frequência. Retorna o id da linha criada (>= 1) em
/// sucesso, ou -1 em erro.
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

/// Alterna o favorito (0 -> 1 ou 1 -> 0) de uma frequência pelo id.
/// Retorna 0 em sucesso, -1 se o id não existir ou der erro.
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

/// Remove uma frequência pelo id. Retorna 0 em sucesso, -1 em erro.
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

/// Retorna todas as frequências como uma string JSON — o Dart lê isso
/// com `jsonDecode` (nativo, sem pacote extra) e monta a lista da UI.
///
/// ATENÇÃO: a string retornada foi alocada aqui do lado Rust — quem
/// chama precisa depois passar esse mesmo ponteiro para
/// `sdr_core_free_string`, ou vaza memória.
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

/// Libera uma string alocada pelo Rust (usada por `sdr_core_list_frequencies`).
#[no_mangle]
pub extern "C" fn sdr_core_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
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
    fn persistent_db_crud_roundtrip() {
        // Banco em memória (":memory:" é um caminho especial do SQLite),
        // só para este teste — não interfere com o banco real do app.
        let path = CString::new(":memory:").unwrap();
        let init_result = sdr_core_db_init(path.as_ptr());
        // Pode já estar inicializado por outro teste rodando em paralelo
        // (cargo test roda testes em threads diferentes) — só falha se
        // o erro for de verdade (código -1, -2 ou -3), não -4 (já init).
        assert!(init_result == 0 || init_result == -4, "init_result = {init_result}");

        let mode = CString::new("FM").unwrap();
        let name = CString::new("Teste CRUD").unwrap();
        let id = sdr_core_add_frequency(144_000_000.0, mode.as_ptr(), name.as_ptr());
        assert!(id >= 1, "id = {id}");

        let toggle_result = sdr_core_toggle_favorite(id);
        assert_eq!(toggle_result, 0);

        let list_ptr = sdr_core_list_frequencies();
        let json = unsafe { CStr::from_ptr(list_ptr) }.to_str().unwrap();
        assert!(json.contains("Teste CRUD"));
        sdr_core_free_string(list_ptr);

        let delete_result = sdr_core_delete_frequency(id);
        assert_eq!(delete_result, 0);
    }
}
