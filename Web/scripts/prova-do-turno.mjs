// Prova de ponta a ponta de um turno do profissional, contra um Worker ligado ao Supabase de dev: candidatar numa vaga
// de urgência → o turno aparece → estou a caminho → cheguei → código da casa → presença confirmada → encerrar o turno.
// Usa uma vaga montada para isso na casa de demonstração. Não imprime e-mail, código nem token.
//
// Uso: node scripts/prova-do-turno.mjs <endereço> <.dev.vars> <arquivo com EMAILS_DE_DEMONSTRACAO=...> <arquivo do código>
//        <arquivo da casa de demonstração> <id da vaga de urgência> [distância em metros]
// A distância faz o papel da medida do navegador no toque (a prova não tem navegador); o padrão é 20 m.
import { readFileSync } from "node:fs";

import { turnoDaVaga } from "./turno-da-vaga.mjs";

const [BASE, arquivoDoAmbiente, arquivoDosEmails, arquivoDoCodigo, arquivoDaCasa, VAGA_ID, distancia = "20"] = process.argv.slice(2);
const chaves = (p) => Object.fromEntries(readFileSync(p, "utf8").split("\n").filter((l) => l.includes("=")).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
const ambiente = chaves(arquivoDoAmbiente);
const emails = chaves(arquivoDosEmails).EMAILS_DE_DEMONSTRACAO.split(",");
const codigoDeEntrada = readFileSync(arquivoDoCodigo, "utf8").trim();
const emailDaCasa = /e-mail:\s*`?([^\s`]+@[^\s`]+)`?/.exec(readFileSync(arquivoDaCasa, "utf8"))?.[1];
const origem = new URL(BASE).origin;
const diz = (nome, ok, extra = "") => console.log(`${ok ? "ok  " : "ERRO"} ${nome} ${extra}`);
// Sem a vaga certa (ou com um id fixo de demonstração, de000000-…), a prova nem começa: ela só toca o turno da vaga dada.
const antes = turnoDaVaga([], VAGA_ID).recusa;
if (antes === "vaga_invalida" || antes === "dado_fixo_de_demonstracao") {
  console.log(`ERRO recusado (${antes}): o id da vaga é obrigatório, precisa ser um uuid e não pode ser de dado fixo de demonstração; a prova não age em nenhum turno`);
  process.exit(1);
}

const pote = new Map();
const guardar = (r) => {
  for (const linha of r.headers.getSetCookie()) {
    const par = linha.split(";")[0];
    const nome = par.slice(0, par.indexOf("="));
    if (/Max-Age=0/.test(linha)) pote.delete(nome);
    else pote.set(nome, par.slice(par.indexOf("=") + 1));
  }
  return r;
};
const cookies = () => [...pote].map(([n, v]) => `${n}=${v}`).join("; ");
const pedir = async (caminho, opcoes = {}) => guardar(await fetch(`${BASE}${caminho}`, { redirect: "manual", ...opcoes, headers: { ...opcoes.headers, Cookie: cookies() } }));
const envio = (caminho, campos) => pedir(caminho, { method: "POST", headers: { Origin: origem, "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams(campos) });

let entrou = false;
for (const email of emails) {
  await envio("/app/entrar", { email, intencao: "pedir" });
  if ((await envio("/app/entrar", { email, codigo: codigoDeEntrada, intencao: "confirmar" })).status === 302) { entrou = true; break; }
}
diz("a profissional de demonstração entra", entrou);
if (!entrou) process.exit(1);

const vaga = await (await pedir(`/app/vagas/${VAGA_ID}`)).text();
diz("a vaga de urgência abre com o botão 'Quero este turno'", vaga.includes("Quero este turno") || vaga.includes("Você foi escolhido"));
if (vaga.includes("Quero este turno")) {
  const candidatou = await (await envio(`/app/vagas/${VAGA_ID}`, { intencao: "candidatar" })).text();
  diz("candidatar numa vaga de urgência confirma o turno na hora", candidatou.includes("Pronto: o turno é seu."));
}

// O turno sai pela vaga dada (meus_turnos, com o token da sessão que a web gravou no pote; não é impresso), e
// nunca pelo primeiro da lista. Sem turno desta vaga, ou com mais de um de pé, a prova recusa e não toca em nada.
const acesso = pote.get("__Host-frila-acesso") ?? pote.get("frila-acesso");
const leitura = acesso
  ? await fetch(`${ambiente.SUPABASE_URL}/rest/v1/rpc/meus_turnos`, { headers: { apikey: ambiente.SUPABASE_CHAVE_PUBLICAVEL, Authorization: `Bearer ${acesso}` } })
  : null;
const escolha = turnoDaVaga(leitura?.ok ? await leitura.json() : null, VAGA_ID);
const turnoId = "turnoId" in escolha ? escolha.turnoId : null;
const lista = turnoId ? await (await pedir("/app/turnos")).text() : "";
diz("o turno DESTA vaga aparece em Meus turnos", Boolean(turnoId) && lista.includes(`href="/app/turnos/${turnoId}"`), turnoId ? "" : `(recusado: ${escolha.recusa})`);
if (!turnoId || !lista.includes(`href="/app/turnos/${turnoId}"`)) {
  await envio("/app/sair", {});
  process.exit(1);
}

const tela = async () => (await pedir(`/app/turnos/${turnoId}`)).text();
let html = await tela();
if (html.includes("Estou a caminho")) {
  const aviso = await (await envio(`/app/turnos/${turnoId}`, { intencao: "a_caminho", turno_id: turnoId })).text();
  diz("estou a caminho", aviso.includes("A casa foi avisada"));
  html = await tela();
}
if (html.includes(">Cheguei<")) {
  const chegada = await (await envio(`/app/turnos/${turnoId}`, { intencao: "chegar", turno_id: turnoId, distancia_m: distancia })).text();
  diz("cheguei: chegada registrada, presença pendente do código", chegada.includes("Chegada registrada") || chegada.includes("Presença confirmada"));
  html = await tela();
}

if (html.includes('name="codigo"')) {
  // A casa gera o código do turno (entrando direto pelo Auth, só nesta prova).
  const publica = { apikey: ambiente.SUPABASE_CHAVE_PUBLICAVEL, Authorization: `Bearer ${ambiente.SUPABASE_CHAVE_PUBLICAVEL}`, "Content-Type": "application/json" };
  const entrada = await fetch(`${ambiente.SUPABASE_URL}/functions/v1/entrar-demonstracao`, { method: "POST", headers: publica, body: JSON.stringify({ email: emailDaCasa, codigo: codigoDeEntrada }) });
  const casa = entrada.ok ? await entrada.json() : null;
  const daCasa = casa ? { ...publica, Authorization: `Bearer ${casa.access_token}` } : null;
  const gerado = daCasa ? await fetch(`${ambiente.SUPABASE_URL}/rest/v1/rpc/gerar_codigo_checkin`, { method: "POST", headers: daCasa, body: JSON.stringify({ turno_id: turnoId }) }) : null;
  const codigo = gerado?.ok ? (await gerado.json()).codigo : null;
  diz("a casa gera o código do turno", Boolean(codigo), gerado?.ok ? "" : `(${gerado?.status ?? "a casa não entrou"})`);
  if (codigo) {
    const errado = await (await envio(`/app/turnos/${turnoId}`, { intencao: "validar", turno_id: turnoId, codigo: "000000" === codigo ? "111111" : "000000", distancia_m: distancia })).text();
    diz("código errado é recusado com o aviso", errado.includes("Código errado ou vencido"));
    const certo = await (await envio(`/app/turnos/${turnoId}`, { intencao: "validar", turno_id: turnoId, codigo, distancia_m: distancia })).text();
    diz("código certo confirma a presença", certo.includes("Presença confirmada"));
  }
  if (casa) await fetch(`${ambiente.SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ambiente.SUPABASE_CHAVE_PUBLICAVEL, Authorization: `Bearer ${casa.access_token}` } });
  html = await tela();
}

if (html.includes("Encerrar o turno")) {
  const saida = await (await envio(`/app/turnos/${turnoId}`, { intencao: "encerrar", turno_id: turnoId, distancia_m: distancia })).text();
  diz("encerrar o turno: saída registrada", saida.includes("Saída registrada"));
}
const fim = await tela();
diz("o turno mostra a saída registrada", fim.includes("Saída registrada"));
// A avaliação só abre depois do fim previsto (o servidor diz em pode_avaliar): rode de novo depois do fim.
if (fim.includes("Você trabalharia nesse local de novo?")) {
  const avaliou = await (await envio(`/app/turnos/${turnoId}`, { intencao: "avaliar", turno_id: turnoId, resposta: "sim" })).text();
  diz("avaliar a casa depois do turno", avaliou.includes("Sua resposta foi registrada"));
} else if (fim.includes("Sua resposta:")) {
  diz("a avaliação já dada aparece no turno", true);
} else {
  console.log("     a avaliação ainda não abriu (abre depois do fim previsto do turno)");
}
await envio("/app/sair", {});
