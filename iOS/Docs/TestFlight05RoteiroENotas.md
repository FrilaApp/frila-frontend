# TestFlight 0.5 — Notas da Versão e Roteiro de Homologação (#66)

Documento de consolidação das Notas da Versão ("What to Test" em pt-BR) para testadores externos do TestFlight 0.5 e do roteiro técnico de homologação externa dos três fluxos centrais contra o ambiente `frila-dev`, atendendo aos critérios do cartão [#66](https://trello.com/c/Kd0RVh9q) para a submissão de 29/10/2026.

---

## 1. Notas da Versão para Testadores Externos ("What to Test")

Texto destinado ao campo **O que testar** (*What to Test*) no App Store Connect / TestFlight para o build 0.5. O limite da Apple é de 4.000 caracteres; o texto abaixo cumpre este teto de forma concisa e acessível para profissionais e contratantes.

```text
Bem-vindo ao teste beta do Frila (Versão 0.5)!

Nesta versão, preparamos novidades fundamentais para conectar profissionais e estabelecimentos com agilidade, pontualidade e transparência.

O que há de novo para você testar:

1. Notificações Instantâneas de Vagas
• Receba alertas imediatos quando surgirem vagas compatíveis com a sua função e disponibilidade.
• Ao tocar na notificação, você é direcionado diretamente para a tela de detalhes da vaga (com função, horário, remuneração e endereço) para se candidatar em poucos toques.
• Lembretes de turno avisam com antecedência antes do início do compromisso confirmado.

2. Confirmação de Presença no Local (Check-in e Check-out)
• Chegou ao evento? Confirme sua presença tocando em "Fazer Check-in".
• O app valida automaticamente se você está no local do evento (tolerância de até 200 metros).
• Sem sinal de GPS ou permissão indisponível? Você pode usar a opção "Check-in Manual", que encaminha o pedido para validação do contratante.
• Ao encerrar a jornada, utilize o "Fazer Check-out" para registrar a saída.

3. Avaliação Rápida do Turno
• Ao término do compromisso, envie sua impressão em uma pergunta direta e binária: "Trabalharia novamente?".
• A avaliação é rápida, mútua e funciona com segurança mesmo se você estiver sem conexão no momento.

Como nos enviar feedback:
• Encontrou algum problema, erro visual ou comportamento inesperado? Tire um print da tela no seu iPhone (botão lateral + volume para cima) e toque em "Compartilhar Feedback Beta".
• Você também pode relatar observações e sugestões pela página do Frila no aplicativo TestFlight.

Obrigado por construir o Frila conosco!
```

---

## 2. Roteiro Técnico de Homologação Externa (`frila-dev`)

Roteiro de homologação ponta a ponta dos três fluxos principais do marco 0.5 contra o ambiente `frila-dev`.

### Pré-requisitos do Ambiente
- **Build:** App Frila versão 0.5 (compilação configurada com `aps-environment: production` pelo perfil de distribuição do TestFlight).
- **Backend:** Conexão ativa com o ambiente de desenvolvimento/homologação `frila-dev`.
- **Contas de Teste:**
  1. Conta A: Perfil **Profissional** com funções e horários configurados.
  2. Conta B: Perfil **Contratante** (estabelecimento) com permissão para publicar vagas e gerenciar turnos.

---

### Fluxo 1: Notificação Push de Vaga e Destino do Toque

Valida a entrega da notificação via FCM/APNs e a navegação contextual tratada pelo `RoteadorDePush`.

| Passo | Ação | Resultado Esperado | Artefato / Referência |
|---|---|---|---|
| 1.1 | Na Conta A (Profissional), faça login e conceda a permissão de notificações no onboarding/perfil. | `AparelhoDePush` envia `registrar_dispositivo` para `frila-dev` e ativa o recebimento. O token FCM fica vinculado à Conta A. | `iOS/Docs/Push.md:8-18` |
| 1.2 | Na Conta B (Contratante), publique uma nova vaga compatível com a função e cidade da Conta A. | O backend despacha notificação com payload contendo `tipo: "vaga"` e `vaga_id`. | `Push.md:125-132` |
| 1.3 | Observe a recepção da notificação na Conta A com o app em segundo plano ou bloqueado. | A notificação aparece na Central de Notificações com som e banner nativo. | `Push.md:47-49` |
| 1.4 | Toque na notificação de vaga recebida. | O app abre diretamente na tela de **Detalhes da Vaga** correspondente ao `vaga_id`, exibindo remuneração, horário e botão de candidatura. | `RoteadorDePush.swift` |
| 1.5 | *Cenário de Exceção:* Toque em notificação de vaga já preenchida ou cancelada. | O app exibe a tela de **Vaga Indisponível** com explicação contextual e botão para retornar à lista de vagas. | `Push.md:150-153` |
| 1.6 | *Cenário de Troca de Conta:* Desconecte a Conta A e entre com outra conta no mesmo aparelho. | O vínculo anterior é encerrado imediatamente. Aplica-se a carência de 60 segundos (`carenciaNaTrocaDeConta`) para impedir que pushes residuais da conta anterior abram telas da nova conta. | `Push.md:178-180` |

---

### Fluxo 2: Check-in e Check-out por Geolocalização (`distanciaMetros`)

Valida a confirmação de presença no local do evento usando CoreLocation e os estados de `PresencaDoTurnoViewModel`.

| Passo | Ação | Resultado Esperado | Artefato / Referência |
|---|---|---|---|
| 2.1 | Com um turno confirmado e no horário previsto de início, acesse a tela do turno na Conta A. | O card de presença exibe o botão **Fazer Check-in** (`fazer-checkin`). | `SecaoDePresenca.swift:61-63` |
| 2.2 | **Check-in dentro do raio ($\le 200$ m):** Estando nas coordenadas do estabelecimento ou simulando localização a menos de 200 metros, toque em "Fazer Check-in". | O app solicita precisão de GPS, calcula a distância, envia `distanciaMetros` na chamada da API e atualiza a UI para `verificado` (ícone `checkmark.seal.fill`) exibindo hora e metros da validação. | `SecaoDePresenca.swift:155-157`, `PresencaDoTurnoViewModel.swift:270-280` |
| 2.3 | **Check-in fora do raio ($> 200$ m) ou sem GPS:** Repita o teste a mais de 200 metros do local do evento. | A UI entra na etapa `.semGPS` informando a distância ou motivo (`longe(distanciaMetros)`). É oferecido o botão alternativo **Check-in Manual** (`registro-manual`). | `SecaoDePresenca.swift:78-87`, `SecaoDePresenca.swift:182` |
| 2.4 | Toque em **Check-in Manual**. | O registro é enviado sem métrica de GPS (`distanciaMetros = nil`). A UI transita para `aguardandoConfirmacao` (ícone `hourglass`), indicando que o check-in depende de confirmação da casa contratante. | `SecaoDePresenca.swift:158-160` |
| 2.5 | Na Conta B (Contratante), abra o painel do turno. | A casa visualiza a solicitação de check-in manual pendente e pode confirmar a presença do profissional no turno. | `Push.md:142` (`checkin_manual_pendente`) |
| 2.6 | Ao término do horário do turno, na Conta A, toque em **Fazer Check-out** (`fazer-checkout`). | A localização é lida novamente; o encerramento é registrado com a distância calculada (`feito.distanciaMetros`) ou registrado como saída sem localização. | `SecaoDePresenca.swift:169-173` |

---

### Fluxo 3: Avaliação Binária e Idempotência

Valida a avaliação mútua rápida pós-turno implementada por `AvaliacaoTurnoViewModel` e `UserDefaultsArmazenamentoAvaliacoes`.

| Passo | Ação | Resultado Esperado | Artefato / Referência |
|---|---|---|---|
| 3.1 | Após a conclusão do turno, abra a tela do turno na Conta A ou toque no push `avaliacao_disponivel`. | O card de avaliação é exibido com a pergunta "Trabalharia novamente?" e duas opções em ordem: **Sim** e **Não**. | `AvaliacaoTurnoViewModel.swift:25-70`, `AvaliacaoTurno-22.md:43` |
| 3.2 | Selecione **Sim** ou **Não** e confirme o envio. | A resposta é persistida localmente no cache (`frila_avaliacao_<contaID>_<turnoID>`) e enviada ao backend via API. Os botões são desabilitados para impedir alteração. | `UserDefaultsArmazenamentoAvaliacoes:45-50` |
| 3.3 | Feche completamente o app Frila e abra novamente na tela do mesmo turno. | A tela reabre mantendo a opção selecionada gravada, exibindo o status de avaliação já registrada. Nenhuma nova requisição de avaliação é disparada (comportamento idempotente). | `AvaliacaoTurno-22.md:12-19` |
| 3.4 | *Cenário de Conflito de Servidor:* Simule cenário em que a avaliação já havia sido registrada no backend (resposta HTTP `409 avaliacao_ja_registrada`). | O app trata o código 409 de forma neutra, bloqueia nova submissão e exibe "Esta avaliação já foi registrada", preservando a integridade dos dados sem exibir falha genérica. | `AvaliacaoTurno-22.md:12-15` |
| 3.5 | *Cenário Offline:* Desative a conexão de rede do aparelho e envie a avaliação. | A avaliação é guardada na fila local (`AcaoPendente.avaliacao`) com o ID da conta. Ao reabrir o app sem rede, a resposta é carregada da fila pendente e sincronizada automaticamente assim que a conexão retornar. | `AvaliacaoTurno-22.md:21-26`, `PresencaDoTurnoViewModel.swift:287-310` |

---

## 3. Orientações de Recuperação para Permissões Recusadas

Caso o testador recuse permissões do sistema durante a primeira execução, o app implementa caminhos claros de recuperação:

### 3.1. Permissão de Notificações Recusada
- **Impacto no teste:** O testador não receberá avisos push de novas vagas disponíveis nem alertas de proximidade do turno.
- **Identificação no App:**
  - Na lista de Vagas e em Minhas Vagas, o app exibe o banner fixo `AvisoDePermissaoDePush`.
  - O aparelho não é registrado no servidor (em conformidade com a RN15: quem não recebe push não é alcançável para despacho).
- **Passo a passo para recuperação:**
  1. No banner `AvisoDePermissaoDePush`, toque no botão de ação "Ativar Notificações".
  2. Caso a permissão tenha sido negada no sistema, o app abre diretamente a tela de ajustes do Frila no iOS (`UIApplication.openNotificationSettingsURLString`).
  3. No menu do iOS, ative a opção **Permitir Notificações** (ativando Alertas e Sons).
  4. Retorne ao app Frila: ao voltar ao primeiro plano, o app detecta a autorização, executa `CanalDePushDoAparelho.ativar()` e registra o token no servidor através de `AparelhoDePush.ligar()`.

### 3.2. Permissão de Localização Recusada ou Aproximada
- **Impacto no teste:** O check-in automatizado com cálculo de raio ($\le 200$ m) não conseguirá obter as coordenadas com a precisão requerida.
- **Identificação no App:**
  - Na seção de presença, ao tentar o check-in, o card transita para o estado `.semGPS` com motivo `permissaoNegada` ou `localizacaoAproximada`.
  - É exibido o link/botão "Abrir Ajustes" (`abrir-ajustes`).
- **Passo a passo para recuperação:**
  1. No aviso do card de presença, toque em **Abrir Ajustes** (redireciona para `UIApplication.openSettingsURLString`).
  2. Em **Ajustes > Frila > Localização**, selecione **Durante o Uso do App**.
  3. Certifique-se de que a chave **Localização Precisa** está ativada (essencial para o cálculo de distância em metros).
  4. Retorne ao app Frila e toque em **Tentar GPS de novo** (`tentar-gps`).
- **Alternativa sem permissão (Contorno do Testador):**
  - Se o testador preferir não ativar a localização, basta tocar em **Check-in Manual** (`registro-manual`). O check-in será submetido e ficará aguardando a confirmação manual do contratante, sem interromper o teste do turno.

---

## 4. Notas Técnicas e Limitações do Marco 0.5

1. **Assinatura e Entitlements no TestFlight:**
   - No TestFlight, o entitlement `aps-environment` é obrigatoriamente assinado como `production` pelo perfil de distribuição da Apple. O script de verificação `iOS/Scripts/conferir-release.sh` deve ser utilizado para validar o `.app` exportado antes do upload.
2. **Ambiente de Teste:**
   - Todos os testes externos de homologação devem apontar para a infraestrutura do `frila-dev`.
3. **Submissão e Beta App Review:**
   - A submissão física do arquivo `.ipa` e o envio para aprovação do Beta App Review no App Store Connect dependem do marco de 29/10/2026 e do acesso do mantenedor à conta de desenvolvedor da Apple.
