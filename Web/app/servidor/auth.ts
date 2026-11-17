/**
 * Conversa com o Supabase Auth, sempre do Worker (o navegador nunca vê token nem chama o Auth).
 * Cada função devolve um resultado com o motivo da falha; nenhuma lança por erro de rede.
 */
import createClient from "openapi-fetch";

import type { paths } from "../contrato/tipos.gerado";
import type { AmbienteDoSupabase } from "./ambiente";
import type { Conferencia, Renovacao, Sessao } from "./sessao";

export const PRAZO_DO_AUTH_MS = 8000;

export type FalhaDeEntrada = "codigo_invalido" | "limite" | "indisponivel";
export type ResultadoDeEntrada = { ok: true; sessao: Sessao } | { ok: false; motivo: FalhaDeEntrada };

export function criarAuth(ambiente: AmbienteDoSupabase, opcoes: { fetch?: typeof fetch; prazoMs?: number } = {}) {
  const cabecalhos = { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${ambiente.chavePublicavel}` };
  const buscar = opcoes.fetch ?? fetch;
  const prazo = () => AbortSignal.timeout(opcoes.prazoMs ?? PRAZO_DO_AUTH_MS);
  const auth = createClient<paths>({ baseUrl: `${ambiente.url}/auth/v1`, headers: cabecalhos, fetch: opcoes.fetch });
  const funcoes = createClient<paths>({ baseUrl: `${ambiente.url}/functions/v1`, headers: cabecalhos, fetch: opcoes.fetch });

  const motivoDe = (status: number): FalhaDeEntrada =>
    status === 429 ? "limite" : status >= 400 && status < 500 ? "codigo_invalido" : "indisponivel";

  return {
    /** Pede o código por e-mail. A resposta é a mesma exista ou não a conta. */
    async pedirCodigo(email: string): Promise<{ ok: true } | { ok: false; motivo: "limite" | "indisponivel" }> {
      try {
        const { response } = await auth.POST("/otp", { body: { email }, signal: prazo() });
        if (response.ok) return { ok: true };
        return { ok: false, motivo: response.status === 429 ? "limite" : "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    async confirmarCodigo(email: string, codigo: string): Promise<ResultadoDeEntrada> {
      try {
        const { data, response } = await auth.POST("/verify", {
          body: { email, token: codigo, type: "email" },
          signal: prazo(),
        });
        return data ? { ok: true, sessao: data } : { ok: false, motivo: motivoDe(response.status) };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /** Porta da conta de demonstração (só e-mail declarado; o servidor recusa qualquer outro). */
    async entrarDemonstracao(email: string, codigo: string): Promise<ResultadoDeEntrada> {
      try {
        const { data, response } = await funcoes.POST("/entrar-demonstracao", { body: { email, codigo }, signal: prazo() });
        return data ? { ok: true, sessao: data } : { ok: false, motivo: motivoDe(response.status) };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    async renovar(tokenDeRenovacao: string): Promise<Renovacao> {
      try {
        const { data, response } = await auth.POST("/token", {
          params: { query: { grant_type: "refresh_token" } },
          body: { refresh_token: tokenDeRenovacao },
          signal: prazo(),
        });
        if (data) return { ok: true, sessao: data };
        // 400 e 401: o token de renovação não vale mais. 429 e 5xx: o Supabase é que falhou.
        const recusada = response.status === 400 || response.status === 401 || response.status === 403;
        return { ok: false, motivo: recusada ? "recusada" : "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * A sessão deste token ainda existe no Auth? O PostgREST aceita o token até vencer, mesmo depois do sair; quem
     * sabe que a sessão foi encerrada é o Auth (provado no dev: depois do logout, 403 session_not_found).
     */
    async conferir(acesso: string): Promise<Conferencia> {
      try {
        // Rota padrão do Supabase Auth, fora do contrato do Frila (não tem regra do produto).
        const resposta = await buscar(`${ambiente.url}/auth/v1/user`, {
          headers: { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${acesso}` },
          signal: prazo(),
        });
        await resposta.body?.cancel();
        if (resposta.ok) return { ok: true };
        // 401 e 403 (token ruim, sessão encerrada) e 404 (usuário apagado): não há sessão. O resto é falha do Auth.
        const recusada = resposta.status === 401 || resposta.status === 403 || resposta.status === 404;
        return { ok: false, motivo: recusada ? "recusada" : "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /** Encerra a sessão no Auth (só esta sessão). Falhar aqui não impede a saída: os cookies são apagados de todo jeito. */
    async encerrar(acesso: string): Promise<void> {
      try {
        // Rota padrão do Supabase Auth; não está no contrato do Frila porque não tem regra do produto.
        await buscar(`${ambiente.url}/auth/v1/logout?scope=local`, {
          method: "POST",
          headers: { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${acesso}` },
          signal: prazo(),
        });
      } catch {
        // Sem rede: a sessão vence sozinha no Auth.
      }
    },
  };
}

export type Auth = ReturnType<typeof criarAuth>;
