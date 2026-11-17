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

// Push (fase 4, item 6.1). O aviso só mostra o conteúdo quando vem para a conta que ligou os avisos neste aparelho
// (`vinculo_id` igual ao guardado, RN15). De outra conta, ou depois do sair, aparece só o texto neutro.
// A tela /avisos manda o vínculo e o texto neutro (do catálogo); ficam num cache próprio, fora do prefixo da casca.
const CACHE_DO_AVISO = "frila-aviso-v1";
const CHAVE_DO_AVISO = "/app/__aviso";

async function lerAviso() {
  try {
    const resposta = await (await caches.open(CACHE_DO_AVISO)).match(CHAVE_DO_AVISO);
    return resposta ? await resposta.json() : null;
  } catch {
    return null;
  }
}

async function gravarAviso(aviso) {
  const cache = await caches.open(CACHE_DO_AVISO);
  await cache.put(CHAVE_DO_AVISO, new Response(JSON.stringify(aviso), { headers: { "Content-Type": "application/json" } }));
}

self.addEventListener("message", (evento) => {
  const mensagem = evento.data ?? {};
  if (mensagem.tipo === "vinculo" && mensagem.neutro) {
    // Sem vínculo na resposta (servidor antigo), o contrato diz: sem conferência por vínculo.
    evento.waitUntil(gravarAviso({ vinculo_id: mensagem.vinculo_id ?? null, conferir: mensagem.vinculo_id != null, neutro: mensagem.neutro }));
  } else if (mensagem.tipo === "esquecer") {
    evento.waitUntil(
      lerAviso().then((aviso) => gravarAviso({ vinculo_id: null, conferir: true, neutro: aviso?.neutro ?? null })),
    );
  }
});

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
      const aviso = await lerAviso();
      const daConta = aviso !== null && (aviso.conferir ? aviso.vinculo_id !== null && dados.vinculo_id === aviso.vinculo_id : true);
      const neutro = aviso?.neutro ?? { titulo: "Frila", corpo: "" };
      // Toda chegada mostra uma notificação (o iPhone corta o push de quem não mostra).
      await self.registration.showNotification(daConta ? (conteudo.title ?? neutro.titulo) : neutro.titulo, {
        body: daConta ? (conteudo.body ?? "") : neutro.corpo,
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
