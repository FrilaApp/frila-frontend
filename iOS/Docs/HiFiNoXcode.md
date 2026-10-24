# Hi-Fi no Xcode: passo a passo

Como gerar o projeto, abrir no Xcode e ver todas as telas no design do Fabrício (claro e escuro), sem rede e contra o `frila-dev`.
Conferido do zero em 24/10/2026, `main` em `4d19e74f`, Xcode 27.0, simulador de iPhone (iOS 26.5). As capturas finais ficam
em `.workers/capita-marvel/hifi/final/` (inventário em `.workers/capita-marvel/hifi/INVENTARIO.md`).

## Pré-requisitos
- Xcode com um simulador de iPhone instalado. A CI fixa o 26.6 (`.github/workflows/ios.yml`); o 27.0 abre e compila o mesmo projeto.
- XcodeGen 2.45.3 (`brew install xcodegen`; a CI usa a mesma versão). O `Frila.xcodeproj` **não é versionado**: é gerado a partir de `project.yml`.
- Nenhum segredo para o esquema `Frila-Local`. Para o `Frila-Dev`, a URL e a chave publicável do `frila-dev` (passo 6).

## Abrir e rodar (API em memória, sem rede)
1. `git checkout main && git pull`
2. `cd iOS && Scripts/gerar-projeto.sh`. Gera o projeto e restaura o `Package.resolved`. Repita a cada `pull`, troca de branch ou arquivo novo em `Sources/`.
3. `open Frila.xcodeproj`
4. Esquema **Frila-Local**, um simulador de iPhone, ⌘R. O app abre com sessão de profissional e dados em memória (`ApiClienteEmMemoria`), no feed "Vagas no DF".
5. Claro/escuro: no simulador, ⇧⌘A alterna a aparência (menu Features → Toggle Appearance), ou Settings → Developer → Dark Appearance. Pela linha de comando: `xcrun simctl ui booted appearance dark` (ou `light`). Tamanho do texto: Settings → Accessibility → Display & Text Size → Larger Text (AX5 está adiado: não é portão).

Pela linha de comando, sem abrir o Xcode (mesmo resultado do ⌘R):

```
xcodebuild -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-frila build
xcrun simctl install booted /tmp/dd-frila/Build/Products/Debug-Local-iphonesimulator/Frila.app
xcrun simctl launch booted com.frila.org.app -FRILA_SCENARIO contratante -FRILA_ABRIR_PUBLICAR
```

## Cair direto numa tela
Edite o esquema (Product → Scheme → Edit Scheme → Run → Arguments → "Arguments Passed On Launch") com os mesmos argumentos que os
testes de UI usam. Cada linha abaixo é um conjunto; `-FRILA_SCENARIO` escolhe os dados do mock (lista completa: `enum Cenario` em
`Sources/Dados/ApiClienteEmMemoria.swift`). `-FRILA_SEM_ANIMACOES` tira as animações, útil para captura.

