# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Driver simulado (`drivers/stub/stub_device.c`) para gerar sinal sintético (onda senoidal) sem depender de hardware físico — usado para validar toda a cadeia antes do RTL-SDR chegar.
- `core/build.rs` com integração do crate `cc`, compilando o driver C e linkando estaticamente no core Rust — primeira validação da ponte C → Rust.
- `core/src/driver_ffi.rs`: wrapper Rust seguro ao redor da função C `stub_device_generate`.
- `core/src/dsp.rs`: primeiro módulo de DSP real do projeto — FFT (via `rustfft`) com detecção de frequência de pico, testado com tons sintéticos de 1000Hz e 5000Hz.
- `core/src/database.rs`: camada de acesso à biblioteca de frequências via SQLite embutido (`rusqlite`, feature `bundled` — não requer instalação de SQLite no sistema).
- `database/schema/001_initial.sql`: schema inicial com as tabelas `frequencies` (já reservando campos `category`/`country` para o banco mundial futuro), `history`, `profiles` e `profile_frequencies`.
- Funções expostas via FFI ao Dart: `sdr_core_add`, `sdr_core_version`, `sdr_core_test_pipeline`, `sdr_core_detect_frequency`, `sdr_core_test_database`.
- `tests/ffi_prototype/`: harness Dart puro (sem dependências externas) validando toda a cadeia C → Rust → Dart via `dart:ffi`.
- 11 testes automatizados no core Rust cobrindo driver FFI, DSP/FFT e banco de dados — todos passando.
- Esqueleto de internacionalização (`flutter_ui/lib/l10n/`) com strings base em EN/JP/PT.
- Documento de arquitetura e roadmap (`docs/PROJECT_CHARTER.md`).
- Estrutura inicial do repositório (core, drivers, flutter_ui, python, plugins, database, sdk, tests, docs) e licença MIT.

<!--
Categorias disponíveis: Added, Changed, Fixed, Deprecated, Removed, Security

## [0.1.0] - AAAA-MM-DD
### Added
- ...
-->