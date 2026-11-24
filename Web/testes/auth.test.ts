import { describe, expect, it } from "vitest";

import { criarAuth } from "~/servidor/auth";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const sessao = { access_token: "a.b.c", refresh_token: "r", token_type: "bearer", expires_in: 3600 };

function authQueResponde(resposta: () => Response | Promise<Response>, prazoMs?: number) {
  const pedidos: Request[] = [];
  const auth = criarAuth(ambiente, {
    prazoMs,
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { auth, pedidos };
}
const corpoDe = async (pedido: Request | undefined) => (pedido ? ((await pedido.json()) as Record<string, unknown>) : {});

describe("conversa com o Supabase Auth", () => {
  it("pede o código em auth/v1/otp só com a chave publicável", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json({}));
    expect(await auth.pedirCodigo("ana@example.com")).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/otp");
    expect(pedidos[0]?.method).toBe("POST");
    expect(pedidos[0]?.headers.get("apikey")).toBe("sb_publishable_teste");
    expect(await corpoDe(pedidos[0])).toEqual({ email: "ana@example.com", create_user: true });
  });

  it("pedirCodigo com criarUsuario=false chama recuperação e não cria usuário", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json({}));
    expect(await auth.pedirCodigo("ana@example.com", { criarUsuario: false })).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/otp");
    expect(await corpoDe(pedidos[0])).toEqual({ email: "ana@example.com", create_user: false });
  });

  it("pedirCodigoRecuperacao devolve enviado=true se 200, enviado=false (neutro) se 422/400/404", async () => {
    const okAuth = authQueResponde(() => Response.json({})).auth;
    expect(await okAuth.pedirCodigoRecuperacao("existe@example.com")).toEqual({ ok: true, enviado: true });

    for (const status of [400, 403, 404, 422]) {
      const { auth } = authQueResponde(() => Response.json({ msg: "user not found" }, { status }));
      expect(await auth.pedirCodigoRecuperacao("inexistente@example.com"), String(status)).toEqual({
        ok: true,
        enviado: false,
      });
    }

    const limiteAuth = authQueResponde(() => Response.json({}, { status: 429 })).auth;
    expect(await limiteAuth.pedirCodigoRecuperacao("a@b.co")).toEqual({ ok: false, motivo: "limite" });

    const foraAuth = authQueResponde(() => Response.json({}, { status: 500 })).auth;
    expect(await foraAuth.pedirCodigoRecuperacao("a@b.co")).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("entrarComSenha chama auth/v1/token?grant_type=password com email e senha", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json(sessao));
    expect(await auth.entrarComSenha("ana@example.com", "senha12345")).toEqual({ ok: true, sessao });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/token?grant_type=password");
    expect(pedidos[0]?.method).toBe("POST");
    expect(await corpoDe(pedidos[0])).toEqual({ email: "ana@example.com", password: "senha12345" });
  });

  it("entrarComSenha: 400 viram credenciais_invalidas (neutro), 429 vira limite e 5xx vira indisponivel", async () => {
    const com = (status: number) => authQueResponde(() => Response.json({ error_description: "Invalid credentials" }, { status })).auth;
    expect(await com(400).entrarComSenha("a@b.co", "s")).toEqual({ ok: false, motivo: "credenciais_invalidas" });
    expect(await com(401).entrarComSenha("a@b.co", "s")).toEqual({ ok: false, motivo: "credenciais_invalidas" });
    expect(await com(422).entrarComSenha("a@b.co", "s")).toEqual({ ok: false, motivo: "credenciais_invalidas" });
    expect(await com(429).entrarComSenha("a@b.co", "s")).toEqual({ ok: false, motivo: "limite" });
    expect(await com(500).entrarComSenha("a@b.co", "s")).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("atualizarSenha chama PUT auth/v1/user com Authorization Bearer e body password", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json({ id: "user-123" }));
    expect(await auth.atualizarSenha("token-acesso", "novaSenha123")).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/user");
    expect(pedidos[0]?.method).toBe("PUT");
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-acesso");
    expect(await corpoDe(pedidos[0])).toEqual({ password: "novaSenha123" });
  });

  it("atualizarSenha mapeia erro de senha fraca, mesma senha, sessao_invalida e limite", async () => {
    const fraca = authQueResponde(() => Response.json({ code: "weak_password" }, { status: 422 })).auth;
    expect(await fraca.atualizarSenha("t", "123")).toEqual({ ok: false, motivo: "senha_fraca" });

    const mesma = authQueResponde(() => Response.json({ error_code: "same_password" }, { status: 422 })).auth;
    expect(await mesma.atualizarSenha("t", "mesma")).toEqual({ ok: false, motivo: "senha_igual" });

    const naoAutenticado = authQueResponde(() => Response.json({}, { status: 401 })).auth;
    expect(await naoAutenticado.atualizarSenha("t", "s")).toEqual({ ok: false, motivo: "sessao_invalida" });

    const limite = authQueResponde(() => Response.json({}, { status: 429 })).auth;
    expect(await limite.atualizarSenha("t", "s")).toEqual({ ok: false, motivo: "limite" });
  });

  it("limite de pedidos de código vira motivo próprio", async () => {
    const { auth } = authQueResponde(() => Response.json({ code: "limite_excedido", message: "x" }, { status: 429 }));
    expect(await auth.pedirCodigo("ana@example.com")).toEqual({ ok: false, motivo: "limite" });
  });

  it("confirma o código em auth/v1/verify e devolve a sessão", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json(sessao));
    expect(await auth.confirmarCodigo("ana@example.com", "123456")).toEqual({ ok: true, sessao });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/verify");
    expect(await corpoDe(pedidos[0])).toEqual({ email: "ana@example.com", token: "123456", type: "email" });
  });

  it("código errado, limite e servidor fora do ar têm motivos diferentes", async () => {
    const com = (status: number) => authQueResponde(() => Response.json({ code: "x", message: "x" }, { status })).auth;
    expect(await com(401).confirmarCodigo("a@b.co", "000000")).toEqual({ ok: false, motivo: "codigo_invalido" });
    expect(await com(403).confirmarCodigo("a@b.co", "000000")).toEqual({ ok: false, motivo: "codigo_invalido" });
    expect(await com(429).confirmarCodigo("a@b.co", "000000")).toEqual({ ok: false, motivo: "limite" });
    expect(await com(500).confirmarCodigo("a@b.co", "000000")).toEqual({ ok: false, motivo: "indisponivel" });
    const semRede = authQueResponde(() => Promise.reject(new TypeError("fetch failed"))).auth;
    expect(await semRede.confirmarCodigo("a@b.co", "000000")).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("renova em auth/v1/token?grant_type=refresh_token", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json(sessao));
    expect(await auth.renovar("r1")).toEqual({ ok: true, sessao });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/token?grant_type=refresh_token");
    expect(await corpoDe(pedidos[0])).toEqual({ refresh_token: "r1" });
  });

  it("renovação: token recusado é diferente de servidor fora do ar", async () => {
    const com = (status: number) => authQueResponde(() => Response.json({ code: "x", message: "x" }, { status })).auth;
    expect(await com(400).renovar("r")).toEqual({ ok: false, motivo: "recusada" });
    expect(await com(401).renovar("r")).toEqual({ ok: false, motivo: "recusada" });
    expect(await com(429).renovar("r")).toEqual({ ok: false, motivo: "indisponivel" });
    expect(await com(503).renovar("r")).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("a conta de demonstração entra pela função própria", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json(sessao));
    expect(await auth.entrarDemonstracao("demo@example.com", "codigo-fixo")).toEqual({ ok: true, sessao });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/functions/v1/entrar-demonstracao");
    expect(await corpoDe(pedidos[0])).toEqual({ email: "demo@example.com", codigo: "codigo-fixo" });
  });

  it("sair encerra só esta sessão, com o token de quem entrou; 204 é revogação confirmada", async () => {
    const { auth, pedidos } = authQueResponde(() => new Response(null, { status: 204 }));
    expect(await auth.encerrar("token-do-usuario")).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/logout?scope=local");
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-do-usuario");
  });

  it("401, 403 e 404 dizem que a sessão já não existe: também confirmam", async () => {
    for (const status of [401, 403, 404]) {
      expect(await authQueResponde(() => new Response(null, { status })).auth.encerrar("t"), String(status)).toEqual({ ok: true });
    }
  });

  it("5xx, limite e falta de rede NÃO confirmam a saída (e não lançam)", async () => {
    for (const status of [429, 500, 503]) {
      expect(await authQueResponde(() => new Response(null, { status })).auth.encerrar("t"), String(status)).toEqual({ ok: false });
    }
    const semRede = authQueResponde(() => Promise.reject(new TypeError("fetch failed"))).auth;
    expect(await semRede.encerrar("t")).toEqual({ ok: false });
  });

  it("servidor que não responde é cortado pelo prazo", async () => {
    const auth = criarAuth(ambiente, {
      prazoMs: 30,
      fetch: (entrada, inicio) =>
        new Promise<Response>((_, rejeitar) => {
          const sinal = new Request(entrada, inicio).signal;
          sinal.addEventListener("abort", () => rejeitar(sinal.reason));
        }),
    });
    expect(await auth.pedirCodigo("a@b.co")).toEqual({ ok: false, motivo: "indisponivel" });
  });
});

