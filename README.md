# SDR Studio

Plataforma SDR (Software Defined Radio) moderna, profissional e multiplataforma, para radioescuta, análise de espectro, experimentação e pesquisa.

**Status:** 🚧 Em desenvolvimento inicial (pré-MVP)

## Idiomas suportados

🇺🇸 English · 🇯🇵 日本語 · 🇧🇷 Português

## Visão

Não é apenas mais um receptor SDR — é uma plataforma completa de análise de sinais, com arquitetura modular, interface moderna e alto desempenho, desenvolvida para evoluir continuamente.

Documento completo de arquitetura e roadmap: [`docs/PROJECT_CHARTER.md`](docs/PROJECT_CHARTER.md)

## Arquitetura (resumo)

| Camada | Linguagem | Responsabilidade |
|---|---|---|
| Core Engine | Rust | DSP, FFT, waterfall, demodulação, tempo real |
| Drivers | C/C++ | Integração com SoapySDR, librtlsdr, Airspy, SDRplay, HackRF, etc. |
| UI | Flutter/Dart | Interface única desktop + mobile |
| Extensões | Python | IA, plugins, scripts, automação |
| Persistência | SQLite | Frequências, favoritos, histórico, config |

## Estrutura do repositório

```
sdr-studio/
├── core/            # Rust — DSP engine
├── drivers/         # C/C++ — integração com hardware SDR
├── flutter_ui/      # Interface (Flutter/Dart)
├── python/          # IA, automação, scripts
├── plugins/         # SDK de plugins e exemplos
├── database/        # Schemas SQLite, migrações
├── sdk/             # SDK público para terceiros
├── tests/
├── examples/
├── assets/
└── docs/            # Manual, wiki, API, charter
```

## Hardware suportado (MVP)

- RTL-SDR Blog V4

Suporte futuro planejado: Airspy, SDRplay, HackRF, LimeSDR, USRP.

## MVP (v0.1.0) — escopo

- RTL-SDR Blog V4, modos AM/FM
- Waterfall + FFT básico
- Windows
- Biblioteca de frequências local (SQLite: favoritos, histórico, perfis)
- Interface em EN/JP/PT

Fora do MVP por enquanto (arquitetado, não implementado): IA, Language Assistant (transcrição/tradução em tempo real), banco mundial de frequências.

## Versionamento

Este projeto segue [SemVer](https://semver.org/) e [Keep a Changelog](https://keepachangelog.com/).

## Licença

MIT — ver [`LICENSE`](LICENSE).

## Contribuindo

Guia de contribuição em construção. Traduções e plugins de terceiros são bem-vindos assim que o SDK estiver disponível (ver roadmap no charter).
