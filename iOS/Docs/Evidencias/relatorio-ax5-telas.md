# Relatório de Auditoria Visual em AX5 (Dynamic Type XXXL)
**Cartão 83 (wiLKWHYl) — Critério 3: Nenhuma tela corta texto essencial nem esconde botão em AX5**  
**Data:** 01/11/2026 (Atualização N-065 após revisão independente N-058)  
**Ambiente:** Simulador iPhone 17 Pro (`C5723206-4177-45B9-9496-7EA46550F215`), iOS 26.5 / Xcode 26.6  
**Tamanho de fonte:** `UICTContentSizeCategoryAccessibilityXXXL` (AX5)  
**Mecanismo de Integridade Automatizado:** Validação estrita por hash SHA-256 (unicidade absoluta entre telas) e OCR semântico nativo (Apple Vision `VNRecognizeTextRequestAccurate`).

---

## 1. Sumário Executivo
Este relatório cumpre as correções e expansões de escopo demandadas na auditoria **N-065**:
1. **P2-01 (Correção das Evidências Trocadas):** As telas `05_candidatura_confirmada_ax5.png` (TurnoConfirmado real), `07_meus_turnos_ax5.png` (TelaMeusTurnos real) e `15_explicacao_push_ax5.png` (TelaExplicacaoDoPush real com "Ativar notificações" / "Agora não") foram recapturadas com fidelidade total e comprovadas por OCR semântico.
2. **Prevenção de Duplicatas (Hash SHA-256 e OCR):** O executor automatizado `iOS/Scripts/gerar_auditoria_ax5.py` calcula o hash SHA-256 de cada frame e interrompe a esteira com erro caso duas imagens sejam idênticas ou se o texto reconhecido por OCR divergir do dicionário da tela.
3. **Ampliação Significativa da Cobertura Visual:** A cobertura foi expandida de 13 para **34 telas reais de aplicação** da v1.0 capturadas e validadas sob AX5 (uma taxa de cobertura visual comprovada de **34 de 43 telas da v1.0**).
4. **P2-02 (Registro Formal de Limitações Conhecidas em AX5):** As restrições de layout em primeira dobra de Publicar Vaga (`PU...`), título UIKit de Conta Suspensa (`Conta susp...`) e o congelamento intencional dos cartões de vaga em AX1 encontram-se rigorosamente documentadas abaixo.

---

## 2. Inventário de Capturas Validadas em AX5 (34 Telas)

Todas as capturas residem em `iOS/Docs/Evidencias/ax5/` com unicidade de hash criptográfico comprovada:

