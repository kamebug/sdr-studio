-- database/schema/001_initial.sql
--
-- Schema inicial da biblioteca de frequências (escopo do MVP), mais a
-- tabela de configurações (settings), usada para persistir preferências
-- simples do usuário (ex: idioma escolhido) sem precisar de pacote extra
-- como shared_preferences — reaproveita o mesmo banco SQLite já existente.

CREATE TABLE IF NOT EXISTS frequencies (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    frequency_hz  REAL    NOT NULL,
    mode          TEXT    NOT NULL,              -- 'AM', 'FM', etc.
    name          TEXT,                          -- ex: "Rádio Amador local"
    category      TEXT,                          -- ex: "Amateur Radio", "Aviation" — reservado p/ banco mundial futuro
    country       TEXT,                          -- ex: "JP", "BR" — reservado p/ banco mundial futuro
    notes         TEXT,
    is_favorite   INTEGER NOT NULL DEFAULT 0,     -- 0 = false, 1 = true (SQLite não tem BOOLEAN nativo)
    created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_frequencies_favorite ON frequencies (is_favorite);
CREATE INDEX IF NOT EXISTS idx_frequencies_hz ON frequencies (frequency_hz);

CREATE TABLE IF NOT EXISTS history (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    frequency_hz      REAL    NOT NULL,
    mode              TEXT    NOT NULL,
    listened_at       TEXT    NOT NULL DEFAULT (datetime('now')),
    duration_seconds  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_history_listened_at ON history (listened_at);

CREATE TABLE IF NOT EXISTS profiles (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,          -- ex: "Rádio amador", "Aviação"
    description TEXT,
    created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS profile_frequencies (
    profile_id    INTEGER NOT NULL REFERENCES profiles(id)    ON DELETE CASCADE,
    frequency_id  INTEGER NOT NULL REFERENCES frequencies(id) ON DELETE CASCADE,
    PRIMARY KEY (profile_id, frequency_id)
);

-- Configurações simples chave/valor (ex: idioma escolhido, tema).
-- "INSERT ... ON CONFLICT DO UPDATE" no Rust usa a PRIMARY KEY abaixo
-- para decidir entre inserir ou atualizar.
CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
