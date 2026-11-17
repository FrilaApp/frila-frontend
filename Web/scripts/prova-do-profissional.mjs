// Prova de ponta a ponta das telas do profissional (vagas perto, detalhe, candidatar e retirar), contra um Worker ligado ao Supabase de dev,
// com as contas de demonstração. Não imprime e-mail, código nem token: só o que aconteceu.
//
// Uso (com `npx vite preview --port 4317` rodando, ou contra a prévia):
//   node scripts/prova-do-profissional.mjs <endereço> <.dev.vars> <arquivo com EMAILS_DE_DEMONSTRACAO=...> <arquivo do código> <arquivo da casa de demonstração>
// Os arquivos ficam FORA do repositório (o .dev.vars é ignorado pelo git).
import { readFileSync } from "node:fs";

const [BASE, arquivoDoAmbiente, arquivoDosEmails, arquivoDoCodigo, arquivoDaCasa] = process.argv.slice(2);
const chaves = (p) => Object.fromEntries(readFileSync(p, "utf8").split("\n").filter((l) => l.includes("=")).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
const ambiente = chaves(arquivoDoAmbiente);
const emails = chaves(arquivoDosEmails).EMAILS_DE_DEMONSTRACAO.split(",");
const codigo = readFileSync(arquivoDoCodigo, "utf8").trim();
const emailDaCasa = /e-mail:\s*`?([^\s`]+@[^\s`]+)`?/.exec(readFileSync(arquivoDaCasa, "utf8"))?.[1];
const origem = new URL(BASE).origin;
const prefixo = new URL(BASE).protocol === "https:" ? "__Host-" : "";
const diz = (nome, ok, extra = "") => console.log(`${ok ? "ok  " : "ERRO"} ${nome} ${extra}`);

// Pote de cookies mínimo (o Worker grava com Path=/).
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

const semSessao = await fetch(`${BASE}/app/vagas`, { redirect: "manual" });
diz("sem sessão, /app/vagas manda entrar", semSessao.status === 302 && /\/app\/entrar$/.test(semSessao.headers.get("location") ?? ""));

let entrou = false;
for (const email of emails) {
  await envio("/app/entrar", { email, intencao: "pedir" });
  const r = await envio("/app/entrar", { email, codigo, intencao: "confirmar" });
  if (r.status === 302) { entrou = true; break; }
}
diz("a profissional de demonstração entra", entrou);
if (!entrou) process.exit(1);
const acesso = pote.get(`${prefixo}frila-acesso`) ?? "";

const inicio = await (await pedir("/app/")).text();
diz("o início mostra o caminho para as vagas", inicio.includes('href="/app/vagas"'));
diz("o início mostra o caminho para os turnos", inicio.includes('href="/app/turnos"'));
const turnos = await pedir("/app/turnos");
const htmlDosTurnos = await turnos.text();
diz("Meus turnos abre", turnos.status === 200 && htmlDosTurnos.includes("Meus turnos"));
const turnoAlheio = await pedir("/app/turnos/00000000-0000-4000-8000-000000000000");
diz("turno que não é da pessoa responde 404", turnoAlheio.status === 404);

const lista = await pedir("/app/vagas");
const htmlDaLista = await lista.text();
const ids = [...htmlDaLista.matchAll(/href="\/app\/vagas\/([0-9a-f-]{36})"/g)].map((m) => m[1]);
diz("a lista abre e mostra vagas abertas", lista.status === 200 && ids.length > 0, `(${ids.length} vagas)`);
diz("o token não aparece na lista", acesso.length > 20 && !htmlDaLista.includes(acesso.slice(0, 40)));
diz("a lista não pede a posição do navegador", !htmlDaLista.includes("geolocation"));
const filtrada = await pedir("/app/vagas?distancia=5");
diz("o filtro de distância responde", filtrada.status === 200 && (await filtrada.text()).includes('value="5" selected'));

if (ids.length > 0) {
  const vaga = await pedir(`/app/vagas/${ids[0]}`);
  const htmlDaVaga = await vaga.text();
  diz("o detalhe da primeira vaga abre", vaga.status === 200 && htmlDaVaga.includes("Quem recebe no local"));
  diz("o token não aparece no detalhe", !htmlDaVaga.includes(acesso.slice(0, 40)));
}
const inexistente = await pedir("/app/vagas/00000000-0000-4000-8000-000000000000");
diz("vaga que não existe responde 404", inexistente.status === 404 && (await inexistente.text()).includes("Vaga não encontrada"));
const torta = await pedir("/app/vagas/nao-e-um-id");
diz("endereço torto responde 404", torta.status === 404);

// Candidatar e retirar, numa vaga do modo seleção (fica pendente; retirar não tem penalidade).
// Vaga do modo urgência confirmaria o turno na hora: essa fica para a prova dos turnos.
const itens = [...htmlDaLista.matchAll(/<li>(.*?)<\/li>/gs)].map((m) => m[1]);
const selecao = itens.find((item) => item.includes("A casa escolhe entre os candidatos"));
const idDaSelecao = selecao ? /href="\/app\/vagas\/([0-9a-f-]{36})"/.exec(selecao)?.[1] : null;
if (idDaSelecao) {
  const antes = await (await pedir(`/app/vagas/${idDaSelecao}`)).text();
  const jaTinha = antes.includes("Você se candidatou");
  if (jaTinha) {
    await envio(`/app/vagas/${idDaSelecao}`, { intencao: "retirar", candidatura_id: /name="candidatura_id" value="([0-9a-f-]{36})"/.exec(antes)?.[1] ?? "" });
  }
  const candidatou = await envio(`/app/vagas/${idDaSelecao}`, { intencao: "candidatar" });
  const htmlCandidatou = await candidatou.text();
  diz("candidatar numa vaga do modo seleção: fica pendente", candidatou.status === 200 && htmlCandidatou.includes("Candidatura enviada"));
  const minhas = await (await pedir("/app/candidaturas")).text();
  diz("a candidatura aparece em Minhas candidaturas, aguardando a casa", minhas.includes(`href="/app/vagas/${idDaSelecao}"`) && minhas.includes("Aguardando a casa"));
  const repetida = await envio(`/app/vagas/${idDaSelecao}`, { intencao: "candidatar" });
  diz("candidatar de novo responde como a primeira", repetida.status === 200 && (await repetida.text()).includes("Candidatura enviada"));
  // Não duplicou: em Minhas candidaturas, continua UMA candidatura desta vaga, e pendente.
  const depoisDaRepeticao = await (await pedir("/app/candidaturas")).text();
  const daVaga = [...depoisDaRepeticao.matchAll(/<li>(.*?)<\/li>/gs)].map((m) => m[1]).filter((item) => item.includes(`href="/app/vagas/${idDaSelecao}"`));
  diz("candidatar de novo não duplica: segue 1 candidatura desta vaga, pendente", daVaga.length === 1 && daVaga[0].includes("Aguardando a casa"), `(${daVaga.length})`);
  const idDaCandidatura = /name="candidatura_id" value="([0-9a-f-]{36})"/.exec(htmlCandidatou)?.[1] ?? "";
  const retirou = await envio(`/app/vagas/${idDaSelecao}`, { intencao: "retirar", candidatura_id: idDaCandidatura });
  diz("retirar a candidatura", retirou.status === 200 && (await retirou.text()).includes("Candidatura retirada"));
} else {
  diz("há vaga do modo seleção para provar o candidatar", false, "(nenhuma na lista)");
}

// Perfil: lê e salva de volta os MESMOS textos (exercita a escrita sem mudar a conta de demonstração).
const desfazer = (texto) => texto.replace(/&#x27;|&#39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
const telaDoPerfil = await pedir("/app/perfil");
const htmlDoPerfil = await telaDoPerfil.text();
diz("Meu perfil abre com as funções", telaDoPerfil.status === 200 && htmlDoPerfil.includes("Funções"));
diz("o perfil não manda ponto base ao navegador", !/latitude|longitude|ponto_base/.test(htmlDoPerfil));
const textoDe = (nome) => {
  const achado = new RegExp(`<textarea[^>]*name="${nome}"[^>]*>([\\s\\S]*?)</textarea>`).exec(htmlDoPerfil);
  return achado ? desfazer(achado[1]) : null;
};
const atuais = { apresentacao: textoDe("apresentacao"), onde_trabalhei: textoDe("onde_trabalhei") };
// Trava: sem ler os dois textos, não salva (mandar vazio apagaria o perfil da conta de demonstração).
if (atuais.apresentacao !== null && atuais.onde_trabalhei !== null) {
  const salvou = await envio("/app/perfil", atuais);
  const htmlSalvo = await salvou.text();
  diz("salvar o perfil (com os mesmos textos)", salvou.status === 200 && htmlSalvo.includes("Perfil salvo."), htmlSalvo.includes("não está disponível") ? "(perfil rico desligado no dev)" : "");
} else {
  diz("ler os textos do perfil antes de salvar", false, "(não salvou nada)");
}

const saida = await envio("/app/sair", {});
diz("a profissional sai", saida.status === 302);

// A casa de demonstração entra direto pelo Auth (a web só aceita como demonstração os e-mails da lista do dev).
// Os cookies montados aqui são os que o Worker gravaria.
const publica = { apikey: ambiente.SUPABASE_CHAVE_PUBLICAVEL, Authorization: `Bearer ${ambiente.SUPABASE_CHAVE_PUBLICAVEL}`, "Content-Type": "application/json" };
const casa = emailDaCasa
  ? await fetch(`${ambiente.SUPABASE_URL}/functions/v1/entrar-demonstracao`, { method: "POST", headers: publica, body: JSON.stringify({ email: emailDaCasa, codigo }) })
  : null;
if (casa?.ok) {
  const sessao = await casa.json();
  pote.clear();
  pote.set(`${prefixo}frila-acesso`, sessao.access_token);
  pote.set(`${prefixo}frila-renovacao`, sessao.refresh_token);
  const recusa = await (await pedir("/app/vagas")).text();
  diz("conta de contratante vê o aviso de que a área é de quem trabalha", recusa.includes("A sua conta é de contratante"));
  await fetch(`${ambiente.SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ambiente.SUPABASE_CHAVE_PUBLICAVEL, Authorization: `Bearer ${sessao.access_token}` } });
} else {
  diz("a casa de demonstração entra", false, `(${casa?.status ?? "sem e-mail no arquivo"})`);
}