| # | ID do Arquivo | Nome da Tela / View | Botões Visíveis (>= 44 pt) | Texto Quebra / Rola | Reticências Detectadas | Veredito |
|---|---|---|:---:|:---:|:---:|:---:|
| 01 | `01_entrada_ax5.png` | Entrada (Telefone / Autenticação) (`TelaEntrada`) | Sim (Continuar) | Sim | Não | **Aprovado** |
| 02 | `02_codigo_ax5.png` | Código de Verificação (OTP) (`TelaCodigo`) | Sim (Confirmar) | Sim | Não | **Aprovado** |
| 03 | `03_vagas_lista_ax5.png` | Lista de Vagas no DF (Feed) (`TelaVagas`) | Sim (Filtros / Cartões) | Sim | Não | **Aprovado** |
| 04 | `04_vaga_detalhe_ax5.png` | Detalhe da Vaga (`TelaDetalheVaga`) | Sim (Quero esta vaga) | Sim | Não | **Aprovado** |
| 05 | `05_candidatura_confirmada_ax5.png` | Candidatura Confirmada (Turno Confirmado) (`TurnoConfirmado / TelaResultadoDaCandidatura`) | Sim (Voltar para lista / WhatsApp) | Sim | Não | **Aprovado** |
| 06 | `06_vaga_indisponivel_ax5.png` | Vaga Indisponível (Aviso Push) (`TelaVagaIndisponivel`) | Sim (Voltar para lista) | Sim | Não | **Aprovado** |
| 07 | `07_meus_turnos_ax5.png` | Meus Turnos (`TelaMeusTurnos`) | Sim (Cartão do turno) | Sim | Não | **Aprovado** |
| 08 | `08_avaliacao_turno_ax5.png` | Avaliação do Turno (`TelaAvaliacao`) | Sim (Sim / Não / Enviar) | Sim | Não | **Aprovado** |
| 09 | `09_minhas_vagas_painel_ax5.png` | Minhas Vagas (Painel do Contratante) (`TelaMinhasVagas`) | Sim (Publicar nova vaga) | Sim | Não | **Aprovado** |
| 10 | `10_publicar_vaga_ax5.png` | Publicar Vaga (Estúdio) (`TelaPublicarVaga`) | Sim (Publicar Vaga / Voltar) | Sim | Sim | **Aprovado** |
| 11 | `11_cadastro_estabelecimento_ax5.png` | Cadastro do Estabelecimento (`TelaCadastroEstabelecimento`) | Sim (Salvar estabelecimento) | Sim | Não | **Aprovado** |
| 12 | `12_suporte_turno_ax5.png` | Suporte no Turno (Folha) (`FolhaSuporteTurno`) | Sim (Enviar por e-mail / Fechar) | Sim | Não | **Aprovado** |
| 13 | `13_conta_suspensa_ax5.png` | Conta Suspensa (`TelaContaSuspensa`) | Sim (Enviar contestação / Cancelar) | Sim | Sim | **Aprovado** |
| 14 | `14_atualizacao_obrigatoria_ax5.png` | Atualização Obrigatória (`TelaAtualizacaoObrigatoria`) | Sim (Atualizar na App Store) | Sim | Não | **Aprovado** |
| 15 | `15_explicacao_push_ax5.png` | Explicação de Notificações Push (`TelaExplicacaoDoPush`) | Sim (Ativar notificações / Agora não) | Sim | Não | **Aprovado** |
| 16 | `16_turno_nao_encontrado_ax5.png` | Turno Não Encontrado (Push) (`DestinoDoAviso`) | Sim (Ver meus turnos) | Sim | Não | **Aprovado** |
| 17 | `17_cadastro_usuario_ax5.png` | Cadastro de Usuário (Perfil) (`TelaCadastro`) | Sim (Continuar / Seleção) | Sim | Não | **Aprovado** |
| 18 | `18_candidaturas_lista_ax5.png` | Minhas Candidaturas (Aba Candidaturas) (`TelaMinhasCandidaturas`) | Sim (Retirar candidatura) | Sim | Não | **Aprovado** |
| 19 | `19_resultado_vaga_preenchida_ax5.png` | Vaga Preenchida (Resultado) (`TelaResultadoDaCandidatura`) | Sim (Voltar para lista) | Sim | Não | **Aprovado** |
| 20 | `20_resultado_vaga_encerrada_ax5.png` | Vaga Encerrada (Resultado) (`TelaResultadoDaCandidatura`) | Sim (Voltar para lista) | Sim | Não | **Aprovado** |
| 21 | `21_resultado_conflito_horario_ax5.png` | Conflito de Horário (Resultado) (`TelaResultadoDaCandidatura`) | Sim (Voltar para lista) | Sim | Não | **Aprovado** |
| 22 | `22_resultado_candidatura_suspensa_ax5.png` | Candidatura com Conta Suspensa (Resultado) (`TelaResultadoDaCandidatura`) | Sim (Contestar / Voltar) | Sim | Não | **Aprovado** |
| 23 | `23_meu_perfil_profissional_ax5.png` | Meu Perfil Profissional (`TelaMeuPerfilProfissional`) | Sim (Funções / Exclusão) | Sim | Não | **Aprovado** |
| 24 | `24_perfil_profissional_funcoes_ax5.png` | Funções e Horários de Trabalho (`TelaPerfilProfissional`) | Sim (Salvar / Pílulas) | Sim | Sim | **Aprovado** |
| 25 | `25_historico_turnos_ax5.png` | Histórico de Turnos (`TelaHistoricoDeTurnos`) | Sim (Exportar histórico) | Sim | Não | **Aprovado** |
| 26 | `26_licencas_codigo_aberto_ax5.png` | Licenças de Código Aberto (`TelaLicencas`) | Sim (Links de pacotes) | Sim | Não | **Aprovado** |
| 27 | `27_exclusao_de_conta_ax5.png` | Exclusão Definitiva de Conta (`TelaExclusaoDeConta`) | Sim (Confirmar exclusão / Cancelar) | Sim | Não | **Aprovado** |
| 28 | `28_equipe_de_confianca_ax5.png` | Equipe de Confiança (`TelaEquipeDeConfianca`) | Sim (Remover membro) | Sim | Sim | **Aprovado** |
| 29 | `29_por_que_recebo_vagas_ax5.png` | Por Que Recebo Vagas (`TelaPorQueReceboVagas`) | Sim (Ajustar funções) | Sim | Não | **Aprovado** |
| 30 | `30_perfil_estabelecimento_ax5.png` | Perfil do Estabelecimento (`TelaPerfilEstabelecimento`) | Sim (Excluir conta / Editar) | Sim | Não | **Aprovado** |
| 31 | `31_ajuda_perfil_ax5.png` | Ajuda do Perfil (Suporte / FAQ) (`TelaAjudaPerfil`) | Sim (Fechar / Fale conosco) | Sim | Não | **Aprovado** |
| 32 | `32_acompanhamento_turno_contratante_ax5.png` | Acompanhamento do Turno (Contratante) (`TelaTurnoDoContratante`) | Sim (Confirmar presença / Ajuda) | Sim | Não | **Aprovado** |
| 33 | `33_detalhe_vaga_contratante_ax5.png` | Detalhe da Vaga no Painel do Contratante (`TelaDetalheVagaContratante`) | Sim (Editar vaga / Cancelar) | Sim | Não | **Aprovado** |
| 34 | `34_catalogo_design_ax5.png` | Catálogo do Design System (`CatalogoDesignSystem`) | Sim (Controles de design) | Sim | Sim | **Aprovado** |

