# Notas do TestFlight 0.5 (Atualizado para Build 0.5.5+)

Notas da versão ("O que testar" / *What to Test*) para o build **0.5.5+** do Frila no TestFlight, em cumprimento ao Cartão [Kd0RVh9q](https://trello.com/c/Kd0RVh9q) e consolidado a partir do histórico de commits da branch `main` (PRs #291, #292, #299, #447, #449, #450, #523, #544, #616, #624, #626, #631, #635 e #636).

---

## 1. O que testar (Texto para o TestFlight em português simples)

1. **Notificações de vagas:** Permita o envio de notificações no momento em que o aplicativo solicitar (ao salvar perfil ou publicar vaga). Ao tocar na notificação recebida, o aplicativo abre diretamente os detalhes da vaga ou do turno correspondente.
2. **Privacidade na tela bloqueada:** Caso o aparelho seja utilizado por mais de uma pessoa ou a conta seja trocada, avisos destinados a outros vínculos exibem apenas "Nova notificação disponível", protegendo dados de turnos e estabelecimentos.
3. **Chegada ao turno (Check-in):** Ao chegar ao endereço combinado no horário de início, toque em "Fazer check-in". O aplicativo confere a proximidade pelo GPS (até 200 metros).
4. **Check-in sem sinal de GPS (Manual):** Se estiver em subsolo, sem sinal de localização ou sem permissão de GPS concedida, toque em "Fazer check-in manual". O pedido é registrado e fica aguardando a confirmação do contratante na tela de acompanhamento.
5. **Saída do turno (Check-out):** Ao concluir a jornada de trabalho, toque em "Fazer check-out" para registrar o encerramento do turno.
6. **Avaliação rápida:** Após o término do turno, responda à pergunta direta: "Você trabalharia nesse local de novo?" selecionando "Sim" ou "Não" e tocando em "Enviar avaliação". Se estiver sem conexão à internet no momento, a resposta fica guardada com segurança no aparelho e é enviada automaticamente assim que a conexão retornar.
7. **Painel do contratante e publicação de vagas:** Para estabelecimentos, experimente o fluxo de publicação com seleção simplificada de função, remuneração e horário, e acompanhe as vagas abertas na nova barra unificada.
8. **Leitura com fontes ampliadas:** Se você utiliza tamanhos de texto maiores nos Ajustes do iPhone (Dynamic Type / Acessibilidade), navegue pelas telas para conferir se textos e botões continuam confortáveis e totalmente acessíveis.

---

## 2. Mudanças nos Builds 0.5.1 a 0.5.5+ (Comparativo de Commits)

| Build / PR | Mudança Implementada | Impacto para Testadores |
|---|---|---|
| **0.5.1** (PR #450 / commit `802c9682`) | Barra de navegação única nativa em Minhas Vagas; correção do seletor de função em Publicar Vaga (`Picker` nativo). | Elimina sobreposição de barras e facilita a escolha de funções como Garçom, Cozinha e Bar. |
| **0.5.1** (PR #449 / commit `1cf02604`) | Exibição e edição do nome do responsável no cadastro do estabelecimento. | Permite conferir o nome de contato do responsável diretamente na tela de perfil da casa. |
| **0.5.2** (PR #447 / commit `747347b3`) | Alinhamento e acessibilidade de cartões de turno e candidaturas em telas com fonte grande. | Melhora a quebra de linha de valores (R$) e horários em aparelhos com fontes acessíveis. |
| **0.5.3** (PR #523 / commit `01b75435`) | Refinamento visual da tela de entrada (Hero, tipografia institucional Frila e foco de teclado). | Entrada mais fluida e legível em todos os modelos de iPhone, do SE ao Pro Max. |
| **0.5.4** (PR #544 / commit `bbbcc8fa`) | Padronização dos procedimentos de release e conferência estrita de conformidade (`conferir-release.sh`). | Garante integridade criptográfica, ausência de ganchos de depuração em produção e estabilidade. |
| **0.5.5** (PR #624 / PR #626) | Otimização de tráfego HTTP da sessão leve (< 10 KB) e conferência de truncamento de push em telas pequenas (iPhone SE). | Abertura ágil e baixo consumo de dados móveis no 4G; textos de avisos sem cortes na tela de bloqueio. |
| **0.5.5+** (PR #631 / PR #635 / PR #636) | Extensão de push por vínculo (NSE), inventário de padrões de estado de tela e cobertura de 34 telas em acessibilidade AX5. | Maior privacidade em notificações multi-conta, mensagens de erro/sem conexão claras e suporte a acessibilidade extrema. |

---

## 3. Como reportar feedback

- **Pelo próprio iPhone (TestFlight):** Faça uma captura de tela (pressione o botão lateral + aumentar volume ao mesmo tempo) e toque na opção **Compartilhar Feedback Beta**. Desenhe ou anote na imagem se desejar destacar o problema.
- **Pelo aplicativo TestFlight:** Abra o app TestFlight, toque em **Frila** e selecione **Enviar Feedback sobre o Beta**.
- **Por e-mail:** Caso prefira detalhar com fotos ou vídeos adicionais, envie para o canal oficial de atendimento em `suporte@frilabr.com`.
- **O que informar no relato:**
  - O que você estava tentando fazer (ex.: "Fazer check-in no turno de garçom").
  - O que aconteceu na tela (ex.: "Apareceu aviso de fora do raio, mas eu estava no local").
  - Modelo do seu aparelho (ex.: iPhone 13, iPhone SE 3ª geração) e versão do iOS (disponível em *Ajustes > Geral > Sobre*).

---

## 4. O que ainda NÃO funciona neste build (Transparência Técnica)

1. **Despacho automático de notificações pelo servidor em `frila-dev`:**  
   O serviço de agendamento e envio automático de notificações push no ambiente de testes depende de rotinas internas em implantação no backend (`frila-dev`). O recebimento em segundo plano pode exigir disparos de teste controlados.
2. **Criação de turnos de teste em tempo real:**  
   Para testar check-in dentro do raio de 200 metros, o turno precisa ter endereço físico acessível pelo testador no Distrito Federal e horário compatível com o relógio do teste.
3. **Disponibilização para grupos externos abertos:**  
   Este build destina-se ao grupo de homologação interna e grupo fechado de testadores. A abertura para grupos públicos sem código de convite ocorre após a validação deste ciclo.

---

## 5. Rastreabilidade: Frase da Nota → Onde é Verdade no Código

| Frase da Nota ao Testador | Onde é verdade no app (`arquivo:linha`) | Mecanismo de Garantia no Código |
|---|---|---|
| "Permita o envio de notificações no momento em que o aplicativo solicitar..." | `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:80` | `TelaExplicacaoDoPush` com botões "Ativar notificações" e "Agora não". |
| "Ao tocar na notificação... o app abre diretamente os detalhes da vaga ou do turno..." | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:24`, `iOS/Sources/App/AppDelegate.swift:69` | Roteador direciona para `.vaga(vagaID)` ou `.meuTurno(turnoID)` conforme payload do push. |
| "Avisos destinados a outros vínculos exibem apenas 'Nova notificação disponível'..." | `iOS/Sources/Apresentacao/Fluxos/Push/FiltroDePushPorVinculo.swift:18`, `NotificationService.swift:34` | Comparação estrita entre `vinculo_id` do payload e o vínculo ativo no App Group (`group.com.frila.org.app`). |
| "Ao chegar ao endereço... toque em 'Fazer check-in'. O app confere pelo GPS (até 200m)." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:62`, `iOS/Sources/Dominio/Localizacao.swift:46` | Cálculo de distância medido localmente; raio máximo de 200 m verificado antes de enviar `fazer_checkin`. |
| "Toque em 'Fazer check-in manual'... aguardando a confirmação do contratante." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:84`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:35` | Dispara `checkin_tipo: "manual"`; exibe estado de espera enquanto contratante não confirma. |
| "Ao concluir a jornada... toque em 'Fazer check-out'..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:65` | Botão "Fazer check-out" ativado após presença confirmada; registra horário e distância. |
| "Responda à pergunta: 'Você trabalharia nesse local de novo?'... 'Sim' ou 'Não'..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:47`, `iOS/Sources/Apresentacao/Componentes.swift:343` | Pergunta textual sem notas numéricas; botões acessíveis "Sim" e "Não". |
| "Se estiver sem conexão... a resposta fica guardada... e é enviada automaticamente..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:45`, `ArmazenamentoSwiftData.swift:82` | Enfileiramento offline no SwiftData (`fila.salvar`) com tentativa automática ao reconectar. |
| "Nova barra unificada e seletor limpo de funções em Minhas Vagas..." | `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:310`, `FluxoDoContratante.swift:115` | Barra única nativa UIKit/SwiftUI e `Picker` de função sem colisão visual. |
| "Navegue com tamanhos de texto maiores (Dynamic Type / AX5)..." | `iOS/Docs/Evidencias/relatorio-ax5-telas.md`, `iOS/Docs/Acessibilidade.md:550` | 34 telas auditadas em AX5 com alvos de toque >= 44 pt e textos com rolagem sem cortes impeditivos. |
| "Canal oficial de atendimento: `suporte@frilabr.com`" | `iOS/Sources/Apresentacao/EnderecosOficiais.swift:22` | E-mail institucional único do Frila registrado no código de produção. |
