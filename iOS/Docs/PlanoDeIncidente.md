Revisado e aprovado pelo Jurídico do time (agente de IA, skill leis-do-brasil) em 31/10/2026. Não é parecer de advogado.

# Plano de Resposta a Incidentes de Segurança com Dados Pessoais — Frila

Documento operacional de diretrizes e fluxo de resposta a incidentes de segurança da informação envolvendo dados pessoais tratados na plataforma Frila, elaborado em conformidade com o Artigo 48 da Lei Geral de Proteção de Dados Pessoais (LGPD — Lei nº 13.709/2018), a Resolução CD/ANPD nº 15/2024 e o Registro das Operações de Tratamento (`RegistroDeTratamentoLGPD.md`).

> [!IMPORTANT]
> **AVISO DE CONFORMIDADE E APROVAÇÃO:** Este plano constitui o protocolo oficial de resposta a incidentes de segurança da plataforma Frila. Revisado e aprovado pelo Jurídico do time em 31/10/2026, com fundamento na LGPD e na Resolução CD/ANPD nº 15/2024, por determinação e mandato do sócio-administrador Cauê Carneiro Crillanovick. Não substitui parecer formal de advogado inscrito na OAB.

---

## 1. Definição de Incidente de Segurança

Para os fins deste plano, considera-se incidente de segurança qualquer evento confirmado ou sob suspeita fundada que resulte em acesso não autorizado, destruição, perda, alteração, comunicação indevida ou qualquer forma de tratamento inadequado ou ilícito de dados pessoais custodiados pelo Frila (LGPD art. 48).

Exemplos de incidentes operacionais:
- Exposição indevida de credenciais de acesso ou chaves criptográficas da infraestrutura;
- Falha de configuração em políticas de segurança de banco de dados (RLS — *Row Level Security*), permitindo acesso cruzado entre contas;
- Comprometimento de credenciais administrativas ou de serviços terceirizados (Supabase, Firebase, Google, Apple, Netlify);
- Vazamento de banco de dados ou logs contendo identificadores de usuários;
- Acesso indevido ou interceptação de comunicações contendo dados de titulares.

---

## 2. Equipe de Resposta e Atribuições por Função

A equipe de resposta atua de forma colegiada, estruturada estritamente por funções e papéis operacionais, sem personalização por nomes ou e-mails individuais:

| Papel / Função | Atribuições Principais no Incidente | Canal de Acionamento |
|---|---|---|
| **Controlador / Responsável Legal pelas Decisões** | `FRILA TECNOLOGIA INOVA SIMPLES (I.S.)` (CNPJ `69.728.564/0001-41`), representada pelos administradores Cauê Carneiro Crillanovick e Fabrício Tosta.<br>- Declara formalmente a abertura e encerramento do incidente.<br>- Aprova medidas drásticas ou de impacto negocial para contenção.<br>- Decide sobre a necessidade de comunicação à ANPD e aos titulares.<br>- Aprova as minutas de comunicação externa e relatórios finais. | Comunicação interna direta |
| **Liderança Técnica de Infraestrutura e Engenharia** | - Coordena as ações técnicas imediatas de contenção e isolamento (0-4 h).<br>- Revoga e rotaciona credenciais, chaves e tokens de acesso (Supabase, FCM, APNs, SMTP Resend/Gmail, GitHub Actions).<br>- Preserva logs e evidências forenses antes de modificações.<br>- Conduz a análise de causa raiz e elabora a correção técnica definitiva. | Monitoramento e canal técnico interno |
| **Responsável por Atendimento e Comunicação** | - Centraliza o recebimento de relatos e dúvidas de titulares.<br>- Opera o canal oficial de contato (`suporte@frilabr.com`).<br>- Conduz os envios de notificações individuais aos titulares sob orientação do Controlador.<br>- Registra o protocolo de cada interação com os titulares afetados. | `suporte@frilabr.com` |

---

## 3. Fluxo Operacional de Resposta a Incidentes

```
+--------------------------------------------------------------------------+
| Fase 1: Detecção e Contenção Imediata (0 a 4 horas)                      |
| Identificação do vetor -> Isolamento -> Revogação -> Preservação de logs|
+--------------------------------------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------+
| Fase 2: Avaliação de Risco e Gravidade (Meta interna: até 1 dia útil)     |
| Cruzamento com ROPA -> Volume e categorias -> Classificação do impacto   |
+--------------------------------------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------+
| Fase 3: Comunicação Externa (Até 3 dias úteis da ciência — Art. 48)      |
| Notificação à ANPD -> Notificação individual aos titulares afetados      |
+--------------------------------------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------+
| Fase 4: Remediação, Registro e Lições Aprendidas (Até 10 dias úteis)     |
| Correção definitiva -> Registro de 5 anos -> Atualização preventiva      |
+--------------------------------------------------------------------------+
```

