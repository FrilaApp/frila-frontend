# Prova parcial da US18 — perfis públicos de profissionais

Cartão: https://trello.com/c/5uYZydYW (#124), consultado em 11/10/2026; descrição em `cartao-us18.json`.
Missão: `.workers/missoes/2026-10-11-homem-aranha-reputacao-perfis-publicos.md`, no workspace Frila.

## Escopo e fonte

A nova suíte percorre Minhas vagas → detalhe da seleção → perfil público de Bruno Tavares → voltar → perfil público de Carla Menezes, no tamanho padrão e AX5. O cenário `selecao-com-candidatos` usa somente `ApiClienteEmMemoria` no esquema Frila-Local.

Os valores vêm de `iOS/Resources/Fixtures/candidatos.json`: Bruno tem 10 recomendações positivas em 12, 18 turnos realizados em 20 considerados; Carla tem todos esses contadores zerados e taxa nula. `perfilPublico(id:)` do dublê retorna o perfil da candidatura. Não se recalcula a regra RN08 neste teste.

`TelaPerfilPublico` usa `SeloReputacao`, que exibe o denominador da recomendação, os turnos realizados/considerados e, sem histórico, os textos “Sem histórico” e “Ainda não há turnos considerados.”. A suíte verifica esses textos, ausência dos números do perfil anterior, alvos de toque de 44 pt e limites horizontais. Capturas próprias permitem conferir o que foi renderizado.

## Independência

O cartão do Hulk é #71; seus arquivos ExclusaoDeContaUITests.swift e evidencias/exclusao-contratante-ax5 não são alterados. A consulta `prs-abertos-na-triagem.json` registra os arquivos dos PRs 163 e 180–188: nenhum é tocado. A nova classe entra automaticamente na parte 2 da CI, conforme `Scripts/partes-dos-testes.sh`; a conferência da divisão foi executada.

## Limites

Esta entrega cobre parte da história, sem encerrar o cartão. Não executa VoiceOver humano, aparelho físico, backend, perfil público de estabelecimento, cálculo servidor da RN08, nem a procura de estrelas em todas as telas. A ausência de truncamento depende também da inspeção das capturas; a largura de um elemento sozinha não a prova. Não houve alteração de fontes SwiftUI.

## Execução

- `xcb.sh Homem-Aranha -- xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination platform=iOS\ Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431 -only-testing:FrilaUITests/ReputacaoDosPerfisPublicosUITests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`, com DerivedData e xcresult próprios: **2/2 aprovados**, nenhuma falha ou teste pulado. Resumo em `resumo-local.json`.
- Ambiente observado no xcresult: simulador Homem-Aranha, iPhone 17, iOS 26.5 (23F77), arm64. Padrão e `UICTContentSizeCategoryAccessibilityXXXL` (AX5).
- Log integral: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/logs-xcodebuild/homem-aranha-20261011-112208-53173.log`. Trecho dos testes em `testes-locais.txt`.
- Oito capturas exportadas e inspecionadas: os textos de reputação dos perfis estão completos no padrão e AX5, com quebra de linha no tamanho maior. As telas vizinhas mostram a lista de candidatos e os botões de abertura de perfil.
- Bloqueios: 1 superado. Primeira tentativa parou antes dos testes porque `-disableAutomaticPackageResolution` recusou uma dependência transitiva. A repetição permitiu a resolução; nenhum pacote versionado foi alterado. Primeiro log: `homem-aranha-20261011-111938-45700.log`.
- Origin/main mesclada antes do teste final: já atualizada, base `57470a6`. Conferência de textos e divisão da CI aprovadas; nova classe na parte 2.
- Nick Fury autorizou expressamente a US18 como recorte de código de testes. O cartão foi colocado em Em andamento com Cauê, com comentário somente sobre o recorte e sem marcar critérios; registro em `trello-reserva.json`.
- Uma CI será disparada pela abertura do PR. O estado observado será entregue por ask-back e registrado na missão; não haverá nova execução.


## Capturas inspecionadas

| Tamanho / etapa | Evidência |
|---|---|
| ax5-candidatos-bruno | [captura](capturas/B12EEB26-8E37-4F45-92C7-AF522FA65285.png) |
| ax5-perfil-bruno | [captura](capturas/AFE98BC1-D0EA-44F7-93EE-7A0692730400.png) |
| ax5-candidatos-carla | [captura](capturas/65BF1615-23C5-423D-B4C6-411A143DE7C7.png) |
| ax5-perfil-carla | [captura](capturas/D920B1DF-78C6-4522-905D-C39D2B0FC76A.png) |
| padrao-candidatos-bruno | [captura](capturas/8B040F38-B831-4F93-939B-B0ACA3AD1387.png) |
| padrao-perfil-bruno | [captura](capturas/D410F673-9000-4010-8CFD-552C290A2D37.png) |
| padrao-candidatos-carla | [captura](capturas/9413FBCE-4F81-40A8-93CA-E4A868F084AB.png) |
| padrao-perfil-carla | [captura](capturas/1D4BC7A5-2C68-47BF-9A1E-AC939EB59A54.png) |
