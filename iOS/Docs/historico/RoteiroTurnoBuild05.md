# Roteiro e Dados de Turno — TestFlight Build 0.5

Roteiro de homologação e especificação de dados para validação operacional de presença (check-in geolocalizado, check-out e alternativa manual confirmada) e avaliação mútua no build 0.5 (`Frila-Beta`) contra o ambiente `frila-dev`.

Este documento atende ao item 5 do diagnóstico de prontidão (`iOS/Docs/ProntidaoBuild05.md:6` e `:64`) e define as etapas para a execução presencial com aparelho físico descrita no item 9 (`iOS/Docs/ProntidaoBuild05.md:68`).

---

## 1. Pré-condições por Papel

As pré-condições estabelecem o estado necessário para cada conta antes de iniciar os testes. Em conformidade com a LGPD e as diretrizes do projeto (`RN15`, `frila-backend/CLAUDE.md:260`), nenhum identificador de acesso restrito, dado pessoal real ou UUID de produção é exposto neste documento.

### 1.1 Papel: Profissional

- **Conta e Perfil**:
  - Conta cadastrada com perfil profissional (`public.criar_conta('profissional', ...)`, `RN25`, `frila-backend/CLAUDE.md:169`, `frila-backend/supabase/migrations/20260924150000_criar_conta.sql:12`).
  - Perfil profissional configurado com ao menos uma função correspondente à vaga (ex.: garçom) e ponto base ativo (`public.criar_perfil_profissional`, `frila-backend/supabase/migrations/20260924180000_perfil_profissional.sql:10`, `TextosDoProfissional.Perfil.titulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:130`).
  - Estado da conta: `ativa` (não suspensa, `RN13`, `frila-backend/supabase/migrations/20260926060100_exigir_conta_ativa_escrita.sql:109`).
  - Identificador da conta profissional: `[A DEFINIR: Cauê]`.
  - Credenciais de autenticação para OTP no `frila-dev`: `[A DEFINIR: Cauê]`.
- **Aparelho e Aplicativo**:
  - iPhone físico com build 0.5 (`Frila-Beta` / `Release-Beta`) instalado via TestFlight (`iOS/README.md:16`, `iOS/Sources/App/ConfiguracaoAmbiente.swift:97` e `:112`).
  - Conexão de dados móveis ou Wi-Fi ativa.
  - Serviços de Localização do iOS ativados nas configurações do sistema.
  - Permissão de localização para o Frila: configurada como "Durante o Uso do App" (`authorizedWhenInUse`, `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:68`) com "Localização Precisa" ativada (`fullAccuracy` / `aoUsarPrecisa`, `iOS/Sources/Dominio/Localizacao.swift:9`, `iOS/Sources/App/Info.plist:9`).
- **Estado do Turno no App**:
  - Turno confirmado vinculado à conta (`public.turno`, `iOS/Sources/Dominio/Modelos.swift:582`), visível na lista `TelaMeusTurnos` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:46`).

### 1.2 Papel: Contratante

- **Conta e Estabelecimento**:
  - Conta cadastrada com perfil contratante (`public.criar_conta('contratante', ...)`, `RN25`, `frila-backend/CLAUDE.md:169`, `frila-backend/supabase/migrations/20260924150000_criar_conta.sql:12`).
  - Estabelecimento cadastrado no Distrito Federal (`public.cadastrar_estabelecimento`, `frila-backend/supabase/migrations/20260924200000_cadastrar_estabelecimento.sql:12`).
  - Conta vinculada como membro ativo do estabelecimento (`privado.eh_membro`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:320`).
  - Estado da conta: `ativa` (não suspensa, `RN13`).
  - Identificador da conta contratante / estabelecimento: `[A DEFINIR: Cauê]`.
  - Credenciais de autenticação para OTP no `frila-dev`: `[A DEFINIR: Cauê]`.
- **Acesso Operacional**:
  - Sessão autenticada ativa no aplicativo iOS ou painel web conectado ao ambiente `frila-dev`.
  - Acesso à tela de acompanhamento `TelaTurnoDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:189`) e à seção `PendenciasDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:444`).
- **Estado da Vaga no Servidor**:
  - Vaga publicada (`public.publicar_vaga`, `RN02`, `frila-backend/CLAUDE.md:170`, `frila-backend/supabase/migrations/20260924220000_publicar_vaga.sql:15`) com posição em estado `confirmada` (`EstadoPosicao.confirmada`, `iOS/Sources/Dominio/Modelos.swift:443`, `RN19`, `frila-backend/CLAUDE.md:165`) alocada para o profissional de teste (`RN21`, `frila-backend/CLAUDE.md:166`).

---

## 2. Dados do Turno de Teste

### 2.1 Campos e Formato do Turno
Os dados do turno devem obedecer ao contrato de API e às regras de integridade do backend:

| Campo | Tipo / Formato | Exemplo Sanitizado | Regra / Fonte |
| --- | --- | --- | --- |
| `funcao` | Nome textual de função cadastrada | "garçom" | `public.funcao` (`frila-backend/supabase/seed.sql:8`) |
| `valor_centavos` (`valorAcordado`) | Inteiro em centavos (`bigint`) | `18000` (R$ 180,00) | `RN18` (`frila-backend/CLAUDE.md:167`), `RN01` (`frila-backend/CLAUDE.md:250`) |
| `inicio_em` | Data/hora em UTC (`timestamptz`) | `[A DEFINIR: Cauê]` | `RN18` (`frila-backend/CLAUDE.md:167`), `Periodo` (`iOS/Sources/Dominio/ObjetosDeValor.swift:34`) |
| `fim_em` | Data/hora em UTC (`timestamptz`) | `[A DEFINIR: Cauê]` | `RN18` (`frila-backend/CLAUDE.md:167`), `Periodo` (`iOS/Sources/Dominio/ObjetosDeValor.swift:34`) |
| `local` (endereço genérico) | Texto curto sem identificador pessoal | "SCLN 406" | `frila-backend/supabase/tests/160_checkin_e_checkout.sql:68` |
| `coordenadas` (`ponto`) | Latitude e longitude com 4 decimais | `{"latitude": -15.7910, "longitude": -47.8860}` | `frila-backend/supabase/tests/160_checkin_e_checkout.sql:79` |
| `chave` | UUID v4 único gerado pelo app | `[UUID v4 gerado no teste]` | Idempotência de publicação (`frila-backend/CLAUDE.md:198`) |

