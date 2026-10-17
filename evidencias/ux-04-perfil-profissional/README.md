# UX-04 — disponibilidade do perfil profissional

## Comportamento

As horas usam `DatePicker(.hourAndMinute)` com estilo `.wheel`. Início e fim ficam lado a lado, cada roda com altura de 132 pt e `.clipped()`. Os rótulos nativos continuam disponíveis para VoiceOver mesmo com `.labelsHidden()`; adicionar outro `accessibilityLabel` repetia o nome no iOS 26.5 e foi removido.

Editar dia, início ou fim marca a faixa como pendente. Salvar inclui essa faixa antes do envio, tanto na criação quanto na edição. Adicionar explicitamente limpa a pendência; remover depois não recria a faixa. Uma falha de rede conserva a lista e a repetição não duplica a faixa. A sugestão inicial sem interação não é adicionada automaticamente.

Início igual ao fim bloqueia o envio. Fim anterior ao início continua válido, inclusive 18:00–02:00, conforme esclarecimento de Nick Fury no arquivo da missão (#98 C2).

## Ambiente e capturas executadas

17/10/2026, simulador Homem-Aranha, iPhone 17, iOS 26.5, UDID `85940BCB-553C-4145-8F8E-E83423D86431`; dados fictícios do cenário `success`. Resolução original: 1206 × 2622 pixels. Tamanho padrão e `UICTContentSizeCategoryAccessibilityXXXL` (AX5).

O portal não fornecia stream com o canvas fechado. Por autorização expressa do usuário, as imagens foram obtidas com `xcrun simctl io <UDID> screenshot <arquivo>`, somente nesse UDID, segurando a vez pela fila. Navegação e rolagens foram feitas por XCTest. Não foi aberto o aplicativo Simulator. As pausas temporárias usadas para sincronizar a coleta foram removidas do teste entregue; os anexos XCTest permanecem.

| Arquivo | Passo verificado visualmente |
| --- | --- |
| [horarios-padrao.png](horarios-padrao.png) | Seção com as duas roletas, rótulos, botão Adicionar e janela noturna existente |
| [horarios-ax5.png](horarios-ax5.png) | Mesma seção no maior tamanho de texto; roletas lado a lado e Adicionar visível |
| [perfil-padrao.png](perfil-padrao.png) | Tela vizinha Meu perfil, antes de abrir Funções e horários |
| [perfil-ax5.png](perfil-ax5.png) | Tela vizinha em AX5; texto existente quebra em várias linhas, sem alteração por esta missão |

## Testes executados

Todos os comandos Xcode passaram por `vigia/xcb.sh 'Homem-Aranha' -- xcodebuild test`, esquema `Frila-Local`, destino acima, assinatura desativada e DerivedData próprio.

- `-only-testing:FrilaTests/PerfilProfissionalViewModelTests`: **25 passaram, 0 falharam**, incluindo criação/edição com faixa pendente noturna, igualdade, exclusão após adição e repetição após falha de rede.
  Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-085549-16186.log`.
- Dois testes UI do perfil, padrão e AX5, com estilo wheel final: **2 passaram, 0 falharam**. Verificaram seletor nativo, rótulos Início/Fim, altura mínima de 44 pt, controles tocáveis e ausência dos campos livres. Essa execução produziu as quatro imagens acima.
  Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-091002-81905.log`.
- `iOS/Scripts/conferir-textos.sh`, `iOS/Scripts/conferir-datas-fixas.sh` e `git diff --check`: aprovados.

As tentativas compactas foram descartadas após o alvo nativo medir 36 pt. A primeira execução com wheel detectou rótulo duplicado e rolagem inadequada do teste; ambos corrigidos. A rolagem final ocorre pela margem e usa o quadro do seletor como referência, evitando girar a roda ao tentar deslocar a tela.

## Limites

A validação de VoiceOver executada confere os rótulos na árvore de acessibilidade; não houve escuta manual com VoiceOver ligado. Não houve TestFlight, backend real nem mudança do contrato. Revisão `swiftui-pro` restrita ao diff, sem modernização de outras telas.
