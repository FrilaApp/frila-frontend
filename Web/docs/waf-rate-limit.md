# Rate Limit de Borda (Cloudflare WAF) — Rotas de Autenticação (`Web/`)

Este documento versiona a configuração operacional do **WAF Rate Limiting** na Cloudflare para proteger as rotas de autenticação da aplicação web (`frilabr.com/app/*`).

> **Por que não há rate limit em memória no Worker (`Web/wrangler.jsonc`)?**  
> O Worker `frila-web` roda *stateless* em múltiplos *isolates* e PoPs da Cloudflare (plano gratuito, sem KV nem Durable Objects). Contadores em memória no Worker não compartilham estado entre requisições distribuídas e podem ser facilmente contornados. A proteção de borda deve ficar no **WAF da Cloudflare**, complementada pelo mapeamento de `HTTP 429` do Supabase Auth/Edge Functions já tratado no Worker (`Web/app/servidor/auth.ts`).

---

## 1. Rotas Protegidas

Incluir todas as rotas `POST` (inclusive submissões `.data` do React Router v8) de entrada, cadastro, recuperação, definição de senha e os futuros endpoints da arquitetura de confiança de dispositivo (após entrega do contrato backend):

* `/app/entrar` e `/app/entrar.data`
* `/app/criar-conta` e `/app/criar-conta.data`
* `/app/recuperar-senha` e `/app/recuperar-senha.data`
* `/app/definir-senha` e `/app/definir-senha.data`
* *(Futuro — Fatia 2 após contrato)* `/app/desafio-dispositivo`, `/app/desafio-dispositivo.data`, `/app/conta/revogar-dispositivos`

---

## 2. Expressão e Parâmetros da Regra WAF (Plano Grátis da Cloudflare)

No plano gratuito da Cloudflare, o recurso **Rate Limiting Rules** (`http_ratelimit`) oferece 1 regra com janela fixa de **10 segundos**, tempo de mitigação de **10 segundos** e chave por IP (`ip.src`).

* **Expressão de filtro:**
  ```text
  (http.request.method eq "POST" and (
    http.request.uri.path eq "/app/entrar" or
    http.request.uri.path eq "/app/entrar.data" or
    http.request.uri.path eq "/app/criar-conta" or
    http.request.uri.path eq "/app/criar-conta.data" or
    http.request.uri.path eq "/app/recuperar-senha" or
    http.request.uri.path eq "/app/recuperar-senha.data" or
    http.request.uri.path eq "/app/definir-senha" or
    http.request.uri.path eq "/app/definir-senha.data" or
    http.request.uri.path eq "/app/desafio-dispositivo" or
    http.request.uri.path eq "/app/desafio-dispositivo.data" or
    http.request.uri.path eq "/app/conta/revogar-dispositivos"
  ))
  ```
* **Characteristics:** `["ip.src"]`
* **Period:** `10` segundos
* **Requests per period:** `10` requisições (permite uso legítimo com eventuais reenvios/correções de erro de digitação, barrando rajadas de força bruta ou *credential stuffing*)
* **Mitigation timeout:** `10` segundos
* **Action:** `block` (retornando `HTTP 429 Too Many Requests` sem revelar detalhes da conta)

*(Em eventual upgrade de plano Cloudflare, ajustar para janela de `60` s com `requests_per_period: 20` e combinar com `cf.waf.credential_check` / headers de rate limit por e-mail na Edge Function).*

---

## 3. Comando Executável para Aplicação Manual (Operador de Infra)

> **Atenção:** Não executar contra a zona `frilabr.com` sem autorização explícita do líder/infra. Requer `CF_ZONE_ID` e `CF_API_TOKEN` (escopo *Zone.Zone WAF Write*) fora do repositório.

### 3.1. Inspecionar ruleset `http_ratelimit` existente na zona
```bash
curl -fsS "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets/phases/http_ratelimit/entrypoint" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json"
```

### 3.2. Aplicar ou atualizar a regra no entrypoint `http_ratelimit`
```bash
curl -fsS -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets/phases/http_ratelimit/entrypoint" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "rules": [
      {
        "action": "block",
        "description": "Frila Web Auth POST Rate Limit (10 req/10s por IP)",
        "enabled": true,
        "expression": "(http.request.method eq \"POST\" and (http.request.uri.path eq \"/app/entrar\" or http.request.uri.path eq \"/app/entrar.data\" or http.request.uri.path eq \"/app/criar-conta\" or http.request.uri.path eq \"/app/criar-conta.data\" or http.request.uri.path eq \"/app/recuperar-senha\" or http.request.uri.path eq \"/app/recuperar-senha.data\" or http.request.uri.path eq \"/app/definir-senha\" or http.request.uri.path eq \"/app/definir-senha.data\" or http.request.uri.path eq \"/app/desafio-dispositivo\" or http.request.uri.path eq \"/app/desafio-dispositivo.data\" or http.request.uri.path eq \"/app/conta/revogar-dispositivos\"))",
        "ratelimit": {
          "characteristics": ["ip.src"],
          "mitigation_timeout": 10,
          "period": 10,
          "requests_per_period": 10
        }
      }
    ]
  }'
```

---

## 4. Camadas Complementares (Sem Dependência de Plano Pago)

1. **Worker (`porteiro.ts`):** Bloqueia com `403` qualquer `POST` sem cabeçalho `Origin` igual ao `url.origin` (CSRF).
2. **Supabase Auth & Edge Functions:** Aplicam limites por e-mail/IP no backend e devolvem `429`, convertidos no Worker em mensagens neutras (`motivo: "limite"`).
