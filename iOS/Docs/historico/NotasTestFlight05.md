> **Histórico: não vale como regra.** O que vale está em [`produto/AGORA.md`](https://github.com/FrilaApp/frila-documentacao/blob/main/produto/AGORA.md).

# Notas do TestFlight 0.5 (Proposta Técnica para o Próximo Build 0.5.5+)

Notas da versão ("O que testar" / *What to Test*) elaboradas como proposta técnica para o próximo build do Frila no TestFlight, em cumprimento ao Cartão [Kd0RVh9q](https://trello.com/c/Kd0RVh9q) e rastreadas contra o histórico de commits da branch `main` e PRs correspondentes.

> [!NOTE]
> Enquanto não houver upload de binário comprovado ao TestFlight, este documento constitui proposta técnica de notas vinculada aos commits da branch `main`. A numeração de build definitiva e a data de liberação serão fixadas na execução manual do workflow pela pessoa responsável.

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

## 2. Mudanças nos Commits da Base (Rastreamento por PR)

| Identificador / PR | Mudança Implementada | Impacto para Testadores |
|---|---|---|
| **PR #450** (`802c9682`) | Barra de navegação única nativa em Minhas Vagas; correção do seletor de função em Publicar Vaga (`Picker` nativo). | Elimina sobreposição de barras e facilita a escolha de funções como Garçom, Cozinha e Bar. |
| **PR #449** (`1cf02604`) | Exibição e edição do nome do responsável no cadastro do estabelecimento. | Permite conferir o nome de contato do responsável diretamente na tela de perfil da casa. |
| **PR #447** (`747347b3`) | Alinhamento e acessibilidade de cartões de turno e candidaturas em telas com fonte grande. | Melhora a quebra de linha de valores (R$) e horários em aparelhos com fontes acessíveis. |
| **PR #523** (`01b75435`) | Refinamento visual da tela de entrada (Hero, tipografia institucional Frila e foco de teclado). | Entrada mais fluida e legível em todos os modelos de iPhone, do SE ao Pro Max. |
| **PR #544** (`bbbcc8fa`) | Documentação de procedimentos operacionais de reversão e rollback (`iOS/Docs/ReversaoDeRelease.md`). | Garante previsibilidade e salvaguarda operacional em caso de incidente em release. |
| **PR #624** (`4d5218ae`) | Otimização de tráfego HTTP da sessão leve medida em 8.1 KB (teto: 1 MB) com cache frio. | Abertura ágil e baixo consumo de dados móveis no 4G durante consulta e candidatura. |
| **PR #626** (`06eda86f`) | Validação de truncamento de push em telas pequenas (iPhone SE 3ª geração). | 19/19 notificações testadas sem corte de texto na tela de bloqueio. |
| **PR #631** (`abb81c71`) | Auditoria visual integral de acessibilidade em AX5 para 43/43 telas da v1.0. | Telas adaptadas ao maior tamanho Dynamic Type com OCR e sem colisões de hash. |
| **PR #635** (Rascunho) | Inventário sistemático dos padrões de estado de tela para espelhamento no Figma. | Documentação técnica dos 5 estados de interface para o time de design. |
| **PR #636** (Rascunho) | Validação da lógica pura de comparação de vínculo no push e roteiro de teste físico. | Roteiro estruturado para conferência em aparelho real com duas contas. |

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
| "Avisos destinados a outros vínculos exibem apenas 'Nova notificação disponível'..." | `iOS/Sources/Dominio/VinculoDoPush.swift:68`, `iOS/Sources/NotificationService/NotificationService.swift:34` | `FiltroDoPushPorVinculo`: comparação entre `vinculo_id` do payload e o vínculo ativo no App Group (`group.com.frila.org.app`). |
| "Ao chegar ao endereço... toque em 'Fazer check-in'. O app confere pelo GPS (até 200m)." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:62`, `iOS/Sources/Dominio/Localizacao.swift:46` | Cálculo de distância medido localmente; raio máximo de 200 m verificado antes de enviar `fazer_checkin`. |
| "Toque em 'Fazer check-in manual'... aguardando a confirmação do contratante." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:84`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:35` | Dispara `checkin_tipo: "manual"`; exibe estado de espera enquanto contratante não confirma. |
| "Ao concluir a jornada... toque em 'Fazer check-out'..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:65`, `PresencaDoTurnoViewModel.swift:109–113` | `podeFazerCheckout`: habilitado assim que o check-in é registrado (`checkin != .naoFeito && checkout == .naoFeito`), inclusive em fila offline. |
| "Responda à pergunta: 'Você trabalharia nesse local de novo?'... 'Sim' ou 'Não'..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:47`, `iOS/Sources/Apresentacao/Componentes.swift:343` | Pergunta textual sem notas numéricas; botões acessíveis "Sim" e "Não". |
| "Se estiver sem conexão... a resposta fica guardada... e é enviada automaticamente..." | `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:45`, `iOS/Sources/Dados/CacheSwiftData.swift:165`, `iOS/Sources/App/FrilaApp.swift:479` | Enfileiramento offline via `CacheSwiftData.salvar(avaliacao:)` com reenvio automático gerenciado pelo `FrilaApp`. |
| "Nova barra unificada e seletor limpo de funções em Minhas Vagas..." | `iOS/Sources/Apresentacao/Fluxos/Contratante/MinhasVagas.swift:310`, `FluxoDoContratante.swift:115` | Barra única nativa UIKit/SwiftUI e `Picker` de função sem colisão visual. |
| "Navegue com tamanhos de texto maiores (Dynamic Type / AX5)..." | `iOS/Docs/Evidencias/relatorio-ax5-telas.md`, `iOS/Docs/Acessibilidade.md:28` | 43 telas auditadas em AX5 (PR #631 na `main`) com alvos de toque >= 44 pt e textos com rolagem sem cortes impeditivos. |
| "Canal oficial de atendimento: `suporte@frilabr.com`" | `iOS/Sources/Apresentacao/EnderecosOficiais.swift:22` | E-mail institucional único do Frila registrado no código de produção. |