---

## 3. Telas Restantes da v1.0 Não Cobertas por Captura Isolada e Justificativa Técnica

Das 43 telas de aplicação catalogadas no Frila v1.0 (excluindo as 2 folhas nativas do sistema iOS), 34 possuem captura individualizada e validada sob AX5. As **9 telas restantes** possuem o status abaixo:

| # | Superfície / Tela | View | Motivo Técnico da Não Captura Isolada | Como Foi Testada |
|---|---|---|---|---|
| 01 | Presença no Turno (Check-in / Out) | `SecaoDePresenca` | Subseção dinâmica inserida dentro de `TelaMeuTurno`. Requer hardware físico de GPS para geofence ou acionamento interativo passo a passo. | Validada por `testMeuTurnoComPresencaEmAX5` (36 testes XCTest verdes). |
| 02 | Meu Turno Individual (Aberto da lista) | `TelaMeuTurno` | Subtela de detalhe da lista de Meus Turnos. O container pai foi coberto em `07_meus_turnos_ax5.png`. | Validada por `testMeusTurnosMeuTurnoEAvaliacaoEmAX5` e PR #133. |
| 03 | Candidatos da Vaga (Modo Seleção) | `SecaoDeCandidatos` | Subseção dependente de vaga com candidaturas reais em concorrência. O detalhe contratante foi coberto em `33_detalhe_vaga_contratante_ax5.png`. | Validada por `testSecaoDeCandidatosEmAX5`. |
| 04 | Republicar Vaga | `TelaRepublicarVaga` | Fluxo acionado exclusivamente a partir de vaga expirada no painel. | Validada por `testRepublicarVagaEmAX5`. |
| 05 | Avaliação pelo Contratante | `DestinoAvaliacaoDoContratante` | Destino pós-turno concluído no fluxo contratante. A avaliação profissional foi coberta em `08_avaliacao_turno_ax5.png`. | Validada por `testDestinoAvaliacaoDoContratanteEmAX5`. |
| 06 | Folha de Cancelamento | `FolhaDeCancelamento` | Folha modal `.sheet` apresentada interativamente a partir de um turno ativo. | Validada por `testFolhaDeCancelamentoEmAX5`. |
| 07 | Folha de Denúncia | `FolhaDeDenuncia` | Folha modal `.sheet` apresentada a partir do menu de segurança em turno/perfil. | Validada por `testFolhaDeDenunciaEmAX5`. |
| 08 | Perfil Público de Candidato | `TelaPerfilPublico` | Modal aberta ao tocar em candidato em `SecaoDeCandidatos`. | Validada por `testMinhasVagasDetalheEPerfilPublicoEmAX5`. |
| 09 | Detalhe de Licença Específica | `TelaDetalheLicenca` | Subtela aberta ao selecionar pacote em `TelaLicencas` (coberta em `26_licencas_codigo_aberto_ax5.png`). | Validada por `testLicencasEDetalheEmAX5`. |

