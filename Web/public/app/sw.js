// Service worker da web do Frila: mínimo e seguro (fase 4, itens 1.9, 1.10 e 6.1 de docs/paridade.md).
// - Guarda SÓ a página "sem conexão" e o texto neutro do push, iguais para todo mundo e sem dado pessoal.
// - Nunca guarda página, dado, sessão ou resposta da API: tudo vai à rede, como se não houvesse service worker.
// - Sem rede numa navegação dentro de /app, mostra a página guardada.
// O domínio é dividido com o site: só mexe nos caches com os prefixos abaixo.
const PREFIXOS = ["frila-casca-", "frila-aviso-"];
const CACHE = "frila-casca-v2";
const SEM_CONEXAO = "/app/sem-conexao";
const TEXTO_NEUTRO = "/app/avisos/texto-neutro";

self.addEventListener("install", (evento) => {
  evento.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll([new Request(SEM_CONEXAO, { cache: "reload" }), new Request(TEXTO_NEUTRO, { cache: "reload" })]))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (evento) => {
  evento.waitUntil(
    (async () => {
      const nomes = await caches.keys();
      const doFrila = (nome) => PREFIXOS.some((prefixo) => nome.startsWith(prefixo));
      await Promise.all(nomes.filter((nome) => doFrila(nome) && nome !== CACHE).map((nome) => caches.delete(nome)));
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

// Push (fase 4, item 6.1). Decisão do O2 (17/11): na web v1, toda notificação mostra SÓ o texto neutro guardado na
// instalação. O título e o corpo que chegam no push nunca são lidos: o conteúdo aparece ao abrir o Frila, com a sessão
// (RN15). Do push, só o tipo e os ids escolhem a página que o toque abre, e essa página exige sessão.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LEMBRETES_DO_TURNO = ["lembrete_24h", "lembrete_3h", "confirmacao", "fim_sem_checkout"];

function destinoDoAviso(dados) {
  const id = (chave) => (typeof dados[chave] === "string" && UUID.test(dados[chave]) ? dados[chave] : null);
  if (id("chamada_id")) return `/app/chamadas/${id("chamada_id")}`;
  if (dados.tipo === "vaga" && id("vaga_id")) return `/app/vagas/${id("vaga_id")}`;
  if (LEMBRETES_DO_TURNO.includes(dados.tipo) && id("turno_id")) return `/app/turnos/${id("turno_id")}`;
  return "/app/";
}

async function textoNeutro() {
  try {
    const resposta = await caches.match(TEXTO_NEUTRO);
    const texto = resposta ? await resposta.json() : null;
    if (typeof texto?.titulo === "string" && typeof texto?.corpo === "string") return texto;
  } catch {
    // Sem o texto guardado, vale só o nome do Frila.
  }
  return { titulo: "Frila", corpo: "" };
}

self.addEventListener("push", (evento) => {
  evento.waitUntil(
    (async () => {
      let dados;
      try {
        dados = (evento.data ? evento.data.json() : {}).data ?? {};
      } catch {
        dados = {};
      }
      const neutro = await textoNeutro();
      // Toda chegada mostra uma notificação (o iPhone corta o push de quem não mostra).
      await self.registration.showNotification(neutro.titulo, {
        body: neutro.corpo,
        icon: "/app/icone-192.png",
        lang: "pt-BR",
        data: { destino: destinoDoAviso(dados) },
      });
    })(),
  );
});

self.addEventListener("notificationclick", (evento) => {
  evento.notification.close();
  const destino = evento.notification.data?.destino ?? "/app/";
  evento.waitUntil(
    (async () => {
      const abertas = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      const doFrila = abertas.find((cliente) => new URL(cliente.url).pathname.startsWith("/app"));
      if (doFrila && "navigate" in doFrila) {
        await doFrila.focus();
        return doFrila.navigate(destino);
      }
      return self.clients.openWindow(destino);
    })(),
  );
});