### 3.1 Fase 1 — Detecção e Contenção Imediata (0 a 4 horas)

1. **Gatilhos de Detecção:**
   - Disparo de alertas automáticos do monitoramento de infraestrutura (`ModelosDeEmail.md:360-462`);
   - Comunicação recebida de titular, pesquisador de segurança ou terceiro pelo canal `suporte@frilabr.com`;
   - Alerta ou notificação de segurança emitido por operador/subprocessador (Supabase, Firebase, Google, Apple, Netlify);
   - Identificação de anomalia ou relato em chamados de suporte/ocorrências (`public.ocorrencia`).

2. **Abertura do Registro:**
   - Anotar de imediato o instante exato (data e hora no horário oficial de Brasília) da tomada de ciência do incidente. Este marco temporal inaugura a contagem de prazos regulatórios.

3. **Contenção e Isolamento Técnico:**
   - Isolar imediatamente o componente, rota de API ou Edge Function afetada;
   - Proceder à revogação e rotação imediata de credenciais de banco (chaves anon/service_role, senhas de banco) e de todas as credenciais externas associadas (sessões Supabase, senha de aplicativo Gmail para disparo de OTP, chaves APNs da Apple, tokens do FCM Google e segredos do GitHub Actions);
   - A geração e armazenamento de novos segredos devem ser realizados exclusivamente em ambiente de cofre seguro, vedada a inserção em código, chat ou canais inseguros.

4. **Preservação Rigorosa de Evidências:**
   - Congelar e exportar logs operacionais (Supabase Auth/Postgres, Firebase Crashlytics, logs de tráfego de borda) antes de qualquer reinicialização, migração ou purga;
   - Assegurar a cadeia de custódia das evidências técnicas para eventual auditoria forense.

5. **Interlocução com Operadores:**
   - Caso o incidente envolva serviço de terceiro (subprocessador), notificá-lo formalmente pelos canais corporativos e requisitar cópia de logs e relatório preliminar de impacto.

---

### 3.2 Fase 2 — Avaliação de Risco e Gravidade (Meta interna: até 1 dia útil)

1. **Cruzamento com o Registro de Operações (ROPA):**
   - Mapear os dados expostos contra o `RegistroDeTratamentoLGPD.md` para determinar as categorias de titulares afetados (profissionais, contratantes ou ambos) e os atributos violados.

2. **Dimensionamento do Incidente:**
   - Levantar a quantidade estimada de contas envolvidas e o número exato ou aproximado de titulares afetados;
   - Verificar se houve exposição de dados de identificação civil (CPF, RG), dados de localização ou conteúdos de comunicações privadas.

3. **Matriz de Gravidade do Incidente:**
   - **Gravidade Baixa:** Não envolveu dados pessoais, ou os dados expostos possuíam nível de agregação/anonimização suficiente para impedir a reidentificação, sem risco aos direitos dos titulares;
   - **Gravidade Média:** Envolveu dados cadastrais básicos de titulares em volume restrito, sem dados financeiros, senhas ou histórico sensível, com potencial limitado de dano;
   - **Gravidade Alta:** Envolveu documentos de identificação (CPF de contratante pessoa física), coordenadas precisas, histórico de comunicações/ocorrências, credenciais com capacidade de personificação ou volume superior a 1.000 titulares.

---

### 3.3 Fase 3 — Comunicação à ANPD e aos Titulares (Art. 48 da LGPD)

1. **Critério Legal de Obrigatoriedade (LGPD art. 48):**
   - A comunicação é obrigatória sempre que o incidente de segurança for suscetível de acarretar risco ou dano relevante aos direitos e liberdades fundamentais dos titulares de dados.

