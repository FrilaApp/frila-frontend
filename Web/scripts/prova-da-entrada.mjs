// Prova de ponta a ponta da entrada (entrar, continuar logado, renovar, sair), contra um Worker ligado ao Supabase
// de dev, com a conta de demonstração. Não imprime e-mail, código nem token: só o que aconteceu.
//
// Uso (com `npx vite preview --port 4317` rodando, ou contra a prévia):
//   node scripts/prova-da-entrada.mjs http://localhost:4317 <arquivo com EMAILS_DE_DEMONSTRACAO=...> <arquivo com o código>
// Os dois arquivos ficam FORA do repositório.
import { readFileSync } from "node:fs";
const BASE = process.argv[2];
const vars = Object.fromEntries(readFileSync(process.argv[3], "utf8").split("\n").filter(Boolean).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
const emails = vars.EMAILS_DE_DEMONSTRACAO.split(",");
const codigo = readFileSync(process.argv[4], "utf8").trim();
const origem = new URL(BASE).origin;
const envio = (caminho, campos, cookies = "") => fetch(`${BASE}${caminho}`, { method: "POST", redirect: "manual", headers: { Origin: origem, "Content-Type": "application/x-www-form-urlencoded", Cookie: cookies }, body: new URLSearchParams(campos) });
const diz = (nome, ok, extra = "") => console.log(`${ok ? "ok  " : "ERRO"} ${nome} ${extra}`);

const tela = await fetch(`${BASE}/app/entrar`);
const htmlDaTela = await tela.text();
diz("GET /app/entrar mostra o formulário de e-mail", tela.status === 200 && htmlDaTela.includes('name="email"') && htmlDaTela.includes('value="pedir"'));

const forjado = await fetch(`${BASE}/app/entrar`, { method: "POST", redirect: "manual", headers: { Origin: "https://outro.example", "Content-Type": "application/x-www-form-urlencoded" }, body: "email=a%40b.co&intencao=pedir" });
diz("POST vindo de outro site é recusado", forjado.status === 403, `(${forjado.status})`);
const semOrigem = await fetch(`${BASE}/app/entrar`, { method: "POST", redirect: "manual", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: "email=a%40b.co&intencao=pedir" });
diz("POST sem origem é recusado", semOrigem.status === 403, `(${semOrigem.status})`);

const invalido = await envio("/app/entrar", { email: "sem-arroba", intencao: "pedir" });
diz("e-mail incompleto volta para o passo do e-mail com aviso", invalido.status === 200 && (await invalido.text()).includes('role="alert"'));

let entrada = null, usado = -1;
for (const [i, email] of emails.entries()) {
  const passo = await envio("/app/entrar", { email, intencao: "pedir" });
  const html = await passo.text();
  if (i === 0) diz("pedir o código leva ao passo do código", passo.status === 200 && html.includes('name="codigo"'));
  const r = await envio("/app/entrar", { email, codigo, intencao: "confirmar" });
  if (r.status === 302) { entrada = r; usado = i; break; }
  console.log(`     conta de demonstração ${i + 1} de ${emails.length}: não entrou (${r.status})`);
}
if (!entrada) { diz("entrar com a conta de demonstração", false); process.exit(1); }
const cookiesGravados = entrada.headers.getSetCookie();
diz("entrar responde 302 para /app/", /\/app\/?$/.test(entrada.headers.get("location") ?? ""), `(conta ${usado + 1})`);
diz("grava 2 cookies, os dois HttpOnly, SameSite=Lax e presos a /app", cookiesGravados.length === 2 && cookiesGravados.every((c) => /; HttpOnly/.test(c) && /; SameSite=Lax/.test(c) && /; Path=\/app/.test(c)));
const cookies = cookiesGravados.map((c) => c.split(";")[0]).join("; ");
const tokenDeAcesso = cookiesGravados[0].split(";")[0].split("=")[1];

const inicio = await fetch(`${BASE}/app/`, { headers: { Cookie: cookies } });
const htmlDoInicio = await inicio.text();
diz("recarregar /app/ continua logado", inicio.status === 200 && htmlDoInicio.includes("Você entrou como"));
diz("a página lê a conta no servidor (minha_conta)", htmlDoInicio.includes("Profissional") || htmlDoInicio.includes("Contratante") || htmlDoInicio.includes("Falta completar"), htmlDoInicio.includes("Profissional") ? "(conta de profissional)" : "");
diz("o token NÃO aparece no HTML nem nos dados da página", !htmlDoInicio.includes(tokenDeAcesso) && !htmlDoInicio.includes(tokenDeAcesso.slice(0, 40)));
const dados = await fetch(`${BASE}/app.data`, { headers: { Cookie: cookies } });
const textoDosDados = await dados.text();
diz("o pedido de dados responde e o token NÃO aparece nele", dados.status === 200 && textoDosDados.includes("entrou") && !textoDosDados.includes(tokenDeAcesso.slice(0, 40)), `(${dados.status})`);
const telaLogado = await fetch(`${BASE}/app/entrar`, { headers: { Cookie: cookies }, redirect: "manual" });
diz("quem já entrou e abre /app/entrar volta ao início", telaLogado.status === 302);

// Renovação: só com o cookie de renovação (como se o de acesso tivesse vencido)
const soRenovacao = cookiesGravados[1].split(";")[0];
const renovado = await fetch(`${BASE}/app/`, { headers: { Cookie: soRenovacao } });
const novos = renovado.headers.getSetCookie();
diz("sem o cookie de acesso, a sessão é renovada e os cookies regravados", (await renovado.text()).includes("Você entrou como") && novos.length === 2 && novos.every((c) => /; HttpOnly/.test(c)));
const cookiesNovos = novos.map((c) => c.split(";")[0]).join("; ");

const saida = await envio("/app/sair", {}, cookiesNovos);
const apagados = saida.headers.getSetCookie();
diz("sair responde 302 para /app/entrar e apaga os 2 cookies", saida.status === 302 && saida.headers.get("location")?.endsWith("/app/entrar") === true && apagados.length === 2 && apagados.every((c) => /Max-Age=0/.test(c)));
const depois = await fetch(`${BASE}/app/`, { headers: { Cookie: soRenovacao.replace(/=.*/, "=" + novos[1].split(";")[0].split("=")[1]) } });
diz("depois de sair, o token de renovação não entra mais", !(await depois.text()).includes("Você entrou como"));
const semCookie = await fetch(`${BASE}/app/`);
diz("sem cookie, a página mostra Entrar", (await semCookie.text()).includes('href="/app/entrar"'));
