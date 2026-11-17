// Service worker da web do Frila: mínimo e seguro (fase 4, itens 1.9 e 1.10 de docs/paridade.md).
// - Guarda SÓ a página "sem conexão", que é igual para todo mundo e não tem dado pessoal.
// - Nunca guarda página, dado, sessão ou resposta da API: tudo vai à rede, como se não houvesse service worker.
// - Sem rede numa navegação dentro de /app, mostra a página guardada.
// O domínio é dividido com o site: só mexe nos caches com o prefixo abaixo.
const PREFIXO = "frila-casca-";
const CACHE = `${PREFIXO}v1`;
const SEM_CONEXAO = "/app/sem-conexao";

self.addEventListener("install", (evento) => {
  evento.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.add(new Request(SEM_CONEXAO, { cache: "reload" })))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (evento) => {
  evento.waitUntil(
    (async () => {
      const nomes = await caches.keys();
      await Promise.all(nomes.filter((nome) => nome.startsWith(PREFIXO) && nome !== CACHE).map((nome) => caches.delete(nome)));
      // A navegação vai à rede enquanto o service worker acorda (não atrasa a página).
      await self.registration.navigationPreload?.enable();
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (evento) => {
  const pedido = evento.request;
  if (pedido.mode !== "navigate" || pedido.method !== "GET") return;
  evento.respondWith(
    (async () => {
      try {
        return (await evento.preloadResponse) ?? (await fetch(pedido));
      } catch {
        return (await caches.match(SEM_CONEXAO)) ?? Response.error();
      }
    })(),
  );
});