describe("conferir a sessão no Auth (auth/v1/user)", () => {
  it("manda o token de acesso e aceita o 200", async () => {
    const { auth, pedidos } = authQueResponde(() => Response.json({ id: "u1" }));
    expect(await auth.conferir("token-de-acesso")).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/auth/v1/user");
    expect(pedidos[0]?.method).toBe("GET");
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-de-acesso");
    expect(pedidos[0]?.headers.get("apikey")).toBe("sb_publishable_teste");
  });

  it("sessão encerrada (403 session_not_found), token ruim (401) e usuário apagado (404) são recusa", async () => {
    for (const status of [401, 403, 404]) {
      const { auth } = authQueResponde(() => Response.json({ error_code: "session_not_found" }, { status }));
      expect(await auth.conferir("t"), String(status)).toEqual({ ok: false, motivo: "recusada" });
    }
  });

  it("limite, erro do Auth, falta de rede e prazo estourado são indisponibilidade, não recusa", async () => {
    for (const status of [429, 500, 503]) {
      const { auth } = authQueResponde(() => new Response(null, { status }));
      expect(await auth.conferir("t"), String(status)).toEqual({ ok: false, motivo: "indisponivel" });
    }
    const semRede = authQueResponde(() => Promise.reject(new TypeError("rede")));
    expect(await semRede.auth.conferir("t")).toEqual({ ok: false, motivo: "indisponivel" });
    // Como o fetch de verdade: o prazo estoura e o pedido é abortado.
    const lento = criarAuth(ambiente, {
      prazoMs: 20,
      fetch: (_entrada, inicio) =>
        new Promise<Response>((_, rejeitar) => inicio?.signal?.addEventListener("abort", () => rejeitar(new Error("prazo")))),
    });
    expect(await lento.conferir("t")).toEqual({ ok: false, motivo: "indisponivel" });
  });
});