### 2.2 Janela de Horário
- **Janela de Registro de Presença**:
  - O backend permite o registro de presença a partir de 60 minutos antes do `inicio_em` até o `fim_em` previsto (`privado.exigir_janela`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:108`, `TextosDoProfissional.Presenca.foraDaJanela`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:65`).
  - Tolerância de adiantamento: o relógio do aparelho pode estar adiantado em no máximo 2 minutos em relação ao relógio do servidor (`privado.agora() + interval '2 minutes'`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:104`, `TextosDoProfissional.Presenca.relogioAdiantado`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:66`).
- **Janela de Teste Recomendada**:
  - Para possibilitar a validação completa de check-in, check-out e avaliação na mesma sessão física sem tempos mortos, recomenda-se combinar previamente com o Cauê um turno com duração compacta (ex.: 20 a 30 minutos entre início e fim): `[A DEFINIR: Cauê]`.

### 2.3 Identificação Sanitizada
- Em relatórios, logs e capturas de tela compartilhadas, o turno deve ser identificado apenas pelos **primeiros 8 caracteres de seu UUID** (ex.: `af000000-...`, padrão estabelecido em `frila-backend/supabase/tests/160_checkin_e_checkout.sql:11`).
- Jamais incluir nomes pessoais, números de telefone, e-mails ou chaves de autenticação nas evidências (`RN15`, `frila-backend/CLAUDE.md:260`).

---

## 3. Passo a Passo de Execução

### Cenário A: Check-in Geolocalizado e Check-out

#### Passo A1: Abertura da Tela do Turno
1. No iPhone do profissional, abrir o app Frila.
2. Na aba de turnos, acessar `TelaMeusTurnos` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:46`).
3. Tocar no cartão do turno de teste (`CartaoMeuTurno`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:4`).
4. **Comportamento Observado**:
   - A `TelaMeuTurno` abre (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:7`).
   - O GPS permanece inativo; nenhuma coordenada é lida e nenhuma permissão é solicitada antecipadamente (`iOS/Sources/Dominio/Localizacao.swift:4`, `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:187`).
   - A seção `SecaoDePresenca` exibe o cabeçalho "PRESENÇA" (`TextosDoProfissional.Presenca.titulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:10`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:23`).
   - O botão primário "Fazer check-in" está visível (`TextosDoProfissional.Presenca.fazerCheckin`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:11`, identificador `fazer-checkin`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:63`, `PresencaDoTurnoViewModel.podeFazerCheckin`, `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:100`).

#### Passo A2: Concessão de Permissão (se primeira execução)
1. Tocar em "Fazer check-in" (`fazer-checkin`).
2. O ViewModel entra em `PresencaDoTurnoViewModel.Etapa.lendo(.checkin)` (`iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:32` e `:159`).
3. Se a permissão estiver como `naoDeterminada` (`PermissaoDeLocalizacao.naoDeterminada`, `iOS/Sources/Dominio/Localizacao.swift:6`), surge o aviso explicativo "Sua localização, só neste toque" (`TextosDoProfissional.Presenca.explicacaoTitulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:14`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:69`).
4. Tocar no botão "Continuar" (`TextosDoProfissional.Presenca.continuar`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:19`, identificador `permitir-localizacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:71`).
5. O sistema operacional exibe o alerta nativo de autorização do CoreLocation (`requestWhenInUseAuthorization`, `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:34`).
6. O testador seleciona "Durante o Uso do App" e mantém "Precisa: Sim" (`aoUsarPrecisa`, `iOS/Sources/Dominio/Localizacao.swift:9`, `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:69`).

#### Passo A3: Leitura e Confirmação de Check-in Geolocalizado
1. O app exibe o indicador de progresso "Lendo sua localização…" (`TextosDoProfissional.Presenca.lendo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:22`) e em seguida "Enviando…" (`TextosDoProfissional.Presenca.enviando`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:23`).
2. O `LeitorDeLocalizacaoDoSistema` faz uma única leitura em até 10 segundos (`RegraDePresenca.tempoLimiteDaLeitura = .seconds(10)`, `iOS/Sources/Dominio/Localizacao.swift:49`) com precisão horizontal suficiente de até 100 metros (`RegraDePresenca.precisaoHorizontalMaximaMetros = 100.0`, `iOS/Sources/Dominio/Localizacao.swift:48`) e encerra o hardware do GPS imediatamente (`iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:81`).
3. O aparelho calcula a distância em metros até o ponto da vaga. Estando a até 200 metros (`RegraDePresenca.distanciaMaximaDoCheckinMetros = 200`, `iOS/Sources/Dominio/Localizacao.swift:46`), envia via RPC `fazer_checkin` apenas a distância inteira e o instante do toque (`iOS/Sources/Dados/SupabaseApiCliente.swift:296`, `PresencaDoTurnoViewModel.swift:244`). As coordenadas não saem do aparelho.
4. **Regra do Backend**:
   - `RN22` / `public.fazer_checkin` (`frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:172`): ao receber `distancia_m <= 200`, o servidor grava `checkin_tipo = 'geolocalizado'` e define `verificacao = 'verificado'`.
   - Dispara recálculo da taxa de comparecimento do profissional (`privado.recalcular_comparecimento`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:191`).
