Revisado e aprovado pelo Jurídico do time (agente de IA, skill leis-do-brasil) em 31/10/2026. Não é parecer de advogado.

# LGPD — Registro, Canal do Titular e Resposta a Incidentes

Documento formal de conformidade com a Lei Geral de Proteção de Dados Pessoais (Lei nº 13.709/2018),
elaborado a partir do dossiê técnico de privacidade aprovado no PR #192 (`iOS/Docs/SegurancaEPrivacidade.md`)
e do código-fonte em `iOS/Sources/`.

> **Status de Governança:**
> - Simulação de incidente de mesa realizada com sucesso em 16/10/2026 (Seção 3.7); simulação ao vivo agendada para pós-piloto.
> - Encarregado pelo Tratamento de Dados (DPO): dispensado nos termos do Art. 11 da Resolução CD/ANPD nº 2/2022 (Regulamento de aplicação da LGPD para agentes de tratamento de pequeno porte / Inova Simples), mantendo canal de atendimento direto ao titular em `suporte@frilabr.com`.
> - Documento formalmente aprovado pelo Jurídico do time em 31/10/2026, sob mandato do sócio-administrador Cauê Carneiro Crillanovick.

---

## 1. Registro das Operações de Tratamento de Dados Pessoais (ROPA — Art. 37)

### 1.1 Identificação do Controlador

| Campo | Valor |
|---|---|
| **Responsável (controlador)** | `FRILA TECNOLOGIA INOVA SIMPLES (I.S.)`, constituída sob a forma de Inova Simples (LC 167/2019 e art. 65-A da LC 123/2006) em 21/10/2026, administrada por Cauê Carneiro Crillanovick e Fabrício Tosta |
| **CNPJ e sede** | CNPJ `69.728.564/0001-41`, com sede em Brasília, Distrito Federal |
| **Encarregado (DPO)** | Dispensado (Resolução CD/ANPD nº 2/2022, Art. 11); atendimento ao titular exercido diretamente pelos administradores |
| **Canal do Titular e Suporte** | `suporte@frilabr.com` — referência: `EnderecosOficiais.swift:22` (D2 unifica todos os canais) |
| **Política de Privacidade** | `https://frila.netlify.app/privacidade` — referência: `EnderecosOficiais.swift:20-21` |

### 1.2 Operações de Tratamento

Tabela alinhada ao mapeamento da Seção 2 do dossiê (`SegurancaEPrivacidade.md:89-103`) e conferida
contra o código-fonte.

