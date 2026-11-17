// Orçamento do pacote: o JavaScript que cada rota baixa na primeira carga (entrada + rotas-mãe + a rota),
// comprimido com gzip, não pode passar do limite. Roda depois de `npm run build`.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { gzipSync } from "node:zlib";

const LIMITE_KB = 150;
const pastaDoCliente = "build/client";
const pastaDosArquivos = join(pastaDoCliente, "app/assets");

const arquivoDoManifesto = readdirSync(pastaDosArquivos).find((nome) => /^manifest-.*\.js$/.test(nome));
if (!arquivoDoManifesto) {
  console.error("erro: manifesto do React Router não encontrado. Rode `npm run build` antes.");
  process.exit(1);
}
const texto = readFileSync(join(pastaDosArquivos, arquivoDoManifesto), "utf8");
const manifesto = JSON.parse(texto.slice(texto.indexOf("{"), texto.lastIndexOf("}") + 1));

const tamanhos = new Map();
function kbComprimido(url) {
  if (!tamanhos.has(url)) {
    tamanhos.set(url, gzipSync(readFileSync(join(pastaDoCliente, url))).length / 1024);
  }
  return tamanhos.get(url);
}

function arquivosDaRota(id) {
  const arquivos = new Set([manifesto.entry.module, ...manifesto.entry.imports]);
  for (let rota = manifesto.routes[id]; rota; rota = manifesto.routes[rota.parentId]) {
    arquivos.add(rota.module);
    for (const importado of rota.imports ?? []) arquivos.add(importado);
  }
  return [...arquivos];
}

let estourou = false;
for (const id of Object.keys(manifesto.routes)) {
  const total = arquivosDaRota(id).reduce((soma, url) => soma + kbComprimido(url), 0);
  const passou = total <= LIMITE_KB;
  if (!passou) estourou = true;
  console.log(`${passou ? "ok  " : "ERRO"} ${id}: ${total.toFixed(1)} KB (limite ${LIMITE_KB} KB)`);
}
process.exit(estourou ? 1 : 0);
