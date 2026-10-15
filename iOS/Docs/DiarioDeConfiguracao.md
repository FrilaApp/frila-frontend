# Diário de configuração

Caderno das mudanças feitas **fora do código** (painéis de Supabase, Google, Netlify, App Store Connect). Cada linha diz o que mudou, por quê, quem fez e o que reconferir. Fica aqui para ninguém depender da memória de uma conversa.

Regras: uma entrada nova no topo, sem senha, token, código, telefone pessoal ou chave (só o nome do campo e o valor público). Dependências e estado geral continuam em `ExternalSetup.md`.

| Campo | O que registrar |
|---|---|
| Quando / onde | data e painel (projeto, conta) |
| Antes → depois | valor antigo e valor novo |
| Por quê | o problema que motivou |
| Prova | captura de tela, log ou quem conferiu |
| Atenção | custo, limite, o que reverter ou repetir em produção |

---

## 2026-10-15 — Supabase `frila-dev`: limite de e-mails de Auth

- **Onde:** Supabase `frila-dev` (`jcobftbhbqdikratzizz`), Authentication, Rate limits.
- **Antes → depois:** `Rate limit for sending emails` de **2 por hora** para **30 por hora**. Nada mais foi alterado (SMTP, modelos e outros projetos ficaram como estavam).
- **Por quê:** com SMTP próprio ligado, o painel mostrava 2 e-mails por hora. O login por código dependeria desse envio, então a partir do 3º usuário na mesma hora o código não sairia.
- **Prova:** capturas de tela antes e depois, feitas pelo agente Steve Rogers no portal do Supabase.
- **Atenção:**
  - O Gmail pessoal tem teto próprio de envios por dia (na casa de 500, valor público do Google; reconferir). 30 por hora dá 720 por dia no papel, então o teto de verdade é o do Gmail, não o do Supabase.
  - Ao configurar o `frila-prod`, repetir este ajuste e reavaliar o provedor de envio antes de abrir para o público.
  - Se o piloto passar de algumas dezenas de cadastros por dia, trocar o Gmail por um provedor de e-mail transacional.

## 2026-10-15 — Supabase `frila-dev`: SMTP e código de entrada

- **Estado conferido:** SMTP próprio ativado; remetente `frilaverificacao@gmail.com`; servidor `smtp.gmail.com`, porta 465; validade do código de 900 s (15 minutos); confirmação de e-mail ligada.
- **Decisão:** a conta de envio **continua** `frilaverificacao@gmail.com`. A conta `frila.org@gmail.com` está sem verificação em duas etapas, então não gera senha de app; trocar exigiria ligar a verificação e refazer a senha.
- **Divergência resolvida:** os textos diziam "10 minutos" em alguns lugares. O valor real é 15 minutos.
- **Pendente:** gerar uma senha de app nova para `frilaverificacao@gmail.com` e atualizar no Supabase e no arquivo local de segredos (a anterior apareceu em um log de sessão em 15/10; não saiu da máquina).

## 2026-10-15 — App Store Connect: ficha do app

- **Estado conferido:** nome `Frila: Turnos e Vagas`; classificação 18+ no Brasil e 17+ no mundo; URL de privacidade `https://frila.netlify.app/privacidade`.
- **Decisão:** categoria primária **Negócios**, secundária **Produtividade** (a Apple lista "job search resources" em Negócios; não existe categoria de empregos). Copyright em nome da pessoa física responsável.
- **Pendente:** subtítulo, URLs de suporte e de marketing, dados do contato de revisão, conta de demonstração e notas de revisão. Nada de Publicar nem Enviar para revisão sem o Cauê.

## 2026-10-15 — Netlify: páginas públicas

- **Onde:** time Frila, site `frila` (`frila.netlify.app`), sem domínio próprio.
- **Estado:** último deploy em 15/10/2026, sem erro.
- **Pendente:** republicar depois da mescla do PR #309 (pessoa física responsável, Brasília/DF, prazos "o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos").