| # | Dado Pessoal | Categoria LGPD | Titular | Finalidade | Base Legal (Art. 7º) | Origem no Código | Armazenamento | Compartilhamento | Retenção e Eliminação |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Nome completo** | Dado pessoal | Profissional / Contratante | Identificação na plataforma; exibição nas candidaturas e turnos | Art. 7º, V — execução de contrato | `Dominio/Portas.swift:3`, RPC `criar_conta` em `SupabaseApiCliente.swift:116` | Supabase Postgres (banco), SwiftData local (cache) | Outra parte do turno confirmado | Exclusão pela RPC de exclusão de conta; cache local apagado em `SaidaDaConta.swift:74-91` |
| 2 | **Endereço de e-mail** | Dado pessoal | Profissional / Contratante | Autenticação via OTP (sem senha) | Art. 7º, V — execução de contrato | `SupabaseApiCliente.swift:61-64` (Supabase Auth) | Supabase Auth | Não compartilhado com terceiros | Exclusão pela RPC de exclusão de conta |
| 3 | **Número de telefone** | Dado pessoal | Profissional / Contratante | Contato entre as partes após confirmação do turno (WhatsApp) | Art. 7º, V — execução de contrato | `ContatoDTO.dominio()` em `DTOsContrato.swift:588` | Supabase Postgres; SwiftData (cache, com expiração) | Outra parte do turno confirmado, via `whatsapp_url` saneado (A5) | Disponível à outra parte por até 7 dias após o fim do turno (RN10), no app e no servidor; offline, o cache local descarta o turno 24 h após o fim (`CacheSwiftData.swift:123-133`) |
| 4 | **Endereço físico do estabelecimento** | Dado pessoal | Contratante | Localização do turno; cálculo de distância para o profissional | Art. 7º, V — execução de contrato | `CadastroEstabelecimento.swift:105`, RPC `cadastrar_estabelecimento` em `SupabaseApiCliente.swift:159` | Supabase Postgres | Profissionais que visualizam a vaga | Exclusão pela RPC de exclusão de conta |
| 5 | **Localização precisa (GPS)** | Dado pessoal sensível (Art. 11) | Profissional | Comprovação de presença no check-in/check-out | Art. 7º, V — execução de contrato; consentimento via permissão "Ao Usar o App" | `LeitorDeLocalizacaoDoSistema.swift:45` (leitura pontual) | **Não armazenada no servidor.** Apenas `distanciaMetros` é enviado (`DTOsContrato.swift:866-875`). Localmente: transitória | Não compartilhada | Não retida: só a distância (não pessoal) é persistida |
| 6 | **Ponto base (coordenada de referência)** | Dado pessoal | Profissional | Calcular proximidade com vagas no feed. Um único ponto, sem histórico de lugares | Art. 7º, V — execução de contrato | `PerfilProfissionalViewModel.swift:108-112` | Supabase Postgres | Não compartilhado (usado apenas em consulta interna) | Exclusão pela RPC de exclusão de conta |
| 7 | **ID do usuário (conta_id)** | Dado pessoal | Profissional / Contratante | Identificação única da conta | Art. 7º, V — execução de contrato | Supabase Auth (`usuarioID`) | Supabase Auth; SwiftData local (`Modelos.swift:13-21`) | Internamente entre módulos | Exclusão pela RPC de exclusão de conta; localmente em `SaidaDaConta.swift` |
| 8 | **Token de push (APNs/FCM)** | Dado pessoal (identificador de dispositivo) | Profissional / Contratante | Notificações push de turnos, candidaturas e avisos | Art. 7º, V — execução de contrato | `AparelhoDePush.swift:208`, RPC `registrar_dispositivo` | Supabase Postgres; Keychain local (`AfterFirstUnlockThisDeviceOnly`) | Firebase Cloud Messaging (operador) | Apagado na saída da conta (`SaidaDaConta.swift`); no App Group: apagado com o vínculo |
| 9 | **Data de nascimento** | Dado pessoal | Profissional / Contratante | Validação de maioridade legal (o app é exclusivo para maiores de 18 anos) | Art. 7º, II — cumprimento de obrigação legal (intermediação de trabalho avulso; ECA Digital, Lei nº 15.211/2025) | Cadastro da conta; no iOS 26.2 ou mais novo, também a faixa de idade do aparelho (*Declared Age Range*), sem a data de nascimento do aparelho | Supabase Postgres | Não compartilhada | Exclusão pela RPC de exclusão de conta |
| 9a | **Documento do Estabelecimento (CNPJ ou CPF)** | Dado pessoal (quando CPF) | Contratante | Identificar quem contrata e evitar cadastro repetido do mesmo estabelecimento | Art. 7º, V — execução de contrato | RPC `cadastrar_estabelecimento` (`estabelecimento.documento`) | Supabase Postgres | Não compartilhado; nunca aparece em leitura pública | Exclusão pela RPC de exclusão de conta (anonimização, RF25) |
| 10 | **Relatos de suporte, contestação e avaliações** | Dado pessoal (conteúdo do usuário) | Profissional / Contratante | Suporte ao usuário; moderação (Diretriz 1.2 Apple); avaliação de turnos | Art. 7º, V — execução de contrato | `FolhaSuporteTurno.swift`, `ContaSuspensaViewModel.swift`, `AvaliacaoTurnoViewModel.swift` | Supabase Postgres | Equipe operacional interna (o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos) | Exclusão pela RPC de exclusão de conta |
| 11 | **Dados de falhas (crash)** | Dado diagnóstico (não pessoal) | — | Estabilidade do app | Art. 7º, IX — legítimo interesse | `TelemetriaCrashlytics.swift` | Firebase Crashlytics | Firebase/Google (operador) | Retenção padrão do Crashlytics (90 dias) |
| 12 | **Telemetria de erros da API** | Dado diagnóstico (não pessoal) | — | Monitoramento de erros | Art. 7º, IX — legítimo interesse | `TelemetriaCrashlytics.swift:44-47` (`codigo`, `rpc`, `duracao_ns`) | Firebase Crashlytics | Firebase/Google (operador) | Retenção padrão do Crashlytics |
| 13 | **Eventos de uso do app** (telemetria `evento_app`) | Dado pessoal (vinculado à conta) | Profissional / Contratante | Medir se o ciclo de vagas e turnos funciona e onde as pessoas desistem; contas de demonstração e da equipe ficam fora das contas | Art. 7º, IX — legítimo interesse | `usuario_id`, `evento` (lista fechada de 14), `vaga_id`, `turno_id`, `ocorrido_em`; sem texto livre, telefone, e-mail ou coordenadas | Supabase Postgres (RLS: só `service_role` e a view de métricas); sem rede, fila local de até 200 eventos por até 30 dias | Não compartilhado | Apagados em 90 dias por `privado.limpar_eventos_app`; a fila local é apagada ao sair da conta |

