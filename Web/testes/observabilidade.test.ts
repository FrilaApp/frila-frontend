/**
 * Achado de segurança (Bússola, 17/11): os logs de invocação dos Workers guardam os cabeçalhos do pedido, e o Cookie
 * carrega a sessão. Estes testes garantem que eles ficam desligados nos 2 ambientes e que nenhum log do código leva
 * cabeçalho, cookie, authorization, token, IP ou e-mail (Política de Privacidade: o log do Worker não leva dado pessoal;
 * parecer P-072 da Bússola, 24/11).
 */
import { describe, expect, it } from "vitest";

import textoDoWrangler from "../wrangler.jsonc?raw";

const fontes = import.meta.glob<string>(["../app/**/*.{ts,tsx}", "../workers/**/*.ts", "../public/**/*.js"], { query: "?raw", import: "default", eager: true });

const consoles = /console\s*\.\s*(log|info|warn|error|debug|trace)\s*\(/g;

/**
 * Lê do `(` que abre a chamada até o `)` que a FECHA: conta parênteses e pula texto entre aspas, crase (com `${}`) e
 * comentários, então `f(x), token` e chamadas em várias linhas entram inteiras. Devolve o texto dos argumentos.
 */
function argumentosAte(fonte: string, abre: number): string {
  let nivel = 0;
  const lerTexto = (inicio: number, aspa: string): number => {
    let i = inicio + 1;
    for (; i < fonte.length && fonte[i] !== aspa; i++) {
      if (fonte[i] === "\\") i++;
      else if (aspa === "`" && fonte[i] === "$" && fonte[i + 1] === "{") i = lerExpressao(i + 2);
    }
    return i;
  };
  /** Dentro de `${ ... }`: devolve a posição do `}` que fecha. */
  const lerExpressao = (inicio: number): number => {
    let chaves = 1;
    let i = inicio;
    for (; i < fonte.length && chaves > 0; i++) {
      const c = fonte[i];
      if (c === "{") chaves++;
      else if (c === "}") {
        if (--chaves === 0) break;
      } else if (c === '"' || c === "'" || c === "`") i = lerTexto(i, c);
    }
    return i;
  };
  for (let i = abre; i < fonte.length; i++) {
    const c = fonte[i];
    if (c === "(") nivel++;
    else if (c === ")") {
      if (--nivel === 0) return fonte.slice(abre + 1, i);
    } else if (c === '"' || c === "'" || c === "`") i = lerTexto(i, c);
    else if (c === "/" && fonte[i + 1] === "/") i = fonte.indexOf("\n", i) < 0 ? fonte.length : fonte.indexOf("\n", i);
    else if (c === "/" && fonte[i + 1] === "*") i = fonte.indexOf("*/", i + 2) < 0 ? fonte.length : fonte.indexOf("*/", i + 2) + 1;
  }
  return fonte.slice(abre + 1);
}

/** Cada `console.*(...)` do arquivo, com o argumento inteiro. */
function chamadasDeConsole(fonte: string): { metodo: string; trecho: string; argumentos: string }[] {
  return [...fonte.matchAll(consoles)].map((achado) => {
    const abre = (achado.index ?? 0) + achado[0].length - 1;
    const argumentos = argumentosAte(fonte, abre);
    return { metodo: achado[1] ?? "", trecho: `${achado[0]}${argumentos})`, argumentos };
  });
}

const palavrasSensiveis = /header|cabe[cç]alho|cookie|authorization|request|pedido|token|acesso|sess[aã]o|e-?mail|connecting/i;

/** `ip` só vale como palavra inteira ou pedaço de identificador (`cliente.ip`, `ipDoCliente`, `CF-Connecting-IP`): nunca em `tipo` ou `script`. */
function temIp(texto: string): boolean {
  const separado = texto.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2");
  return separado.toLowerCase().split(/[^a-z0-9]+/).some((palavra) => /^ipv?[46]?$/.test(palavra));
}

function levaDadoSensivel(argumentos: string): boolean {
  return palavrasSensiveis.test(argumentos) || temIp(argumentos);
}

/** Código que roda no Worker: com SSR, o app inteiro (loaders, actions e componentes) e o `workers/` (o lint `no-console` do eslint.config.js usa o mesmo recorte). */
const ehServidor = (arquivo: string) => /^\.\.\/(app|workers)\//.test(arquivo);

/** Tira os comentários do JSONC sem mexer no que está dentro de aspas. */
function semComentarios(texto: string): string {
  let saida = "";
  for (let i = 0, emTexto = false; i < texto.length; i++) {
    const c = texto[i] ?? "";
    if (emTexto) {
      saida += c;
      if (c === "\\") saida += texto[++i] ?? "";
      else if (c === '"') emTexto = false;
    } else if (c === '"') {
      emTexto = true;
      saida += c;
    } else if (c === "/" && texto[i + 1] === "/") {
      while (i < texto.length && texto[i] !== "\n") i++;
      saida += "\n";
    } else if (c === "/" && texto[i + 1] === "*") {
      i = texto.indexOf("*/", i + 2) + 1;
    } else saida += c;
  }
  return saida.replace(/,(\s*[}\]])/g, "$1");
}

