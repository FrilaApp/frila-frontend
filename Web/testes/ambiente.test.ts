import { describe, expect, it } from "vitest";

import { ambienteDoSupabase, ChaveProibida, ehChaveDeServico } from "~/servidor/ambiente";

const jwtComPapel = (role: string) => `cabecalho.${btoa(JSON.stringify({ role }))}.assinatura`;

describe("ambiente do Supabase", () => {
  it("devolve nulo quando falta o endereço ou a chave", () => {
    expect(ambienteDoSupabase({})).toBeNull();
    expect(ambienteDoSupabase({ SUPABASE_URL: "https://exemplo.supabase.co" })).toBeNull();
    expect(ambienteDoSupabase({ SUPABASE_URL: " ", SUPABASE_CHAVE_PUBLICAVEL: "sb_publishable_teste" })).toBeNull();
  });

  it("tira a barra do fim do endereço", () => {
    expect(
      ambienteDoSupabase({ SUPABASE_URL: "https://exemplo.supabase.co/", SUPABASE_CHAVE_PUBLICAVEL: "sb_publishable_teste" }),
    ).toEqual({ url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" });
  });

  it("recusa chave de serviço, no formato novo e no antigo", () => {
    expect(ehChaveDeServico("sb_secret_teste")).toBe(true);
    expect(ehChaveDeServico(jwtComPapel("service_role"))).toBe(true);
    expect(() =>
      ambienteDoSupabase({ SUPABASE_URL: "https://exemplo.supabase.co", SUPABASE_CHAVE_PUBLICAVEL: "sb_secret_teste" }),
    ).toThrow(ChaveProibida);
  });

  it("aceita chave publicável, no formato novo e no antigo", () => {
    expect(ehChaveDeServico("sb_publishable_teste")).toBe(false);
    expect(ehChaveDeServico(jwtComPapel("anon"))).toBe(false);
  });
});