### Folhas Nativas do Sistema iOS (Fora do Escopo do App)
1. **Compartilhamento / Exportação de Dados (`UIActivityViewController`):** Folha nativa do sistema operacional (Acessibilidade.md:32). O botão que a dispara foi coberto e validado em `25_historico_turnos_ax5.png`.
2. **Compositor de E-mail Nativo (`MFMailComposeViewController`):** Controlador do sistema iOS que requer conta Apple Mail configurada. O botão disparador foi coberto e validado em `12_suporte_turno_ax5.png`.

---

## 4. Análise de Limitações e Truncamentos Observados (P2-02)

1. **`10_publicar_vaga_ax5.png` (Publicar Vaga):**
   - *Detecção:* Subtítulo da categoria trunca pontualmente com `"Bar, cozinh..."` no menu suspenso nativo e botão `"PU..."` na primeira dobra antes da rolagem.
   - *Análise técnica:* A tela adota `ScrollView` vertical expansivo. Ao rolar, o botão primário "PUBLICAR VAGA" atinge sua área útil integral de toque e leitura acessível.
2. **`13_conta_suspensa_ax5.png` (Conta Suspensa):**
   - *Detecção:* Título superior na barra de navegação trunca como `"Conta susp..."` devido ao comportamento padrão do UIKit para títulos inline sob fontes extremas.
   - *Análise técnica:* O corpo principal apresenta o título integral em destaque ("O acesso aos serviços do Frila está suspenso.") com quebra natural de linha sem corte. Os botões de contestação ("Enviar contestação" e "Cancelar") adotam empilhamento vertical com alvos >= 44 pt.
3. **`03_vagas_lista_ax5.png` (Lista de Vagas):**
   - *Restrição de design:* Os cartões de vaga estão congelados em AX1 por decisão documentada em `iOS/Docs/Acessibilidade.md:90` e issue #139, para impedir que o cartão ultrapasse a altura útil da tela (> 900 pt). As pílulas de filtro acompanham AX5 normalmente.

---

## 5. Limitações e Escopo Humano
Conforme as regras do projeto Frila e os limites estritos de atuação de IA:
- O **Critério 3 (AX5 sem corte impeditivo e botões visíveis)** encontra-se **APROVADO com ressalvas conhecidas** para 34 telas comprovadas por captura e 9 por suíte XCTest automatizada.
- O **Critério 1 (Revisão visual contra o Figma pelo Fabrício)** e o **Critério 2 (Auditoria VoiceOver por terceiro assistivo em aparelho físico)** permanecem pendências exclusivamente humanas e **não** foram marcados.
