# UX-04 — disponibilidade do perfil profissional

## Comportamento

As horas usam `DatePicker(.hourAndMinute)` com estilo `.wheel`, lado a lado. Cada roda tem 216 pt no padrão e 248 pt nos tamanhos de acessibilidade, conforme `dynamicTypeSize.isAccessibilitySize`. A altura acomoda o conteúdo nativo sem cortar texto. `clipShape(.rect)` e `contentShape` contêm o desenho e a interação em cada coluna; não há `.clipped()` nem redução do tamanho do texto. Os rótulos nativos Início/Fim continuam disponíveis para VoiceOver com `.labelsHidden()`.

O dia continua sendo selecionado com Picker em menu nativo. O rótulo do menu tem altura livre e mostra “Sexta-feira” inteiro em AX5. Adicionar anuncia “Adicionar horário”, reutilizando `TextosDoProfissional.Perfil.adicionarHorario` e o catálogo existente.

Editar dia, início ou fim marca a faixa como pendente. Salvar inclui essa faixa antes do envio, tanto na criação quanto na edição. Adicionar explicitamente limpa a pendência; remover depois não recria a faixa. Uma falha de rede conserva a lista e a repetição não duplica a faixa. A sugestão inicial sem interação não é adicionada automaticamente.

Início igual ao fim bloqueia o envio. Fim anterior ao início continua válido, inclusive 18:00–02:00 e 23:59–00:00, conforme esclarecimento de Nick Fury (#98 C2). A devolução acrescenta três testes: 23:59–00:00 aceito, 00:00–00:00 rejeitado sem chamada à API e inválido → salvar → corrigir → salvar com mensagem limpa.

## Meu perfil — devolução 2

Em tamanhos de acessibilidade, Telefone, E-mail, Funções e Horários disponíveis têm rótulo acima do valor. O tamanho padrão conserva o `LabeledContent` horizontal, as fontes, as cores e os espaçamentos anteriores. A comparação visual da nova captura padrão com a do head `8a8b903` preserva a aparência do conteúdo.

Telefone e e-mail usam uma linha com largura natural e rolagem horizontal, sem hifenização, reticências nem redução da fonte. Em AX5, ambos excedem a largura disponível: a captura inicial mostra o começo, e `perfil-ax5-contatos-fim.png` mostra o final após a rolagem. O texto completo permanece na árvore de acessibilidade. O alvo da rolagem tem altura mínima de 44 pt. Funções e Horários podem ocupar várias linhas abaixo dos rótulos, sem limite artificial de altura.

## Ambiente e capturas desta revisão

17/10/2026: capturas de horários às 10:07–10:08; as imagens de Meu perfil foram substituídas na devolução 2 às 10:44–10:45 (horário visível em cada imagem). Simulador Homem-Aranha, iPhone 17, iOS 26.5, UDID `85940BCB-553C-4145-8F8E-E83423D86431`; dados fictícios do cenário `success`. Resolução original: 1206 × 2622 pixels. Tamanho padrão e `UICTContentSizeCategoryAccessibilityXXXL` (AX5).

O portal não fornecia stream com o canvas fechado. Por autorização expressa do usuário, as imagens foram obtidas com `xcrun simctl io <UDID> screenshot <arquivo>`, somente nesse UDID, segurando a vez pela fila. Navegação e rolagens foram feitas por XCTest. Não foi aberto o aplicativo Simulator. As pausas temporárias usadas para sincronizar a coleta foram removidas do teste entregue; os anexos XCTest permanecem.

| Arquivo | Passo conferido visualmente nesta revisão |
| --- | --- |
| [horarios-padrao.png](horarios-padrao.png) | Dia inteiro, duas rodas contidas nas colunas, Início/Fim, Adicionar e janela noturna existente |
| [horarios-ax5.png](horarios-ax5.png) | “Sexta-feira” inteiro em AX5, duas rodas lado a lado e Adicionar visível |
| [perfil-padrao.png](perfil-padrao.png) | Nova captura: aparência horizontal de Meu perfil preservada no tamanho padrão |
| [perfil-ax5.png](perfil-ax5.png) | Nova captura AX5: rótulos Telefone/E-mail acima dos valores, contatos em linha única na posição inicial |
| [perfil-ax5-contatos-fim.png](perfil-ax5-contatos-fim.png) | AX5 após rolagem horizontal: final do telefone e do e-mail acessíveis |
| [perfil-ax5-funcoes-horarios.png](perfil-ax5-funcoes-horarios.png) | AX5 após rolagem vertical: Funções e Horários disponíveis com rótulo acima do valor |

## Validação da devolução 2

- Regressão com o código final, sem pausas de captura: **1.265 passaram, 0 falharam, 0 pulados**. Inclui todos os **1.250 unitários** (`FrilaTests`) e a classe completa **AcessibilidadeDoProfissionalUITests, 15 testes**. Comando: `vigia/xcb.sh 'Homem-Aranha' -- xcodebuild test -project iOS/Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431' -derivedDataPath DerivedData-UX04-Devolucao2 -resultBundlePath resultados-ux04-devolucao2-final -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:FrilaTests -only-testing:FrilaUITests/AcessibilidadeDoProfissionalUITests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`.
- Log final: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-104036-85517.log`.
- Os dois testes novos conferem os quatro pares de rótulo/valor: alinhamento horizontal no padrão e rótulo acima do valor em AX5; contatos com texto completo, altura compatível com a fonte escalada e uma única linha; viewport contido no cartão e alvo mínimo de 44 pt; rolagem até o fim de telefone/e-mail. Também percorrem os campos inferiores, deixando Funções fora da barra de navegação para a captura. Os testes anteriores de rodas, janela noturna, rótulos e alvos continuam na classe executada.
- A primeira passagem da classe, com sincronização de capturas, também passou: **15/15**, sem falhas nem pulados. Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-103546-69124.log`.
- Coleta final das quatro imagens de Meu perfil: **2 testes passaram, 0 falhas, 0 pulados**, log `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-104425-93902.log`. As pausas de sincronização foram removidas depois da coleta; o arquivo entregue foi conferido como idêntico ao da regressão final sem pausas. Todas as novas imagens foram abertas e conferidas visualmente.
- Portões `conferir-textos.sh`, `conferir-datas-fixas.sh` e `git diff --check`: aprovados.
- Revisão `swiftui-pro` limitada ao diff de Meu perfil: sem erro adicional. Nenhuma fonte foi reduzida e nenhum texto novo entrou na interface.

## Validação da primeira devolução (histórico)

Todos os comandos Xcode passaram por `vigia/xcb.sh 'Homem-Aranha' -- xcodebuild test`, esquema `Frila-Local`, destino acima, paralelismo desativado e DerivedData próprio. As execuções direcionadas usaram `CODE_SIGNING_ALLOWED=NO`; a suíte completa final usou assinatura ad hoc (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), como exige o acesso real ao Keychain no simulador.

- Classes `PerfilProfissionalViewModelTests` e `PerfisDaContaTests`: **46 passaram, 0 falharam**, incluindo os três novos testes pedidos na devolução. Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100312-97102.log`. A inspeção das primeiras imagens desta execução identificou desenho das rodas fora das colunas; essa versão foi corrigida e suas capturas substituídas.
- Dois testes UI, padrão e AX5, com a altura e contenção finais: **2 passaram, 0 falharam**. Esta execução gerou as imagens de horários mantidas acima e as imagens de Meu perfil substituídas na devolução 2. Conferiu largura e altura mínimas de 44 pt em dia, Adicionar, Remover e rodas; nomes/valor do dia; rótulos Início/Fim e Adicionar horário; tocabilidade; troca do dia pelo menu; rolagem sem mudar a hora. Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100711-11445.log`.
- Regressão final sem pausas de captura, com `-only-testing:FrilaTests` e os dois testes UI acima: **1.252 passaram, 0 falharam, 0 pulados** (1.250 unitários e 2 UI). Log: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-101048-15621.log`.
- A tentativa de suíte completa sem assinatura falhou em 6 testes de Keychain (9 ocorrências, incluindo `-34018`). A repetição com assinatura ad hoc resolveu essas falhas sem mudança de código. Log da tentativa sem assinatura: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261017-100916-13759.log`.
- `iOS/Scripts/conferir-textos.sh`, `iOS/Scripts/conferir-datas-fixas.sh` e `git diff --check`: aprovados.

## Limites

A validação de VoiceOver confere os rótulos na árvore de acessibilidade; não houve escuta manual com VoiceOver ligado. A suíte completa de interface não foi executada localmente: `iOS/Docs/CI.md` registra aproximadamente 71 minutos, acima do teto de 40 minutos desta devolução. A CI remota deve ser consultada no [PR #370](https://github.com/FrilaApp/frila-frontend/pull/370); este documento registra resultados locais. Não houve TestFlight nem mudança de backend ou contrato. Revisão `swiftui-pro` restrita ao diff, sem modernização de outras telas.