| Tela | Argumentos |
|---|---|
| Entrada (e-mail → código), sem sessão | `-FRILA_SCENARIO entrada` (ou `-FRILA_SEM_SESSAO` com qualquer cenário) |
| Tela do código, direto | `-FRILA_SCENARIO entrada -FRILA_ABRIR_CODIGO` |
| Código errado / expirado | `-FRILA_SCENARIO codigo-errado` / `codigo-expirado` |
| Primeiro acesso do profissional (cadastro) | `-FRILA_SCENARIO primeiro-acesso` (menor de idade: `menor-de-idade`) |
| Feed de vagas do profissional | sem argumento (ou `-FRILA_SCENARIO success`) |
| Vaga em seleção, candidatura pendente | `-FRILA_SCENARIO vaga-em-selecao` / `candidatura-pendente` |
| Candidatura escolhida / recusada / expirada | `-FRILA_SCENARIO candidatura-escolhida` / `candidatura-recusada` / `candidatura-expirada` |
| Vaga preenchida / encerrada / inelegível / função incompatível | `-FRILA_SCENARIO vaga-preenchida` / `vaga-encerrada` / `inelegivel` / `funcao-incompativel` |
| Erro na lista de vagas | `-FRILA_SCENARIO erro-na-lista` |
| Sem rede (cache) | `-FRILA_SCENARIO sem-rede` |
| Conta suspensa | `-FRILA_SCENARIO conta-suspensa` |
| Turno do profissional: a caminho / encerrado (avaliar) / cancelado / avaliado | `-FRILA_SCENARIO a-caminho` / `turno-encerrado` / `turno-cancelado` / `turno-avaliado` |
| Avaliação do turno aberta direto | `-FRILA_SCENARIO turno-encerrado -FRILA_ABRIR_AVALIACAO_UI_TEST` |
| Atualização obrigatória (portão) | `-FRILA_SCENARIO atualizacao-obrigatoria` |
| Contratante: Minhas vagas (painel) | `-FRILA_SCENARIO painel-contratante -FRILA_ABRIR_MINHAS_VAGAS` (painel vazio: `painel-vazio`) |
| Contratante: detalhe com candidatos | `-FRILA_SCENARIO selecao-com-candidatos -FRILA_ABRIR_MINHAS_VAGAS` |
| Contratante: pendências de presença → turno | `-FRILA_SCENARIO checkin-manual-pendente` (atraso: `atraso-no-turno`) |
| Contratante: vaga encerrada → republicar | `-FRILA_SCENARIO vaga-encerrada-contratante -FRILA_ABRIR_MINHAS_VAGAS` |
| Contratante: Estúdio de criação (publicar) | `-FRILA_SCENARIO contratante -FRILA_ABRIR_PUBLICAR` |
| Contratante sem casa: cadastro do estabelecimento | `-FRILA_ABRIR_CADASTRO_ESTABELECIMENTO -FRILA_CADASTRO_UI_TEST` (sem cenário; o segundo argumento usa o mock de primeiro acesso) |
| Equipe de confiança com membro | `-FRILA_SCENARIO equipe-de-confianca-com-membro` |
| Suporte do turno | `-FRILA_ABRIR_SUPORTE_TURNO` |
| Explicação e aviso de permissão de push | `-FRILA_PERMISSAO_PUSH nao-pedida` (ou `negada`); `-FRILA_PERMISSAO_PUSH_RESPOSTA negada` faz a pessoa recusar |
| Toque num push (vaga indisponível, turno, avaliação…) | `-FRILA_PUSH <tipo> -FRILA_PUSH_ID <uuid>`; tipos em `Sources/Dominio/AvisoDePush.swift` (`vaga`, `confirmacao`, `cancelamento`, `avaliacao_disponivel`, `vaga_vazia`…) |
| Catálogo do design system (todas as peças) | `-FRILA_ABRIR_CATALOGO` (`-FRILA_ABRIR_FOLHA_DEMO` abre a folha; `-FRILA_MODO_ESCURO` força o escuro) |

Os argumentos `-FRILA_*` só têm efeito no `Frila-Local` (Debug); os builds de Release ignoram o mock e os argumentos.

## Contra o `frila-dev` (backend de teste)
6. Gere `Configurations/Secrets.xcconfig` com `Scripts/generate-supabase-secrets.sh dev`, a partir das variáveis de ambiente
   `FRILA_SUPABASE_DEV_URL` e `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY` (o script valida e grava o arquivo com permissão 600, sem imprimir
   valores). O formato está em `Configurations/Secrets.example.xcconfig`; o arquivo gerado é ignorado pelo Git e nunca entra em commit.
   Esquema **Frila-Dev**, ⌘R. Detalhes dos ambientes: `Docs/Environments.md`.
7. Entre com a conta de demonstração (`revisao-contratante@frila.app` ou `revisao-profissional@frila.app`); o código fixo fica com o Cauê, fora do repositório.
8. Fluxo de prova (Fase 5 do Hi-Fi): como contratante, publicar uma vaga pelo Estúdio e vê-la em Minhas vagas; como profissional, ver a vaga no feed e candidatar-se.

## Conferido
- `Scripts/gerar-projeto.sh` com XcodeGen 2.45.3 e build do `Frila-Local` em simulador: passam na `main` em `4d19e74f`.
- O app abre no feed Hi-Fi; `-FRILA_SCENARIO contratante -FRILA_ABRIR_PUBLICAR` abre o Estúdio na etapa 1.
