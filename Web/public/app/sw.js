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

// Push (fase 4, item 6.1). O conteúdo só aparece quando o Worker do Frila, com a sessão viva deste navegador, confirma
// que o aviso é dela (RN15): a cada push o SW pergunta, e nada fica guardado aqui que uma página, outra aba ou uma
// resposta atrasada possa trocar. Sem sessão, depois do sair, de outra conta ou sem rede: só o texto neutro.
const CACHE_DO_AVISO = "frila-aviso-v1";
const CHAVE_DO_NEUTRO = "/app/__neutro";
const CONFERIR = "/app/avisos/vinculo";

async function conferirComOServidor(vinculoId) {
  try {
    const resposta = await fetch(
      new Request(CONFERIR, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ vinculo_id: vinculoId ?? null }) }),
    );
    if (!resposta.ok) return null;
    const corpo = await resposta.json();
    // O texto neutro (do catálogo, sem dado de ninguém) fica guardado para o push que chegar sem rede.
    if (corpo.neutro) {
      const cache = await caches.open(CACHE_DO_AVISO);
      await cache.put(CHAVE_DO_NEUTRO, new Response(JSON.stringify(corpo.neutro), { headers: { "Content-Type": "application/json" } }));
    }
    return corpo;
  } catch {
    return null;
  }
}

async function neutroGuardado() {
  try {
    const resposta = await (await caches.open(CACHE_DO_AVISO)).match(CHAVE_DO_NEUTRO);
    return resposta ? await resposta.json() : null;
  } catch {
    return null;
  }
}

self.addEventListener("push", (evento) => {
  evento.waitUntil(
    (async () => {
      let carga;
      try {
        carga = evento.data ? evento.data.json() : {};
      } catch {
        carga = {};
      }
      const conteudo = carga.notification ?? {};
      const dados = carga.data ?? {};
      const conferido = await conferirComOServidor(dados.vinculo_id);
      const mostrar = conferido?.mostrar === true;
      const neutro = conferido?.neutro ?? (await neutroGuardado()) ?? { titulo: "Frila", corpo: "" };
      // Toda chegada mostra uma notificação (o iPhone corta o push de quem não mostra).
      await self.registration.showNotification(mostrar ? (conteudo.title ?? neutro.titulo) : neutro.titulo, {
        body: mostrar ? (conteudo.body ?? "") : neutro.corpo,
        icon: "/app/icone-192.png",
        lang: "pt-BR",
      });
    })(),
  );
});

self.addEventListener("notificationclick", (evento) => {
  evento.notification.close();
  evento.waitUntil(
    (async () => {
      const abertas = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      const doFrila = abertas.find((cliente) => new URL(cliente.url).pathname.startsWith("/app"));
      if (doFrila) return doFrila.focus();
      return self.clients.openWindow("/app/");
    })(),
  );
});
