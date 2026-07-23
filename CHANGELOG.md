# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Estrutura inicial do repositório (core, drivers, flutter_ui, python, plugins, database, sdk, tests, docs) e licença MIT.
- Documento de arquitetura e roadmap (`docs/PROJECT_CHARTER.md`).
- Esqueleto de internacionalização (`flutter_ui/lib/l10n/`) com strings base em EN/JP/PT.
- Driver simulado (`drivers/stub/stub_device.c`) para gerar sinal sintético sem depender de hardware físico.
- `core/build.rs` com integração do crate `cc`, compilando o driver C e linkando estaticamente no core Rust.
- `core/src/driver_ffi.rs`: wrapper Rust seguro ao redor da função C `stub_device_generate`.
- `core/src/dsp.rs`: DSP real — FFT (`rustfft`) com detecção de frequência de pico e espectro completo, mais demodulação AM (detecção de envelope) e FM (diferença de fase entre amostras IQ), testadas com sinal sintético modulado.
- `core/src/database.rs`: camada de acesso à biblioteca de frequências via SQLite (`rusqlite`, feature `bundled`).
- `database/schema/001_initial.sql`: tabelas `frequencies` (com `category`/`country` reservados para o banco mundial futuro), `history`, `profiles`, `profile_frequencies`, e `settings` (configurações chave/valor, ex: idioma escolhido).
- Banco de dados persistente (arquivo em disco): `sdr_core_db_init`, `sdr_core_add_frequency`, `sdr_core_toggle_favorite`, `sdr_core_delete_frequency`, `sdr_core_list_frequencies`, `sdr_core_set_setting`, `sdr_core_get_setting`.
- `resolveDatabasePath()`: caminho estável do banco em `%APPDATA%\SDRStudio\` (Windows).
- `tests/ffi_prototype/`: harness Dart puro validando a cadeia C → Rust → Dart via `dart:ffi`.
- App Flutter rodando no Windows: waterfall animado (dado sintético), controle de frequência, play/stop, seletor de idioma (EN/JP/PT) em tempo real com persistência entre reinicializações.
- `flutter_ui/lib/sdr_core_bridge.dart`: camada única de acesso ao core Rust via FFI.
- `flutter_ui/lib/widgets/waterfall_painter.dart`: renderização do waterfall clássico.
- `flutter_ui/lib/screens/frequency_library_screen.dart`: tela de biblioteca de frequências — listar, favoritar, remover, adicionar.
- Botão "Salvar" na tela principal grava a frequência atual do slider diretamente no banco.
- Funções expostas via FFI ao Dart: `sdr_core_add`, `sdr_core_version`, `sdr_core_test_pipeline`, `sdr_core_detect_frequency`, `sdr_core_test_database`, `sdr_core_spectrum_bins`, `sdr_core_generate_spectrum`, `sdr_core_free_spectrum`, `sdr_core_test_am_demod`, `sdr_core_test_fm_demod`, `sdr_core_set_setting`, `sdr_core_get_setting`.
- 18 testes automatizados no core Rust — todos passando (driver FFI, DSP/FFT, demodulação AM/FM, banco em memória, CRUD persistente, configurações).

### Changed
- `Cargo.toml`: dependências `serde`/`serde_json` (JSON da lista de frequências) e `rusqlite`.
- `pubspec.yaml`: pacote `ffi` (conversão String Dart <-> string C) e `flutter_localizations`/`intl` (i18n).
- `l10n.yaml`: removida a opção `synthetic-package` (obsoleta nas versões recentes do Flutter).
- `main.dart`: agora carrega o idioma salvo do banco na inicialização, em vez de sempre abrir em inglês.

### Fixed
- N/A

<!--
Categorias disponíveis: Added, Changed, Fixed, Deprecated, Removed, Security

## [0.1.0] - AAAA-MM-DD
### Added
- ...
-->