### 1.3 Operadores (Subprocessadores)

| Operador | Dado Acessado | Finalidade | Salvaguarda |
|---|---|---|---|
| **Supabase Inc.** (infraestrutura de banco, autenticação e Edge Functions) | Todos os dados pessoais do banco e da autenticação (itens 1-10 e 13) | Hospedagem e processamento dos dados | Contrato de processamento de dados do Supabase (DPA); dados em trânsito sobre TLS; banco cifrado em repouso |
| **Google / Firebase** (Crashlytics e FCM) | Token de push (item 8), dados de crash e telemetria (itens 11-12) | Entrega de notificações push e relatórios de falhas | DPA do Firebase; sem `setUserID`, sem dados pessoais nos eventos; dados desvinculados da identidade |
| **Apple Inc.** (APNs) | Token de push (item 8) | Entrega de notificações push no iOS | Termos do Apple Push Notification service |
| **Google (Gmail)** | Endereço de e-mail (item 2) | Envio do código temporário de entrada | Termos do Google Workspace/Gmail; o e-mail leva só o código, sem outros dados da conta |

### 1.4 Transferência Internacional

Os dados pessoais são processados nos servidores do Supabase e do Firebase, que podem estar
localizados fora do Brasil (EUA). A transferência é amparada pelo Art. 33, II, da LGPD (cláusulas
contratuais padrão / DPA dos operadores).

### 1.5 Medidas de Segurança Técnicas e Administrativas (Art. 46)