5. **Resultado Esperado na Tela**:
   - Linha de situação `checkin-situacao` exibe ícone `checkmark.seal.fill`, cor de sucesso e texto: "Check-in verificado às [hora], a [distância] m do endereço." (`TextosDoProfissional.Presenca.checkinVerificado`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:42`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:156`).
   - O botão "Fazer check-in" desaparece e o botão "Fazer check-out" torna-se disponível (`PresencaDoTurnoViewModel.podeFazerCheckout`, `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:104`, identificador `fazer-checkout`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:66`).

#### Passo A4: Registro de Check-out (Saída)
1. Ao encerrar o turno (dentro da janela válida do turno, antes do `fim_em`), tocar em "Fazer check-out" (`TextosDoProfissional.Presenca.fazerCheckout`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:12`, identificador `fazer-checkout`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:66`).
2. O app lê novamente a localização no toque e invoca a RPC `fazer_checkout` (`iOS/Sources/Dados/SupabaseApiCliente.swift:300`, `PresencaDoTurnoViewModel.swift:264`).
3. **Regra do Backend**:
   - `RN22` / `public.fazer_checkout` (`frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:207` e `:265`): no check-out a distância não tem teto limitador (permite encerramento mesmo que o profissional tenha se afastado). Exige `checkin_em is not null` (caso contrário, erro 409 `checkin_pendente`, `:255`) e horário dentro da janela (`privado.exigir_janela`, `:258`).
   - Grava `checkout_em`, `checkout_recebido_em` e `checkout_distancia_m` (`:266-268`).
4. **Resultado Esperado na Tela**:
   - Linha de situação `checkout-situacao` exibe ícone `checkmark.circle.fill` com texto: "Check-out registrado às [hora], a [distância] m do endereço." (`TextosDoProfissional.Presenca.checkoutRegistrado`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:57`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:172`).
   - Nenhum botão de registro pendente permanece na seção.

---

### Cenário B: Alternativa Manual e Confirmação pelo Contratante

#### Passo B1: Tentativa Fora do Local ou Sem Sinal GPS
1. O profissional tenta o check-in distante do ponto da vaga (> 200 metros, ex.: a 350 m), ou com precisão degradada (> 100 m), ou com permissão negada (`PresencaDoTurnoViewModel.MotivoSemGPS`, `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:16`).
2. O app detecta a condição e transiciona para `PresencaDoTurnoViewModel.Etapa.semGPS(.checkin, motivo)` (`iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:34`).
3. **Resultado Esperado na Tela do Profissional**:
   - Cartão de aviso `sem-gps` exibe o título "Localização não confirmada" (`TextosDoProfissional.Presenca.semGPSTitulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:25`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:80`).
   - Mensagem explicativa correspondente (ex.: "O GPS indica que você está a cerca de [X] m do endereço da vaga.", `TextosDoProfissional.Presenca.motivoLonge`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:30`).
   - Orientação: "Você pode fazer o check-in manual. Ele fica aguardando a confirmação do contratante." (`TextosDoProfissional.Presenca.manualExplicacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:35`).
   - Botão primário visível: "Fazer check-in manual" (`TextosDoProfissional.Presenca.checkinManual`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:36`, identificador `registro-manual`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:87`).
   - Botão secundário: "Tentar o GPS de novo" (`TextosDoProfissional.Presenca.tentarGPS`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:39`, identificador `tentar-gps`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:89`).

#### Passo B2: Envio do Check-in Manual
1. Tocar em "Fazer check-in manual" (`registro-manual`).
2. O app chama `PresencaDoTurnoViewModel.registrarSemGPS()` (`iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:188`), enviando a RPC `fazer_checkin` com `distancia_m = null` (`PresencaDoTurnoViewModel.swift:191`).
3. **Regra do Backend**:
   - `RN22` / `public.fazer_checkin` (`frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:175`): sem distância comprovada do GPS, o servidor define `checkin_tipo = 'manual'` e `verificacao = 'pendente'`.
4. **Resultado Esperado na Tela do Profissional**:
   - Linha de situação `checkin-situacao` exibe ícone de ampulheta `hourglass`, cor de alerta e texto: "Check-in manual feito às [hora]. Aguardando confirmação do contratante." (`TextosDoProfissional.Presenca.checkinAguardando`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:46`, `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:159`, `PresencaDoTurnoViewModel.aguardandoConfirmacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:107`).

#### Passo B3: Confirmação pelo Contratante
1. O contratante acessa o app ou web com sua conta e abre `TelaTurnoDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:189`) ou a seção `PendenciasDoContratante` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:444`).
2. O turno pendente aparece na seção "Presenças a confirmar" (`TextosDoAcompanhamento.presencasAConfirmar`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:33`, `:453`) com o detalhe: "Confirme se a pessoa chegou. Sem a sua confirmação, o turno fica como não verificado." (`TextosDoAcompanhamento.explicacaoDaConfirmacao`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:12`).
3. O contratante toca no botão "Confirmar presença" (`TextosDoAcompanhamento.confirmarPresenca`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:13`, identificador `confirmar-presenca-[turnoID]`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:341` e `:457`, `AcompanhamentoViewModel.podeConfirmar`, `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:185`).
4. Dispara a chamada `AcompanhamentoViewModel.confirmarPresenca` (`iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:287`), que invoca a RPC `confirmar_checkin_manual(turno_id)` (`iOS/Sources/Dados/SupabaseApiCliente.swift:311`).
5. **Regra do Backend**:
   - `RF20`, `RN22` / `public.confirmar_checkin_manual` (`frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:288`): valida autor como membro do estabelecimento (`privado.eh_membro`, `:320`), exige `checkin_em is not null` e `checkin_tipo = 'manual'`. Atualiza `checkin_confirmado_em = privado.agora()` e `verificacao = 'verificado'` (`:345-346`). Recalcula o comparecimento do profissional (`privado.recalcular_comparecimento`, `:350`).
6. **Resultado Esperado**:
   - Na tela do contratante: o item é removido das pendências e o status passa a "Presença verificada." (`TextosDoAcompanhamento.verificada`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:14`).
   - Na tela do profissional: ao atualizar (`refreshable` / reabrir), a linha `checkin-situacao` passa a exibir o selo de verificado (`checkmark.seal.fill`, `Verificacao.verificado`, `iOS/Sources/Dominio/Modelos.swift:464`).

