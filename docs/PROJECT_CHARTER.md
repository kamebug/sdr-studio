# SDR Studio — Project Charter

> Documento de referência derivado do documento de inicialização original.
> Objetivo: transformar a visão em fases executáveis, com um MVP claro antes da expansão total do escopo.

---

## 1. Visão

Plataforma SDR multiplataforma (Windows, Android, Linux/macOS futuramente), arquitetura polyglot, modular, com foco em desempenho, UX profissional e extensibilidade via plugins. Evolução contínua ao longo de anos.

**Princípio geral:** nenhuma escolha técnica por preferência pessoal — cada linguagem/lib é escolhida pelo domínio em que tem melhor desempenho comprovado.

---

## 2. Arquitetura Polyglot (referência rápida)

| Camada | Linguagem | Responsabilidade | Nunca deve |
|---|---|---|---|
| Core Engine | Rust | DSP, FFT, waterfall, demodulação, AGC, noise blanker/reduction, threads, SIMD, GPU | Depender de Python em tempo real |
| Drivers | C/C++ | SoapySDR, librtlsdr, Airspy, SDRplay, HackRF, LimeSuite, UHD | Reimplementar o que a lib já faz |
| UI | Flutter/Dart | Interface única (desktop + mobile), layout adaptativo | Fazer DSP na UI thread |
| Extensões | Python | IA, ML, plugins, scripts, automação, testes | Processamento crítico em tempo real |
| Persistência | SQLite | Frequências, favoritos, histórico, config, banco mundial, perfis, logs | — |
| Config | JSON/YAML/TOML | — | — |
| Docs | Markdown | README, manual, wiki, API, roadmap, changelog | — |

Comunicação entre módulos: sempre via APIs bem definidas (FFI Rust↔C++, e Rust/C++↔Dart via `dart:ffi` ou `flutter_rust_bridge`; Python isolado como processo/plugin externo, nunca linkado no hot path).

---

## 3. Estrutura de repositório

```
sdr-studio/
├── .github/              # CI/CD workflows
├── docs/
│   ├── manual/
│   ├── wiki/
│   └── api/
├── core/                 # Rust — DSP engine
├── drivers/              # C/C++ — integração hardware
├── flutter_ui/           # Interface
├── python/               # IA, automação, scripts
├── plugins/               # SDK de plugins + exemplos
├── database/             # Schemas SQLite, migrações, banco mundial de frequências
├── sdk/                  # SDK público para terceiros
├── tests/
├── examples/
├── assets/
├── CHANGELOG.md
├── PROBLEMAS_RECORRENTES.md
└── README.md
```

Convenção alinhada com os outros projetos: `CHANGELOG.md` seguindo Keep a Changelog, versionamento SemVer estrito, e um `PROBLEMAS_RECORRENTES.md` para documentar bugs recorrentes (mesmo padrão do Onion Payroll).

---

## 4. Fases — reordenadas para permitir um MVP cedo

O plano original tinha 15 capítulos sequenciais de pesquisa/definição antes de código de produto. Reorganizei em **fases com entregável verificável no fim de cada uma**, para reduzir o risco de "specar para sempre".

### Fase 0 — Fundação (1–2 semanas)
- Visão e escopo (já feito, este documento).
- Benchmark rápido (não exaustivo) de SDR++, SDRangel, CubicSDR, GQRX: focar em 3 perguntas — como fazem waterfall performático, como estruturam drivers, o que a comunidade reclama.
- Definir MVP explicitamente (ver seção 5).
- Estrutura de repositório + CI básico (build vazio compilando nas 3 plataformas-alvo do MVP).

### Fase 1 — Núcleo DSP mínimo (Rust)
- FFT + waterfall básico.
- Demodulação AM/FM.
- Sem GPU/SIMD ainda — otimizar depois de funcionar.

### Fase 2 — Integração com 1 hardware (C/C++)
- RTL-SDR Blog V4 via SoapySDR ou librtlsdr diretamente.
- FFI Rust↔C++ funcionando ponta a ponta.

### Fase 3 — UI mínima (Flutter, Windows apenas)
- Waterfall renderizado, controle de frequência, play/pause.
- Strings já externalizadas desde o primeiro commit (arquivo de tradução, não texto hardcoded), seletor de idioma EN/JP/PT funcional.
- Sem tema/dark mode ainda — só funcional.

### Fase 4 — MVP integrado e testável
- SQLite com schema para favoritos, frequências salvas, histórico e perfis (biblioteca de frequências local).
- Schema desenhado já prevendo campos que o banco mundial vai usar depois (categoria, país, observações), mas sem tela de import/export ainda.
- Testes automatizados básicos no core.
- **Marco: v0.1.0 — RTL-SDR + AM/FM + waterfall + biblioteca de frequências + interface em EN/JP/PT, rodando no Windows.**

### Fase 5 — Expansão de plataforma
- Android via Flutter (reaproveitando UI).
- CI/CD completo (build automática APK/Windows/Linux/macOS).

### Fase 6 — Expansão de recursos
- SSB, CW, modos digitais, scanner, múltiplos VFO, gravação IQ.
- Dark mode, design system completo, acessibilidade.

