# AGENTS.md: a web do Frila (`Web/`)

Web do Frila em `frilabr.com/app`: React Router v8 (modo framework) num único Worker da Cloudflare, TypeScript estrito.
Vale o `AGENTS.md` da raiz; aqui fica só o que é da web. O que construir e em que ordem: `docs/paridade.md`.

## Rodar e testar (a partir de `Web/`)
```bash
npm ci                 # instala (versões exatas, pelo lockfile)
npm run dev            # servidor local em http://localhost:5173/app/
npm run conferir       # contrato + lint + tipos + testes + build + orçamento + fumaça: o gate local (a CI roda o mesmo)
scripts/gerar-dev-vars.sh   # uma vez: cria o .dev.vars (ignorado pelo git) com o Supabase de dev
```

## Regras que o agente erra sem ler
- **React Router v8:** tudo vem de `react-router`. `react-router-dom` e `@remix-run/*` não existem mais (o lint barra).
  Não use `json()` nem `defer()`: o loader devolve o objeto direto. A documentação da versão instalada está em
  `node_modules/react-router/docs/`: leia antes de usar API de que não tem certeza.
- **Contrato:** `contrato/openapi.yaml` é espelho de `frila-documentacao/api/openapi.yaml`. Não edite: mudança de
  contrato nasce lá, depois backend, depois clientes. Para atualizar: `scripts/contrato-traz.sh <arquivo>`. Os tipos
  (`app/contrato/tipos.gerado.ts`) saem do espelho em `npm run tipos` e não entram no git.
- **Supabase só pelo servidor**, com `criarApi` (`app/servidor/api.ts`), tipado pelo contrato. O navegador nunca chama
  o Supabase direto. Toda chamada tem prazo e um estado para a falha (veja `app/servidor/configuracao.ts`).
- **Tudo debaixo de `/app`** (`basename` no `react-router.config.ts`). Link interno é relativo à base: `<Link to="/">`.
  Na tela de erro, use `<a href>` (a navegação sem recarregar não existe com a chave desligada).
- **Variáveis do Worker:** `import { env } from "cloudflare:workers"`, só em código de servidor (loader, action, `app/servidor/`).
- **Sessão só no servidor:** cookie `HttpOnly` gravado pelo Worker. Token nunca vai para o JavaScript da página, nem
  `localStorage`. Não use `@supabase/ssr`. Nunca `service_role`.
- **CSP com nonce** (`app/entry.server.tsx`, `app/servidor/cabecalhos.ts`): nada de `<script>` ou `<style>` embutido
  sem nonce, nada de `style=""` no JSX, nada de script de terceiro. Precisa abrir a política? Mude lá, com teste.
- **Textos só pelo catálogo** `app/textos/pt-BR.ts`. Nenhum texto visível direto no JSX.
- **Regra de negócio fica no servidor do Frila.** A web mostra o que o servidor decide.
- **Tela provisória** leva o comentário `// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício` e usa só os tokens de
  `app/app.css`. Decisão de tela é do Fabrício.
- **Sala limpa:** nada de código, texto, imagem, cor, nome ou dado de outros produtos.
- **Custo zero:** plano grátis da Cloudflare. Página pública pronta de antemão, servidor mínimo, nada de serviço pago.
- **Dependência nova:** versão exata (`npm install --save-exact`), citada no PR. Não crie `.npmrc` (a guarda de segredos barra). Endereço e chave do Supabase não entram no repositório
  (`.dev.vars` local, variáveis do Worker no painel).
- **Chave `WEB_LIGADA`:** fora de `"1"`, só a página "em breve" existe. Produção fica desligada até ordem do Cauê.