---

### Cenário C: Avaliação Mútua Após o Fim do Turno

#### Passo C1: Liberação do Cartão de Avaliação
1. Condições de liberação (`RN07`, `privado.pode_avaliar`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:90`):
   - O horário de término previsto do turno já passou (`privado.agora() >= p.fim_em`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:98`, `MeuTurnoViewModel.podeAvaliar`, `iOS/Sources/Apresentacao/Fluxos/Profissional/MeuTurnoViewModel.swift:100`, `AcompanhamentoViewModel.podeAvaliar`, `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:437`).
   - A presença do turno está verificada (`verificacao = 'verificado'`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:97`, `MeuTurnoViewModel.swift:99`, `AcompanhamentoViewModel.swift:436`).
   - O lado chamador ainda não registrou avaliação para este turno (`frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:99-103`).
2. Se o horário ainda não passou ou a presença não foi verificada, a avaliação permanece bloqueada (no app o botão não é liberado; no backend retornaria erro 422 `avaliacao_indisponivel`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:287` e `:290`).
3. Com as condições satisfeitas:
   - No profissional: `TelaMeuTurno` exibe o cartão `cartaoAvaliacao` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:255`) com o título "AVALIAÇÃO DO TURNO" (`TextosDoProfissional.Avaliacao.cartaoTitulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:188`), a chamada "Como foi sua experiência no turno?" (`cartaoChamada`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:189`) e o botão "Avaliar turno" (`botaoAvaliar`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:190`, identificador `botao-abrir-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:303`).
   - No contratante: `TelaTurnoDoContratante` exibe o cartão `cartao-avaliacao-turno` (`iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:284`) com o botão "Avaliar turno" (`botao-abrir-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:277`).

#### Passo C2: Preenchimento na `TelaAvaliacao`
1. Tocar em "Avaliar turno" (`botao-abrir-avaliacao`).
2. O app abre `TelaAvaliacao` (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:4`, identificador `tela-avaliacao`, `:53` / `DestinoAvaliacaoDoContratante`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:512`).
3. A tela exibe:
   - Título de navegação: "Avaliar turno" (`TextosDoProfissional.Avaliacao.titulo`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:168`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:47`).
   - Pergunta binária no cabeçalho (`pergunta-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:60`):
     - Para o profissional: "Você trabalharia nesse local de novo?" (`TextosDoProfissional.Avaliacao.perguntaProfissional`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:169`).
     - Para o contratante: "Chamaria este profissional de novo?" (`TextosDoProfissional.Avaliacao.perguntaContratante`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:170`).
   - Cartão explicativo com selo de anonimato (`explicacao-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:77`, `TextosDoProfissional.Avaliacao.explicacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:171` e `:175`).
   - Componente de seleção binária `RespostaSimNao` (`iOS/Sources/Apresentacao/Componentes.swift:327`) com botões "Sim" e "Não" (`iOS/Sources/Apresentacao/Componentes.swift:343-344`).
4. O usuário seleciona "Sim" (ou "Não"). O ícone de checkmark surge no botão selecionado (`iOS/Sources/Apresentacao/Componentes.swift:358-359`).
5. O botão primário "Enviar avaliação" fica habilitado (`TextosDoProfissional.Avaliacao.botaoEnviar`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:179`, identificador `botao-enviar-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:127`).

#### Passo C3: Envio e Persistência
1. Tocar em "Enviar avaliação" (`botao-enviar-avaliacao`).
2. O ViewModel invoca `AvaliacaoTurnoViewModel.salvar()` (`iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:286`), chamando a RPC `avaliar(turno_id, resposta)` via `SupabaseApiCliente.avaliar` (`iOS/Sources/Dados/SupabaseApiCliente.swift:304`).
3. **Regra do Backend**:
   - `RN07` / `public.avaliar` (`frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:240`):
     - Confere autenticação e ausência de suspensão (`RN13`, `:246`).
     - Identifica o alvo pelo perfil do autor (`:266-274`): profissional avalia `estabelecimento`; contratante avalia `profissional`.
     - Confere que `agora() >= fim_em` e `verificacao = 'verificado'` (`:286-291`).
     - Insere na tabela `public.avaliacao` com garantia de voto único por lado via chave natural `unique (turno_id, alvo_tipo)` (`:301`).
     - Gatilho `avaliacao_soma_na_reputacao` (`:143`) executa `privado.somar_avaliacao()` (`:119`), incrementando de forma atômica `aval_total` e `aval_positivas` na contraparte (`RN08`, `:126-136`).
4. **Resultado Esperado na Tela**:
   - Exibição do aviso de sucesso: "Avaliação registrada." (`TextosDoProfissional.Avaliacao.avaliadoSucesso`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:180`, identificador `aviso-sucesso-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:102`).
   - A seleção é desabilitada para novas alterações (`disabled`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:86`).
   - O botão de envio desaparece (`TelaAvaliacao.swift:117`).

