# Ajuda, Suporte e Termos no app iOS

Documento de auditoria técnica e matriz de rastreabilidade do fluxo de Ajuda, Suporte e Termos Legais do Frila iOS.
Atende ao critério de aceite do cartão Trello [#182 (MNm4dGWq)](https://trello.com/c/MNm4dGWq), mapeando cada tópico da Visão 7.3 a telas existentes no código do aplicativo, auditando a derivação dos canais oficiais e conferindo os requisitos da Diretriz 1.2 da App Store.

Data da auditoria: 11/10/2026
Auditor: Loki
Repositório: `frila-frontend`
Base: `origin/main` (`57470a6`)

---

## 1. Auditoria dos Canais Oficiais de Suporte e Termos Legais

### 1.1 Centralização e Derivação nas Telas de Perfil
A arquitetura do aplicativo centraliza os endereços oficiais e termos na estrutura `EnderecosOficiais` (`iOS/Sources/Apresentacao/EnderecosOficiais.swift:4-24`):
- `termosDeUso`: `https://frila.app/termos`
- `politicaDePrivacidade`: `https://frila.app/privacidade`
- `emailSuporte`: `suportefrila@gmail.com`
- `urlSuporte`: `mailto:\(emailSuporte)`

Nas telas de perfil e configurações, a auditoria confirmou que todos os pontos de contato derivam estritamente da injeção de `EnderecosOficiais`:
1. **Meu Perfil do Profissional (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:107-162`):**
   - Recebe `enderecos: EnderecosOficiais = .padrao` no ViewModel (`linha 111`).
   - Apresenta o botão "Ajuda" (`TextosPerfilConta.ajuda`, `linha 161`), abrindo a folha modal `TelaAjudaPerfil(enderecos: enderecos)` (`linha 344`).
2. **Perfil do Estabelecimento (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:245-299`):**
   - Recebe `enderecos: EnderecosOficiais = .padrao` no ViewModel (`linha 247`).
   - Apresenta o botão "Ajuda" (`TextosPerfilConta.ajuda`, `linha 298`), abrindo a folha modal `TelaAjudaPerfil(enderecos: enderecos)` (`linha 344`).
3. **Tela de Ajuda do Perfil (`iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:348-444`):**
   - Renderiza o link direto `enderecos.urlSuporte` com acessibilidade (`linhas 361-377`).
   - Expõe o endereço de texto `enderecos.emailSuporte` com seleção habilitada (`.textSelection(.enabled)`) e rótulo de acessibilidade `"E-mail: \(enderecos.emailSuporte)"` (`linhas 384-391`).
   - Exibe o prazo de atendimento informativo: `"Respondemos em até 5 dias úteis."` (`TextosPerfilConta.prazoSuporte`, `linha 393`).
   - Renderiza links externos autenticados para Termos de Uso (`enderecos.termosDeUso`, `linhas 399-414`) e Política de Privacidade (`enderecos.politicaDePrivacidade`, `linhas 415-430`).
   - Fornece rota de navegação para licenças de terceiros (`TelaLicencas()`, `linhas 431-440`).

**Conclusão da auditoria de Perfil:** Nenhuma string hardcoded de e-mail de suporte existe de forma dispersa nas telas de perfil (`PerfisDaConta.swift`). O canal é 100% derivado de `EnderecosOficiais.padrao.emailSuporte`.

### 1.2 Divergência Identificada de Canais de Suporte
A auditoria identificou uma bifurcação entre dois canais de suporte no repositório:
- **Canal em `EnderecosOficiais.padrao` (`EnderecosOficiais.swift:22`):** Configurado como `"suportefrila@gmail.com"`, verificado por testes de unidade e UI (`PerfisDaContaTests.swift:65,90,105`, `FrilaUITests.swift:740,781`, `ContaSuspensaUITests.swift:131`).
- **Canal em Suporte de Turno (`SuporteTurnoViewModel.swift:142` e `TextosDoSuporte.swift:36,41,42`):** Configurado como `"suporte@frila.app"`, alinhado à documentação de requisitos (`frila-docs/requisitos/ingestao-email-suporte-v1.1.md:13`).

**Recomendação:** Unificar o e-mail padrão de `EnderecosOficiais` para `"suporte@frila.app"` em ciclo coordenado com a atualização dos testes que fixam asserções em `suportefrila@gmail.com`.

---

## 2. Conformidade com a Diretriz 1.2 da App Store (User-Generated Content e Moderação)

A Diretriz 1.2 da App Store exige que aplicativos com conteúdo gerado por usuários incluam:
1. Mecanismo para denúncia de conteúdo ofensivo/abusivo.
2. Compromisso de resposta e moderação tempestiva em até 24 horas.
3. Mecanismo para bloqueio de usuários abusivos.
4. Informações de contato publicadas e acessíveis.

### Estado de Conformidade no App iOS:
- **Mecanismo de Denúncia (Conforme):** `FolhaDeDenuncia` (`iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:62-150`), integrada com a RPC `denunciar` (alvo, motivo, relato de no mínimo 10 caracteres e geração de protocolo).
- **Mecanismo de Bloqueio (Conforme):** `BotaoBloquear` (`iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:20-60`), executando bloqueio mútuo definitivo entre profissional e estabelecimento para impedir qualquer novo contato na plataforma.
- **Informações de Contato (Conforme):** Disponibilizadas em `TelaAjudaPerfil` (`PerfisDaConta.swift:348-444`) com e-mail clicável e copiável.
- **Prazo de Atendimento / SLA de 24 horas (Ponto de Atenção):**
  - O texto informativo de perfil indica `"Respondemos em até 5 dias úteis."` (`TextosPerfilConta.prazoSuporte`).
  - O protocolo de denúncia (`AcoesDeSeguranca.swift:83-89`) calcula a data limite a partir de `protocolo.prazoRespostaAte`, que no backend (`privado.prazo_de_resposta`) projeta o quinto dia útil.
  - Para cumprir formalmente a Diretriz 1.2 da App Store durante a revisão da Apple, o canal de moderação e denúncias de conteúdo ofensivo deve assegurar SLA operacional de triagem em até 24 horas (distinto do suporte negocial geral de 5 dias úteis).

---

## 3. Matriz de Rastreabilidade dos Tópicos de Ajuda (Visão 7.3)

Mapeamento de todos os itens funcionais e tópicos de ajuda às respectivas telas implementadas no aplicativo iOS:

| Tópico de Ajuda / Negócio (Visão 7.3) | Tela / Componente iOS | Arquivo(s) Fonte | Descrição do Fluxo e Decisão no App |
|---|---|---|---|
| **Como funciona o pagamento de freela** | Tela de Histórico de Turnos e Detalhes da Vaga | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaHistoricoDeTurnos.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/TextosHistoricoDeTurnos.swift:8`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift` | O app esclarece explicitamente que o valor exibido é acordado diretamente entre as partes e pago pela casa ao profissional sem intermediação de pagamento pelo Frila. |
| **Política de cancelamento de turno** | Folha de Cancelamento de Turno / Meu Turno | `iOS/Sources/Apresentacao/Fluxos/Cancelamento/FolhaDeCancelamento.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:188`<br>`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:386`<br>`iOS/Sources/Apresentacao/Fluxos/Cancelamento/TextosDoCancelamento.swift` | Apresenta modal de cancelamento com validação de antecedência, justificativa e indicação clara de registro de falta (RN24). Notifica a contraparte e atualiza o estado do turno. |
| **Suporte em turno ativo** | Folha de Suporte do Turno | `iOS/Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/SuporteTurnoViewModel.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/TextosDoSuporte.swift` | Acionada via "Ajuda no turno" em turnos confirmados. Chama RPC `abrir_suporte` (UC14, RF23), gera número de protocolo e abre compositor de e-mail para `suporte@frila.app`. Inclui atalhos de emergência para 190 e 180. |
| **Contestação de suspensão de conta** | Tela de Conta Suspensa | `iOS/Sources/Apresentacao/Fluxos/Conta/TelaContaSuspensa.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Conta/ContaSuspensaViewModel.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Conta/TextosContaSuspensa.swift` | Exibida em bloqueios de acesso por suspensão (403). Permite envio de relato de contestação (RPC `contestar_suspensao`), exibe número de protocolo e acompanha prazo de resposta. |
| **Revisão de despacho / elegibilidade de vagas** | Tela "Por que recebo vagas" | `iOS/Sources/Apresentacao/Fluxos/Perfil/TelaPorQueReceboVagas.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/PorQueReceboVagasViewModel.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Perfil/TextosPorQueReceboVagas.swift` | Explica as regras de compatibilidade de vagas (funções, distância e horários de disponibilidade) e oferece ação para solicitar revisão formal de despacho. |
| **Denúncia de conduta ou conteúdo (Diretriz 1.2)** | Folha de Denúncia | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:62-150`<br>`iOS/Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift`<br>`iOS/Sources/Apresentacao/Fluxos/Confianca/TextosDaSeguranca.swift` | Modal para reportar assédio, discriminação ou problemas de conduta com justificativa obrigatória e geração de protocolo de ocorrência. |
| **Bloqueio mútuo de usuários (Diretriz 1.2)** | Ações de Segurança | `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:20-60` | Botão que aciona a RPC `bloquear`, cessando imediatamente novas visualizações de vagas, candidaturas ou mensagens entre as partes. |
| **Termos de Uso e Política de Privacidade** | Tela de Ajuda do Perfil | `iOS/Sources/Apresentacao/Fluxos/Perfil/PerfisDaConta.swift:399-430`<br>`iOS/Sources/Apresentacao/EnderecosOficiais.swift:20-21` | Links para `https://frila.app/termos` e `https://frila.app/privacidade` com rótulos acessíveis e abertura no navegador do sistema. |
| **Licenças de bibliotecas e terceiros** | Tela de Licenças | `iOS/Sources/Apresentacao/TelaLicencas.swift`<br>`iOS/Resources/Licencas.json` | Lista todas as dependências de código aberto e suas respectivas licenças de distribuição. |

---

## 4. Auditoria de Textos e Conformidade de Scripts
- O script oficial de verificação de catálogo de textos e tokens (`iOS/Scripts/conferir-textos.sh`) foi executado e concluiu com sucesso (`OK: textos no bundle da Apresentação e tokens em conformidade`).
- Nenhuma string ou chave de localização ficou fora do catálogo ou em desconformidade com os tokens de design.
