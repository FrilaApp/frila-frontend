# Mapa de Paridade Android × iOS (v1.0 → v1.2)

**Documento Normativo de Roadmap:** Cartão v1.2 ("App Android completo com paridade da v1.0")  
**Data da Auditoria Atualizada:** 19/11/2026 (auditado contra a `main`, commit `b7ad4248`)  
**Fontes Canônicas do iOS:** `iOS/Docs/Acessibilidade.md` (§ Checklist central de telas da v1.0, 46 telas/fluxos), `iOS/Docs/HiFi/REFERENCIA.md` e `iOS/Docs/PadroesDeEstado.md`.  
**Ambiente Android Alvo:** `android/` (Jetpack Compose, Material 3, Clean Architecture + Koin, minSdk 28).  
**Diretriz de Design (Regras 16-11 e 16-14):** Nenhuma frente espera tela do Fabrício. Telas novas são implementadas como **PROVISÓRIAS de baixíssima fidelidade** (`// TELA PROVISÓRIA`), com componentes nativos existentes, prontas para substituição posterior pelo High-Fi.

---

## 1. Resumo Executivo da Paridade

O Frila iOS v1.0 possui **46 superfícies de interface** catalogadas (43 telas catalogadas na auditoria de acessibilidade mais 3 fluxos/folhas integrados de sistema e suporte).

A auditoria anterior (02/11/2026) reportava apenas 17 telas existentes e 22 faltantes. A auditoria minuciosa do código da `main` em **19/11/2026** comprova que a ampla maioria das telas já foi implementada (incluindo todo o módulo do contratante, painel de vagas, publicação, cancelamento, triagem de candidatos, equipe de confiança, denúncia/bloqueio, conta suspensa e check-in/check-out).

| Situação no Android | Quantidade | Percentual | Descrição |
|---|:---:|:---:|---|
| **Existe** | **35** | **76,1%** | Telas e fluxos plenamente funcionais com ViewModel, regras de domínio e cobertura de testes unitários/Compose na `main` |
| **Parcial** | **7** | **15,2%** | Funcionalidades implementadas e ativas, porém integradas em cartões expansíveis/inline ou cobrindo parte do fluxo (ex.: histórico no feed de turnos, detalhes no cartão de Minhas Vagas) |
| **Falta** | **4** | **8,7%** | Telas que ainda não possuem interface dedicada no Android |
| **Total** | **46** | **100,0%** | **Cobertura integral da camada de apresentação da v1.0** |

---

## 2. Tabela Geral de Paridade (46 Telas e Fluxos)

> [!NOTE]
> Conforme as regras permanentes 16-11 e 16-14 da orquestração, **nenhuma implementação nova espera tela do Fabrício**. Telas faltantes utilizam componentes nativos do Design System Android (`FrilaTema`, `BotaoPrimario`, `BotaoSecundario`, `AvisoFrila`, `EstadoErro`) marcadas no topo com o comentário normativo `// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício`.

