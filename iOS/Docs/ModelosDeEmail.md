# Modelos de E-mail do Frila

Documento de especificação e catálogo de modelos de e-mails transacionais e operacionais do Frila, em versões HTML e texto simples.

- **Sprint:** S1 · Ciclo principal
- **Cartão Trello:** [oYSwLrIS](https://trello.com/c/oYSwLrIS)
- **Histórias e Requisitos:** RF01 (Entrada por código no e-mail), RF24 (Contestação de suspensão), RF25 (Privacidade e descarte de dados), RF26 (Denúncia e moderação), RN13 (Suspensão de conta), Diretriz 1.2 da App Store (Moderação tempestiva de conteúdo), RNF09 (Usabilidade para público não corporativo), RNF15 (Localização em português do Brasil).
- **Referência de Redação:** [Guia de Voz e Glossário](GuiaDeVoz.md) (PR #220).
- **Repositório:** `frila-frontend` (`iOS/Docs/ModelosDeEmail.md`).

---

## 1. Diretrizes de Design, Entregabilidade e Fontes Oficiais

Os e-mails transacionais do Frila são projetados para máxima entregabilidade, acessibilidade e clareza, evitando filtros de spam no Gmail e iCloud Mail.

### 1.1 Fontes Oficiais de Endereços, URLs e Prazos

O canal de suporte e as referências técnicas estão abaixo. As URLs públicas dependem de domínio aprovado pelo Cauê; os modelos usam variáveis, sem assumir um domínio disponível:

| Parâmetro / Variável | Valor / Formato | Fonte Verificada | Observação de Governança |
|---|---|---|---|
| `{{email_suporte}}` | `suportefrila@gmail.com` | `iOS/Sources/Apresentacao/EnderecosOficiais.swift:22`<br>`iOS/Docs/AjudaESuporte.md:19` | E-mail oficial padrão do produto injetado na camada de apresentação (`EnderecosOficiais.padrao.emailSuporte`). |
| `{{destinatario_time}}` | `[A DEFINIR]` | Cartão Trello `oYSwLrIS` | Destinatário da lista operacional técnica. Não definido em código; mantido como variável a configurar na infraestrutura. |
| `{{link_painel}}` | `[A DEFINIR]` | Cartão Trello `oYSwLrIS` | URL do painel de monitoramento do backend. Mantido como variável a configurar. |
| `{{url_termos}}` | `[A DEFINIR: URL pública dos termos]` | Decisão do Cauê de 15/10/2026 | Confirmar domínio aprovado antes do envio; não usar os endereços atuais do app sem revisão. |
| `{{url_privacidade}}` | `[A DEFINIR: URL pública de privacidade]` | Decisão do Cauê de 15/10/2026 | Confirmar domínio aprovado antes do envio. |
| `{{url_site}}` | `[A DEFINIR: URL pública do site]` | Decisão do Cauê de 15/10/2026 | Configurar a variável no backend somente após a aprovação do domínio. |
| Validade do código de entrada | *"O código vale por 15 minutos e só pode ser usado uma vez."* | Configuração do Auth do `frila-dev` (900 s), conferida em 15/10; e-mail real com o mesmo texto (capturas do Steve Rogers, 16/10); `iOS/Docs/DiarioDeConfiguracao.md` | O valor de 10 min do `config.toml` local (`otp_expiry = 600`) não vale para o servidor `frila-dev`. Decisão de 16/10 (Nick Fury, por delegação do Cauê): o e-mail informa o número real, 15 minutos, porque o cartão pede a validade e o texto já estava assim no ar. Se o tempo mudar no Auth, mudar aqui e no modelo do Supabase no mesmo dia. |
| Prazo de moderação, denúncias e atendimento | *o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos* | Decisão do Cauê (15/10/2026)<br>`iOS/Docs/AjudaESuporte.md` | Compromisso documental atualizado; textos do app, modelos do backend e cálculo de prazo ainda dependem de missão própria/cartão no Trello. |
| Prazo de resposta a contestações | *o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos* | Decisão do Cauê (15/10/2026) | O backend (`frila-backend/supabase/functions/enviar-email/modelos.ts`) ainda informa 5 dias úteis; alinhar pelo cartão do backend. |
| Telefones de emergência | 190 e 180 | Requisitos v1.5.0 (RF23, UC14)<br>`iOS/Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift` | Canais públicos de atendimento policial (190) e violência contra a mulher (180). |

### 1.2 Princípios de Construção Visual
1. **Sem dependências externas de imagem:** Não há carregamento de imagens remotas, rastreadores ou fontes externas via web. A identidade visual usa a marca em texto formatado (*wordmark* CSS). Isso impede bloqueio de exibição nos clientes de e-mail e garante carregamento instantâneo.
2. **Compatibilidade com modo escuro:** O leiaute utiliza cores neutras com estilos inline e regras CSS que preservam contraste legível tanto no modo claro quanto no modo escuro do Apple Mail e Gmail.
3. **Visibilidade do código na notificação:** O código de acesso de 6 dígitos é posicionado no início do assunto e no pré-cabeçalho, permitindo leitura direta na notificação do sistema ou na lista de mensagens sem necessidade de abrir o e-mail.
4. **Marcação uniforme de variáveis:** Todas as variáveis dinâmicas utilizam o formato padronizado `{{variavel}}` (duplas chaves sem espaços internos).
5. **Zero dados pessoais em trânsito (RN15, LGPD):** Nenhum e-mail transacional replica relatos de denúncia, nomes da outra parte envolvida, CPFs ou textos livres. O acompanhamento é feito exclusivamente por meio de números de protocolo.
6. **Ausência de comissão e promessas de tempo:** Os textos seguem com rigor o Guia de Voz do produto: nenhuma menção a "comissão" e nenhuma promessa subjetiva de rapidez.

---

## 2. Modelo 1: Código de Entrada

E-mail disparado durante o fluxo de entrada e cadastro (RF01, UC09, UC10). A pessoa informa o e-mail no aplicativo e recebe o código numérico de 6 dígitos para abrir a sessão.

- **Gatilho:** Solicitação de código na tela de entrada do aplicativo.
- **Destinatário:** E-mail informado pelo usuário.
- **Variáveis:**
  - `{{codigo}}` (código de 6 dígitos gerado pelo serviço de autenticação).
  - `{{email_suporte}}` (e-mail oficial de suporte: `suportefrila@gmail.com`).

### 2.1 Metadados do E-mail
- **Assunto:** `{{codigo}} é seu código de entrada no Frila`
- **Pré-cabeçalho:** `{{codigo}} é o código para entrar na sua conta. Ele vale por 15 minutos e só pode ser usado uma vez.`

### 2.2 Versão Texto Simples

```text
Frila

Seu código de entrada: {{codigo}}

Digite este código no aplicativo para entrar na sua conta. Ele vale por 15 minutos e só pode ser usado uma vez.

Se você não solicitou este código, ignore esta mensagem. Ninguém consegue entrar na sua conta sem o código de acesso.

--
Frila · Turnos avulsos e trabalho pontual
{{email_suporte}} · {{url_site}}
```

### 2.3 Versão HTML

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{codigo}} é seu código de entrada no Frila</title>
  <style>
    body { margin: 0; padding: 0; background-color: #f7f7f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; -webkit-font-smoothing: antialiased; }
    .preview-text { display: none; font-size: 1px; color: #f7f7f8; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; }
    .container { max-width: 480px; margin: 32px auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e5e7; padding: 36px 28px; }
    .brand { font-size: 22px; font-weight: 700; letter-spacing: -0.5px; color: #111111; margin-bottom: 24px; }
    .lead { font-size: 15px; line-height: 1.5; color: #333333; margin: 0 0 20px 0; }
    .code-box { background-color: #f2f2f4; border-radius: 8px; padding: 18px 24px; text-align: center; margin: 24px 0; }
    .code-value { font-size: 34px; font-weight: 700; letter-spacing: 8px; color: #111111; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-variant-numeric: tabular-nums; display: inline-block; padding-left: 8px; }
    .info { font-size: 14px; line-height: 1.5; color: #555555; margin: 0 0 16px 0; }
    .security-note { font-size: 13px; line-height: 1.5; color: #777777; border-top: 1px solid #eeeeee; padding-top: 18px; margin-top: 24px; }
    .footer { max-width: 480px; margin: 0 auto; text-align: center; font-size: 12px; line-height: 1.5; color: #888888; padding: 0 24px 32px 24px; }
    .footer a { color: #555555; text-decoration: underline; }
    @media (prefers-color-scheme: dark) {
      body { background-color: #121212; color: #e5e5e7; }
      .container { background-color: #1e1e20; border-color: #2c2c2e; }
      .brand { color: #ffffff; }
      .lead { color: #d1d1d6; }
      .code-box { background-color: #2c2c2e; }
      .code-value { color: #ffffff; }
      .info { color: #a1a1a6; }
      .security-note { color: #8e8e93; border-top-color: #2c2c2e; }
      .footer { color: #636366; }
      .footer a { color: #8e8e93; }
    }
  </style>
</head>
<body>
  <div class="preview-text">{{codigo}} é o código para entrar na sua conta. Ele vale por 15 minutos e só pode ser usado uma vez.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: transparent;">
    <tr>
      <td align="center">
        <div class="container">
          <div class="brand">Frila</div>
          <p class="lead">Seu código de entrada:</p>
          <div class="code-box">
            <span class="code-value">{{codigo}}</span>
          </div>
          <p class="info">Digite este código no aplicativo para continuar. Ele vale por 15 minutos e só pode ser usado uma vez.</p>
          <p class="security-note">Se você não solicitou este código, ignore esta mensagem. Ninguém consegue entrar na sua conta sem o código de acesso.</p>
        </div>
        <div class="footer">
          Frila · Turnos avulsos e trabalho pontual<br>
          <a href="{{url_site}}">{{url_site}}</a> · <a href="mailto:{{email_suporte}}">{{email_suporte}}</a>
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 3. Modelo 2: Protocolo de Denúncia

E-mail de confirmação enviado à pessoa que submeteu uma denúncia de conteúdo impróprio ou conduta abusiva pelo aplicativo (RF26, RN13, Diretriz 1.2 da App Store).

- **Gatilho:** Chamada concluída da RPC `denunciar`.
- **Destinatário:** E-mail do autor da denúncia.
- **Variáveis:**
  - `{{protocolo}}` (identificador completo da ocorrência).
  - `{{protocolo_curto}}` (primeiros 8 caracteres alfanuméricos em maiúsculas).
  - `{{categoria}}` (motivo classificado: Assédio, Discriminação, Risco à segurança ou Outro).
  - `{{data_abertura}}` (data formatada no padrão DD/MM/AAAA).
  - `{{email_suporte}}` (e-mail oficial de suporte: `suportefrila@gmail.com`).

### 3.1 Metadados do E-mail
- **Assunto:** `[Frila] Recebemos sua denúncia · Protocolo {{protocolo_curto}}`
- **Pré-cabeçalho:** `Sua denúncia foi registrada sob o protocolo {{protocolo_curto}} e está com a Equipe Frila.`

### 3.2 Versão Texto Simples

```text
Frila

Recebemos sua denúncia e ela já está com a Equipe Frila.

Protocolo: {{protocolo}}
Referência curta: {{protocolo_curto}}
Categoria: {{categoria}}
Data de registro: {{data_abertura}}

As denúncias são atendidas o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos.

Guarde este número de protocolo: é por meio dele que nossa equipe acompanha o caso.

Em caso de risco imediato, procure a autoridade policial pelos números 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher). O Frila não substitui o atendimento de emergência.

--
Equipe Frila · Moderação e Segurança
{{email_suporte}} · {{url_site}}
```

### 3.3 Versão HTML

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recebemos sua denúncia · Protocolo {{protocolo_curto}}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #f7f7f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; -webkit-font-smoothing: antialiased; }
    .preview-text { display: none; font-size: 1px; color: #f7f7f8; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; }
    .container { max-width: 480px; margin: 32px auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e5e7; padding: 36px 28px; }
    .brand { font-size: 22px; font-weight: 700; letter-spacing: -0.5px; color: #111111; margin-bottom: 24px; }
    .lead { font-size: 16px; font-weight: 600; line-height: 1.4; color: #111111; margin: 0 0 16px 0; }
    .protocol-card { background-color: #f2f2f4; border-radius: 8px; padding: 18px 20px; margin: 20px 0; }
    .protocol-line { font-size: 14px; line-height: 1.6; color: #333333; margin: 4px 0; }
    .protocol-line strong { color: #111111; }
    .protocol-highlight { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-weight: 700; font-size: 15px; }
    .text-body { font-size: 14px; line-height: 1.6; color: #444444; margin: 16px 0; }
    .emergency-box { background-color: #fff9f2; border: 1px solid #ffe8cc; border-radius: 8px; padding: 14px 18px; margin: 24px 0 0 0; }
    .emergency-title { font-size: 13px; font-weight: 700; color: #9c4200; margin: 0 0 6px 0; }
    .emergency-text { font-size: 13px; line-height: 1.5; color: #7a3400; margin: 0; }
    .footer { max-width: 480px; margin: 0 auto; text-align: center; font-size: 12px; line-height: 1.5; color: #888888; padding: 0 24px 32px 24px; }
    .footer a { color: #555555; text-decoration: underline; }
    @media (prefers-color-scheme: dark) {
      body { background-color: #121212; color: #e5e5e7; }
      .container { background-color: #1e1e20; border-color: #2c2c2e; }
      .brand { color: #ffffff; }
      .lead { color: #ffffff; }
      .protocol-card { background-color: #2c2c2e; }
      .protocol-line { color: #d1d1d6; }
      .protocol-line strong { color: #ffffff; }
      .text-body { color: #a1a1a6; }
      .emergency-box { background-color: #2b1f14; border-color: #4a3420; }
      .emergency-title { color: #ffab66; }
      .emergency-text { color: #e69550; }
      .footer { color: #636366; }
      .footer a { color: #8e8e93; }
    }
  </style>
</head>
<body>
  <div class="preview-text">Sua denúncia foi registrada sob o protocolo {{protocolo_curto}} e está com a Equipe Frila.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: transparent;">
    <tr>
      <td align="center">
        <div class="container">
          <div class="brand">Frila</div>
          <p class="lead">Recebemos sua denúncia</p>
          <p class="text-body">Ela já foi encaminhada para análise da Equipe Frila.</p>
          <div class="protocol-card">
            <div class="protocol-line"><strong>Protocolo:</strong> <span class="protocol-highlight">{{protocolo}}</span></div>
            <div class="protocol-line"><strong>Referência curta:</strong> <span class="protocol-highlight">{{protocolo_curto}}</span></div>
            <div class="protocol-line"><strong>Categoria:</strong> {{categoria}}</div>
            <div class="protocol-line"><strong>Data de registro:</strong> {{data_abertura}}</div>
          </div>
          <p class="text-body">As denúncias são atendidas o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Guarde este número de protocolo para acompanhar o caso.</p>
          <div class="emergency-box">
            <div class="emergency-title">Orientação de segurança</div>
            <p class="emergency-text">Em caso de risco imediato, procure a autoridade policial pelos números 190 (Polícia Militar) ou 180 (Central de Atendimento à Mulher). O Frila não substitui o atendimento de emergência.</p>
          </div>
        </div>
        <div class="footer">
          Equipe Frila · Moderação e Segurança<br>
          <a href="{{url_site}}">{{url_site}}</a> · <a href="mailto:{{email_suporte}}">{{email_suporte}}</a>
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 4. Modelo 3: Protocolo de Contestação

E-mail de confirmação enviado quando o usuário registra uma contestação formal de suspensão de conta (RF24, RN13) ou pedido de revisão de critérios de despacho (RF27, C05).

- **Gatilho:** Submissão bem-sucedida em `contestar_suspensao` ou `pedir_revisao_despacho`.
- **Destinatário:** E-mail do titular da conta.
- **Variáveis:**
  - `{{protocolo}}` (identificador completo da ocorrência).
  - `{{protocolo_curto}}` (primeiros 8 caracteres alfanuméricos em maiúsculas).
  - `{{tipo_contestacao}}` (Suspensão de conta ou Revisão de despacho).
  - `{{data_abertura}}` (data formatada no padrão DD/MM/AAAA).
  - `{{prazo_resposta}}` (data limite para resposta formal, em até 15 dias corridos; o cálculo atual do backend ainda precisa ser alinhado).
  - `{{email_suporte}}` (e-mail oficial de suporte: `suportefrila@gmail.com`).

### 4.1 Metadados do E-mail
- **Assunto:** `[Frila] Recebemos sua contestação · Protocolo {{protocolo_curto}}`
- **Pré-cabeçalho:** `Sua solicitação sob o protocolo {{protocolo_curto}} está em análise pela Equipe Frila.`

### 4.2 Versão Texto Simples

```text
Frila

Recebemos sua contestação e ela já está com a Equipe Frila.

Protocolo: {{protocolo}}
Referência curta: {{protocolo_curto}}
Tipo: {{tipo_contestacao}}
Data de registro: {{data_abertura}}
Previsão de resposta: até {{prazo_resposta}}

A Equipe Frila analisa cada pedido com base nos termos de uso e nas regras do produto. O pedido é atendido o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. A resposta será enviada para este mesmo endereço de e-mail.

Guarde o número do seu protocolo para referência.

--
Equipe Frila · Atendimento e Conformidade
{{email_suporte}} · {{url_site}}
```

### 4.3 Versão HTML

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recebemos sua contestação · Protocolo {{protocolo_curto}}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #f7f7f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; -webkit-font-smoothing: antialiased; }
    .preview-text { display: none; font-size: 1px; color: #f7f7f8; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; }
    .container { max-width: 480px; margin: 32px auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e5e7; padding: 36px 28px; }
    .brand { font-size: 22px; font-weight: 700; letter-spacing: -0.5px; color: #111111; margin-bottom: 24px; }
    .lead { font-size: 16px; font-weight: 600; line-height: 1.4; color: #111111; margin: 0 0 16px 0; }
    .protocol-card { background-color: #f2f2f4; border-radius: 8px; padding: 18px 20px; margin: 20px 0; }
    .protocol-line { font-size: 14px; line-height: 1.6; color: #333333; margin: 4px 0; }
    .protocol-line strong { color: #111111; }
    .protocol-highlight { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-weight: 700; font-size: 15px; }
    .text-body { font-size: 14px; line-height: 1.6; color: #444444; margin: 16px 0; }
    .footer { max-width: 480px; margin: 0 auto; text-align: center; font-size: 12px; line-height: 1.5; color: #888888; padding: 0 24px 32px 24px; }
    .footer a { color: #555555; text-decoration: underline; }
    @media (prefers-color-scheme: dark) {
      body { background-color: #121212; color: #e5e5e7; }
      .container { background-color: #1e1e20; border-color: #2c2c2e; }
      .brand { color: #ffffff; }
      .lead { color: #ffffff; }
      .protocol-card { background-color: #2c2c2e; }
      .protocol-line { color: #d1d1d6; }
      .protocol-line strong { color: #ffffff; }
      .text-body { color: #a1a1a6; }
      .footer { color: #636366; }
      .footer a { color: #8e8e93; }
    }
  </style>
</head>
<body>
  <div class="preview-text">Sua solicitação sob o protocolo {{protocolo_curto}} está em análise pela Equipe Frila.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: transparent;">
    <tr>
      <td align="center">
        <div class="container">
          <div class="brand">Frila</div>
          <p class="lead">Recebemos sua contestação</p>
          <p class="text-body">Sua solicitação já está com a Equipe Frila para revisão.</p>
          <div class="protocol-card">
            <div class="protocol-line"><strong>Protocolo:</strong> <span class="protocol-highlight">{{protocolo}}</span></div>
            <div class="protocol-line"><strong>Referência curta:</strong> <span class="protocol-highlight">{{protocolo_curto}}</span></div>
            <div class="protocol-line"><strong>Tipo:</strong> {{tipo_contestacao}}</div>
            <div class="protocol-line"><strong>Data de registro:</strong> {{data_abertura}}</div>
            <div class="protocol-line"><strong>Previsão de resposta:</strong> até {{prazo_resposta}}</div>
          </div>
          <p class="text-body">A Equipe Frila analisa cada pedido com base nos termos de uso e nas regras do produto. O pedido é atendido o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. A resposta será enviada para este endereço de e-mail.</p>
          <p class="text-body">Guarde o número do seu protocolo para acompanhar o caso.</p>
        </div>
        <div class="footer">
          Equipe Frila · Atendimento e Conformidade<br>
          <a href="{{url_site}}">{{url_site}}</a> · <a href="mailto:{{email_suporte}}">{{email_suporte}}</a>
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 5. Modelo 4: Alerta do Time

E-mail de notificação técnica operacional enviado à Equipe Frila quando o monitoramento do backend identifica falha em serviços essenciais (fila de mensagens, gateway de autenticação ou anomalia operacional).

- **Gatilho:** Disparo do monitoramento interno (job agendado ou detector de integridade).
- **Destinatário:** `{{destinatario_time}}` `[A DEFINIR]`.
- **Variáveis:**
  - `{{destinatario_time}}` (`[A DEFINIR]` na infraestrutura operacional).
  - `{{codigo_alerta}}` (código técnico do evento, ex.: `FILA_PUSH_BLOQUEADA`, `TAXA_FALHA_RPC`).
  - `{{servico}}` (componente afetado: Postgres, Edge Functions, APNs, SMTP).
  - `{{instante}}` (data e hora no fuso oficial de Brasília: DD/MM/AAAA às HH:mm).
  - `{{detalhe_metrica}}` (valor numérico observado, ex.: `42 falhas`).
  - `{{link_painel}}` (`[A DEFINIR]` na infraestrutura operacional).

### 5.1 Metadados do E-mail
- **Assunto:** `[Frila Alerta] {{codigo_alerta}} · {{servico}}`
- **Pré-cabeçalho:** `Alerta operacional disparado pelo monitoramento em {{instante}}.`

### 5.2 Versão Texto Simples

```text
[Frila Alerta Operacional]

O monitoramento do sistema identificou uma anomalia em produção.

Código do evento: {{codigo_alerta}}
Serviço afetado: {{servico}}
Horário do disparo: {{instante}}
Métrica observada: {{detalhe_metrica}}

Link de diagnóstico: {{link_painel}}

Este alerta não contém dados pessoais de usuários (RN15, LGPD). Acesse o painel pelo link acima para inspecionar os logs operacionais.

--
Monitoramento Frila · Infraestrutura e Confiabilidade
```

### 5.3 Versão HTML

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>[Frila Alerta] {{codigo_alerta}} · {{servico}}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #f7f7f8; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; -webkit-font-smoothing: antialiased; }
    .preview-text { display: none; font-size: 1px; color: #f7f7f8; line-height: 1px; max-height: 0px; max-width: 0px; opacity: 0; overflow: hidden; }
    .container { max-width: 520px; margin: 32px auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e5e5e7; padding: 36px 28px; }
    .badge { display: inline-block; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; background-color: #fee2e2; color: #b91c1c; padding: 4px 8px; border-radius: 4px; margin-bottom: 16px; }
    .title { font-size: 18px; font-weight: 700; color: #111111; margin: 0 0 16px 0; }
    .alert-card { background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 18px 20px; margin: 20px 0; }
    .alert-row { font-size: 13px; line-height: 1.6; color: #334155; margin: 4px 0; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
    .alert-row strong { color: #0f172a; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    .btn-container { text-align: center; margin: 28px 0 20px 0; }
    .btn { display: inline-block; background-color: #111111; color: #ffffff !important; font-size: 14px; font-weight: 600; text-decoration: none; padding: 12px 24px; border-radius: 8px; }
    .privacy-notice { font-size: 12px; line-height: 1.5; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 16px; margin-top: 20px; }
    .footer { max-width: 520px; margin: 0 auto; text-align: center; font-size: 12px; line-height: 1.5; color: #888888; padding: 0 24px 32px 24px; }
    @media (prefers-color-scheme: dark) {
      body { background-color: #0f172a; color: #e2e8f0; }
      .container { background-color: #1e293b; border-color: #334155; }
      .title { color: #f8fafc; }
      .alert-card { background-color: #0f172a; border-color: #334155; }
      .alert-row { color: #cbd5e1; }
      .alert-row strong { color: #f1f5f9; }
      .btn { background-color: #38bdf8; color: #0f172a !important; }
      .privacy-notice { color: #94a3b8; border-top-color: #334155; }
      .footer { color: #64748b; }
    }
  </style>
</head>
<body>
  <div class="preview-text">Alerta operacional disparado pelo monitoramento em {{instante}}.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: transparent;">
    <tr>
      <td align="center">
        <div class="container">
          <div class="badge">Alerta Operacional</div>
          <div class="title">Anomalia detectada em produção</div>
          <div class="alert-card">
            <div class="alert-row"><strong>Código:</strong> {{codigo_alerta}}</div>
            <div class="alert-row"><strong>Serviço:</strong> {{servico}}</div>
            <div class="alert-row"><strong>Momento:</strong> {{instante}}</div>
            <div class="alert-row"><strong>Métrica:</strong> {{detalhe_metrica}}</div>
          </div>
          <div class="btn-container">
            <a href="{{link_painel}}" class="btn">Abrir Painel de Diagnóstico</a>
          </div>
          <div class="privacy-notice">
            Este alerta foi gerado automaticamente sem dados pessoais ou identificadores de usuários (RN15, LGPD).
          </div>
        </div>
        <div class="footer">
          Frila · Confiabilidade de Sistemas e Infraestrutura
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 6. Matriz de Rastreabilidade e Critérios de Aceite

| Requisito do Cartão oYSwLrIS | Situação | Evidência na Entrega |
|---|:---:|---|
| **Quatro modelos especificados (código, denúncia, contestação e alerta)** | Concluído | Seções 2, 3, 4 e 5 completas com assunto, pré-cabeçalho, corpo e rodapé. |
| **Versões completas em HTML e texto simples** | Concluído | Todos os 4 modelos contam com código HTML independente e bloco de texto simples. |
| **HTML sem recursos externos e legível em modo escuro** | Concluído | Zero imagens remotas, CSS inline, paleta sem dependências e estilos dark mode testados. |
| **Código no assunto e legível na notificação sem abrir o e-mail** | Concluído | Assunto e pré-cabeçalho começam pelo código: `{{codigo}} é seu código de entrada no Frila` e `{{codigo}} é o código para entrar na sua conta…` (corrigido em 16/10: o texto anterior dizia que o pré-cabeçalho começava pelo código, mas não começava). |
| **Prazos documentais atualizados** | Backend pendente | Seções 3 (denúncia) e 4 (contestação): o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (decisão do Cauê em 15/10/2026). Textos e cálculo do prazo no backend dependem de cartão no Trello. |
| **Telefones de emergência 190 e 180 no modelo de denúncia** | Concluído | Seção 3 (texto simples e HTML) com destaque para atendimento policial e mulher. |
| **Alerta do time sem dados pessoais e com destinatário/link a definir** | Concluído | Seção 5 restrita a métricas operacionais, instante, `{{destinatario_time}} [A DEFINIR]` e `{{link_painel}} [A DEFINIR]`. |
| **Canal oficial e URLs pendentes** | Parcial | Variável `{{email_suporte}}` definida como `suportefrila@gmail.com`. URLs públicas em variáveis, pendentes de domínio aprovado pelo Cauê. |
| **Validade do código informada** | Concluído | O modelo diz *"Ele vale por 15 minutos e só pode ser usado uma vez"*, o mesmo valor do Auth do `frila-dev` (900 s) e do e-mail que já está no ar. |
| **Terminologia do Guia de Voz e ausência da palavra "comissão"** | Concluído | Vocabulário auditado contra `GuiaDeVoz.md`, sem "comissão". |
| **Conferência de scripts (`conferir-textos.sh`)** | Concluído | `iOS/Scripts/conferir-textos.sh` aprovado sem erros. |
| **Definição de prazos de moderação e atendimento** | Concluído nos textos | Decisão do Cauê em 15/10/2026: o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (incorporado aos modelos em texto simples e HTML). |
| **Validação da entrega na caixa de entrada (Gmail e iCloud) com captura no Trello** | Concluído na prova; captura no cartão pendente | Prova de 16/10 registrada em `DiarioDeConfiguracao.md`: Gmail e iCloud na caixa de entrada em cerca de 1 s, SPF, DKIM e DMARC PASS; Outlook no spam (aceito pelo Cauê até haver domínio próprio). Não há captura da caixa de entrada anexada. |
| **Aprovação dos textos pela Júlia** | Concluído por delegação | Revisão profunda de 16/10 feita por Nick Fury, **por delegação do Cauê** (a Júlia não precisa mais aprovar): quatro modelos conferidos contra o `GuiaDeVoz.md` (sem "comissão", sem promessa de rapidez, sem estrangeirismo, sem exclamação, "Vaga"/"Equipe Frila" nos termos do glossário), prazos 5 dias úteis e 15 dias corridos, suportefrila@gmail.com, 190 e 180 no modelo de denúncia, sem dado pessoal no alerta. Não é parecer jurídico. |
| **Homologação formal do prazo de validade do código OTP** | Concluído | Decisão de 16/10 (Nick Fury, por delegação do Cauê): informar 15 minutos, o valor real do Auth do `frila-dev`. |

### 6.1 Decisões Pendentes (Cauê e João Paulo)

1. **Prazos de moderação e atendimento (Definidos pelo Cauê em 15/10/2026):** o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos. Aplicados aos Modelos 2 (Protocolo de Denúncia) e 3 (Protocolo de Contestação) em texto simples e HTML. Alinhar implementação e cálculo de prazo do backend por cartão no Trello.
2. **Prazo numérico de validade do código OTP (decidido em 16/10):** o e-mail informa 15 minutos, o valor real do Auth do `frila-dev` (900 s). O `otp_expiry = 600` do `config.toml` local não vale para o servidor. Se o tempo mudar, mudar o modelo do Supabase e este documento no mesmo dia.
3. **Destinatário e infraestrutura do alerta do time:** Definir o e-mail real de monitoramento (`{{destinatario_time}}`) e a URL do painel (`{{link_painel}}`).