2. **Prazos Regulatórios e Avaliação Jurídica:**
   - Adota-se o prazo estrito de **3 (três) dias úteis**, contados a partir da ciência do incidente, fixado no Art. 5º da Resolução CD/ANPD nº 15/2024;
   - Embora o Frila se qualifique como agente de tratamento de pequeno porte (Inova Simples, Resolução CD/ANPD nº 2/2022) e pudesse usufruir de prazo em dobro (Art. 14 da Resolução 2/2022), a plataforma opta pela transparência e pelo prazo padrão de 3 dias úteis;
   - Na indisponibilidade temporária de todas as conclusões técnicas no encerramento do prazo, realiza-se a comunicação preliminar com os dados consolidados, complementando-se formalmente as informações adicionais tão logo apuradas.
   - > [!CAUTION]
   - > **PONTO DE ATENÇÃO ("PRECISA DE ADVOGADO"):** A definição jurídica sobre se um incidente concreto enseja "risco ou dano relevante" aos direitos e liberdades dos titulares (Art. 48 da LGPD e Art. 4º da Resolução CD/ANPD nº 15/2024), apto a dispensar ou justificar a notificação ampla, precisa de parecer de advogado em caso de dúvida fática.

3. **Comunicação à Autoridade Nacional de Proteção de Dados (ANPD):**
   - Transmitida via formulário eletrônico oficial disponibilizado pelo portal da ANPD (`https://www.gov.br/anpd/`), observando os campos estruturados do **Anexo I**.

4. **Comunicação Individual aos Titulares Afetados:**
   - Enviada diretamente ao endereço de e-mail cadastrado de cada titular afetado, com redação direta, transparente e em português claro, nos moldes do **Anexo II**;
   - Caso a comunicação individual seja comprovadamente inviável devido ao volume ou impossibilidade de identificação pontual, o Controlador avaliará com o jurídico a realização de aviso público oficial.

---

### 3.4 Fase 4 — Remediação, Registro e Lições Aprendidas (Até 10 dias úteis)

1. **Correção Definitiva e Testes:**
   - Aplicação de patches de software, correção de regras de RLS no banco ou reconfiguração de permissões de infraestrutura;
   - Execução de testes de regressão técnica e validação automatizada de segurança.

2. **Livro/Registro de Incidentes de Segurança:**
   - Conforme exigido pela Resolução CD/ANPD nº 15/2024, **todos** os incidentes de segurança devem ser lançados no Registro de Incidentes interno, mesmo aqueles que não ensejarem notificação à ANPD ou aos titulares;
   - O registro deve documentar:
     a) Data e hora da ciência e da contenção;
     b) Descrição fática da ocorrência;
     c) Categorias de dados e volume aproximado de titulares atingidos;
     d) Gravidade atribuída e justificativa fundamentada sobre a necessidade ou dispensa de comunicação externa;
     e) Medidas corretivas implementadas;
   - **Prazo de guarda do registro:** Manter arquivado pelo prazo mínimo de **5 (cinco)** anos a contar da data de encerramento do registro, em conformidade expressa com a Resolução CD/ANPD nº 15/2024;
   - O arquivo do registro deve ser armazenado em repositório seguro e de acesso restrito à Liderança Técnica e ao Controlador, sem incluir cópias de dados pessoais violados.

3. **Revisão Preventiva de Processos:**
   - Reunião de pós-incidente para identificação de falhas em processos, revisão deste plano e atualização preventiva dos controles de privacidade e proteção de dados.

---

## 4. Anexos: Modelos de Comunicação Padronizados

Os modelos abaixo utilizam campos delimitados por colchetes `[...]`, a serem preenchidos na ocorrência concreta de um evento:

### Anexo I: Modelo de Notificação de Incidente à ANPD

