import { describe, expect, it } from "vitest";

import { fotoDoPerfil, LIMITE_DA_FOTO } from "../app/servidor/contratante/foto-do-perfil";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const PRO = "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d";
const LINK = "https://exemplo.supabase.co/functions/v1/ler-midia?midia_id=m1&token=" + "a".repeat(64);
/** A sessão que a rota entrega: o token e o IP do visitante (aqui sem IP: nada é assinado). */
const sessao = (acesso: string) => ({ acesso, visitante: null });
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

/** Servidor de mentira: o perfil por POST e a miniatura no link da ler-midia. */
function servidor(opcoes: { link?: string | null; foto?: () => Response } = {}) {
  const pedidos: Request[] = [];
  const fetch = async (entrada: RequestInfo | URL, inicio?: RequestInit) => {
    const pedido = new Request(entrada, inicio);
    pedidos.push(pedido);
    if (new URL(pedido.url).pathname === "/rest/v1/rpc/perfil_publico") {
      return Response.json({ id: PRO, tipo: "profissional", nome: "P", reputacao: {}, ...(opcoes.link === null ? {} : { foto_url: opcoes.link ?? LINK }) });
    }
    return opcoes.foto ? opcoes.foto() : new Response(JPEG, { headers: { "Content-Type": "image/jpeg" } });
  };
  return { fetch: fetch as typeof globalThis.fetch, pedidos };
}

describe("foto do perfil, embutida pelo Worker (sem token no navegador)", () => {
  it("pede o perfil por POST com o token da casa e devolve a miniatura como data:", async () => {
    const { fetch, pedidos } = servidor();
    const foto = await fotoDoPerfil(ambiente, sessao("token-da-casa"), PRO, { buscar: fetch });
    expect(foto).toBe(`data:image/jpeg;base64,${btoa(String.fromCharCode(...JPEG))}`);
    expect(pedidos[0]?.method).toBe("POST");
    expect(await pedidos[0]?.json()).toEqual({ id: PRO });
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-da-casa");
    // A miniatura é pedida sem o token da casa: quem autoriza é o token opaco do link.
    expect(pedidos[1]?.headers.get("Authorization")).toBeNull();
    expect(foto).not.toContain("token");
  });

  it("sem foto aprovada, sem foto", async () => {
    expect(await fotoDoPerfil(ambiente, sessao("t"), PRO, { buscar: servidor({ link: null }).fetch })).toBeNull();
  });

  it("só aceita o link da ler-midia do próprio Supabase (nada de outro endereço)", async () => {
    for (const link of ["https://outro.example/functions/v1/ler-midia?x=1", "https://exemplo.supabase.co/rest/v1/qualquer", "http://exemplo.supabase.co/functions/v1/ler-midia"]) {
      const s = servidor({ link });
      expect(await fotoDoPerfil(ambiente, sessao("t"), PRO, { buscar: s.fetch }), link).toBeNull();
      expect(s.pedidos, link).toHaveLength(1);
    }
  });

  it("recusa o que não é imagem, a recusa do link e o arquivo grande demais", async () => {
    const casos: Array<() => Response> = [
      () => new Response("<html>", { headers: { "Content-Type": "text/html" } }),
      () => new Response(null, { status: 404 }),
      () => new Response(new Uint8Array(LIMITE_DA_FOTO + 1), { headers: { "Content-Type": "image/jpeg" } }),
      () => new Response(JPEG, { headers: { "Content-Type": "image/jpeg", "Content-Length": String(LIMITE_DA_FOTO + 1) } }),
    ];
    for (const foto of casos) expect(await fotoDoPerfil(ambiente, sessao("t"), PRO, { buscar: servidor({ foto }).fetch })).toBeNull();
  });

  it("id torto nem sai; falha de rede vira sem foto", async () => {
    const s = servidor();
    expect(await fotoDoPerfil(ambiente, sessao("t"), "../x", { buscar: s.fetch })).toBeNull();
    expect(s.pedidos).toHaveLength(0);
    const quebrado = (async () => {
      throw new Error("rede");
    }) as unknown as typeof globalThis.fetch;
    expect(await fotoDoPerfil(ambiente, sessao("t"), PRO, { buscar: quebrado })).toBeNull();
  });
});
