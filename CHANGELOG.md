# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Estrutura inicial do repositório (core, drivers, flutter_ui, python, plugins, database, sdk, tests, docs) e licença MIT.
- Documento de arquitetura e roadmap (`docs/PROJECT_CHARTER.md`).
- Driver simulado (`drivers/stub/stub_device.c`) para gerar sinal sintético sem depender de hardware físico.
- `core/build.rs` com integração do crate `cc`, compilando o driver C e linkando estaticamente no core Rust.
- `core/src/dsp.rs`: DSP real — FFT (`rustfft`), espectro completo, demodulação AM (envelope) e FM (diferença de fase entre amostras IQ).
- `core/src/database.rs` + `database/schema/001_initial.sql`: biblioteca de frequências, histórico, perfis e configurações via SQLite (`rusqlite`, bundled).
- Banco de dados persistente com CRUD completo: frequências, favoritos, histórico de escuta, configurações (idioma).
- Áudio em tempo real: `sdr_core_generate_audio_chunk` (demodulação AM/FM tocável) + `AudioEngine` (Dart, via `flutter_soloud`) tocando os blocos gerados pelo core.
- App Flutter completo rodando no Windows: waterfall + modo de visualização vetorial (linha fina, alternável), biblioteca de frequências, histórico de escuta, tela de configurações dedicada, controle de volume.
- Sistema de tema centralizado (`lib/theme/app_theme.dart`): paleta própria (grafite + acento âmbar), tipografia IBM Plex Sans/Mono, inspirado em instrumentos de laboratório digitais (não copia identidade visual de nenhuma marca real).
- `lib/widgets/spectrum_line_painter.dart`: visualização alternativa em traço fino (grade hairline, crosshair no pico), pensada para telas pequenas/mobile.
- Controle de frequência com três formas de ajuste sincronizadas: slider, campo de texto editável (com confirmação por Enter, perda de foco, ou botão ✓ — cobrindo teclado físico e touch), e passo configurável (1kHz/10kHz/100kHz/1MHz).
- `lib/utils/frequency_format.dart`: formatação de frequência com escala automática de unidade (Hz/kHz/MHz/GHz).
- Faixa de sintonia ajustada para a faixa real do RTL-SDR Blog V4 (500 kHz–1.766 GHz).
- Internacionalização completa (EN/JP/PT) com persistência de idioma entre reinicializações.
- `.github/workflows/ci.yml`: CI real — build e teste do core Rust em Linux e Windows (matriz), `flutter analyze` + `flutter build windows` no Flutter, a cada push/PR.
- 18 testes automatizados no core Rust — todos passando.

### Changed
- Widgets migrados para APIs não-depreciadas do Flutter mais recente (`withValues` em vez de `withOpacity`, `RadioGroup` em vez de `groupValue`/`onChanged` por item).
- `test/widget_test.dart` corrigido para referenciar `SdrStudioApp` (o widget raiz real), não o `MyApp` do template padrão.
- Geração do espectro/waterfall desacoplada da frequência de RF exibida (usa tom de demonstração fixo internamente — necessário porque a frequência agora cobre a faixa real de RF, muito além do que a FFT síncrona de 48kHz pode representar).

### Fixed
- N/A

<!--
Categorias disponíveis: Added, Changed, Fixed, Deprecated, Removed, Security

## [0.1.0] - AAAA-MM-DD
### Added
- ...
-->
