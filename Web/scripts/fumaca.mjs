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
  confere("a página vem em pt-BR", /<html\b[^>]*\blang="pt-BR"[^>]*>/.test(html));
  confere("sem cookie de aparência, o HTML já vem em Claro", /<html\b[^>]*\bdata-aparencia="claro"[^>]*>/.test(html));
  for (const [valor, esperado] of [["escuro", "escuro"], ["invalido", "claro"]]) {
    const resposta = await fetch(`${BASE}/app/`, { headers: { Cookie: `frila-aparencia=${valor}` } });
    const documento = await resposta.text();
    confere(
      `cookie de aparência ${valor}: o HTML já vem em ${esperado}`,
      resposta.status === 200 && new RegExp(`<html\\b[^>]*\\bdata-aparencia="${esperado}"[^>]*>`).test(documento),
    );
  }
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

  for (const dados of ["/app.data", "/app/_.data"]) {
    const resposta = await fetch(`${BASE}${dados}`, { redirect: "manual" });
    confere(`pedido de dados da página inicial (${dados})`, resposta.status === 200 && (resposta.headers.get("content-type") ?? "").includes("text/x-script"), String(resposta.status));
  }

  const entrar = await fetch(`${BASE}/app/entrar`);
  const htmlDoEntrar = await entrar.text();
  confere("GET /app/entrar mostra o formulário e não vai para buscador", entrar.status === 200 && htmlDoEntrar.includes('name="email"') && htmlDoEntrar.includes('content="noindex"'));
  const forjado = await fetch(`${BASE}/app/entrar`, { method: "POST", redirect: "manual", headers: { Origin: "https://outro.example" }, body: new URLSearchParams({ email: "a@b.co", intencao: "pedir" }) });
  confere("envio vindo de outro site é recusado (403)", forjado.status === 403, String(forjado.status));
  const semOrigem = await fetch(`${BASE}/app/sair`, { method: "POST", redirect: "manual" });
  confere("envio sem origem é recusado (403)", semOrigem.status === 403, String(semOrigem.status));
  const sair = await fetch(`${BASE}/app/sair`, { method: "POST", redirect: "manual", headers: { Origin: BASE } });
  const apagados = sair.headers.getSetCookie();
  confere(
    "sair sem sessão responde 302 e apaga os cookies, todos HttpOnly",
    sair.status === 302 && apagados.length === 2 && apagados.every((linha) => linha.includes("HttpOnly") && linha.includes("Max-Age=0")),
    `${sair.status} ${apagados.length}`,
  );
  const cadastroSemSessao = await fetch(`${BASE}/app/cadastro`, { redirect: "manual" });
  confere("cadastro sem sessão manda entrar", cadastroSemSessao.status === 302 && (cadastroSemSessao.headers.get("location") ?? "").endsWith("/app/entrar"));
  const aceiteSemSessao = await fetch(`${BASE}/app/aceitar-termos`, { method: "POST", redirect: "manual", headers: { Origin: BASE } });
  confere("aceite dos termos sem sessão manda entrar", aceiteSemSessao.status === 302 && (aceiteSemSessao.headers.get("location") ?? "").endsWith("/app/entrar"));
  const semCookie = await fetch(`${BASE}/app/`);
  confere("sem sessão, a página não grava cookie nenhum", semCookie.headers.getSetCookie().length === 0);

  const perdida = await fetch(`${BASE}/app/nao-existe`);
  confere("rota inexistente responde 404 com CSP", perdida.status === 404 && perdida.headers.has("content-security-policy"));

  const saude = await fetch(`${BASE}/app/saude`);
  const corpoDaSaude = await saude.json();
  confere("GET /app/saude responde JSON sem cache", saude.status === 200 && saude.headers.get("cache-control") === "no-store");
  confere("a saúde diz o estado da configuração", typeof corpoDaSaude.configuracao_do_app === "string");

  const manifesto = await fetch(`${BASE}/app/site.webmanifest`);
  const icones = manifesto.ok ? (await manifesto.json()).icons : [];
  confere("o manifest responde e lista os ícones", icones.length === 3);
  for (const caminho of ["/app/favicon.svg", "/app/apple-touch-icon-180.png", "/app/og-1200x630.png", ...new Set(icones.map((icone) => icone.src))]) {
    confere(`ativo de marca ${caminho}`, (await fetch(`${BASE}${caminho}`)).status === 200);
  }
  const sw = await fetch(`${BASE}/app/sw.js`);
  confere(
    "o service worker responde em JavaScript e é conferido a cada visita",
    sw.status === 200 && (sw.headers.get("content-type") ?? "").includes("javascript") && sw.headers.get("cache-control") === "no-cache",
    `${sw.status} ${sw.headers.get("content-type")} ${sw.headers.get("cache-control")}`,
  );
  const semConexao = await fetch(`${BASE}/app/sem-conexao`);
  const htmlSemConexao = await semConexao.text();
  confere(
    "a página sem conexão se basta (sem script, CSP fechada)",
    semConexao.status === 200 && !htmlSemConexao.includes("<script") && (semConexao.headers.get("content-security-policy") ?? "").startsWith("default-src 'none'"),
    String(semConexao.status),
  );
  const neutro = await fetch(`${BASE}/app/avisos/texto-neutro`);
  const corpoNeutro = neutro.ok ? await neutro.json() : {};
  confere("o texto neutro do push responde (o SW guarda ao instalar)", typeof corpoNeutro.titulo === "string" && typeof corpoNeutro.corpo === "string", String(neutro.status));
  const semConferencia = await fetch(`${BASE}/app/avisos/vinculo`, { method: "POST", headers: { Origin: BASE } });
  confere("não existe conferência de push no servidor", semConferencia.status === 404 || semConferencia.status === 405, String(semConferencia.status));
  const instalar = await fetch(`${BASE}/app/instalar`);
  confere("GET /app/instalar responde 200 e não vai para buscador", instalar.status === 200 && (await instalar.text()).includes('content="noindex"'));
  const fonte = /href="(\/app\/assets\/ProdigySans-Bold-[^"]+\.woff2)"/.exec(html)?.[1];
  confere("a fonte do título é pré-carregada e responde", Boolean(fonte) && (await fetch(`${BASE}${fonte}`)).status === 200, String(fonte));
  confere("a página aponta a imagem de compartilhamento em frilabr.com/app", html.includes('content="https://frilabr.com/app/og-1200x630.png"'));

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
