// database — camada de acesso à biblioteca de frequências (SQLite).

use rusqlite::Connection;

// pub(crate) — visível para o resto do crate (lib.rs precisa usar ao
// inicializar o banco persistente), mas não exposto fora do core.
pub(crate) const SCHEMA: &str = include_str!("../../database/schema/001_initial.sql");

/// Abre um banco em memória (não grava em disco) e aplica o schema.
/// Usado só em testes — o banco "de verdade" do app usa um arquivo em
/// disco, inicializado em lib.rs via `sdr_core_db_init`.
pub fn open_test_database() -> Connection {
    let conn = Connection::open_in_memory().expect("failed to open in-memory database");
    conn.execute_batch(SCHEMA)
        .expect("failed to apply schema");
    conn
}

pub fn insert_and_count_frequencies(conn: &Connection) -> i64 {
    conn.execute(
        "INSERT INTO frequencies (frequency_hz, mode, name, is_favorite) VALUES (?1, ?2, ?3, ?4)",
        rusqlite::params![144_000_000.0_f64, "FM", "Repetidora de teste", 1],
    )
    .expect("insert failed");

    conn.query_row("SELECT COUNT(*) FROM frequencies", [], |row| row.get(0))
        .expect("count query failed")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_applies_without_error() {
        let _conn = open_test_database();
    }

    #[test]
    fn insert_and_read_back() {
        let conn = open_test_database();
        let count = insert_and_count_frequencies(&conn);
        assert_eq!(count, 1);
    }

    #[test]
    fn favorite_flag_is_stored_correctly() {
        let conn = open_test_database();
        insert_and_count_frequencies(&conn);

        let is_favorite: i64 = conn
            .query_row(
                "SELECT is_favorite FROM frequencies WHERE name = ?1",
                rusqlite::params!["Repetidora de teste"],
                |row| row.get(0),
            )
            .expect("query failed");

        assert_eq!(is_favorite, 1);
    }
}
