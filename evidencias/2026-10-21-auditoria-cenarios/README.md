# Auditoria de Cenários de Demonstração e Dublês (21/10/2026)

## 1. Contexto e Missão
Auditoria e higienização dos 27 cenários em `ApiClienteEmMemoria.Cenario` apontados como candidatos a remoção em `.workers/antigravity-3/mapa-cenarios-api-real-21-10.md` (seção 3, item 2).

Conforme os critérios de aceite da missão:
1. `grep -rn` no repositório inteiro (`iOS/Sources`, `iOS/Tests`, `Scripts`, `.github`, `iOS/Docs`, `*.md`, `project.yml`) pelo nome do cenário e pelo valor de `-FRILA_SCENARIO`.
2. Se algum aparecer em doc, script ou teste de outro alvo: **não remover**; listar na entrega.
3. Correção de escopo do Fabrício (21/10): `entrada` mantido para capturas de tela.

## 2. Resultado da Auditoria dos 27 Cenários

| cenário | onde aparecia | removido sim/não |
|---|---|---|
| `a-caminho` | iOS/Tests/UI/PresencaUITests.swift:95, 109 | não |
| `avaliacao-sem-rede` | iOS/Tests/UI/TurnoContrato0231UITests.swift:185 | não |
| `cancelar-sem-rede` | iOS/Tests/UI/CancelamentoDoProfissionalUITests.swift:125 | não |
| `candidatura-com-turno-cancelado` | iOS/Tests/UI/ModoSelecaoDoProfissionalUITests.swift:163 | não |
| `candidatura-expirada` | iOS/Tests/UI/ModoSelecaoDoProfissionalUITests.swift:208 | não |
| `candidatura-recusada` | iOS/Tests/UI/ModoSelecaoDoProfissionalUITests.swift:187 | não |
| `codigo-expirado` | iOS/Tests/Unitarios/AutenticacaoTests.swift:103 | não |
| `conta-existente` | iOS/Tests/Unitarios/AutenticacaoTests.swift:367 | não |
| `despacho-contestacao-ja-aberta` | iOS/Tests/UI/PorQueReceboVagasUITests.swift:95 | não |
| `entrada` | iOS/Docs/MidFi/FLUXOS.md:14, 15; iOS/Sources/App/FrilaApp.swift:640 | mantido (capturas do Fabrício) |
| `erro-criacao-perfil-profissional` | iOS/Tests/UI/FrilaUITests.swift:405, 418 | não |
| `escolha-perde-corrida` | iOS/Tests/UI/ModoSelecaoDoContratanteUITests.swift:139 | não |
| `exportar-intervalo-maximo-excedido` | iOS/Tests/UI/HistoricoDeTurnosUITests.swift:68 | não |
| `exportar-turnos-sem-turnos` | iOS/Tests/UI/HistoricoDeTurnosUITests.swift:38 | não |
| `funcao-incompativel` | iOS/Tests/UI/FrilaUITests.swift:266 | não |
| `inelegivel` | iOS/Tests/UI/AuditoriaDeAcessibilidadeUITests.swift:221 | não |
| `inelegivel-suspenso` | iOS/Tests/UI/AuditoriaDeAcessibilidadeUITests.swift:222 | não |
| `menor-de-idade` | iOS/Tests/Unitarios/AutenticacaoTests.swift:249 | não |
| `perfil-profissional-com-erro-de-rede` | iOS/Tests/Unitarios/AutenticacaoTests.swift:482 | não |
| `publicar-sem-rede` | iOS/Tests/UI/PublicarVagaEmMinhasVagasUITests.swift:148 | não |
| `resposta-invalida-publicacao` | iOS/Tests/Unitarios/PublicarVagaTests.swift:206, 287 | não |
| `resposta-perdida-publicacao` | iOS/Tests/Unitarios/PublicarVagaTests.swift:186, 225 | não |
| `retirar-sem-rede` | iOS/Tests/UI/ModoSelecaoDoProfissionalUITests.swift:124 | não |
| `selecao-com-candidato-da-equipe` | iOS/Tests/UI/ModoSelecaoDoContratanteUITests.swift:191 | não |
| `turno-encerrado-verificado` | iOS/Tests/Unitarios/CancelamentoPelaApiTests.swift:205 | não |
| `vaga-em-selecao` | iOS/Tests/UI/ModoSelecaoDoProfissionalUITests.swift:49 | não |
| `vaga-encerrada` | iOS/Tests/UI/AuditoriaDeAcessibilidadeUITests.swift:220 | não |

**Conclusão da auditoria:** Todos os 27 cenários estão ativamente referenciados em testes (20 em testes de UI, 7 em testes unitários e/ou inicialização do app). Nenhuma remoção foi efetuada para não violar as regras de integridade dos testes e conformidade com os critérios de aceite.

## 3. Verificação dos 4 Campos dos Dublês (Correção de Escopo)
Verificação solicitada por Fabrício a respeito de resquícios de wireframes nos dublês (`ApiClienteEmMemoria` e fixtures):
- **Ponto de referência do estabelecimento:** Não existe no dublê nem no DTO (`CadastroEstabelecimento` / `Estabelecimento`). Documentado previamente como exceção em `iOS/Docs/MidFi/FLUXOS.md:44`.
- **E-mail da conta no estabelecimento:** Não existe no dublê do estabelecimento (`FLUXOS.md:44`).
- **"Profissionais avisados":** Não existe no dublê de publicação de vaga nem nas fixtures (`FLUXOS.md:28`).
- **Chip "Garçom +1":** Não existe no feed de vagas nem nos dublês (`FLUXOS.md:43`).

Nenhum campo fictício precisou ser apagado nos dublês, pois eles já não constavam no código.

## 4. Execuções de Teste (`xcb.sh`)

### Execução 1: `FrilaTests` (Unitários)
- **Comando:** `xcb.sh "Steve Rogers" -- xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FrilaTests`
- **Log:** `logs-xcodebuild/steve-rogers-20261021-143544-95356.log`
- **Resultado:** Passed · passou 1559 · falhou 0 · pulou 0 · falha esperada 0 · total 1559

### Execução 2: Classes de UI com Cenários
- **Comando:** `xcb.sh "Steve Rogers" -- xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FrilaUITests/ModoSelecaoDoContratanteUITests -only-testing:FrilaUITests/ModoSelecaoDoProfissionalUITests`
- **Log:** `logs-xcodebuild/steve-rogers-20261021-150300-19404.log`
- **Resultado:** Passed · passou 19 · falhou 0 · pulou 0 · falha esperada 0 · total 19