**Nota sobre múltiplos VFO (esclarecimento de terminologia):** não são telas/displays separados — é a mesma tela de waterfall com vários marcadores de frequência simultâneos, cada um com seu próprio demodulador, todos dentro da mesma faixa de banda que o hardware está capturando naquele momento (ex: SDR++ permite decodificar 3 sinais AERO ao mesmo tempo com um único RTL-SDR). Requer: (1) capturar uma faixa larga de IQ em vez de uma única frequência por vez, (2) múltiplos demoduladores rodando em paralelo sobre essa mesma captura, (3) UI com múltiplos marcadores coloridos no waterfall. Fica de fora do MVP de propósito — só faz sentido testar contra sinal de RF real, não contra o sinal sintético usado até a Fase 5.

### Fase 7 — i18n (expansão)
- Base já existe desde o MVP (EN/JP/PT) — aqui é só ampliar: segunda fase de idiomas (ES/FR/DE/IT/KR/ZH-Hans/ZH-Hant).
- Formatação regional de data/hora/número.
- RTL, se algum idioma futuro exigir.

### Fase 8 — Módulos opcionais desacoplados
- SDK de plugins.
- Banco mundial de frequências (import/export).
- IA (classificação de sinal, sugestão de filtro) — como plugin Python isolado.
- Language Assistant (transcrição/tradução) — módulo totalmente opt-in, arquitetura de providers.

### Fase 9 — Documentação e comunidade
- Manual do usuário/desenvolvedor, wiki, API/SDK docs em EN/JP/PT.
- Guia de contribuição para tradutores e devs de plugin.

### Fase 10+ — Roadmap contínuo
- Airspy, SDRplay, HackRF, LimeSDR, USRP.
- Mais idiomas (fase 2 e 3 do plano de i18n).

---

## 5. MVP — definição explícita

**Dentro do MVP (v0.1.0):**
- 1 hardware: RTL-SDR Blog V4
- 2 modos: AM, FM
- Waterfall + FFT básico
- 1 plataforma: Windows
- **Biblioteca de frequências (SQLite local)**: salvar, favoritar, histórico, perfis — armazenamento local, sem qualquer sincronização ou catálogo comunitário
- **Interface multi-idioma (i18n)**: strings 100% externalizadas desde o primeiro commit, seletor de idioma na UI, cobertura inicial EN/JP/PT — sem tradução automática de conteúdo/áudio, só a UI do app mesmo
- Sem IA, sem Language Assistant, sem plugins, sem banco mundial de frequências

**Por que i18n e biblioteca de frequências entram no MVP e não no backlog:**
- i18n é caro de retrofitar — se as strings nascem hardcoded no código, depois é preciso caçar cada uma pra externalizar. Trazer isso desde o início custa pouco agora e evita retrabalho grande depois.
- Salvar frequência é infraestrutura básica de qualquer receptor SDR, não depende de nenhuma feature avançada — é só uma tabela SQLite local, sem relação com o banco mundial (que é o catálogo colaborativo importável/exportável da comunidade).

**Fora do MVP, mas arquitetado para receber depois (interface pronta, implementação não):**
- **IA** (classificação de sinal, sugestão de filtro) — pontos de extensão previstos no core, mas nenhum modelo/lógica implementada ainda.
- **Language Assistant** (transcrição, tradução em tempo real, TTS) — pipeline desenhado (seção 6), módulo desligado por padrão, arquitetura de providers definida mas sem providers implementados.
- **Banco mundial de frequências** (catálogo comunitário, import/export) — schema SQLite pensado para comportar isso depois, sem tela nem sincronização agora.

**Fora do MVP e sem trabalho de arquitetura ainda (backlog puro):** demais itens do documento original (SSB/CW/modos digitais, scanner, múltiplos VFO, gravação IQ, plugins, hardwares adicionais, plataformas adicionais) — permanecem no roadmap, sem bloquear a primeira versão funcional.

---

## 6. Módulo Language Assistant — resumo técnico (para quando chegar a Fase 8)

Pipeline: Recepção SDR → Demodulador → Áudio → Speech-to-Text → Translation Engine → Subtitle Engine → Tela (+ TTS opcional).

- Arquitetura de *providers* plugável (Android nativo, ML Kit, OpenAI, Azure, DeepL, LibreTranslate).
- Modo offline priorizado quando disponível.
- Privacidade: local-only, nuvem configurada pelo usuário, ou módulo desativado — nunca envio automático.
- Totalmente desacoplado do núcleo: SDR deve funcionar 100% sem esse módulo.

---

## 7. Riscos identificados

| Risco | Mitigação |
|---|---|
| Escopo grande demais para 1 dev solo em turno noturno | MVP restrito (seção 5), backlog explícito para o resto |
| FFI Rust↔C++↔Dart é a parte mais frágil tecnicamente | Prototipar isso já na Fase 2, antes de investir em UI polida |
| 15 capítulos de planejamento sem código pode virar paralisia | Fases 0–4 entregam código funcional em semanas, não meses |
| Python usado incorretamente em hot path | Regra explícita: Python só como processo externo/plugin, nunca linkado no core |
| i18n tardia é cara de retrofitar | Estrutura de strings já prevista desde Fase 3, ativada na Fase 7 |

---

## 8. Próximas ações imediatas

1. Confirmar o MVP da seção 5 (ou ajustar escopo).
2. Criar o repositório com a estrutura da seção 3 + `.nojekyll` se GitHub Pages for usado para docs.
3. Rodar o benchmark reduzido da Fase 0 (SDR++, SDRangel, GQRX) — só o suficiente pra decidir a abordagem de waterfall e drivers.
4. Prototipar a ponte FFI Rust↔C++ isoladamente antes de qualquer UI.
