# E2E do MVP contra o frila-dev — 21/10/2026 (Capitã Marvel)

Simulador "Capitã Marvel" (iPhone, iOS 26), esquema `Frila-Dev` (Debug-Dev, FRILA_ENVIRONMENT=frila-dev), base `origin/feat/backend-integracao` (25f7bf1). Contas de demonstração (contratante "Bar da Revisão" e "Perfil de Demonstração"). Nenhum dado de terceiros foi apagado; "Excluir conta" não foi exercido.

| # | Passo | Resultado | Captura |
|---|-------|-----------|---------|
| 1 | Contratante: Entrada (e-mail) | passou | 01-contratante-entrada |
| 2 | Contratante: Código de acesso | passou | 02-contratante-codigo |
| 3 | Contratante: Minhas vagas | passou | 03-contratante-minhas-vagas |
| 4 | Contratante: Perfil / Dados do negócio | passou (conta já cadastrada: tela de perfil, não o primeiro acesso) | 04-contratante-perfil-estabelecimento |
| 5 | Contratante: Publicar vaga (garçom, 22/10 18:34–21:34, R$ 150, seleção) | passou | 05-contratante-publicar-vaga-inicio, 06-contratante-publicar-vaga-preenchida |
| 6 | Permissão de aviso: aceitar (contratante) | passou | 08-permissao-aviso-tela-do-app, 09-permissao-aviso-dialogo-sistema, 10-permissao-aviso-aceita |
| 7 | Contratante: Vaga aberta sem candidatos | passou | 11-contratante-vaga-aberta-sem-candidatos |
| 8 | Profissional: Entrada + Código | passou | 12-profissional-entrada-codigo |
| 9 | Profissional: Vagas no DF | passou | 13-profissional-vagas-no-df |
| 10 | Profissional: Meu perfil | passou | 14-profissional-meu-perfil |
| 11 | Profissional: Funções e horários | passou | 15-profissional-funcoes-e-horarios |
| 12 | Profissional: Detalhe da vaga → candidatar | passou | 16-profissional-detalhe-da-vaga, 17-profissional-candidatura-enviada, 18-profissional-minhas-candidaturas |
| 13 | Contratante: sair e entrar de novo | **falhou (app)** — abriu direto no detalhe da vaga anterior | 19-contratante-apos-reentrar-detalhe-restaurado |
| 14 | Contratante: escolher candidato (modo seleção) | passou | 20-contratante-escolher-candidato |
| 15 | Contratante: Vaga preenchida com contato | passou | 21-contratante-vaga-preenchida-contato, 22-contratante-contato-liberado, 23-contratante-minhas-vagas-preenchida |
| 16 | Profissional: confirmação e contato | passou | 24-profissional-candidaturas-confirmada, 25-profissional-meus-turnos, 26-profissional-meu-turno-confirmado-contato |
| 17 | Sem rede numa lista (Vagas no DF) | passou: "Sem conexão" + "Tentar de novo"; com a rede de volta, a lista voltou no segundo toque | 27-sem-rede-lista-vagas, 28-sem-rede-tentar-de-novo, 29-rede-de-volta-lista-carregada |
| 18 | Sem rede numa ação (carregar perfil, check-in) | passou: erro claro, sem travar; Meus turnos em modo offline | 30-sem-rede-acao-carregar-perfil, 30-sem-rede-acao-check-in, 30-sem-rede-meus-turnos-modo-offline |
| 19 | Permissão de aviso: negar (profissional) | passou | 31-permissao-aviso-profissional-banner, 32-permissao-aviso-profissional-explicacao, 33-permissao-aviso-dialogo-negar, 34-permissao-aviso-negada-estado-do-app |
| 20 | Sessão expirada | pulado: sem acesso ao banco/painel do frila-dev para invalidar a sessão | — |

Sem rede foi simulado com proxy HTTP/HTTPS morto no Mac (`networksetup -setwebproxy … 127.0.0.1 9`), com o app relançado antes de cada teste (conexões keep-alive ignoram o proxy).

Defeito #1 (app): `FrilaApp.sairDaConta` não limpa a pilha do contratante (`RoteadorDoContratante.caminho`). PR `fix/e2e-mvp-rota-do-contratante-apos-sair`.

Observação (sem correção, fora do escopo): no Publicar vaga, o rótulo de acessibilidade do seletor de Função continua "Função, Função" depois de escolher uma função (`PublicarVaga.swift:707`).

Vaga criada no frila-dev: garçom, Bar da Revisão, 22/10/2026 18:34–21:34, R$ 150, responsável "Capita Marvel E2E", modo seleção, preenchida pelo Perfil de Demonstração (id não exibido pelo app).
