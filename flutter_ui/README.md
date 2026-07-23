# flutter_ui

Interface do SDR Studio (Flutter/Dart) — desktop + mobile a partir do mesmo código.

## i18n

Strings traduzíveis em `lib/l10n/` (`app_en.arb`, `app_ja.arb`, `app_pt.arb`).
Configuração em `l10n.yaml`. Para gerar as classes de localização depois que
o projeto Flutter for inicializado aqui (`flutter create .`), rode:

```
flutter gen-l10n
```

## Status

Ainda não inicializado como projeto Flutter — próximo passo é rodar
`flutter create .` dentro desta pasta, preservando `lib/l10n/` e `l10n.yaml`.
