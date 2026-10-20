# Notas do TestFlight 0.5

Rascunho das notas da versão ("O que testar") para o build 0.5 do Frila no TestFlight, em cumprimento ao item 6 do `iOS/Docs/ProntidaoBuild05.md` e aos critérios do cartão [Kd0RVh9q](https://trello.com/c/Kd0RVh9q).

---

## 1. O que testar

1. Notificações de vagas: permissão de notificações no aplicativo e abertura da vaga ao tocar no aviso (o envio remoto pelo servidor ainda não está ativo no ambiente de teste [A DEFINIR: Cauê]).
2. Chegada ao turno: ao estar no endereço no horário combinado, toque em "Fazer check-in" para registrar a presença.
3. Encerramento do trabalho: ao terminar o turno, toque em "Fazer check-out" para registrar a saída.
4. Check-in sem GPS: se estiver sem sinal ou sem permissão de localização, toque em "Fazer check-in manual" para aguardar a confirmação do contratante.
5. Avaliação do turno: após o término do turno cumprido, toque em "Avaliar turno" e responda "Você trabalharia nesse local de novo?".
6. Envio da resposta: selecione "Sim" ou "Não" e toque em "Enviar avaliação". Se estiver sem conexão, a resposta fica salva no aparelho até a internet voltar.

---

## 2. Como reportar

- **Onde enviar:**
  - Pelo TestFlight: faça uma captura de tela no iPhone (botão lateral + volume para cima) e toque em "Compartilhar Feedback Beta".
  - Por e-mail: envie para o canal oficial da Equipe Frila em `suporte@frilabr.com` (sem uso de e-mail pessoal).
- **O que anexar e informar:**
  - Captura de tela (print) ou gravação mostrando o comportamento encontrado ou a mensagem na tela.
  - Modelo do iPhone e versão do iOS (disponíveis em Ajustes > Geral > Sobre).
  - Descrição objetiva da ação realizada, do resultado na tela e do comportamento esperado.
  - Horário aproximado do teste e identificação do perfil utilizado (profissional ou contratante).

---

## 3. O que ainda NÃO funciona neste build

1. **Envio remoto de notificações push pelo servidor:**
   O serviço de despacho e envio remoto de notificações push (FCM) não está publicado no ambiente de testes `frila-dev` (`iOS/Docs/ProntidaoBuild05.md:44`, cartão 36fU0CEO). O recebimento de alertas de vagas em segundo plano ou com o aplicativo fechado depende da publicação desse serviço pelo backend `[A DEFINIR: Cauê]`.
2. **Configuração de chaves e permissões APNs/FCM de produção no build Beta:**
   A configuração definitiva de credenciais e certificados de envio remoto para o ambiente de distribuição externa depende de validação nos painéis da Apple e do Firebase `[A DEFINIR: Cauê]`.
3. **Disponibilização do build para grupos externos:**
   A abertura do grupo externo de testes no TestFlight (como o Piloto DF) e a submissão para Beta App Review `[A DEFINIR: Cauê]`.
4. **Criação prévia de turnos de teste no ambiente de desenvolvimento:**
   A criação de turnos no `frila-dev` com horários válidos, contratante ativo e endereços no Distrito Federal para permitir o teste de check-in dentro do limite de 200 m e de avaliação pós-término `[A DEFINIR: Cauê]`.
5. **Envio de código de acesso por e-mail no ambiente de teste:**
   A configuração de envio de código por e-mail (SMTP/OTP) para acesso de testadores externos no `frila-dev` (`iOS/README.md:94`, `iOS/Docs/ProntidaoBuild05.md:50`) `[A DEFINIR: Cauê]`.

---

## 4. Frase da nota → Onde isso é verdade no app

| Frase da nota / Promessa | Onde isso é verdade no app (`arquivo:linha`) | Observação de validação |
|---|---|---|
| "Notificações de vagas: permissão de notificações no aplicativo..." | `iOS/Sources/Apresentacao/Fluxos/Push/TextosDoPush.swift:11`, `iOS/Sources/Apresentacao/Fluxos/Push/TelasDaPermissaoDePush.swift:80` | Tela de explicação e botão `TextosDoPush.Explicacao.ativar` ("Ativar notificações"). |
| "...e abertura da vaga ao tocar no aviso..." | `iOS/Sources/Apresentacao/Fluxos/Push/RoteadorDePush.swift:24`, `iOS/Sources/App/AppDelegate.swift:69`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift:104` | Aviso com `tipo == .vaga` direciona para `.vaga(vagaID)` e abre a tela com título "Vaga". |
| "...o envio remoto pelo servidor ainda não está ativo no ambiente de teste [A DEFINIR: Cauê]" | Sem fonte no app (`iOS/Docs/ProntidaoBuild05.md:44`, cartão 36fU0CEO) | Não implementado no backend `frila-dev` `[A DEFINIR: Cauê]`. |
| "Chegada ao turno: ao estar no endereço no horário combinado, toque em 'Fazer check-in' para registrar a presença." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:62`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:11`, `iOS/Sources/Dominio/Localizacao.swift:46` | Botão com rótulo "Fazer check-in". Limite de distância de 200 m medido no toque. |
| "Encerramento do trabalho: ao terminar o turno, toque em 'Fazer check-out' para registrar a saída." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:65`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:12` | Botão com rótulo "Fazer check-out", registrando horário e distância. |
| "Check-in sem GPS: se estiver sem sinal ou sem permissão de localização, toque em 'Fazer check-in manual' para aguardar a confirmação do contratante." | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:84`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:35-36`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:159` | Botão "Fazer check-in manual" no estado `.semGPS`; exibe estado de aguardo com ícone `hourglass`. |
| "Avaliação do turno: após o término do turno cumprido, toque em 'Avaliar turno' e responda 'Você trabalharia nesse local de novo?'." | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:47`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:168-169`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:183` | Título da tela "Avaliar turno", pergunta "Você trabalharia nesse local de novo?" e bloqueio antes do término/sem presença. |
| "Envio da resposta: selecione 'Sim' ou 'Não' e toque em 'Enviar avaliação'." | `iOS/Sources/Apresentacao/Componentes.swift:343-344`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:119`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:179` | Componente `RespostaSimNao` com botões "Sim" e "Não", e botão "Enviar avaliação". |
| "Se estiver sem conexão, a resposta fica salva no aparelho até a internet voltar." | `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:45`, `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:148`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:181` | Resposta salva localmente via `salvar` e enfileirada no estado `enfileiradoOffline` com aviso textual. |
| Canal de atendimento e reporte: `suporte@frilabr.com` | `iOS/Sources/Apresentacao/EnderecosOficiais.swift:22`, `iOS/Docs/AjudaESuporte.md:27` | Canal oficial único do produto registrado em `EnderecosOficiais.padrao.emailSuporte`. |