| # | Tela / Fluxo no iOS | View / Rota no iOS | Estado Android | Arquivo / Linha no Android | Esforço | Dependências / Observações | Lote |
|---|---|---|:---:|---|:---:|---|:---:|
| 1 | Entrada ("Frila") | `TelaEntrada` | **Existe** | `feature/entrada/src/main/kotlin/br/com/frila/feature/entrada/entrada/TelaEntrada.kt:52` | P | Nenhuma | Concluído |
| 2 | Código de verificação ("Digite o código") | `TelaCodigo` | **Existe** | `feature/entrada/src/main/kotlin/br/com/frila/feature/entrada/codigo/TelaCodigo.kt:51` | P | Nenhuma | Concluído |
| 3 | Cadastro ("Como você vai usar o Frila?") | `TelaCadastro` | **Existe** | `feature/entrada/src/main/kotlin/br/com/frila/feature/entrada/cadastro/TelaCadastro.kt:57` | P | Nenhuma | Concluído |
| 4 | Vagas no DF (Feed de vagas abertas) | `TelaVagas` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/feed/TelaFeedVagas.kt:54` | P | Nenhuma | Concluído |
| 5 | Detalhe da vaga | `TelaDetalheVaga` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaDetalheVaga.kt:69` | P | Nenhuma | Concluído |
| 6 | Turno confirmado! (Sucesso candidatura) | `TurnoConfirmado` | **Existe (provisória)** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaTurnoConfirmado.kt:54` | P | Nenhuma | Concluído |
| 7 | Vaga preenchida (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Parcial** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaVagaIndisponivel.kt:108` | P | Tratada via push em `TelaVagaIndisponivel.kt`; falta transição direta da candidatura | Lote A |
| 8 | Vaga encerrada (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Parcial** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaVagaIndisponivel.kt:108` | P | Tratada via push em `TelaVagaIndisponivel.kt`; falta transição direta da candidatura | Lote A |
| 9 | Conflito de horário (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Existe (provisória)** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaConflitoHorario.kt:52` | P | Nenhuma | Concluído |
| 10 | Conta suspensa (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Parcial** | `feature/conta/src/main/kotlin/br/com/frila/feature/conta/TelaContaSuspensa.kt:42` | P | `TelaContaSuspensa` existe; falta transição direta da candidatura | Lote A |
| 11 | Candidaturas (Aba Minhas Candidaturas) | `TelaMinhasCandidaturas` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/candidaturas/TelasCandidaturas.kt:73` | M | Fiação em `AppNavegacao.kt:1215` | Concluído |
| 12 | Meus turnos (Lista de turnos aceitos) | `TelaMeusTurnos` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaMeusTurnos.kt:86` | P | Nenhuma | Concluído |
| 13 | Meu turno (Acompanhamento individual) | `TelaMeuTurno` | **Parcial** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaMeusTurnos.kt:314` | M | Detalhes consolidados em `CartaoDoTurno`; sem tela cheia isolada | Lote C |
| 14 | Presença no turno (Check-in/Check-out) | `SecaoDePresenca` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaMeusTurnos.kt:360` | P | `SecaoDeCheckout.kt:36` e `DialogoComprovanteCheckin.kt:35` implementados | Concluído |
| 15 | Avaliação do turno (Profissional → Local) | `TelaAvaliacao` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaAvaliacao.kt:42` | P | Nenhuma | Concluído |
| 16 | Meu perfil (Visão geral da conta) | `TelaMeuPerfilProfissional` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaPerfil.kt:111` | P | Nenhuma | Concluído |
| 17 | Funções e horários (Disponibilidade) | `TelaPerfilProfissional` | **Existe (provisória)** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaFuncoesEHorarios.kt:45` | M | Nenhuma | Concluído |
| 18 | Exclusão de conta (Direito LGPD) | `TelaExclusaoDeConta` | **Existe** | `feature/conta/src/main/kotlin/br/com/frila/feature/conta/TelaExclusaoDeConta.kt:55` | M | Fiação em `AppNavegacao.kt:700` | Concluído |
| 19 | Conta suspensa (Punição e contestação) | `TelaContaSuspensa` | **Existe** | `feature/conta/src/main/kotlin/br/com/frila/feature/conta/TelaContaSuspensa.kt:42` | M | `TelasContestacao.kt:48,139` (fiação em `AppNavegacao.kt:931`) | Concluído |
| 20 | Cadastro do estabelecimento | `TelaCadastroEstabelecimento` | **Existe** | `feature/estabelecimento/src/main/kotlin/br/com/frila/feature/estabelecimento/TelaCadastroEstabelecimento.kt:39` | G | Fiação em `AppNavegacao.kt:1034` | Concluído |
| 21 | Publicar vaga (Contratante) | `TelaPublicarVaga` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/publicacao/TelaPublicarVaga.kt:91` | G | Fiação em `AppNavegacao.kt:1133` | Concluído |
| 22 | Minhas vagas (Painel do contratante) | `TelaMinhasVagas` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/painel/TelaMinhasVagas.kt:86` | G | Fiação em `AppNavegacao.kt:1149` | Concluído |
| 23 | Detalhe da vaga do contratante | `TelaDetalheVagaContratante` | **Parcial** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/painel/TelaMinhasVagas.kt:223` | M | Detalhes em `CartaoDaVaga` e `TelaCandidatosDaVaga.kt:87` | Lote C |
| 24 | Candidatos da vaga (Modo Seleção) | `SecaoDeCandidatos` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/candidatos/TelaCandidatosDaVaga.kt:87` | G | Fiação em `AppNavegacao.kt:1200` | Concluído |
| 25 | Republicar vaga | `TelaRepublicarVaga` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/painel/TelasRepublicarVaga.kt:33` | M | Linhas 33 e 130; fiação em `AppNavegacao.kt:1172,1198` | Concluído |
| 26 | Acompanhamento do turno (Contratante) | `TelaTurnoDoContratante` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/contratante/TelaTurnoDoContratante.kt:64` | G | Fiação em `ContratanteNavegacao.kt:70` | Concluído |
| 27 | Avaliação do profissional (Contratante) | `DestinoAvaliacaoDoContratante` | **Existe (provisória)** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/contratante/TelaAvaliacaoDoContratante.kt:44` | M | Nenhuma | Concluído |
| 28 | Perfil do estabelecimento | `TelaPerfilEstabelecimento` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaPerfil.kt:531` | M | `ConteudoDaCasa` com ações, atalhos administrativos e encerramento | Concluído |
| 29 | Perfil público (Consulta mútua segura) | `TelaPerfilPublico` | **Existe** | `feature/chamadas/src/main/kotlin/br/com/frila/feature/chamadas/casa/TelaPerfilPublico.kt:35` | P | Fiação em `RotasChamadaCasa.kt:105` | Concluído |
| 30 | Publicar vaga: erro ao ler casa | `TelaPublicarVaga (estado erro)` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/publicacao/TelaPublicarVaga.kt:159` | P | Tratamento inline via `AvisoFrila` e `MensagemJuntoAoBotao` | Concluído |
| 31 | Folha de cancelamento (Contratante) | `FolhaDeCancelamento` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/painel/TelaCancelarVaga.kt:30` | M | `TelaCancelarVaga.kt:30` e `DialogoCancelamentoTurno.kt:441` | Concluído |
| 32 | Histórico de turnos e extrato | `TelaHistoricoDeTurnos` | **Existe (provisória)** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaHistoricoDeTurnos.kt:45` | M | Tela dedicada com período, formato CSV/PDF e compartilhamento | Concluído |
| 33 | Confirmação de exclusão de conta | `TelaExclusaoDeConta (modal)` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaPerfil.kt:1123` | P | `DialogoConfirmarExclusao` em `TelaPerfil.kt:1123` | Concluído |
| 34 | Por que recebo vagas (Transparência) | `TelaPorQueReceboVagas` | **Parcial** | `feature/conta/src/main/kotlin/br/com/frila/feature/conta/TelasContestacao.kt:139` | P | `TelaContestarDespacho.kt:139` existe; falta tela explicativa | Lote B |
| 35 | Equipe de confiança (Favoritos) | `TelaEquipeDeConfianca` | **Existe** | `feature/equipe/src/main/kotlin/br/com/frila/feature/equipe/TelaEquipeDeConfianca.kt:46` | M | `TelaEquipeDeConfianca.kt:46` e `TelaEquipeDaCasa.kt:48` | Concluído |
| 36 | Folha de suporte no turno | `FolhaSuporteTurno` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaOcorrencia.kt:45` | P | Fiação em `AppNavegacao.kt:1316` | Concluído |
| 37 | Folha de denúncia / bloqueio | `FolhaDeDenuncia` | **Existe** | `feature/suporte/src/main/kotlin/br/com/frila/feature/suporte/TelaDenuncia.kt:42` | M | `TelaDenuncia.kt:42` e `TelaBloqueios.kt:42` (`AppNavegacao.kt:985`) | Concluído |
| 38 | Ajuda do perfil (Canais / Termos) | `TelaAjudaPerfil` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaAjudaPerfil.kt:66` | P | Fiação em `AppNavegacao.kt:856` | Concluído |
| 39 | Licenças de código aberto | `TelaLicencas` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaLicencas.kt:467` | P | Fiação em `AppNavegacao.kt:863` | Concluído |
| 40 | Detalhe da licença | `TelaDetalheLicenca` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaLicencas.kt:521` | P | Fiação em `AppNavegacao.kt:869` | Concluído |
| 41 | Explicação de notificações push | `TelaExplicacaoDoPush` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/DialogoPermissaoNotificacao.kt:23` | P | Integrado em `TelaDetalheVaga.kt:104` | Concluído |
| 42 | Vaga indisponível (Aviso Push) | `TelaVagaIndisponivel` | **Existe** | `feature/vagas/src/main/kotlin/br/com/frila/feature/vagas/detalhe/TelaVagaIndisponivel.kt:108` | P | Fiação em `AppNavegacao.kt:1232` | Concluído |
| 43 | Turno do aviso não encontrado (Push) | `TelaTurnoNaoEncontrado` | **Existe** | `feature/turnos/src/main/kotlin/br/com/frila/feature/turnos/TelaTurnoNaoEncontrado.kt:36` | P | Fiação em `AppNavegacao.kt:1270` | Concluído |
| 44 | Atualização obrigatória (Portão versão) | `TelaAtualizacaoObrigatoria` | **Existe** | `core/designsystem/src/main/kotlin/br/com/frila/core/designsystem/componentes/TelaAtualizacaoObrigatoria.kt:62` | P | Nenhuma | Concluído |
| 45 | Compartilhamento / exportação | `FolhaCompartilhamento` | **Existe** | `feature/perfil/src/main/kotlin/br/com/frila/feature/perfil/TelaPerfil.kt:301` | P | `Intent.ACTION_SEND` nativo via FileProvider | Concluído |
| 46 | Compositor de e-mail nativo | `CompositorDeEmailNativo` | **Existe** | `app/src/main/kotlin/br/com/frila/app/EmailDeSuporte.kt:14` | P | `Intent.ACTION_SENDTO` nativo com mailto e fallback | Concluído |

---

## Fora do ecossistema: verificação de identidade (decisão do Cauê, 19/11/2026)

A verificação de identidade (envio de RG/CNH e selfie, o selo "Identidade Verificada" e a exigência depois de denúncia grave) está **fora do Frila nas três plataformas**: sem análise, sem verba, com jurídico trabalhoso e telas faltando. Não é falta de paridade: o iOS e a web não a terão, e o Android não a liga.

- **Android:** o código existe (`core/rede/.../ServicoVerificacaoIdentidade.kt`, `RepositorioVerificacaoIdentidade.kt`, `feature/perfil/.../TelaVerificacaoDocumento.kt` e `TelaConsentimentoSelo.kt`, `core/dominio/.../RegraSeloConfianca.kt`), mas fica atrás da chave `recursoSeloHabilitado` (`app/.../AppNavegacao.kt:297`), que é `false` por padrão e não é ligada em lugar nenhum do código. Desligada, a rota `selo_confianca` nem entra no grafo e o perfil não consulta o selo. Ela não pede permissão de câmera nem traz biblioteca de câmera; a foto da tela de perfil usa o seletor do sistema (`PickVisualMedia`), sem permissão. Por isso nada disso aparece na ficha de Segurança dos Dados da Play.
- **Não ligar a chave** (vale também o alerta do parecer P-059 da Bússola: a Política não cobre esse envio). Se a decisão mudar, o caminho é um parecer novo, a Política nova e as telas do Fabrício.
- **iOS e web:** não há código de verificação; só o espelho do contrato (`/rpc/solicitar_upload_verificacao` e `/rpc/confirmar_envio_verificacao` em `iOS/Contrato/openapi.yaml` e `Web/contrato/openapi.yaml`).

## 3. O Que Falta de Verdade (Organização em Lotes)

A auditoria comprova que restam apenas **4 telas totalmente não iniciadas** e **7 superfícies parciais** (que funcionam inline ou em componentes compartilhados, mas carecem de transição dedicada ou tela cheia independente).

Seguindo as regras permanentes 16-11 e 16-14 (telas novas com `// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício`, sem esperar design), o trabalho restante é organizado em 3 lotes objetivos:

### Lote A: Desfechos de Candidatura e Avaliação pelo Contratante
1. **Turno confirmado! (`TurnoConfirmado`) — Item 6 (Falta):**
   - Criação da tela provisória de desfecho positivo após candidatura bem-sucedida em vaga urgente.
   - Apresenta: celebração ("Turno confirmado!"), função, dia, horário, endereço, quem recebe e botão "Ver meus turnos" navegando para a aba de Meus Turnos.
2. **Desfechos de candidatura (`TelaResultadoDaCandidatura`) — Itens 7, 8, 9, 10 (Falta / Parcial):**
   - Transições de tela dedicada para:
     - Conflito de horário (Item 9, Falta) — `422 conflito_horario`;
     - Vaga preenchida (Item 7, Parcial) — `409 posicao_ja_preenchida`;
     - Vaga encerrada (Item 8, Parcial) — `409 vaga_encerrada`;
     - Conta suspensa (Item 10, Parcial) — `403 conta_suspensa` com atalho para `TelaContaSuspensa`.
3. **Avaliação do profissional pelo contratante (`DestinoAvaliacaoDoContratante`) — Item 27 (Falta):**
   - Adaptação/extensão de `TelaAvaliacao` para suportar o fluxo da casa: pergunta ("Você contrataria/chamaria esse profissional de novo?"), registro binário e envio para `/rpc/avaliar_turno`.

### Lote B: Disponibilidade do Profissional e Transparência de Vagas
1. **Funções e horários / Disponibilidade semanal (`TelaPerfilProfissional`) — Item 17 (Falta):**
   - Tela provisória para visualização e edição de:
     - Funções exercidas pelo profissional (seleção via catálogo);
     - Grade de disponibilidade semanal (matriz dos 7 dias com horários de início e fim).
   - O contrato e a camada de rede já possuem suporte completo (`DtosPerfil.kt:14-34`).
2. **Por que recebo vagas / Transparência explicativa (`TelaPorQueReceboVagas`) — Item 34 (Parcial):**
   - Tela explicativa com os critérios algorítmicos que levaram o profissional a receber a vaga (distância, função, reputação e disponibilidade).
   - A contestação de despacho já está implementada (`TelaContestarDespacho.kt:139` e `ServicoConta.kt:62`), bastando ligá-la como ação secundária desta tela.

### Lote C: Telas Cheias Dedicadas (Refinamento de Apresentação)
1. **Acompanhamento individual do turno (`TelaMeuTurno`) — Item 13 (Parcial):**
   - O acompanhamento já funciona integralmente dentro de `CartaoDoTurno` em `TelaMeusTurnos.kt:314`. Este item consiste na extração opcional para uma tela cheia dedicada com rota própria `meu_turno/{turnoId}`.
2. **Detalhe da vaga do contratante (`TelaDetalheVagaContratante`) — Item 23 (Parcial):**
   - Os detalhes já são exibidos no `CartaoDaVaga` de `TelaMinhasVagas.kt:223` e na `TelaCandidatosDaVaga.kt:87`. Este item consiste na rota isolada caso necessária.
3. **Histórico de turnos com filtros de período e exportação CSV/PDF (`TelaHistoricoDeTurnos`) — Item 32 (Parcial):**
   - A listagem com paginação infinita já funciona na aba Histórico de `TelaMeusTurnos.kt:153` e o PDF é gerado via `TelaPerfil.kt:298`. Este item consiste em adicionar seletor de datas e formato (CSV/PDF) numa tela dedicada.
