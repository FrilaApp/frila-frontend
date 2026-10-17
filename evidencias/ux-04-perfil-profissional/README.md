# UX-04 — disponibilidade do perfil profissional

## Comportamento

As horas usam `DatePicker(.hourAndMinute)` com estilo `.wheel`, lado a lado. Cada roda tem 216 pt no padrão e 248 pt nos tamanhos de acessibilidade, conforme `dynamicTypeSize.isAccessibilitySize`. A altura acomoda o conteúdo nativo sem cortar texto. `clipShape(.rect)` e `contentShape` contêm o desenho e a interação em cada coluna; não há `.clipped()` nem redução do tamanho do texto. Os rótulos nativos Início/Fim continuam disponíveis para VoiceOver com `.labelsHidden()`.

O dia continua sendo selecionado com Picker em menu nativo. O rótulo do menu tem altura livre e mostra “Sexta-feira” inteiro em AX5. Adicionar anuncia “Adicionar horário”, reutilizando `TextosDoProfissional.Perfil.adicionarHorario` e o catálogo existente.

Editar dia, início ou fim marca a faixa como pendente. Salvar inclui essa faixa antes do envio, tanto na criação quanto na edição. Adicionar explicitamente limpa a pendência; remover depois não recria a faixa. Uma falha de rede conserva a lista e a repetição não duplica a faixa. A sugestão inicial sem interação não é adicionada automaticamente.

Início igual ao fim bloqueia o envio. Fim anterior ao início continua válido, inclusive 18:00–02:00 e 23:59–00:00, conforme esclarecimento de Nick Fury (#98 C2). A devolução acrescenta três testes: 23:59–00:00 aceito, 00:00–00:00 rejeitado sem chamada à API e inválido → salvar → corrigir → salvar com mensagem limpa.

## Ambiente e capturas desta revisão

17/10/2026, 10:07–10:08, simulador Homem-Aranha, iPhone 17, iOS 26.5, UDID `85940BCB-553C-4145-8F8E-E83423D86431`; dados fictícios do cenário `success`. Resolução original: 1206 × 2622 pixels. Tamanho padrão e `UICTContentSizeCategoryAccessibilityXXXL` (AX5).

O portal não fornecia stream com o canvas fechado. Por autorização expressa do usuário, as imagens foram obtidas com `xcrun simctl io <UDID> screenshot <arquivo>`, somente nesse UDID, segurando a vez pela fila. Navegação e rolagens foram feitas por XCTest. Não foi aberto o aplicativo Simulator. As pausas temporárias usadas para sincronizar a coleta foram removidas do teste entregue; os anexos XCTest permanecem.

| Arquivo | Passo conferido visualmente nesta revisão |
| --- | --- |
| [horarios-padrao.png](horarios-padrao.png) | Dia inteiro, duas rodas contidas nas colunas, Início/Fim, Adicionar e janela noturna existente |
| [horarios-ax5.png](horarios-ax5.png) | “Sexta-feira” inteiro em AX5, duas rodas lado a lado e Adicionar visível |
| [perfil-padrao.png](perfil-padrao.png) | Tela vizinha Meu perfil, antes de abrir Funções e horários |
| [perfil-ax5.png](perfil-ax5.png) | Tela vizinha em AX5; quebras de linha existentes no telefone/e-mail, sem alteração nesta missão |

## Testes executados nesta revisão

Todos os comandos Xcode passaram por `vigia/xcb.sh 'Homem-Aranha' -- xcodebuild test`, esquema `Frila-Local`, destino acima, paralelismo desativado e DerivedData próprio. As execuções direcionadas usaram `CODE_SIGNING_ALLOWED=NO`; a suíte completa final usou assinatura ad hoc (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), como exige o acesso real ao Keychain no simulador.

- Classes `PerfilProfissionalViewModelTests` e `PerfisDaContaTests`: **46 passaram, 0 falharam**, incluindo os três novos testes pedidos na devolução. Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100312-97102.log`. A inspeção das primeiras imagens desta execução identificou desenho das rodas fora das colunas; essa versão foi corrigida e suas capturas substituídas.
- Dois testes UI, padrão e AX5, com a altura e contenção finais: **2 passaram, 0 falharam**. Esta execução gerou as quatro imagens acima. Conferiu largura e altura mínimas de 44 pt em dia, Adicionar, Remover e rodas; nomes/valor do dia; rótulos Início/Fim e Adicionar horário; tocabilidade; troca do dia pelo menu; rolagem sem mudar a hora. Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100711-11445.log`.
- Regressão final sem pausas de captura, com `-only-testing:FrilaTests` e os dois testes UI acima: **1.252 passaram, 0 falharam, 0 pulados** (1.250 unitários e 2 UI). Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-101048-15621.log`.
- A tentativa de suíte completa sem assinatura falhou em 6 testes de Keychain (9 ocorrências, incluindo `-34018`). A repetição com assinatura ad hoc resolveu essas falhas sem mudança de código. Log da tentativa sem assinatura: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100916-13759.log`.
- `iOS/Scripts/conferir-textos.sh`, `iOS/Scripts/conferir-datas-fixas.sh` e `git diff --check`: aprovados.

## Limites

A validação de VoiceOver confere os rótulos na árvore de acessibilidade; não houve escuta manual com VoiceOver ligado. A suíte completa de interface não foi executada localmente: `iOS/Docs/CI.md` registra aproximadamente 71 minutos, acima do teto de 40 minutos desta devolução. A CI remota deve ser consultada no [PR #370](https://github.com/FrilaApp/frila-frontend/pull/370); este documento registra resultados locais. Não houve TestFlight nem mudança de backend ou contrato. Revisão `swiftui-pro` restrita ao diff, sem modernização de outras telas.