type Observabilidade = { enabled?: boolean; logs?: { invocation_logs?: boolean } };
const config = JSON.parse(semComentarios(textoDoWrangler)) as { observability?: Observabilidade; env?: Record<string, { observability?: Observabilidade }> };

describe("logs do Worker sem cabeçalho do pedido", () => {
  it("os logs de invocação ficam desligados no dev e em produção", () => {
    expect(config.observability?.logs?.invocation_logs).toBe(false);
    expect(Object.keys(config.env ?? {})).toContain("producao");
    for (const [nome, ambiente] of Object.entries(config.env ?? {})) {
      expect(ambiente.observability?.logs?.invocation_logs, nome).toBe(false);
    }
  });

  it("nenhum console.* do código recebe cabeçalho, pedido, cookie, authorization, token, IP ou e-mail", () => {
    const suspeitos = Object.entries(fontes).flatMap(([arquivo, fonte]) =>
      chamadasDeConsole(fonte)
        .filter((chamada) => levaDadoSensivel(chamada.argumentos))
        .map((chamada) => `${arquivo}: ${chamada.trecho}`),
    );
    expect(suspeitos).toEqual([]);
  });

  it("o código que roda no Worker (app inteiro, por SSR) só usa console.error", () => {
    const servidor = Object.entries(fontes).filter(([arquivo]) => ehServidor(arquivo));
    expect(servidor.length).toBeGreaterThan(10);
    const soltos = servidor.flatMap(([arquivo, fonte]) =>
      chamadasDeConsole(fonte)
        .filter((chamada) => chamada.metodo !== "error")
        .map((chamada) => `${arquivo}: ${chamada.trecho}`),
    );
    expect(soltos).toEqual([]);
  });
});

describe("a guarda de log pega o que deve e deixa passar o resto", () => {
  it("pega IP como palavra ou pedaço de identificador, e não confunde com tipo, script ou participante", () => {
    for (const texto of ["ip", "cliente.ip", "ipDoCliente", "cf-connecting-ip", '"CF-Connecting-IP"', "IPDoCliente", "enderecoIp", "ipv4"]) {
      expect(levaDadoSensivel(texto), texto).toBe(true);
    }
    for (const texto of ["tipo", "script", "descricao", "participante", "erro.message", "String(erro)", "disponivel"]) {
      expect(levaDadoSensivel(texto), texto).toBe(false);
    }
  });

  it("pega e-mail em qualquer escrita, além de token, authorization e cabeçalho", () => {
    for (const texto of ["email", "e-mail", "eMail", "emailDoUsuario", "token", "authorization", "cabeçalho", "pedido.headers", "sessão"]) {
      expect(levaDadoSensivel(texto), texto).toBe(true);
    }
  });

  it("lê o argumento até o parêntese que FECHA a chamada, em várias linhas e com texto entre aspas ou crase", () => {
    const fonte = [
      "console.error(montar(a), token);",
      'console.error("fecha ) dentro do texto", cliente.ip);',
      "console.error(`falha (${f(email)}) ok`);",
      "console.error(",
      '  "cabeçalho",',
      '  pedido.headers.get("CF-Connecting-IP"),',
      ");",
      "console.error(erro.message);",
    ].join("\n");
    expect(chamadasDeConsole(fonte).map((chamada) => levaDadoSensivel(chamada.argumentos))).toEqual([true, true, true, true, false]);
    expect(chamadasDeConsole(fonte)[0]?.argumentos).toBe("montar(a), token");
    expect(chamadasDeConsole(fonte)[4]?.argumentos).toBe("erro.message");
  });
});