#### Passo C4: Reabertura e Idempotência
1. Retornar ao detalhe do turno (`TelaMeuTurno` ou `TelaTurnoDoContratante`).
2. **Resultado Esperado no Detalhe**:
   - O cartão de avaliação agora exibe o texto de estado: "Turno avaliado · Resposta: Sim" (ou Não) (`TextosDoProfissional.Avaliacao.statusResposta`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:193`, identificador `texto-status-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:266` e `:270`).
   - O botão altera para "Ver avaliação" (`TextosDoProfissional.Avaliacao.botaoVerAvaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:191`, identificador `botao-ver-avaliacao`, `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:285`, `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:261`).
3. Ao tocar em "Ver avaliação", a `TelaAvaliacao` abre exibindo a resposta gravada anteriormente e os controles bloqueados (`AvaliacaoTurnoViewModel.jaAvaliado`, `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:145`).
4. **Garantia de Idempotência no Servidor**:
   - Reenvio da mesma resposta devolve o registro existente com HTTP 200 (`frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:280-284`).
   - Tentativa de envio com resposta divergente resulta em recusa HTTP 409 `avaliacao_ja_registrada` (`frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:307`).

---

## 4. O que Conferir no Servidor Depois (Somente Leitura)

Após a realização do roteiro de testes pelo testador, realizar as consultas de verificação em modo somente leitura (via CLI do Supabase, `psql` ou painel do projeto `frila-dev`), sem efetuar qualquer escrita.

### 4.1 Registro de Presença na Tabela `public.turno`

Substituir `<turno_id>` pelo UUID do turno testado:

```sql
select id,
       posicao_id,
       checkin_em,
       checkin_recebido_em,
       checkin_tipo,
       checkin_distancia_m,
       checkin_confirmado_em,
       checkout_em,
       checkout_recebido_em,
       checkout_distancia_m,
       verificacao
  from public.turno
 where id = '<turno_id>';
```

**Critérios de Aceite na Saída**:
- `checkin_em`: timestamp correspondente ao instante do toque no aparelho.
- `checkin_recebido_em`: timestamp de recepção no servidor (`privado.agora()`).
- `checkin_tipo`:
  - Cenário A: `'geolocalizado'`.
  - Cenário B: `'manual'`.
- `checkin_distancia_m`:
  - Cenário A: valor inteiro `<= 200`.
  - Cenário B: `null`.
- `checkin_confirmado_em`:
  - Cenário A: `null`.
  - Cenário B: timestamp preenchido após confirmação do contratante.
- `checkout_em` e `checkout_recebido_em`: ambos preenchidos.
- `checkout_distancia_m`: distância inteira registrada na saída.
- `verificacao`: `'verificado'`.

### 4.2 Registro na Tabela `public.avaliacao`

```sql
select turno_id,
       alvo_tipo,
       resposta,
       criada_em
  from public.avaliacao
 where turno_id = '<turno_id>'
 order by criada_em;
```

**Critérios de Aceite na Saída**:
- Exatamente 1 registro por lado avaliador:
  - Avaliação do profissional: `alvo_tipo = 'estabelecimento'`.
  - Avaliação do contratante: `alvo_tipo = 'profissional'`.
- `resposta`: booleano (`true` para Sim, `false` para Não), conforme escolhido.
- `criada_em`: preenchido com a data/hora do registro.
- Nenhuma coluna contém dado pessoal, comentário ou nota fracionária (`RN07`, `frila-backend/CLAUDE.md:249`).

### 4.3 Totalizadores de Reputação e Comparecimento

```sql
-- Reputação do profissional avaliado
select id,
       taxa_comparecimento,
       aval_total,
       aval_positivas
  from public.profissional
 where id = '<profissional_id>';

-- Reputação do estabelecimento avaliado
select id,
       aval_total,
       aval_positivas
  from public.estabelecimento
 where id = '<estabelecimento_id>';
```

**Critérios de Aceite na Saída**:
- O campo `aval_total` incrementou em 1 em cada tabela (`privado.somar_avaliacao()`, `RN08`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:119`).
- Se a resposta foi positiva (`true`), `aval_positivas` incrementou em 1; se negativa, permaneceu estável.
- O campo `taxa_comparecimento` reflete a presença verificada recalculada (`privado.recalcular_comparecimento()`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:191` e `:350`).

### 4.4 Registro da Evidência
- Capturas de tela do aparelho devem ser salvas no diretório `iOS/Docs/Evidencias/` conforme previsto no item 9 (`iOS/Docs/ProntidaoBuild05.md:68`), com nomes padronizados e sem dados pessoais.
- O resultado das consultas SQL de leitura acima deve ser anotado no documento de evidências com os identificadores dos turnos sanitizados (primeiros 8 caracteres).

---

## 5. O que NÃO Está Provado

Para garantir rigor técnico e integridade das comprovações, separa-se a cobertura assegurada por automação daquela que depende exclusivamente de teste em aparelho físico.

### 5.1 O que Possui Teste Automatizado

As seguintes regras e comportamentos possuem testes automatizados implementados no repositório, mas **não foram executados durante a elaboração deste documento** (teto de 0 execução de CI e 0 simulador):

1. **Check-in Próximo e Verificação Imediata**:
   - Check-in a 150 m resulta em presença verificada e armazena distância inteira: teste unitário em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:135` (`checkinPerto`) e teste de UI em `iOS/Tests/UI/PresencaUITests.swift:46`.
2. **Limite Rígido de Distância (200 m)**:
   - Limite exato de 200 m (200 m verifica; 201 m oferece manual): teste parametrizado em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:174` (`limiteDeDistancia`).
3. **Leitura Pontual do GPS no Toque**:
   - O GPS só é ligado no toque e leitura finaliza em até 10 s: teste unitário em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:187` (`soNoToque`).
4. **Proteção contra Toque Duplo**:
   - Toque duplo em "Fazer check-in" envia apenas um registro: teste unitário em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:211` (`toqueDuplo`).
5. **Alternativa Manual sob Falha de Sinal ou Permissão**:
   - Permissão negada ou sinal indisponível exibe aviso e oferece check-in manual: testes unitários em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:227` (`permissaoNegada`), `:243` (`permissaoJaNegada`) e `:256` (`semSinal`), e teste de UI em `iOS/Tests/UI/PresencaUITests.swift:97`.
6. **Controle de Precisão Horizontal**:
   - Precisão acima de 100 m tratada como imprecisa: teste unitário em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:267` (`precisao`).
7. **Localização Aproximada e Precisão Temporária**:
   - Localização aproximada solicita precisão temporária com a chave "CheckIn": testes unitários em `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:278` (`aproximadaConcedida`) e `:290`.
8. **Validação Local e Remota da Avaliação**:
   - Avaliação antes do fim do turno ou sem presença verificada é bloqueada: testes unitários em `iOS/Tests/Unitarios/AvaliacaoTurnoViewModelTests.swift:356` e `:394` (`meuTurnoPodeAvaliar`).
9. **Idempotência e Reabertura da Avaliação**:
   - Reabertura do turno preserva a resposta dada e impede alteração: testes unitários em `iOS/Tests/Unitarios/AvaliacaoTurnoViewModelTests.swift:128`, `:295` e `:427`, e testes de UI em `iOS/Tests/UI/AvaliacaoUITests.swift:69` e `:168`.
10. **Comportamento Offline e Fila de Ações**:
    - Falha de conexão enfileira a ação para reenvio e salva resposta localmente: testes unitários em `iOS/Tests/Unitarios/AvaliacaoTurnoViewModelTests.swift:215` e `iOS/Tests/UI/AvaliacaoUITests.swift:10`.
11. **Regras SQL do Backend**:
    - Validação de regras e constraints (`RN07`, `RN18`, `RN22`, `privado.exigir_janela`): testes pgTAP em `frila-backend/supabase/tests/160_checkin_e_checkout.sql:1` e `frila-backend/supabase/tests/180_avaliar_e_perfil_publico.sql:1`.

### 5.2 O que Precisa de Aparelho Físico (Não Provado)

Os itens abaixo **não são comprovados por dublês de teste, simulador ou leitura estática de código** e dependem obrigatoriamente da execução física prevista no item 9 do diagnóstico:

1. **Hardware Real de GPS**:
   - Comportamento de `CLLocationManager` em condições reais de recepção de satélite, variações de acurácia em ambiente urbano e fechamento imediato do hardware pelo sistema operacional após a leitura.
2. **Caixas de Diálogo Nativo do iOS**:
   - Apresentação e resposta aos diálogos de sistema para permissão "Durante o Uso do App" e pedido de precisão temporária (`requestTemporaryFullAccuracyAuthorization`).
3. **Distribuição e Comunicação do Artefato TestFlight**:
   - Comunicação real de rede HTTPS entre o build compilado `Frila-Beta` instalado via TestFlight e os endpoints PostgREST do projeto `frila-dev`.
4. **Persistência Ponta a Ponta no Banco Remoto**:
   - Gravação real nas tabelas `public.turno` e `public.avaliacao` no `frila-dev`, com execução dos triggers de reputação no ambiente remoto.
5. **Interação Cruzada entre Perfis em Aparelhos Reais**:
   - Fluxo de trabalho em que o profissional realiza check-in manual no iPhone, o contratante visualiza a pendência e confirma a presença no painel, e o profissional verifica a mudança de estado em seu app.
6. **Usabilidade, Acessibilidade e Layout Real**:
   - Comportamento de renderização com Dynamic Type ajustado, contraste de componentes e resposta do leitor de tela VoiceOver em dispositivo físico.
7. **Estabilidade de Conexão na Porta do Estabelecimento**:
   - Comportamento de transição de conectividade (Wi-Fi para 4G/5G ou sinal fraco) durante a execução de presença e avaliação.

---

## 6. Índice de Citações do Código (Citação → Arquivo:Linha)

Todas as telas, botões, identificadores de acessibilidade, enums, regras de negócio e funções citadas neste documento são indexados abaixo com seus respectivos arquivos e linhas no código-fonte:

| Elemento / Citação | Tipo | Arquivo e Linha |
| --- | --- | --- |
| `Item 5 da prontidão` | Diagnóstico / Missão | `iOS/Docs/ProntidaoBuild05.md:6` e `:64` |
| `Item 9 da prontidão` | Diagnóstico / Missão | `iOS/Docs/ProntidaoBuild05.md:68` |
| `Frila-Beta` / `Release-Beta` | Configuração / Build | `iOS/README.md:16` |
| `ConfiguracaoAmbiente` | Código de ambiente | `iOS/Sources/App/ConfiguracaoAmbiente.swift:97` e `:112` |
| `Info.plist` | Configuração / Permissões | `iOS/Sources/App/Info.plist:9` |
| `PermissaoDeLocalizacao` | Enum de domínio | `iOS/Sources/Dominio/Localizacao.swift:5` |
| `RegraDePresenca` | Enum / Constantes | `iOS/Sources/Dominio/Localizacao.swift:44` |
| `distanciaMaximaDoCheckinMetros` | Constante (200 m) | `iOS/Sources/Dominio/Localizacao.swift:46` |
| `precisaoHorizontalMaximaMetros` | Constante (100.0 m) | `iOS/Sources/Dominio/Localizacao.swift:48` |
| `tempoLimiteDaLeitura` | Constante (10 s) | `iOS/Sources/Dominio/Localizacao.swift:49` |
| `chaveDaPrecisaoTemporaria` | Constante ("CheckIn") | `iOS/Sources/Dominio/Localizacao.swift:50` |
| `LeitorDeLocalizacaoDoSistema` | Classe de infraestrutura | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:9` |
| `pedirPermissao()` | Método | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:30` |
| `pedirPrecisaoTemporaria(chave:)` | Método | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:39` |
| `lerUmaVez(...)` | Método | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:45` |
| `concluir(_:)` / stopUpdatingLocation | Método / Encerramento GPS | `iOS/Sources/Infraestrutura/LeitorDeLocalizacaoDoSistema.swift:81` |
| `EstadoPosicao` | Enum de domínio | `iOS/Sources/Dominio/Modelos.swift:441` |
| `Posicao` | Struct de domínio | `iOS/Sources/Dominio/Modelos.swift:448` |
| `Verificacao` | Enum de domínio | `iOS/Sources/Dominio/Modelos.swift:462` |
| `TipoRegistro` | Enum de domínio | `iOS/Sources/Dominio/Modelos.swift:474` |
| `Presenca` | Struct de domínio | `iOS/Sources/Dominio/Modelos.swift:555` |
| `Turno` | Struct de domínio | `iOS/Sources/Dominio/Modelos.swift:582` |
| `ResultadoRegistro` | Struct de domínio | `iOS/Sources/Dominio/Modelos.swift:698` |
| `Avaliacao` | Struct de domínio | `iOS/Sources/Dominio/Modelos.swift:725` |
| `Periodo` | Struct de valor | `iOS/Sources/Dominio/ObjetosDeValor.swift:34` |
| `TelaMeusTurnos` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:46` |
| `CartaoMeuTurno` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeusTurnos.swift:4` |
| `TelaMeuTurno` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:7` |
| `SecaoDePresenca` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:10` |
| `fazer-checkin` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:63` |
| `fazer-checkout` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:66` |
| `permitir-localizacao` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:71` |
| `cancelar-presenca` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:73` e `:99` |
| `registro-manual` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:87` |
| `tentar-gps` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:89` |
| `abrir-ajustes` | Link / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:96` |
| `checkin-situacao` | Elemento / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:29`, `:156`, `:159` |
| `checkout-situacao` | Elemento / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:32`, `:172` |
| `sem-gps` | Elemento / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/SecaoDePresenca.swift:82` |
| `TextosDoProfissional.Presenca` | Textos localizados | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:9` |
| `TextosDoProfissional.Presenca.titulo` | Texto ("Presença") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:10` |
| `TextosDoProfissional.Presenca.fazerCheckin` | Texto ("Fazer check-in") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:11` |
| `TextosDoProfissional.Presenca.fazerCheckout` | Texto ("Fazer check-out") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:12` |
| `TextosDoProfissional.Presenca.explicacaoTitulo` | Texto ("Sua localização, só neste toque") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:14` |
| `TextosDoProfissional.Presenca.explicacao` | Texto explicativo | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:15` |
| `TextosDoProfissional.Presenca.continuar` | Texto ("Continuar") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:19` |
| `TextosDoProfissional.Presenca.agoraNao` | Texto ("Agora não") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:20` |
| `TextosDoProfissional.Presenca.lendo` | Texto ("Lendo sua localização…") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:22` |
| `TextosDoProfissional.Presenca.enviando` | Texto ("Enviando…") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:23` |
| `TextosDoProfissional.Presenca.semGPSTitulo` | Texto ("Localização não confirmada") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:25` |
| `TextosDoProfissional.Presenca.manualExplicacao` | Texto explicativo | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:35` |
| `TextosDoProfissional.Presenca.checkinManual` | Texto ("Fazer check-in manual") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:36` |
| `TextosDoProfissional.Presenca.tentarGPS` | Texto ("Tentar o GPS de novo") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:39` |
| `TextosDoProfissional.Presenca.abrirAjustes` | Texto ("Abrir Ajustes") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:40` |
| `TextosDoProfissional.Presenca.checkinVerificado` | Texto de resultado | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:42` |
| `TextosDoProfissional.Presenca.checkinAguardando` | Texto de resultado | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:46` |
| `TextosDoProfissional.Presenca.checkoutRegistrado` | Texto de resultado | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:57` |
| `TextosDoProfissional.Presenca.foraDaJanela` | Texto de erro | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:65` |
| `TextosDoProfissional.Presenca.relogioAdiantado` | Texto de erro | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDaPresenca.swift:66` |
| `PresencaDoTurnoViewModel` | ViewModel | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:9` |
| `PresencaDoTurnoViewModel.Registro` | Enum | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:10` |
| `PresencaDoTurnoViewModel.MotivoSemGPS` | Enum | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:16` |
| `PresencaDoTurnoViewModel.Etapa` | Enum | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:28` |
| `PresencaDoTurnoViewModel.Situacao` | Enum | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:50` |
| `PresencaDoTurnoViewModel.podeFazerCheckin` | Propriedade | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:100` |
| `PresencaDoTurnoViewModel.podeFazerCheckout` | Propriedade | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:104` |
| `PresencaDoTurnoViewModel.aguardandoConfirmacao` | Propriedade | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:107` |
| `PresencaDoTurnoViewModel.iniciar(_:)` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:159` |
| `PresencaDoTurnoViewModel.continuarComPermissao()` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:173` |
| `PresencaDoTurnoViewModel.tentarGPSDeNovo()` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:181` |
| `PresencaDoTurnoViewModel.registrarSemGPS()` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:188` |
| `PresencaDoTurnoViewModel.lerEEnviar(_:)` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:206` |
| `PresencaDoTurnoViewModel.enviar(...)` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:258` |
| `MeuTurnoViewModel.podeAvaliar` | Propriedade | `iOS/Sources/Apresentacao/Fluxos/Profissional/MeuTurnoViewModel.swift:96` |
| `MeuTurnoViewModel.jaAvaliado` | Propriedade | `iOS/Sources/Apresentacao/Fluxos/Profissional/MeuTurnoViewModel.swift:113` |
| `cartaoAvaliacao` | ViewBuilder | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:255` |
| `botao-abrir-avaliacao` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:303` |
| `botao-ver-avaliacao` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:285` |
| `texto-status-avaliacao` | Texto / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaMeuTurno.swift:266` e `:270` |
| `TelaAvaliacao` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:4` |
| `tela-avaliacao` | Identificador de tela | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:53` |
| `pergunta-avaliacao` | Cabeçalho / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:60` |
| `explicacao-avaliacao` | Cartão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:77` |
| `aviso-ja-avaliado` | Aviso / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:97` |
| `aviso-sucesso-avaliacao` | Aviso / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:102` |
| `botao-enviar-avaliacao` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Profissional/TelaAvaliacao.swift:127` |
| `RespostaSimNao` | Componente SwiftUI | `iOS/Sources/Apresentacao/Componentes.swift:327` |
| `TextosDoProfissional.Avaliacao` | Textos localizados | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:167` |
| `TextosDoProfissional.Avaliacao.titulo` | Texto ("Avaliar turno") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:168` |
| `TextosDoProfissional.Avaliacao.perguntaProfissional` | Texto de pergunta | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:169` |
| `TextosDoProfissional.Avaliacao.perguntaContratante` | Texto de pergunta | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:170` |
| `TextosDoProfissional.Avaliacao.explicacao` | Texto explicativo | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:171` |
| `TextosDoProfissional.Avaliacao.explicacaoContratante` | Texto explicativo | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:175` |
| `TextosDoProfissional.Avaliacao.botaoEnviar` | Texto ("Enviar avaliação") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:179` |
| `TextosDoProfissional.Avaliacao.avaliadoSucesso` | Texto de sucesso | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:180` |
| `TextosDoProfissional.Avaliacao.cartaoTitulo` | Texto ("Avaliação do turno") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:188` |
| `TextosDoProfissional.Avaliacao.cartaoChamada` | Texto de chamada | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:189` |
| `TextosDoProfissional.Avaliacao.botaoAvaliar` | Texto ("Avaliar turno") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:190` |
| `TextosDoProfissional.Avaliacao.botaoVerAvaliacao` | Texto ("Ver avaliação") | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:191` |
| `TextosDoProfissional.Avaliacao.statusAvaliado` | Texto de status | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:192` |
| `TextosDoProfissional.Avaliacao.statusResposta` | Função de status | `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:193` |
| `AvaliacaoTurnoViewModel` | ViewModel | `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:130` |
| `AvaliacaoTurnoViewModel.salvar()` | Método | `iOS/Sources/Apresentacao/Fluxos/Profissional/AvaliacaoTurnoViewModel.swift:286` |
| `TelaTurnoDoContratante` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:189` |
| `PendenciasDoContratante` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:444` |
| `DestinoAvaliacaoDoContratante` | View SwiftUI | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:512` |
| `TextosDoAcompanhamento.confirmarPresenca` | Texto ("Confirmar presença") | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:13` |
| `TextosDoAcompanhamento.verificada` | Texto ("Presença verificada.") | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:14` |
| `TextosDoAcompanhamento.explicacaoDaConfirmacao` | Texto explicativo | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:12` |
| `TextosDoAcompanhamento.presencasAConfirmar` | Texto de seção | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:33` |
| `confirmar-presenca-[id]` | Botão / Acessibilidade | `iOS/Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift:344` e `:460` |
| `AcompanhamentoViewModel` | ViewModel | `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:90` |
| `AcompanhamentoViewModel.podeConfirmar` | Método | `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:185` |
| `AcompanhamentoViewModel.confirmarPresenca` | Método | `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:287` |
| `AcompanhamentoViewModel.podeAvaliar` | Método | `iOS/Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:432` |
| `SupabaseApiCliente.fazerCheckin` | Chamada API RPC | `iOS/Sources/Dados/SupabaseApiCliente.swift:296` |
| `SupabaseApiCliente.fazerCheckout` | Chamada API RPC | `iOS/Sources/Dados/SupabaseApiCliente.swift:300` |
| `SupabaseApiCliente.avaliar` | Chamada API RPC | `iOS/Sources/Dados/SupabaseApiCliente.swift:304` |
| `SupabaseApiCliente.confirmarCheckinManual` | Chamada API RPC | `iOS/Sources/Dados/SupabaseApiCliente.swift:311` |
| `RN01` | Regra de negócio (valor integral) | `frila-backend/CLAUDE.md:250` |
| `RN02` | Regra de negócio (vaga completa) | `frila-backend/CLAUDE.md:170` |
| `RN07` | Regra de negócio (avaliação binária) | `frila-backend/CLAUDE.md:173`, `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:317` |
| `RN08` | Regra de negócio (reputação atômica) | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:141` |
| `RN10` | Regra de negócio (prazo de contato) | `frila-backend/CLAUDE.md:262` |
| `RN13` | Regra de negócio (conta suspensa) | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:242` |
| `RN15` | Regra de negócio (privacidade em log) | `frila-backend/CLAUDE.md:260` |
| `RN18` | Regra de negócio (centavos / UTC) | `frila-backend/CLAUDE.md:167` |
| `RN19` | Regra de negócio (posição única) | `frila-backend/CLAUDE.md:165` |
| `RN21` | Regra de negócio (sem sobreposição) | `frila-backend/CLAUDE.md:166` |
| `RN22` | Regra de negócio (limite 200 m / manual) | `frila-backend/CLAUDE.md:172`, `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:170` |
| `RN25` | Regra de negócio (uma conta um perfil) | `frila-backend/CLAUDE.md:169` |
| `RF13` | Requisito funcional (check-in/out) | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:203` e `:281` |
| `RF15` | Requisito funcional (avaliação) | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:317` |
| `RF20` | Requisito funcional (confirmação manual) | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:316` |
| `privado.exigir_janela` | Função SQL backend | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:90` |
| `public.fazer_checkin` | RPC SQL backend | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:118` |
| `public.fazer_checkout` | RPC SQL backend | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:212` |
| `public.confirmar_checkin_manual` | RPC SQL backend | `frila-backend/supabase/migrations/20260925000000_checkin_e_checkout.sql:288` |
| `privado.pode_avaliar` | Função SQL backend | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:90` |
| `privado.somar_avaliacao` | Trigger function backend | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:119` |
| `public.avaliar` | RPC SQL backend | `frila-backend/supabase/migrations/20260925030000_avaliar_e_perfil_publico.sql:240` |
| `PresencaDoTurnoViewModelTests` | Testes unitários de presença | `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:135` |
| `PresencaUITests` | Testes de UI de presença | `iOS/Tests/UI/PresencaUITests.swift:46` |
| `AvaliacaoTurnoViewModelTests` | Testes unitários de avaliação | `iOS/Tests/Unitarios/AvaliacaoTurnoViewModelTests.swift:100` |
| `AvaliacaoUITests` | Testes de UI de avaliação | `iOS/Tests/UI/AvaliacaoUITests.swift:69` |
| `160_checkin_e_checkout.sql` | Teste pgTAP backend | `frila-backend/supabase/tests/160_checkin_e_checkout.sql:1` |
| `180_avaliar_e_perfil_publico.sql` | Teste pgTAP backend | `frila-backend/supabase/tests/180_avaliar_e_perfil_publico.sql:1` |
