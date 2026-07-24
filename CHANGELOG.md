# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Estrutura inicial do repositório, arquitetura polyglot (C/Rust/Dart) validada, DSP real (FFT, espectro, demodulação AM/FM), banco de dados persistente (frequências, histórico, configurações), app Flutter completo com i18n (EN/JP/PT) — ver histórico completo de commits para o detalhamento sessão a sessão.
- **Dual VFO real**: dois canais de sintonia simultâneos (`VfoState`), cada um com frequência/modo/mudo independentes — espectro combinado (max por bin), áudio misturado (média), histórico registrando os dois canais. Painéis laterais (VFO A / VFO B) clicáveis para trocar qual está em edição.
- **Espectro em dB**: `compute_spectrum_db`/`sdr_core_generate_spectrum_db` — escala logarítmica (a que analisadores de espectro profissionais usam), substituindo a magnitude linear 0.0–1.0 anterior.
- **Max-hold**: traço de pico retido no modo vetorial, com botão de reset.
- **Zoom**: span visível do waterfall/espectro ajustável (10kHz–2MHz), afetando o cálculo de toque-para-sintonizar e a posição do marcador do outro VFO.
- **Marcador de VFO fora de alcance**: seta indicando a direção do outro VFO quando ele está fora do span visível atual, em vez de uma posição enganosa "grudada" na borda.
- **Dígitos de frequência individuais roláveis** (`FrequencyDigitDisplay`) — scroll do mouse ou toque na metade superior/inferior de cada dígito, convenção clássica do SDR#/HDSDR/SDRuno.
- **Seletor de unidade no campo de texto** (`FrequencyUnit`: Hz/kHz/MHz/GHz) — digite "112.123" selecionando MHz em vez de precisar digitar Hz cru.
- **Faixa de sintonia real**: 500 kHz–1.766 GHz (RTL-SDR Blog V4), com formatação automática de unidade (`formatFrequency`).
- **Espectro + waterfall empilhados** (não mais alternados por toggle) com **divisória arrastável (SplitPane)** entre os dois painéis.
- **Tema de aviônica** (`AppColors` reformulado): paleta inspirada em convenções de cockpit de vidro (ciano = selecionado/ativo, magenta = canal secundário, âmbar = caução, verde = normal, vermelho = alerta) — aplicada também às cores do waterfall e da linha do espectro.
- **Decodificador ADS-B/Mode S** (`core/src/adsb.rs`): extração de DF/ICAO/Type Code, decodificação de callsign (6-bit), altitude barométrica (AC12, caso Q=1), decodificação de posição CPR global (fórmula pública, testada por ida-e-volta), e CRC-24 (melhor esforço). Função FFI `sdr_core_decode_adsb` exposta. 8 testes novos, todos passando.
- Seletor de modo (AM/FM) sempre visível na tela principal (antes só existia dentro do diálogo de adicionar frequência).
- Toque/arrasto no waterfall/espectro para sintonizar (clique direto no gráfico, como SDR++/SDRangel/SDR#).

### Changed
- Geração do espectro/waterfall desacoplada da frequência de RF exibida (usa tom de demonstração fixo internamente, já que a frequência agora cobre a faixa real de RF).
- Widgets migrados para APIs não-depreciadas do Flutter (`withValues`, `RadioGroup`).

### Fixed
- Teste padrão do Flutter (`widget_test.dart`) corrigido para referenciar `SdrStudioApp`.
- Avisos de depreciação eliminados do `flutter analyze`.

<!--
Categorias disponíveis: Added, Changed, Fixed, Deprecated, Removed, Security

## [0.1.0] - AAAA-MM-DD
### Added
- ...
-->