Conferidas no dossiê `SegurancaEPrivacidade.md` (PR #192):

1. **Criptografia em trânsito:** TLS obrigatório (ATS padrão, sem exceções — `SegurancaEPrivacidade.md:59`).
2. **Criptografia em repouso (dispositivo):**
   - Keychain: `AfterFirstUnlockThisDeviceOnly` para token de push e sessão (`A2`, `ArmazenamentoKeychain.swift:17`).
   - Arquivos temporários: `completeFileProtection` (`A1`, `A3`).
   - SwiftData: `completeUntilFirstUserAuthentication` (`CacheSwiftData.swift:70-73`).
3. **Proteção de tela:** Cortina de privacidade sobre o seletor de apps (`A4`, `CortinaDePrivacidade.swift`).
4. **Minimização de dados:** Coordenada GPS nunca enviada ao servidor; apenas `distanciaMetros`.
5. **Logs sem dados pessoais:** Nenhum nome, e-mail, telefone ou documento nos logs (`SegurancaEPrivacidade.md:34-40`).
6. **Controle de acesso:** Chave `service_role` recusada no build (`ConfiguracaoAmbiente.swift:155-163`).
7. **Validação de entradas externas:** Push de outra conta ou anterior ao vínculo bloqueado; URL do WhatsApp saneada.
8. **Eliminação na saída:** `SaidaDaConta.swift:74-91` purga avaliações, vínculo, cache SwiftData, `UserDefaults` e sessão.

---

## 2. Canal do Titular de Dados (Arts. 17-22)

### 2.1 Canal de Exercício de Direitos

| Campo | Valor |
|---|---|
| **E-mail oficial** | `suporte@frilabr.com` (D2 unifica atendimento e exercício de direitos do titular) |
| **Acesso no app** | Perfil → "Política de privacidade" (link para `https://frila.netlify.app/privacidade`) |
| **Acesso no app** | Perfil → "Exportar meus dados" / "Excluir conta" |
| **Referência no código** | `EnderecosOficiais.swift:19-23`, `PerfisDaConta.swift:200-215` |

### 2.2 Direitos do Titular e Forma de Exercício

| Direito (LGPD) | Artigo | Implementação no App | Pendência |
|---|---|---|---|
| Confirmação e acesso (Art. 18, I-II) | Art. 18 e Art. 19 | "Exportar meus dados" — RPC `exportar-meus-dados`, JSON com todos os dados da conta (`ExportarDadosViewModel.swift`) | — |
| Correção (Art. 18, III) | Art. 18 | Edição de perfil no app (nome, telefone, endereço, ponto base) | — |
| Anonimização, bloqueio ou eliminação (Art. 18, IV) | Art. 18 | "Excluir conta" — RPC de exclusão + purga local (`ExclusaoDeContaViewModel.swift`, `SaidaDaConta.swift`) | — |
| Portabilidade (Art. 18, V) | Art. 18 | "Exportar meus dados" em JSON; histórico de turnos em CSV/PDF (`HistoricoDeTurnosViewModel`) | — |
| Eliminação de dados tratados com consentimento (Art. 18, VI) | Art. 18 | "Excluir conta" remove todos os dados | — |
| Informação sobre compartilhamento (Art. 18, VII) | Art. 18 | Política de Privacidade em `https://frila.netlify.app/privacidade`; este documento (ROPA, Seção 1.3) | Publicar na página pública |
| Revogação do consentimento (Art. 18, IX) | Art. 18 | Saída da conta + exclusão; permissão de localização revogável nos Ajustes do iOS | — |

### 2.3 Procedimento de Atendimento

1. O titular envia solicitação para `suporte@frilabr.com` identificando-se e descrevendo o pedido.
2. Prazo de resposta: **15 dias corridos** (Art. 19, II da LGPD; triagem inicial em até 5 dias úteis).
3. Solicitações de acesso e portabilidade: encaminhar ao titular o resultado da RPC `exportar-meus-dados`.
4. Solicitações de exclusão: confirmar a identidade e processar a exclusão via RPC; confirmar por e-mail.
5. Registrar toda solicitação e resposta internamente para fins de prestação de contas (Art. 6º, X).

---

## 3. Plano de Resposta a Incidentes de Segurança (Arts. 48-49)

### 3.1 Definição de Incidente

Qualquer evento confirmado ou suspeito de acesso não autorizado, destruição, perda, alteração ou
vazamento de dados pessoais tratados pelo Frila, acidental ou ilícito.

### 3.2 Equipe de Resposta

| Papel | Responsável | Contato |
|---|---|---|
| **Controlador / Coordenação do Incidente** | `FRILA TECNOLOGIA INOVA SIMPLES (I.S.)` (CNPJ `69.728.564/0001-41`), administrada por Cauê Carneiro Crillanovick e Fabrício Tosta | `suporte@frilabr.com` |
| **Equipe Técnica** | Liderança técnica de infraestrutura e engenharia | Monitoramento interno |
| **Comunicação e Atendimento** | Atendimento oficial aos titulares e ANPD | `suporte@frilabr.com` |

### 3.3 Fases do Plano

#### Fase 1 — Detecção e Contenção (0-4 h)

1. Identificar o vetor de incidente (acesso indevido ao banco, vazamento de credencial, vulnerabilidade, etc.).
2. Isolar o componente afetado (revogar chaves, bloquear acesso, desativar Edge Function). Quando houver
   suspeita de credencial exposta, revogar também as que ficam fora do banco: sessões e chaves do Supabase,
   senha de app do Gmail usada no envio do código de entrada, chave do APNs e do FCM e segredos do GitHub
   Actions. Quem grava segredo novo é o Responsável; o valor nunca vai para chat, e-mail ou repositório.
3. Preservar evidências (logs do Supabase, logs do Firebase Crashlytics, registros de acesso).
4. Comunicar internamente ao responsável.
5. Se o incidente puder estar no lado de um operador (Seção 1.3), pedir a ele o relato e as evidências pelos
   canais oficiais e anotar data e hora do pedido.
6. Abrir o registro do incidente (Seção 3.6) já nesta fase, com a data e a hora da ciência.

#### Fase 2 — Avaliação (meta interna: até 1 dia útil)

1. Determinar os dados pessoais afetados (cruzar com a tabela do ROPA, Seção 1.2).
2. Estimar o número de titulares afetados.
3. Avaliar o risco e o dano potencial aos titulares.
4. Classificar a gravidade: **baixa** (sem dado pessoal exposto), **média** (dados pessoais não sensíveis),
   **alta** (dados sensíveis, financeiros ou de menores, ou volume acima de 1.000 titulares).

#### Fase 3 — Comunicação (até 3 dias úteis do conhecimento do incidente — Art. 48 e Resolução CD/ANPD nº 15/2024)

1. Notificar a ANPD pelo formulário oficial, se o incidente puder acarretar risco ou dano relevante.
2. Notificar os titulares afetados por e-mail individual.
3. Registrar internamente toda a comunicação.
4. Prazo: adotamos os 3 dias úteis da Resolução, contados da ciência do incidente. A Resolução CD/ANPD
   nº 2/2022 permite contar em dobro para agente de pequeno porte, mas o Frila não usa essa folga: se faltar
   informação no prazo, comunica-se o que já se sabe e complementa-se depois, pelo prazo que o texto oficial
   da Resolução fixar (conferir o número de dias no texto publicado no Diário Oficial da União antes de usar).

#### Fase 4 — Remediação (até 10 dias úteis)

1. Corrigir a vulnerabilidade ou a causa raiz.
2. Revisar as medidas de segurança (Seção 1.5).
3. Documentar lições aprendidas e atualizar este plano.

### 3.4 Modelo de Comunicação à ANPD

```
COMUNICAÇÃO DE INCIDENTE DE SEGURANÇA COM DADOS PESSOAIS
(Art. 48 da Lei nº 13.709/2018)

Data da comunicação: ____/____/________
Data da ciência do incidente: ____/____/________

1. IDENTIFICAÇÃO DO CONTROLADOR
   Razão Social: FRILA TECNOLOGIA INOVA SIMPLES (I.S.)
   CNPJ: 69.728.564/0001-41
   Administradores: Cauê Carneiro Crillanovick e Fabrício Tosta
   E-mail: suporte@frilabr.com
   Sede: Brasília/DF

2. DESCRIÇÃO DO INCIDENTE
   Natureza do incidente:
   [ ] Acesso não autorizado  [ ] Vazamento  [ ] Perda  [ ] Alteração  [ ] Destruição
   [ ] Outro: ________________

   Data e hora do incidente (estimada): ____/____/________ às ____h____
   Data e hora da ciência: ____/____/________ às ____h____
   Duração estimada: ________________

   Descrição resumida:
   ________________________________________________________________________
   ________________________________________________________________________

3. DADOS PESSOAIS AFETADOS
   Tipos de dados: ________________
   (Referência: ROPA itens nº ____ desta documentação)
   Volume estimado de registros: ________________
   Número estimado de titulares: ________________
   Categorias de titulares: [ ] Profissionais  [ ] Contratantes  [ ] Ambos

4. CONSEQUÊNCIAS DO INCIDENTE
   Riscos e danos potenciais aos titulares:
   ________________________________________________________________________

5. MEDIDAS DE CONTENÇÃO E MITIGAÇÃO ADOTADAS
   ________________________________________________________________________
   ________________________________________________________________________

6. MEDIDAS PARA REVERTER OU MITIGAR OS EFEITOS
   ________________________________________________________________________

7. INFORMAÇÕES ADICIONAIS
   ________________________________________________________________________

Assinatura do responsável: ________________
```

### 3.5 Modelo de Comunicação aos Titulares

```
Assunto: Aviso importante sobre a segurança dos seus dados no Frila

Prezado(a) [Nome do Titular],

Informamos que identificamos um incidente de segurança que pode ter afetado
os seguintes dados pessoais vinculados à sua conta no Frila:

- [Listar dados afetados, ex.: nome, e-mail, telefone]

O que aconteceu:
[Descrição clara e objetiva do incidente, em linguagem acessível]

O que fizemos:
- [Medida de contenção 1]
- [Medida de contenção 2]
- [Comunicação à ANPD, se aplicável]

O que recomendamos que você faça:
- [Recomendação 1, ex.: alterar senha de serviços que usem o mesmo e-mail]
- [Recomendação 2]

Estamos à disposição pelo e-mail suporte@frilabr.com para esclarecer
quaisquer dúvidas.

Atenciosamente,
Equipe Frila
```

### 3.6 Registro de Incidentes

Todo incidente, inclusive o que não exigiu comunicação à ANPD nem aos titulares, entra num registro com: data e
hora da ciência, descrição, dados e titulares afetados, gravidade (Fase 2), medidas de contenção com a hora de
cada uma, decisão de comunicar ou não (com o motivo) e lições aprendidas. A Resolução CD/ANPD nº 15/2024 exige
a guarda por no mínimo cinco anos, contados do registro. O registro fica fora do repositório público, em local
de acesso restrito ao Responsável e à equipe técnica, e não leva o dado pessoal afetado, só a descrição dele.

### 3.7 Simulação de Mesa (16/10/2026)

**Natureza:** exercício de mesa, sem acionar ninguém nem alterar sistema. Os tempos abaixo são **estimativas** de
quem leu o plano e os fatos do app; não são medição. A medição vem do exercício ao vivo.

**Cenário (hipotético):** uma pessoa avisa em `suporte@frilabr.com`, numa terça às 09h00, que uma regra de
acesso do banco deixa qualquer conta autenticada ler o telefone e o documento de outros estabelecimentos.

| Hora | Passo | Fase |
|---|---|---|
| 09h00 | Ciência: a mensagem chega ao canal do titular. É a hora que conta para os 3 dias úteis | 1 |
| 09h15 | Responsável lê, abre o registro (3.6) e chama a equipe técnica | 1 |
| 09h45 | Equipe técnica reproduz com duas contas de teste no ambiente de desenvolvimento e confirma | 1 |
| 10h30 | **Contenção:** correção da regra aplicada em produção (ou, se não der, Edge Function e acesso à tabela desativados) | 1 |
| 11h00 | Evidências preservadas (logs do Supabase), antes de qualquer limpeza | 1 |
| Dia útil 1 | Avaliação: consulta aos logs diz se houve leitura por terceiros; cruza com o ROPA (telefone, documento); gravidade **alta** se houve leitura de documento | 2 |
| Até o dia útil 3 | Comunicação à ANPD (3.4) e aos titulares (3.5), se houve risco ou dano relevante | 3 |
| Até o dia útil 10 | Teste de regressão da regra, revisão das demais regras e lições aprendidas | 4 |

**Tempo até a contenção (estimado):** 1 h 30 min, da ciência (09h00) até a correção em produção (10h30), em horário
comercial e com a equipe técnica disponível. Fora do horário, o tempo depende de haver alguém da equipe técnica com
acesso de administrador à produção.

**Lacunas achadas e o que mudou:**

1. A equipe técnica não tinha nome nem contato (3.2). A equipe técnica será definida quando o piloto estiver
   pronto. Até lá, o Responsável aciona o time do backend diretamente.
2. A Fase 1 só falava de chaves do banco; credenciais de fora do banco ficaram de fora. Incluídas na Fase 1.
3. Não havia registro de incidentes. Incluído (3.6), com guarda de cinco anos.
4. A Fase 3 não dizia se o Frila usa o prazo em dobro de pequeno porte. Anotado: não usa.
5. Faltava pedir relato ao operador quando o incidente pode estar do lado dele. Incluído na Fase 1.
6. O documento citava a URL antiga da política (`frila.app`). Corrigida para `frila.netlify.app`.

### 3.8 Aprovação do Plano

Revisado e aprovado em 31/10/2026 pelo Jurídico do time (agente de IA, skill leis-do-brasil), por determinação e
mandato do sócio-administrador Cauê Carneiro Crillanovick. Alinhado à Lei Geral de Proteção de Dados Pessoais
(Lei nº 13.709/2018), à Resolução CD/ANPD nº 15/2024 e à Resolução CD/ANPD nº 2/2022. Esta aprovação não
constitui parecer de advogado inscrito na OAB.

---

## 4. Coerência com a Política de Privacidade

Checklist de coerência entre este registro e a política publicada em `https://frila.netlify.app/privacidade`:

| Item | ROPA (este documento) | Política de Privacidade |
|---|---|---|
| Dados coletados | Itens 1-13 da Seção 1.2 | **Conforme:** alinhado à Seção 2 da política |
| Finalidades | Coluna "Finalidade" da Seção 1.2 | **Conforme:** finalidades operacionais de contratação |
| Base legal | Coluna "Base Legal" da Seção 1.2 | **Conforme:** Art. 7º, II, V e IX |
| Compartilhamento | Seção 1.3 (Supabase, Firebase, Apple, Gmail/Resend) | **Conforme:** operadores e infraestrutura declarados |
| Transferência internacional | Seção 1.4 | **Conforme:** processamento em nuvem com cláusulas contratuais |
| Direitos do titular | Seção 2.2 | **Conforme:** Arts. 17 a 22 da LGPD |
| Canal do titular | `suporte@frilabr.com` | **Conforme:** D2 unifica canal no domínio oficial |
| Retenção e eliminação | Coluna "Retenção e Eliminação" | **Conforme:** prazos e regras de anonimização |

---

## 5. Pontos de Risco Real ("Precisa de Advogado")

1. **Vínculo Empregatício (CLT arts. 2º e 3º):** *Precisa de advogado para avaliar se a exibição da taxa de comparecimento e registro de faltas objetivas na plataforma não geram risco de caracterização de subordinação jurídica estrutural.*
2. **Aferição de Maioridade no ECA Digital (Lei nº 15.211/2025):** *Precisa de advogado para analisar a suficiência da combinação de data de nascimento no cadastro com a classificação 18+ da App Store perante a futura regulamentação da ANPD (Art. 9º, § 1º, que veda autodeclaração).*
3. **Dispensa Formal de DPO perante a ANPD:** *Precisa de advogado para ratificar a dispensa de encarregado pelo enquadramento de agente de pequeno porte (Resolução CD/ANPD nº 2/2022, Art. 11).*

---

## Histórico

| Data | Autor | Alteração |
|---|---|---|
| 2026-10-12 | Bucky (ajudante) | Versão inicial: ROPA, canal do titular e plano de incidentes |
| 2026-10-15 | Nick Fury | Responsável pessoa física (sem CNPJ nem DPO); telefone em 7 dias (RN10); documento do estabelecimento; telemetria `evento_app`; Gmail como operador; incidente em 3 dias úteis (Res. CD/ANPD 15/2024) |
| 2026-10-16 | Nick Fury | Plano de incidente: simulação de mesa (3.7), registro de incidentes por 5 anos (3.6), credenciais fora do banco na Fase 1, prazo de pequeno porte anotado, URL da política corrigida; aprovação por delegação do Responsável (3.8) |
