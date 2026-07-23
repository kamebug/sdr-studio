# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Estrutura inicial do repositório (core, drivers, flutter_ui, python, plugins, database, sdk, tests, docs) e licença MIT.
- Documento de arquitetura e roadmap (`docs/PROJECT_CHARTER.md`).
- Esqueleto de internacionalização (`flutter_ui/lib/l10n/`) com strings base em EN/JP/PT.
- Driver simulado (`drivers/stub/stub_device.c`) para gerar sinal sintético (onda senoidal) sem depender de hardware físico — usado para validar toda a cadeia antes do RTL-SDR chegar.
- `core/build.rs` com integração do crate `cc`, compilando o driver C e linkando estaticamente no core Rust — primeira validação da ponte C → Rust.
- `core/src/driver_ffi.rs`: wrapper Rust seguro ao redor da função C `stub_device_generate`.
- `core/src/dsp.rs`: módulo de DSP real — FFT (via `rustfft`) com detecção de frequência de pico e cálculo de espectro completo.
- `core/src/database.rs`: camada de acesso à biblioteca de frequências via SQLite (`rusqlite`, feature `bundled` — não requer instalação de SQLite no sistema).
- `database/schema/001_initial.sql`: schema inicial com as tabelas `frequencies` (já reservando campos `category`/`country` para o banco mundial futuro), `history`, `profiles` e `profile_frequencies`.
- Banco de dados persistente (arquivo em disco): `sdr_core_db_init`, `sdr_core_add_frequency`, `sdr_core_toggle_favorite`, `sdr_core_delete_frequency`, `sdr_core_list_frequencies` (retorna JSON).
- `resolveDatabasePath()`: caminho estável do banco em `%APPDATA%\SDRStudio\` (Windows) — evita problema de caminho relativo mudar conforme onde o app é executado.
- `tests/ffi_prototype/`: harness Dart puro validando a cadeia C → Rust → Dart via `dart:ffi`.
- App Flutter inicial rodando no Windows: waterfall animado (dado sintético), controle de frequência, play/stop, seletor de idioma (EN/JP/PT) em tempo real.
- `flutter_ui/lib/sdr_core_bridge.dart`: camada única de acesso ao core Rust via FFI, isolando `dart:ffi` do resto da UI.
- `flutter_ui/lib/widgets/waterfall_painter.dart`: renderização do waterfall clássico (histórico de espectro + mapa de cor).
- `flutter_ui/lib/screens/frequency_library_screen.dart`: tela de biblioteca de frequências — listar, favoritar, remover, adicionar.
- Botão "Salvar" na tela principal grava a frequência atual do slider diretamente no banco.
- Funções expostas via FFI ao Dart: `sdr_core_add`, `sdr_core_version`, `sdr_core_test_pipeline`, `sdr_core_detect_frequency`, `sdr_core_test_database`, `sdr_core_spectrum_bins`, `sdr_core_generate_spectrum`, `sdr_core_free_spectrum`.
- 12 testes automatizados no core Rust cobrindo driver FFI, DSP/FFT, banco em memória e roundtrip completo de CRUD no banco persistente — todos passando.

### Changed
- `Cargo.toml`: adicionadas dependências `serde`/`serde_json` (serialização JSON da lista de frequências) e `rusqlite`.
- `pubspec.yaml`: adicionado pacote `ffi` (conversão de String Dart <-> string C, necessária para enviar texto ao Rust) e `flutter_localizations`/`intl` (i18n).
- `l10n.yaml`: removida a opção `synthetic-package` (obsoleta nas versões recentes do Flutter).

### Fixed
- N/A

<!--
Categorias disponíveis: Added, Changed, Fixed, Deprecated, Removed, Security

## [0.1.0] - AAAA-MM-DD
### Added
- ...
-->
