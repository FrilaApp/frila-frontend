# Diário de configuração e dívidas de escala

Caderno das decisões e ajustes feitos **fora do código** (painéis de Supabase, Google, Netlify, App Store Connect) que são **suficientes para o piloto, mas vão precisar ser revistos quando o Frila crescer**. Serve para voltar a cada ponto na hora certa, sem depender da memória de uma conversa.

Regras: sem senha, token, código, telefone pessoal ou chave (só o nome do campo e o valor público). Dependências e estado geral continuam em `ExternalSetup.md`.

## 1. Para revisitar quando crescer

Cada linha tem o **gatilho**: o sinal de que chegou a hora de voltar ao assunto.

| # | Assunto | Hoje (piloto) | Gatilho para voltar | O que fazer |
|---|---|---|---|---|
| 1 | **E-mail de entrada (código)** | Auth do Supabase `frila-dev` envia por SMTP do Gmail (`frilaverificacao@gmail.com`), limite do Supabase em 30/h (era 2/h). Gmail pessoal tem teto próprio por dia (na casa de 500; conferir). Prova de 16/10: cai no spam do Outlook (sem domínio próprio); aceito pelo Cauê. | Mais de algumas dezenas de cadastros por dia, qualquer reclamação de "código não chegou", ou abertura do `frila-prod`. | Trocar para provedor de e-mail transacional, com domínio próprio e SPF/DKIM; repetir o ajuste de limite no `frila-prod`; medir entrega. |
| 2 | **Responsável e conta Apple** | Pessoa física (Cauê Carneiro Kilanovic); a conta de desenvolvedor é pessoal e o nome aparece na App Store. Sem razão social, CNPJ, sede nem encarregado (DPO). | Primeira receita, investidor, mais de uma pessoa assinando pelo produto, ou exigência jurídica/ANPD. | Abrir CNPJ, transferir o app para conta de organização, nomear encarregado, trocar nome do vendedor, copyright, política de privacidade e termos. |
| 3 | **Prazo de moderação e resposta ao titular** | Texto público: "o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos". Promessa de 24 h retirada. | Equipe de suporte/moderação, ou volume de denúncias que torne 24 h viável. | Voltar a prazo fixo menor; alinhar o backend (`ModelosDeEmail.md` já está alinhado, sem 24 h; o cálculo de `prazo_resposta` no backend ainda precisa ser alinhado). |
| 4 | **Domínio e e-mail de suporte** | Site em `frila.netlify.app`, sem domínio próprio; suporte em `suporte@frilabr.com`. A URL `frila.app` foi rejeitada. | Lançamento público, ou necessidade de e-mail com a marca. | Registrar domínio, apontar o Netlify, e-mail do domínio; atualizar `EnderecosOficiais` no app, ficha da App Store e páginas. |
| 5 | **Ambientes do Supabase** | Só o `frila-dev` é servidor de verdade (sem ambiente local, por decisão). `frila-prod` criado, banco ainda vazio. Plano gratuito pausa projeto parado por uma semana. | Primeiro usuário real, ou projeto pausado por inatividade. | Plano pago no `frila-prod`, migrações e Auth de produção (cartões #76 e #207), ambiente de teste separado do `dev`. |
| 6 | **Segredos** | Senhas e chaves em cofre KeePassXC no Drive e em arquivos locais da máquina de quem opera; senha de app do Gmail em arquivo local. | Mais de uma pessoa operando produção, qualquer vazamento, ou abertura do `frila-prod`. A senha de app do Gmail não foi rotacionada por decisão de 15/10. | Gestor de segredos da equipe, rotação periódica, ninguém com cópia em texto puro. |
| 7 | **Firebase de produção** | Conferido em 15/10 (capturas do Thor): o projeto `frila-prod` existe; app iOS `com.frila.org.app` registrado; chaves de APNs de desenvolvimento e de produção cadastradas. Crashlytics do `frila-prod` ainda sem SDK (tela de introdução). | Antes do primeiro build de produção ou do primeiro push em produção. | Ativar o Crashlytics no `frila-prod` com o primeiro build, e testar um push real de ponta a ponta. |
| 8 | **Contas Google de operação** | `frilaverificacao@gmail.com` envia o código; `frila.org@gmail.com` (Netlify, Firebase) com verificação em duas etapas **ativada** em 15/10. | Antes de abrir para o público. | Passar a conta de envio para o provedor da linha 1 e revisar quem tem acesso às duas contas. |
| 9 | **Conta de demonstração da revisão** | Contas `revisao-contratante` e `revisao-profissional` no `frila-dev` com dados renovados; segredos `DEMONSTRACAO_CODIGO` e `DEMONSTRACAO_EMAILS` criados no `frila-dev` em 15/10 e a função `entrar-demonstracao` validada (código certo entra, errado é recusado). | Antes da submissão (prevista para 06/11) e antes de abrir o `frila-prod`. | Trocar o código se ele tiver passado por chat; repetir os segredos no `frila-prod`; digitar o código só na ficha da App Store Connect. |
| 10 | **Verificação de idade (ECA Digital)** | App só para maiores de 18: data de nascimento no cadastro (menor é bloqueado) somada à classificação 18+ da App Store. Sem verificação própria (documento, biometria). A leitura jurídica é interna; não é parecer de advogado inscrito na OAB. | **01/12/2026**: reler a página da ANPD, o guia de aferição de idade e os regulamentos de novembro. Decidir **antes de 01/01/2027**, quando a fiscalização se intensifica. Também: antes de lançar Android ou web (v1.2), e a qualquer denúncia, notificação da ANPD ou mudança na regra da Apple. | Decidir se o sinal da loja basta; se não, adotar aferição própria (a opção pública do gov.br, art. 28 do Decreto, é a mais barata). Web exige aferição própria. Reduzir o risco com uma hora de consulta a advogado de proteção de dados. Só então registrar em RN20, T-0019 e cartão #78. |

## 2. Registro de mudanças

Entrada nova no topo: onde, antes → depois, por quê, prova, atenção.

### 2026-10-16 — Supabase `frila-dev`: prova de entrega do código de entrada (liga com as linhas 1 e 8)

- **Prova:** código disparado no `frila-dev` para três provedores de e-mail de teste (Gmail, iCloud e Outlook); o servidor respondeu 200 nos três.
- **Resultado:** Gmail e iCloud na caixa de entrada, em cerca de 1 s; **Outlook caiu no spam**. No cabeçalho do Gmail, SPF, DKIM e DMARC deram PASS. O remetente aparece como "Frila".
- **Leitura:** o limite é esperado de remetente Gmail pessoal sem domínio próprio: o Outlook desconfia, e não há como corrigir sem domínio com SPF/DKIM próprios. Não bloqueia o piloto.
- **Decisão do Cauê (16/10):** aceitar assim até ter domínio próprio. A correção definitiva é a da linha 1 (provedor transacional com domínio próprio) e fica para quando a empresa crescer. Enquanto isso, quem usar Outlook deve olhar o spam.
- **Feito (16/10):** o rodapé "Dúvidas" dos modelos "Magic link or OTP" e "Confirm sign up" (Authentication, Email Templates, `frila-dev`) agora aponta para o suporte oficial, `suporte@frilabr.com` (linha 4). Nenhum outro modelo tinha o rodapé. Repetir no `frila-prod` quando ele for aberto.
- **Atenção:** nenhum endereço de pessoa nem código entra neste registro.

### 2026-10-15 — Verificação de idade: leitura do ECA Digital (liga com as linhas 2 e 10)

- **Estado conferido:** o Frila provavelmente está fora do alcance de acesso da lei, mas o tratamento seguro é 18+ obrigatório. Data de nascimento sozinha não basta (é autodeclaração); a combinação data de nascimento, sinal de idade da Apple (Declared Age Range) e bloqueio 18+ da loja é o desenho mais defensável para um app só de iOS, e não é porto seguro.
- **Decisão:** para 06/11 não exigir documento nem biometria; sinal ausente segue, com registro interno de que a loja já bloqueia 18+ não confirmado. Menor bloqueado tem caminho para contestar pelo e-mail de suporte.
- **Pendente (baixa prioridade):** backend corrigir o fuso do `current_date` em `criar_conta` (servidor conta em UTC, 3 h à frente de Brasília; cartão #265, Sprint 2); uma frase na política de privacidade e no LGPD.md sobre finalidade e retenção do e-mail de menor bloqueado.
- **Prova:** comentário no cartão #215 do Trello com o resumo e as fontes (lei, Decreto, página da ANPD).
- **Atenção:** a lei tem 13 meses e o Decreto é de 2026; não há jurisprudência. O ponto que um advogado conservador criticaria primeiro é "sinal ausente, seguir".

### 2026-10-15 — Supabase `frila-dev`: limite de e-mails de Auth (liga com a linha 1)

- **Onde:** Supabase `frila-dev` (`jcobftbhbqdikratzizz`), Authentication, Rate limits.
- **Antes → depois:** `Rate limit for sending emails` de **2 por hora** para **30 por hora**. Nada mais foi alterado.
- **Por quê:** com SMTP próprio ligado, o painel mostrava 2 e-mails por hora. O login por código dependeria desse envio, então a partir do 3º usuário na mesma hora o código não sairia.
- **Prova:** capturas de tela antes e depois, feitas pelo agente Steve Rogers no portal do Supabase.
- **Atenção:** 30 por hora dá 720 por dia no papel, mas o teto de verdade é o do Gmail.

### 2026-10-15 — Supabase `frila-dev`: SMTP e código de entrada

- **Estado conferido:** SMTP próprio ativado; remetente `frilaverificacao@gmail.com`; servidor `smtp.gmail.com`, porta 465; validade do código de 900 s (15 minutos); confirmação de e-mail ligada.
- **Decisão:** a conta de envio continua `frilaverificacao@gmail.com`. A `frila.org@gmail.com` está sem verificação em duas etapas, então não gera senha de app.
- **Divergência resolvida:** alguns textos diziam "10 minutos"; o valor real é 15.
- **Decisão do Cauê (15/10):** a senha de app atual **fica**; não será rotacionada agora. Ela apareceu uma vez em log de sessão local em 15/10 e foi apagada do registro; não saiu da máquina. O gatilho de rotação está na linha 6 da tabela.
- **Regra:** nenhum agente imprime o conteúdo de `~/.config/frila/*`; para conferir formato, só tamanho e permissão.

### 2026-10-15 — App Store Connect: ficha do app (liga com as linhas 2 e 4)

- **Estado conferido:** nome `Frila: Turnos e Vagas`; classificação 18+ no Brasil e 17+ no mundo; URL de privacidade `https://frila.netlify.app/privacidade`.
- **Decisão:** categoria primária **Negócios**, secundária **Produtividade** (a Apple lista "job search resources" em Negócios; não existe categoria de empregos). Copyright em nome da pessoa física responsável.
- **Pendente:** subtítulo, URLs de suporte e de marketing, contato de revisão, conta de demonstração e notas de revisão. Nada de Publicar nem Enviar para revisão sem o Cauê.

### 2026-10-15 — Netlify: páginas públicas (liga com a linha 4)

- **Onde:** time Frila, site `frila` (`frila.netlify.app`), sem domínio próprio.
- **Antes → depois:** páginas `/privacidade`, `/termos` e `/suporte` republicadas a partir de `iOS/Docs/PaginaPublica/*.md` da `main` (após o PR #309): responsável pessoa física (Cauê Carneiro Kilanovic), Brasília/DF, prazo "o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos".
- **Como:** `netlify deploy --prod` de uma pasta gerada dos três `.md` (o site não tem repositório ligado; é publicação manual pela CLI). Deploy `6ad12d5bce108cd346eb80e1`, 15/10.
- **Prova:** conferido no ar com `curl`: nome do responsável e Brasília/DF presentes; sem "a confirmar". O único "24 horas" que sobra é o prazo de expiração dos contatos de turno (outro assunto).
- **Atenção:** toda mudança nos `.md` exige novo deploy manual. Quando houver domínio próprio (linha 4), ligar o site ao repositório.
