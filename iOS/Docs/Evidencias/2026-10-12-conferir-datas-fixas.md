# Prova do portão de datas fixas — 12/10/2026

Escopo: literais ISO (`2025/2026-MM-DD`, com ou sem horário), `year:`, `ano:` e atribuição `.year` nos corpos de tipos Duble/Mock/Fake/Stub/Falso/Simulado ou implementações de `ApiCliente`/`ApiClienteEncaminhador`, incluindo extensões. Varredura recursiva dos arquivos Swift em `iOS/Tests`. Comentários e tipos de teste terminados em `Tests` são ignorados. Testes de formato/contrato e relógios fixos fora desses corpos ficam fora da regra. Anos diferentes de 2025/2026 e timestamps numéricos não são proibidos por este recorte.

O autoteste exercitou 12 verificações: entrada por arquivo e pasta, prazos relativos, comentários aninhados, outros anos, ISO de 2025, JSON escapado, `DataCivil` de 2026, criação e atribuição de componentes, string raw multilinha, extensão em subpasta e entradas ausente/vazia. Não compilou Swift nem executou suítes iOS: a prova pedida é o próprio script.

A varredura real reprovou com exit 1 e três ocorrências preexistentes, mantidas sem alteração conforme a missão:

| Arquivo | Linha | Dublê | Literal |
|---|---:|---|---|
| `iOS/Tests/Unitarios/ExclusaoDeContaViewModelTests.swift` | 15 | `DublePortaExclusao` | `2026-10-16` |
| `iOS/Tests/Unitarios/ExportarDadosViewModelTests.swift` | 16 | `DubleApiExportar` | `2026-10-02T12:00:00Z` |
| `iOS/Tests/Unitarios/SuporteTurnoTests.swift` | 300 | `ApiDeSuporteTeste` | `2026-10-16` |

O mesmo passo da CI que confere textos agora roda o autoteste e o verificador de datas. Enquanto as três ocorrências permanecerem, esse portão reprovará; este PR não cria exceções nem corrige fixtures.

## Execução local

```text
$ iOS/Scripts/teste-conferir-datas-fixas.sh
OK: autoteste de conferir-datas-fixas.sh (12 verificações).
exit: 0

$ bash -n iOS/Scripts/conferir-datas-fixas.sh iOS/Scripts/teste-conferir-datas-fixas.sh
exit: 0

$ iOS/Scripts/conferir-datas-fixas.sh
iOS/Tests/Unitarios/ExclusaoDeContaViewModelTests.swift:15: data fixa no dublê: 2026-10-16; use relogio.agora e prazo relativo
iOS/Tests/Unitarios/ExportarDadosViewModelTests.swift:16: data fixa no dublê: 2026-10-02; use relogio.agora e prazo relativo
iOS/Tests/Unitarios/SuporteTurnoTests.swift:300: data fixa no dublê: 2026-10-16; use relogio.agora e prazo relativo
FALHA: 3 data(s) fixa(s) nos dublês
exit: 1

$ iOS/Scripts/teste-conferir-textos.sh
OK: autoteste de conferir-textos.sh passou
exit: 0

$ iOS/Scripts/conferir-textos.sh
OK: textos no bundle da Apresentação e tokens em conformidade.
exit: 0

$ iOS/Scripts/teste-conferir-movimento.sh
OK: autoteste de conferir-movimento.sh passou
exit: 0

$ iOS/Scripts/conferir-movimento.sh
OK: todas as animações respeitam Reduzir Movimento via FrilaMovimento.animacao.
exit: 0
```
