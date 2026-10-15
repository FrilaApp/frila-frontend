# Diário de configuração e dívidas de escala

Caderno das decisões e ajustes feitos **fora do código** (painéis de Supabase, Google, Netlify, App Store Connect) que são **suficientes para o piloto, mas vão precisar ser revistos quando o Frila crescer**. Serve para voltar a cada ponto na hora certa, sem depender da memória de uma conversa.

Regras: sem senha, token, código, telefone pessoal ou chave (só o nome do campo e o valor público). Dependências e estado geral continuam em `ExternalSetup.md`.

## 1. Para revisitar quando crescer

Cada linha tem o **gatilho**: o sinal de que chegou a hora de voltar ao assunto.

| # | Assunto | Hoje (piloto) | Gatilho para voltar | O que fazer |
|---|---|---|---|---|
| 1 | **E-mail de entrada (código)** | Auth do Supabase `frila-dev` envia por SMTP do Gmail (`frilaverificacao@gmail.com`), limite do Supabase em 30/h (era 2/h). Gmail pessoal tem teto próprio por dia (na casa de 500; conferir). | Mais de algumas dezenas de cadastros por dia, qualquer reclamação de "código não chegou", ou abertura do `frila-prod`. | Trocar para provedor de e-mail transacional, com domínio próprio e SPF/DKIM; repetir o ajuste de limite no `frila-prod`; medir entrega. |
| 2 | **Responsável e conta Apple** | Pessoa física (Cauê Carneiro Kilanovic); a conta de desenvolvedor é pessoal e o nome aparece na App Store. Sem razão social, CNPJ, sede nem encarregado (DPO). | Primeira receita, investidor, mais de uma pessoa assinando pelo produto, ou exigência jurídica/ANPD. | Abrir CNPJ, transferir o app para conta de organização, nomear encarregado, trocar nome do vendedor, copyright, política de privacidade e termos. |
| 3 | **Prazo de moderação e resposta ao titular** | Texto público: "o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos". Promessa de 24 h retirada. | Equipe de suporte/moderação, ou volume de denúncias que torne 24 h viável. | Voltar a prazo fixo menor; alinhar backend e `ModelosDeEmail.md` (texto em HTML ainda cita 24 h; `prazo_resposta` ainda precisa ser alinhado). |
| 4 | **Domínio e e-mail de suporte** | Site em `frila.netlify.app`, sem domínio próprio; suporte em `suportefrila@gmail.com`. A URL `frila.app` foi rejeitada. | Lançamento público, ou necessidade de e-mail com a marca. | Registrar domínio, apontar o Netlify, e-mail do domínio; atualizar `EnderecosOficiais` no app, ficha da App Store e páginas. |
| 5 | **Ambientes do Supabase** | Só o `frila-dev` é servidor de verdade (sem ambiente local, por decisão). `frila-prod` criado, banco ainda vazio. Plano gratuito pausa projeto parado por uma semana. | Primeiro usuário real, ou projeto pausado por inatividade. | Plano pago no `frila-prod`, migrações e Auth de produção (cartões #76 e #207), ambiente de teste separado do `dev`. |
| 6 | **Segredos** | Senhas e chaves em cofre KeePassXC no Drive e em arquivos locais da máquina de quem opera; senha de app do Gmail em arquivo local. | Mais de uma pessoa operando produção, qualquer vazamento, ou abertura do `frila-prod`. A senha de app do Gmail não foi rotacionada por decisão de 15/10. | Gestor de segredos da equipe, rotação periódica, ninguém com cópia em texto puro. |
| 7 | **Firebase de produção** | O projeto `frila-prod` não aparece para a conta `frila.org@gmail.com`; app iOS lá não foi conferido por ferramenta. | Antes do primeiro envio de push em produção. | Conferir app, chave APNs e Crashlytics no `frila-prod`. |
| 8 | **Contas Google de operação** | `frilaverificacao@gmail.com` envia o código; `frila.org@gmail.com` (Netlify, Firebase) com verificação em duas etapas em ativação (telefone cadastrado, falta confirmar o botão final). | Antes de abrir para o público. | Confirmar a verificação em duas etapas e passar a conta de envio para o provedor da linha 1. |
| 9 | **Conta de demonstração da revisão** | Contas `revisao-contratante` e `revisao-profissional` existem no `frila-dev` com dados renovados; o segredo `DEMONSTRACAO_CODIGO` ainda **não** foi criado. | Antes de preencher a conta de demonstração e o contato de revisão na App Store Connect (submissão prevista para 06/11). | Definir o código fixo (nunca em arquivo versionado), criar o segredo no `frila-dev` e no `frila-prod`, e digitar o mesmo código na ficha. |

## 2. Registro de mudanças

Entrada nova no topo: onde, antes → depois, por quê, prova, atenção.

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
