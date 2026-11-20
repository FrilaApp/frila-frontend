# Publicação da web (Worker `frila-web`) e volta de versão

Produção é o ambiente `producao` do `wrangler.jsonc`: Worker `frila-web`, sem `*.workers.dev`, só nas rotas
`frilabr.com/app`, `frilabr.com/app/*` e `frilabr.com/app.data`. O resto do `frilabr.com` (site, `/privacidade`,
`/termos`, `/suporte`) não passa pelo Worker. Não troque as rotas por `frilabr.com/app*`: esse padrão pega também
`/apps` e qualquer caminho que comece com `/app`.

Publicar em produção só com ordem do líder (que segue o roteiro do Orquestrador 2). Sem Workers Builds.

**Login da Cloudflare:** todo comando `wrangler` daqui roda com o token de API do Frila (conta frila.org), nunca com
`wrangler login` nem `wrangler logout`: o Mac guarda um só login, e trocá-lo derruba os outros projetos. Quem publica
usa o script do time, que lê o token na hora e repassa o comando. Onde este texto diz `wrangler …`, é o comando que
vai para esse script. Nunca imprima o token.

## Publicar
1. Antes: guarde status, cabeçalhos e sha256 do corpo de `/`, `/privacidade`, `/termos` e `/suporte`.
2. `npm ci && npm run conferir`, depois `CLOUDFLARE_ENV=producao npm run build`.
3. Confira `build/server/wrangler.json`: `"name": "frila-web"`, `WEB_LIGADA` e as três rotas.
4. `wrangler deploy` (pelo script do time). Na primeira publicação (ou para trocar o par do Supabase), use
   `--secrets-file <arquivo fora do repositório, umask 077>` com `SUPABASE_URL` e `SUPABASE_CHAVE_PUBLICAVEL` de prod,
   e apague o arquivo logo depois. Nunca imprima os valores.
5. Depois: as quatro páginas iguais ao "antes"; `/app/` responde 200; `/app/saude` diz o `web_ligada` esperado.

## Voltar atrás
- Versão anterior do Worker: `wrangler rollback --name frila-web [id da versão]` (pelo script do time; sem o id, volta à anterior; não mexe nas rotas). Ids: `wrangler deployments list --name frila-web`.
- Tirar a web do ar sem apagar nada: remover as três rotas no painel da Cloudflare (Workers → `frila-web` → Domínios e
  rotas). O `frilabr.com/app` volta ao 404 do site.
- Desligar a web mantendo a página "em breve": publicar com `WEB_LIGADA` diferente de `"1"`.
