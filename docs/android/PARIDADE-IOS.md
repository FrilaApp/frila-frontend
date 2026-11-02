# Mapa de Paridade Android × iOS (v1.0 → v1.2)

**Documento Normativo de Roadmap:** Cartão v1.2 ("App Android completo com paridade da v1.0")  
**Fontes Canônicas do iOS:** `iOS/Docs/Acessibilidade.md` (§ Checklist central de telas da v1.0, 46 telas/fluxos), `iOS/Docs/HiFi/REFERENCIA.md` e `iOS/Docs/PadroesDeEstado.md`.  
**Ambiente Android Alvo:** `android/` (Jetpack Compose, Material 3, Clean Architecture + Koin, minSdk 28).

---

## 1. Resumo Executivo da Paridade

O Frila iOS v1.0 possui **46 superfícies de interface** (43 telas catalogadas na auditoria de acessibilidade mais 3 fluxos/folhas integrados de sistema e suporte).

| Situação no Android | Quantidade | Percentual | Descrição |
|---|:---:|:---:|---|
| **Existe** | 16 | 34,8% | Telas plenamente funcionais com ViewModel, regras de domínio e cobertura de testes unitários/Compose |
| **Parcial** | 6 | 13,0% | Funcionalidades implementadas parcialmente (ex.: backend/PDF presente mas sem lista navegável na UI) |
| **Falta** | 24 | 52,2% | Telas ainda não iniciadas na plataforma Android |
| **Total** | **46** | **100,0%** | **Cobertura integral da camada de apresentação da v1.0** |

---

## 2. Tabela Geral de Paridade (46 Telas e Fluxos)

> [!NOTE]
> Os itens com a dependência **"depende do Fabrício"** aguardam refinamento de tokens Hi-Fi, componentes Figma ou alinhamento visual antes da implementação no Compose. Itens com dependência **"nenhuma / independente"** utilizam exclusivamente componentes e tokens existentes do Design System Android (`FrilaTheme`, `BotaoPrimario`, `AvisoFrila`, `EstadoErro`).