```text
COMUNICAÇÃO DE INCIDENTE DE SEGURANÇA COM DADOS PESSOAIS
(Artigo 48 da Lei Federal nº 13.709/2018 — LGPD e Resolução CD/ANPD nº 15/2024)

1. INFORMAÇÕES DO CONTROLADOR
- Denominação/Identificação: FRILA TECNOLOGIA INOVA SIMPLES (I.S.) — CNPJ 69.728.564/0001-41
- Administradores: Cauê Carneiro Crillanovick e Fabrício Tosta
- Canal Oficial de Privacidade e Suporte: suporte@frilabr.com
- Papel do Declarante: Controlador / Responsável Legal pelas Decisões

2. CRONOLOGIA DO INCIDENTE
- Data e hora estimada do início do incidente: [DD/MM/AAAA às HH:mm]
- Data e hora da tomada de ciência formal: [DD/MM/AAAA às HH:mm]
- Data e hora da contenção das vulnerabilidades: [DD/MM/AAAA às HH:mm]
- Duração estimada do incidente até a contenção: [X horas / X dias]

3. DESCRIÇÃO FÁTICA E NATUREZA DO EVENTO
- Natureza da violação: [Acesso não autorizado / Vazamento / Destruição / Alteração / Perda / Outro]
- Componente de infraestrutura envolvido: [Banco Postgres / Auth / Edge Function / Serviço Operador Terceiro]
- Resumo descritivo: [Breve relato fático e objetivo de como o incidente ocorreu e o vetor explorado]

4. CATEGORIAS DE DADOS E TITULARES AFETADOS
- Referência no Registro de Tratamento: [Itens correspondentes de RegistroDeTratamentoLGPD.md, ex.: itens 1, 2, 3]
- Dados pessoais específicos violados: [Listar, ex.: nome, e-mail, telefone, dados cadastrais]
- Dados sensíveis ou de menores envolvidos: [Não / Sim - especificar se houver]
- Número estimado de titulares afetados: [X titulares]
- Categorias de titulares atingidos: [Profissionais autônomos / Contratantes / Ambos]

5. ANÁLISE DE RISCO E POSSÍVEIS DANOS
- Riscos potenciais aos direitos e liberdades dos titulares: [Descrição de possíveis impactos, ex.: spam direcionado, phishing, perda de privacidade de contato]
- Nível de severidade atribuído: [Baixa / Média / Alta]

6. MEDIDAS TÉCNICAS E DE CONTENÇÃO ADOTADAS
- Medidas imediatas de isolamento implementadas: [Revogação de credenciais, desativação de endpoint, bloqueio de rota]
- Preservação de registros: [Exportação de logs do Supabase/Firebase em cofre seguro]
- Ações para mitigar ou reverter eventuais efeitos: [Ajuste de RLS, redefinição de tokens, auditoria de integridade]

7. COMUNICAÇÃO AOS TITULARES
- Houve comunicação direta aos titulares afetados? [Sim, em DD/MM/AAAA / Em andamento / Não - justificar fundamentação de dispensa se ausente risco relevante]
- Canal utilizado para notificação: [Mensagem individual por e-mail via suporte@frilabr.com]

8. DECLARAÇÃO E RESPONSABILIDADE
- Local e Data: Brasília/DF, [DD/MM/AAAA]
- Identificação da Função: [Controlador / Responsável Legal pelas Decisões]
```

---

### Anexo II: Modelo de Notificação Individual aos Titulares de Dados

```text
Assunto: Comunicado importante de segurança da sua conta no Frila

Prezado(a) [Nome do Titular],

Entramos em contato para informar com transparência sobre um incidente de segurança ocorrido em nossos sistemas e as providências adotadas para proteger suas informações.

O que aconteceu:
No dia [DD/MM/AAAA], às [HH:mm], identificamos [descrição clara e acessível da falha, ex.: um acesso não autorizado a um módulo interno do sistema], o que pode ter exposto temporariamente algumas informações da sua conta.

Quais informações podem ter sido atingidas:
Com base em nossa apuração técnica, o evento pode ter afetado os seguintes dados vinculados ao seu cadastro:
- [Listar itens afetados, ex.: Nome completo cadastrado]
- [Listar itens afetados, ex.: Endereço de e-mail]
- [Listar itens afetados, ex.: Número de telefone operacional]

[Ressalva de segurança, se aplicável: Confirmamos que senhas ou códigos de segurança não foram expostos, e dados financeiros ou bancários nunca são tratados pelo Frila.]

O que já fizemos para proteger você:
Assim que o problema foi detectado, nossa equipe técnica agiu de forma imediata:
1. O acesso ao componente envolvido foi bloqueado e as credenciais do sistema foram integralmente redefinidas em [X horas] da identificação;
2. As falhas foram corrigidas e novas travas de segurança foram implementadas;
3. O evento foi formalmente notificado à Autoridade Nacional de Proteção de Dados (ANPD), nos termos da lei.

O que recomendamos que você faça:
- Mantenha atenção redobrada a mensagens suspeitas, e-mails ou contatos de terceiros que solicitem códigos, senhas ou transferências de valores em nome do Frila. O Frila nunca solicita códigos temporários ou senhas por canais externos.
- Caso utilize o mesmo e-mail em outros serviços, recomendamos conferir as opções de segurança das suas contas.

Estamos à disposição para ajudar:
Sua segurança e a integridade dos seus dados são prioridades absolutas para o Frila. Caso tenha qualquer dúvida ou necessite de esclarecimentos adicionais sobre este comunicado, entre em contato direto pelo nosso canal oficial de privacidade:

- E-mail: suporte@frilabr.com
- Informações sobre nossa política de privacidade: https://frila.netlify.app/privacidade

Atenciosamente,

Equipe Frila
Canal Oficial de Privacidade
```
