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
const seguro = new URL(BASE).protocol === "https:";

// Pote de cookies como o do navegador (RFC 6265): guarda o que o Worker grava e só manda cada cookie aos caminhos
// que o Path dele cobre. Nada de montar o cabeçalho Cookie à mão: foi assim que o /app.data sem sessão passou batido.
const pote = new Map();
const caminhoCasa = (doCookie, doPedido) => doPedido === doCookie || (doPedido.startsWith(doCookie) && (doCookie.endsWith("/") || doPedido[doCookie.length] === "/"));
function guardar(resposta) {
  for (const linha of resposta.headers.getSetCookie()) {
    const [par, ...atributos] = linha.split(";").map((parte) => parte.trim());
    const nome = par.slice(0, par.indexOf("="));
    const attr = Object.fromEntries(atributos.map((a) => [a.split("=")[0].toLowerCase(), a.split("=")[1] ?? ""]));
    if (attr.domain !== undefined) throw new Error(`cookie ${nome} com Domain: a sessão tem de ficar presa ao host`);
    if (nome.startsWith("__Host-") && (!("secure" in attr) || attr.path !== "/")) throw new Error(`cookie ${nome} quebra a regra do __Host-`);
    if (attr["max-age"] === "0") pote.delete(nome);
    else pote.set(nome, { valor: par.slice(par.indexOf("=") + 1), caminho: attr.path ?? "/", seguro: "secure" in attr });
  }
  return resposta;
}
const cookiesPara = (caminho) => [...pote].filter(([, c]) => caminhoCasa(c.caminho, caminho) && (!c.seguro || seguro)).map(([n, c]) => `${n}=${c.valor}`).join("; ");
const pedir = async (caminho, opcoes = {}) => guardar(await fetch(`${BASE}${caminho}`, { redirect: "manual", ...opcoes, headers: { ...opcoes.headers, Cookie: cookiesPara(caminho) } }));
const envio = (caminho, campos) => pedir(caminho, { method: "POST", headers: { Origin: origem, "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams(campos) });
const nomeDe = (parte) => [...pote.keys()].find((n) => n.endsWith(`frila-${parte}`));
const diz = (nome, ok, extra = "") => console.log(`${ok ? "ok  " : "ERRO"} ${nome} ${extra}`);

const tela = await pedir("/app/entrar");
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
diz("grava 2 cookies, os dois HttpOnly, SameSite=Lax e Path=/", cookiesGravados.length === 2 && cookiesGravados.every((c) => /; HttpOnly/.test(c) && /; SameSite=Lax/.test(c) && /; Path=\/;/.test(c)));
if (seguro) diz("em HTTPS os cookies são __Host- e Secure", cookiesGravados.every((c) => c.startsWith("__Host-") && /; Secure/.test(c)));
const tokenDeAcesso = pote.get(nomeDe("acesso")).valor;

const inicio = await pedir("/app/");
const htmlDoInicio = await inicio.text();
diz("recarregar /app/ continua logado", inicio.status === 200 && htmlDoInicio.includes("Você entrou como"));
diz("a página lê a conta no servidor (minha_conta)", htmlDoInicio.includes("Profissional") || htmlDoInicio.includes("Contratante") || htmlDoInicio.includes("Falta completar"), htmlDoInicio.includes("Profissional") ? "(conta de profissional)" : "");
diz("o token NÃO aparece no HTML nem nos dados da página", !htmlDoInicio.includes(tokenDeAcesso) && !htmlDoInicio.includes(tokenDeAcesso.slice(0, 40)));
diz("o navegador manda a sessão a /app.data (o Path cobre)", cookiesPara("/app.data").includes(nomeDe("acesso")));
const dados = await pedir("/app.data");
const textoDosDados = await dados.text();
diz("o pedido de dados chega logado e o token NÃO aparece nele", dados.status === 200 && textoDosDados.includes("entrou") && !textoDosDados.includes(tokenDeAcesso.slice(0, 40)), `(${dados.status})`);
const telaLogado = await pedir("/app/entrar");
diz("quem já entrou e abre /app/entrar volta ao início", telaLogado.status === 302);

// Renovação: o cookie de acesso some do pote (como se tivesse vencido no navegador)
pote.delete(nomeDe("acesso"));
const renovado = await pedir("/app/");
const novos = renovado.headers.getSetCookie();
diz("sem o cookie de acesso, a sessão é renovada e os cookies regravados", (await renovado.text()).includes("Você entrou como") && novos.length === 2 && novos.every((c) => /; HttpOnly/.test(c)));
// Guarda a sessão renovada: é o que uma resposta atrasada regravaria depois do sair.
const regravadaDepois = new Map([...pote].filter(([n]) => /frila-(acesso|renovacao)$/.test(n)));

const saida = await envio("/app/sair", {});
const linhasDaSaida = saida.headers.getSetCookie();
const apagados = linhasDaSaida.filter((c) => /frila-(acesso|renovacao)=/.test(c));
diz("sair responde 302 para /app/entrar e apaga os 2 cookies", saida.status === 302 && saida.headers.get("location")?.endsWith("/app/entrar") === true && apagados.length === 2 && apagados.every((c) => /Max-Age=0/.test(c)));
// Repetir o token de renovação velho à mão é de propósito: é o que alguém com o cookie copiado tentaria.
const [nomeDaRenovacao, renovacaoVelha] = [...regravadaDepois].find(([n]) => n.endsWith("renovacao"));
const somenteRenovacaoVelha = await fetch(`${BASE}/app/`, { headers: { Cookie: `${nomeDaRenovacao}=${renovacaoVelha.valor}` } });
diz("depois de sair, o token de renovação não entra mais", !(await somenteRenovacaoVelha.text()).includes("Você entrou como"));
// Resposta atrasada: os cookies da sessão renovada voltam ao pote depois do sair. O Auth sabe que ela foi encerrada.
for (const [nome, cookie] of regravadaDepois) pote.set(nome, cookie);
const aposAtrasada = await pedir("/app/");
diz("resposta atrasada que regrava a sessão depois do sair não reativa a conta", !(await aposAtrasada.text()).includes("Você entrou como") && aposAtrasada.headers.getSetCookie().some((c) => /frila-acesso=;.*Max-Age=0/.test(c)));
pote.clear();
const semCookie = await pedir("/app/");
diz("sem cookie, a página mostra Entrar", (await semCookie.text()).includes('href="/app/entrar"'));