| # | Tela / Fluxo no iOS | View / Rota no iOS | Estado Android | Arquivo / Linha no Android | Esforço | Dependências | Ordem Sugerida |
|---|---|---|:---:|---|:---:|---|:---:|
| 1 | Entrada ("Frila") | `TelaEntrada` | **Existe** | `feature:entrada/.../TelaEntrada.kt:38` | P | Nenhuma | Concluído |
| 2 | Código de verificação ("Digite o código") | `TelaCodigo` | **Existe** | `feature:entrada/.../TelaCodigo.kt:39` | P | Nenhuma | Concluído |
| 3 | Cadastro ("Como você vai usar o Frila?") | `TelaCadastro` | **Existe** | `feature:entrada/.../TelaCadastro.kt:53` | P | Nenhuma | Concluído |
| 4 | Vagas no DF (Feed de vagas abertas) | `TelaVagas` | **Existe** | `feature:vagas/.../TelaFeedVagas.kt:60` | P | Nenhuma | Concluído |
| 5 | Detalhe da vaga | `TelaDetalheVaga` | **Existe** | `feature:vagas/.../TelaDetalheVaga.kt:60` | P | Nenhuma | Concluído |
| 6 | Turno confirmado! (Sucesso candidatura) | `TurnoConfirmado` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 7 | Vaga preenchida (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 8 | Vaga encerrada (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 9 | Conflito de horário (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 10 | Conta suspensa (Resultado candidatura) | `TelaResultadoDaCandidatura` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 11 | Candidaturas (Aba Minhas Candidaturas) | `TelaMinhasCandidaturas` | **Falta** | — | M | depende do Fabrício | Fase 2 |
| 12 | Meus turnos (Lista de turnos aceitos) | `TelaMeusTurnos` | **Existe** | `feature:turnos/.../TelaMeusTurnos.kt:60` | P | Nenhuma | Concluído |
| 13 | Meu turno (Acompanhamento individual) | `TelaMeuTurno` | **Parcial** | `feature:turnos/.../TelaMeusTurnos.kt:180` | M | depende do Fabrício | Fase 2 |
| 14 | Presença no turno (Check-in/Check-out) | `SecaoDePresenca` | **Existe** | `feature:turnos/.../DialogoComprovanteCheckin.kt:35` | P | Nenhuma | Concluído |
| 15 | Avaliação do turno (Profissional → Local) | `TelaAvaliacao` | **Existe** | `feature:turnos/.../TelaAvaliacao.kt:50` | P | Nenhuma | Concluído |
| 16 | Meu perfil (Visão geral da conta) | `TelaMeuPerfilProfissional` | **Existe** | `feature:perfil/.../TelaPerfil.kt:60` | P | Nenhuma | Concluído |
| 17 | Funções e horários (Disponibilidade) | `TelaPerfilProfissional` | **Falta** | — | M | depende do Fabrício | Fase 2 |
| 18 | Exclusão de conta (Direito LGPD) | `TelaExclusaoDeConta` | **Falta** | — | M | backend (Edge Function) | Fase 2 |
| 19 | Conta suspensa (Punição e contestação) | `TelaContaSuspensa` | **Falta** | — | M | depende do Fabrício | Fase 2 |
| 20 | Cadastro do estabelecimento | `TelaCadastroEstabelecimento` | **Falta** | — | G | depende do Fabrício + contrato | Fase 3 |
| 21 | Publicar vaga (Contratante) | `TelaPublicarVaga` | **Falta** | — | G | depende do Fabrício + contrato | Fase 3 |
| 22 | Minhas vagas (Painel do contratante) | `TelaMinhasVagas` | **Falta** | — | G | depende do Fabrício | Fase 3 |
| 23 | Detalhe da vaga do contratante | `TelaDetalheVagaContratante` | **Falta** | — | M | depende do Fabrício | Fase 3 |
| 24 | Candidatos da vaga (Modo Seleção) | `SecaoDeCandidatos` | **Falta** | — | G | depende do Fabrício | Fase 3 |
| 25 | Republicar vaga | `TelaRepublicarVaga` | **Falta** | — | M | depende do Fabrício | Fase 3 |
| 26 | Acompanhamento do turno (Contratante) | `TelaTurnoDoContratante` | **Falta** | — | G | depende do Fabrício | Fase 3 |
| 27 | Avaliação do profissional (Contratante) | `DestinoAvaliacaoDoContratante` | **Falta** | — | M | depende do Fabrício | Fase 3 |
| 28 | Perfil do estabelecimento | `TelaPerfilEstabelecimento` | **Falta** | — | M | depende do Fabrício | Fase 3 |
| 29 | Perfil público (Consulta mútua segura) | `TelaPerfilPublico` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 30 | Publicar vaga: erro ao ler casa | `TelaPublicarVaga (estado erro)` | **Falta** | — | P | fluxo contratante | Fase 3 |
| 31 | Folha de cancelamento (Contratante) | `FolhaDeCancelamento` | **Parcial** | `feature:turnos/.../DialogoCancelamentoTurno.kt:40` | M | depende do Fabrício | Fase 3 |
| 32 | Histórico de turnos e extrato | `TelaHistoricoDeTurnos` | **Parcial** | `feature:perfil/.../GeradorExtratoPdf.kt:30` | M | depende do Fabrício | Fase 2 |
| 33 | Confirmação de exclusão de conta | `TelaExclusaoDeConta (modal)` | **Falta** | — | P | tela de exclusão | Fase 2 |
| 34 | Por que recebo vagas (Transparência) | `TelaPorQueReceboVagas` | **Falta** | — | P | depende do Fabrício | Fase 2 |
| 35 | Equipe de confiança (Favoritos) | `TelaEquipeDeConfianca` | **Falta** | — | M | depende do Fabrício | Fase 3 |
| 36 | Folha de suporte no turno | `FolhaSuporteTurno` | **Parcial** | `feature:turnos/.../TelaOcorrencia.kt:45` | P | Nenhuma | Concluído |
| 37 | Folha de denúncia / bloqueio | `FolhaDeDenuncia` | **Falta** | — | M | depende do Fabrício + backend | Fase 2 |
| 38 | Ajuda do perfil (Canais / Termos) | `TelaAjudaPerfil` | **Existe** | `feature:perfil/.../TelaAjudaPerfil.kt:50` | P | Nenhuma | Concluído |
| 39 | Licenças de código aberto | `TelaLicencas` | **Existe** | `feature:perfil/.../TelaLicencas.kt:35` | P | Nenhuma | Concluído |
| 40 | Detalhe da licença | `TelaDetalheLicenca` | **Existe** | `feature:perfil/.../TelaDetalheLicenca.kt:30` | P | Nenhuma | Concluído |
| 41 | Explicação de notificações push | `TelaExplicacaoDoPush` | **Existe** | `feature:vagas/.../DialogoPermissaoNotificacao.kt:36` | P | Nenhuma | Concluído |
| 42 | Vaga indisponível (Aviso Push) | `TelaVagaIndisponivel` | **Existe** | `feature:vagas/.../TelaVagaIndisponivel.kt:40` | P | Nenhuma | Concluído |
| 43 | Turno do aviso não encontrado (Push) | `TelaTurnoNaoEncontrado` | **Existe** | `feature:turnos/.../TelaTurnoNaoEncontrado.kt:40` | P | Nenhuma | Concluído |
| 44 | Atualização obrigatória (Portão versão) | `TelaAtualizacaoObrigatoria` | **Existe** | `core:designsystem/.../TelaAtualizacaoObrigatoria.kt:42` | P | Nenhuma | Concluído |
| 45 | Compartilhamento / exportação | `FolhaCompartilhamento` | **Parcial** | `feature:perfil/.../GeradorExtratoPdf.kt:85` | P | Nenhuma | Concluído |
| 46 | Compositor de e-mail nativo | `CompositorDeEmailNativo` | **Parcial** | `feature:turnos/.../TelaOcorrencia.kt:120` | P | Nenhuma | Concluído |

---

## 3. Roteiro de Implementação Sugerido

### Fase 1: Apoio Institucional e Telas de Estado (Independente de Design Novo)
1. **Licenças de código aberto (`TelaLicencas` + `TelaDetalheLicenca`):** lista e detalha as dependências e licenças de código aberto (Kotlin, Jetpack Compose, Ktor, Koin, Coroutines, etc.) com conformidade legal. Esforço: **P**.
2. **Atualização obrigatória (`TelaAtualizacaoObrigatoria`):** bloqueio normativo de abertura quando a versão instalada é incompatível com a versão mínima da API, com atalho para a Google Play Store. Esforço: **P**.
3. **Ajuda do perfil (`TelaAjudaPerfil`):** canais oficiais de suporte, links legais para Termos de Uso e Política de Privacidade. Esforço: **P**.
4. **Estados de erro de deep link / push (`TelaVagaIndisponivel` e `TelaTurnoNaoEncontrado`):** desfechos limpos para links de notificação obsoletos. Esforço: **P**.

### Fase 2: Fechamento do App do Profissional (v1.2)
- Aba de Minhas Candidaturas (`TelaMinhasCandidaturas`);
- Transições completas de resultado de candidatura (`TurnoConfirmado`, `VagaPreenchida`, `ConflitoHorario`);
- Seletor de disponibilidade semanal em matriz (`TelaPerfilProfissional`);
- Fluxo de exclusão de conta (LGPD) e contestação de conta suspensa (`TelaContaSuspensa`).

### Fase 3: Módulo do Contratante (v1.2 Completo)
- Onboarding do estabelecimento (`TelaCadastroEstabelecimento`);
- Painel de controle de vagas (`TelaMinhasVagas`);
- Fluxo de criação de vaga (`TelaPublicarVaga`);
- Triagem e seleção de candidatos com indicação de equipe de confiança (`SecaoDeCandidatos`).
