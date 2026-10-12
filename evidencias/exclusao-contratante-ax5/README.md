# Exclusão de conta do contratante: padrão e AX5

Recorte do [cartão #71](https://trello.com/c/wiLKWHYl), no [PR 201](https://github.com/FrilaApp/frila-frontend/pull/201). **Os dois novos testes passaram na validação final local**, com 0 falhas e 0 pulos em 57,521 s. Nenhuma alteração de SwiftUI ou de produção.

## Resultado e correção

A inspeção solicitada pelo Fury imprimiu `app.debugDescription` antes da asserção problemática. A hierarquia expõe quatro `StaticText` com o mesmo identifier `item-turno-futuro-82000000-0000-0000-0000-000000000001`: função, profissional, horário e endereço. Eles não são filhos de um contêiner acessível. As hierarquias reais foram preservadas em [AX5](hierarquia-AX5.txt) e [padrão](hierarquia-Padrao.txt).

O teste agora consulta diretamente o `StaticText` pelo identifier do turno **e** pelo rótulo `Garçom` observado na fixture. Isso distingue o vínculo da exclusão da vaga com a mesma função na tela subjacente. Não faltou identifier na tela; faltava desambiguar o identifier propagado aos textos. O ajuste mantém todas as asserções posteriores e percorreu consentimento, confirmação e cancelamento nos dois tamanhos.

A rodada final executou somente os dois casos novos, conforme a última ordem. Os cinco testes antigos passaram na rodada anterior da suíte completa; não foram repetidos nesta última tentativa. Não declarar uma rodada única de 7/7 após o ajuste. Bloqueios locais pendentes: 0.

## Execução reproduzível

Comando a partir da raiz do repositório, após obter a vez com `vez.sh hulk --segurar 15` e aguardar `xcrun simctl bootstatus 1D91FAA0-595D-4C54-87BC-FCF91A7CA94D -b`:

```sh
~/Documents/Projetos/Apps/.workers/vigia/xcb.sh hulk -- xcodebuild test \
  -project iOS/Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,id=1D91FAA0-595D-4C54-87BC-FCF91A7CA94D' \
  -derivedDataPath ../derived-exclusao-ax5 \
  -resultBundlePath ../exclusao-ax5-identifiers.xcresult \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests/testContratanteComTurnosCancelaExclusaoEmAX5 \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests/testContratanteComTurnosCancelaExclusaoNoTamanhoPadrao \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

Projeto ignorado gerado com XcodeGen 2.45.3. [Ambiente real e hash do teste validado](ambiente.json): Hulk, iPhone 17, iOS 26.5, Xcode 27.0 (27A266a). A CI usa Xcode 26.6, portanto seu resultado é uma validação separada. A vez foi devolvida; DerivedData e xcresult são temporários próprios removidos depois de exportar as provas.

## Capturas revisadas

São 16 capturas independentes da rodada aprovada, oito por tamanho, com origem e timestamp no [manifesto](manifesto-capturas.json). Algumas etapas não mudam a posição da rolagem; seus arquivos registram momentos distintos, sem reutilizar uma captura para dois passos.

| Etapa | Padrão | AX5 | Prova e limite |
|---|---|---|---|
| Perfil | [Padrão](ContratantePadraoPerfil.png) | [AX5](ContratanteAX5Perfil.png) | Acesso à exclusão tocável, alvo mínimo e limites horizontais |
| Consequencias | [Padrão](ContratantePadraoConsequencias.png) | [AX5](ContratanteAX5Consequencias.png) | Tela e aviso presentes |
| TurnoFuturo | [Padrão](ContratantePadraoTurnoFuturo.png) | [AX5](ContratanteAX5TurnoFuturo.png) | Texto do turno encontrado e alcançado por rolagem |
| ListaIncompleta | [Padrão](ContratantePadraoListaIncompleta.png) | [AX5](ContratanteAX5ListaIncompleta.png) | Aviso presente e alcançável; em AX5 a captura mostra somente seu início |
| SemConsentimento | [Padrão](ContratantePadraoSemConsentimento.png) | [AX5](ContratanteAX5SemConsentimento.png) | Interruptor desligado; asserção comprova exclusão desabilitada |
| ComConsentimento | [Padrão](ContratantePadraoComConsentimento.png) | [AX5](ContratanteAX5ComConsentimento.png) | Interruptor ligado; exclusão habilitada e tocável |
| Confirmacao | [Padrão](ContratantePadraoConfirmacao.png) | [AX5](ContratanteAX5Confirmacao.png) | Cancelar/Excluir com alvo mínimo e inteiros na janela |
| Cancelada | [Padrão](ContratantePadraoCancelada.png) | [AX5](ContratanteAX5Cancelada.png) | Diálogo fecha; tela permanece, sem voltar à entrada |

O alvo mínimo verificado é 44 pt, com tolerância de 0,01 pt para arredondamento. Os controles exercitados são conferidos nos limites horizontais; os dois botões da confirmação também têm limites verticais verificados. A tela anterior à confirmação é rolável: capturas de lista e consentimento em AX5 não comprovam que todo o texto cabe de uma vez. No tamanho padrão, a captura sem consentimento não enquadra o botão Excluir; seu estado desabilitado é comprovado pela asserção executada.

VoiceOver por pessoa independente, aparelho físico e demais telas estão fora do recorte e não foram executados. O cartão #71 não está encerrado.

## Provas e histórico

- Validação final: [resumo-identifiers.json](resumo-identifiers.json) e [trecho do log](xcb-identifiers-trecho.log), 2/2 aprovados. Log completo `.workers/vigia/logs-xcodebuild/hulk-20261011-231419-81119.log`.
- Inspeção da hierarquia antes de corrigir: [resumo-hierarquia.json](resumo-hierarquia.json), [trecho](xcb-hierarquia-trecho.log), 2 falhas esperadas no seletor antigo; log `hulk-20261011-231124-74416.log`.
- Rodada anterior completa: [resumo-retomada.json](resumo-retomada.json), [trecho](xcb-retomada-trecho.log), 5 antigos passaram e 2 novos falharam; log `hulk-20261011-230259-58197.log`.
- Primeira suíte: [resumo-primeira-rodada.json](resumo-primeira-rodada.json), log `hulk-20261011-112146-51068.log`. Tentativa intermediária `hulk-20261011-113656-81124.log` não iniciou casos por preflight/Busy; não voltou na retomada.
- Conferência de textos e `git diff --check` aprovados antes do push. Estado da única CI registrado no PR e no arquivo de retomada; não inferir aprovação remota deste resultado local.
