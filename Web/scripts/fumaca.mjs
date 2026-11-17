// Teste de fumaça: sobe o build no runtime local da Cloudflare (`vite preview`) e confere, com pedidos de
// verdade, as rotas e os cabeçalhos de segurança. Roda depois de `npm run build`. Não precisa do Supabase.
import { spawn } from "node:child_process";

const PORTA = 4390;
const BASE = `http://localhost:${PORTA}`;
const falhas = [];
const confere = (nome, condicao, detalhe = "") => {
  console.log(`${condicao ? "ok  " : "ERRO"} ${nome}${condicao ? "" : ` ${detalhe}`}`);
  if (!condicao) falhas.push(nome);
};

const servidor = spawn("npx", ["vite", "preview", "--port", String(PORTA), "--strictPort"], { stdio: "ignore" });

async function esperarSubir() {
  for (let tentativa = 0; tentativa < 120; tentativa++) {
    if (servidor.exitCode !== null) throw new Error("o servidor local encerrou antes de responder");
    try {
      await fetch(`${BASE}/app/`, { redirect: "manual" });
      return;
    } catch {
      await new Promise((resolver) => setTimeout(resolver, 250));
    }
  }
  throw new Error("o servidor local não respondeu em 30 s");
}

try {
  await esperarSubir();

  const pagina = await fetch(`${BASE}/app/`);
  const html = await pagina.text();
  const csp = pagina.headers.get("content-security-policy") ?? "";
  const nonce = /'nonce-([^']+)'/.exec(csp)?.[1];
  confere("GET /app/ responde 200 em HTML", pagina.status === 200 && (pagina.headers.get("content-type") ?? "").startsWith("text/html"));
  confere("a página vem em pt-BR", html.includes('<html lang="pt-BR">'));
  confere("a CSP traz um nonce e não tem unsafe-inline", Boolean(nonce) && !csp.includes("unsafe-inline"), csp);
  const scriptsEmbutidos = [...html.matchAll(/<script(?![^>]*\ssrc=)([^>]*)>/g)].map((achado) => achado[1] ?? "");
  confere(
    "todo script embutido na página leva o nonce da CSP",
    scriptsEmbutidos.length > 0 && scriptsEmbutidos.every((atributos) => atributos.includes(`nonce="${nonce}"`)),
    `${scriptsEmbutidos.length} scripts`,
  );
  confere("a página não tem estilo embutido", !/<style[\s>]/.test(html) && !/\sstyle="/.test(html));
  for (const [nome, valor] of [
    ["x-content-type-options", "nosniff"],
    ["x-frame-options", "DENY"],
    ["referrer-policy", "strict-origin-when-cross-origin"],
    ["strict-transport-security", "max-age=31536000"],
    ["cross-origin-opener-policy", "same-origin"],
  ]) {
    confere(`cabeçalho ${nome}`, pagina.headers.get(nome) === valor, String(pagina.headers.get(nome)));
  }
  confere("a página não fica em cache compartilhado", pagina.headers.get("cache-control") === "private, no-store");

  const outra = await fetch(`${BASE}/app/`);
  const outroNonce = /'nonce-([^']+)'/.exec(outra.headers.get("content-security-policy") ?? "")?.[1];
  confere("cada resposta tem um nonce novo", Boolean(outroNonce) && outroNonce !== nonce);

  const raiz = await fetch(`${BASE}/`, { redirect: "manual" });
  confere("GET / vai para /app/", raiz.status === 302 && raiz.headers.get("location") === `${BASE}/app/`);
  confere("o redirecionamento também leva nosniff", raiz.headers.get("x-content-type-options") === "nosniff");

  const perdida = await fetch(`${BASE}/app/nao-existe`);
  confere("rota inexistente responde 404 com CSP", perdida.status === 404 && perdida.headers.has("content-security-policy"));

  const saude = await fetch(`${BASE}/app/saude`);
  const corpoDaSaude = await saude.json();
  confere("GET /app/saude responde JSON sem cache", saude.status === 200 && saude.headers.get("cache-control") === "no-store");
  confere("a saúde diz o estado da configuração", typeof corpoDaSaude.configuracao_do_app === "string");

  const arquivo = /\/app\/assets\/entry\.client-[^"]+\.js/.exec(html)?.[0];
  const estatico = arquivo ? await fetch(`${BASE}${arquivo}`) : null;
  confere("o JavaScript da página responde 200", estatico?.status === 200, String(arquivo));
  confere(
    "arquivo com hash fica em cache para sempre",
    (estatico?.headers.get("cache-control") ?? "").includes("immutable"),
    String(estatico?.headers.get("cache-control")),
  );
} catch (erro) {
  confere("teste de fumaça rodou até o fim", false, String(erro));
} finally {
  servidor.kill();
}

process.exit(falhas.length > 0 ? 1 : 0);
