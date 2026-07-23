// database — camada de acesso à biblioteca de frequências (SQLite).
//
// `include_str!` embute o conteúdo do arquivo .sql dentro do binário
// compilado em tempo de compilação — ou seja, o schema em
// database/schema/001_initial.sql é a fonte da verdade (versionada,
// legível, editável), mas o Rust não precisa ler o arquivo em tempo de
// execução, só na hora de compilar.

use rusqlite::Connection;

const SCHEMA: &str = include_str!("../../database/schema/001_initial.sql");

/// Abre um banco em memória (não grava em disco) e aplica o schema.
/// Útil para testes e para este protótipo — o banco "de verdade" do app
/// vai abrir um arquivo .db em disco, mas a lógica de migração é a mesma.
pub fn open_test_database() -> Connection {
    let conn = Connection::open_in_memory().expect("failed to open in-memory database");
    conn.execute_batch(SCHEMA)
        .expect("failed to apply schema");
    conn
}

/// Insere uma frequência de teste e retorna quantas frequências existem
/// no banco depois disso — usado para provar que escrita E leitura
/// funcionam corretamente através da cadeia inteira.
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
        // Se chegou aqui sem panic, o schema foi aplicado com sucesso.
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
