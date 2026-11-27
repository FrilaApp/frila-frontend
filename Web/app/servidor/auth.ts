/**
 * Conversa com o Supabase Auth, sempre do Worker (o navegador nunca vê token nem chama o Auth).
 * Cada função devolve um resultado com o motivo da falha; nenhuma lança por erro de rede.
 */
import createClient from "openapi-fetch";

import type { paths } from "../contrato/tipos.gerado";
import type { AmbienteDoSupabase } from "./ambiente";
import { cabecalhosDoIp, cabecalhosDoIpAnonimo, type ChavesDoIp } from "./saida-rest";
import type { Conferencia, Renovacao, Sessao } from "./sessao";

export const PRAZO_DO_AUTH_MS = 8000;

export type FalhaDeEntrada = "codigo_invalido" | "credenciais_invalidas" | "limite" | "indisponivel";
export type ResultadoDeEntrada = { ok: true; sessao: Sessao } | { ok: false; motivo: FalhaDeEntrada };

export type FalhaAtualizarSenha =
  | "senha_fraca"
  | "senha_igual"
  | "reautenticacao_necessaria"
  | "sessao_invalida"
  | "limite"
  | "indisponivel";
export type ResultadoAtualizarSenha = { ok: true } | { ok: false; motivo: FalhaAtualizarSenha };

export type ResultadoRecuperacao =
  | { ok: true; enviado: boolean }
  | { ok: false; motivo: "limite" | "indisponivel" };

export type ResultadoAutenticarSenha =
  | { ok: true; status: "autenticado"; sessao: Sessao; precisaDefinirSenha: boolean }
  | {
      ok: true;
      status: "desafio_otp";
      desafioId: string;
      descartarDeviceToken: boolean;
      reenviarEmSegundos?: number;
    }
  | { ok: false; motivo: "credenciais_invalidas" | "limite" | "indisponivel" };

export type FalhaConfirmarDispositivo =
  | "codigo_invalido"
  | "desafio_ja_usado"
  | "desafio_expirado"
  | "limite"
  | "indisponivel";

export type ResultadoConfirmarDispositivo =
  | { ok: true; sessao: Sessao; precisaDefinirSenha: boolean; deviceToken: string | null }
  | { ok: false; motivo: FalhaConfirmarDispositivo };

export type ResultadoReenviarDispositivo =
  | { ok: true; reenviarEmSegundos: number }
  | { ok: false; motivo: "desafio_ja_usado" | "desafio_expirado" | "limite" | "indisponivel" };

export type ResultadoDefinirSenha =
  | { ok: true; sessao: Sessao | null }
  | { ok: false; motivo: FalhaAtualizarSenha };

export type ResultadoRevogarDispositivos =
  | { ok: true }
  | { ok: false; motivo: "sessao_invalida" | "limite" | "indisponivel" };

export type FalhaTrocaPkce =
  | "conflito_identidade"
  | "apple_recusado"
  | "google_recusado"
  | "limite"
  | "indisponivel";
export type ResultadoIniciarSocialPkce =
  | { ok: true; transacaoId: string; urlAutorizacao: string }
  | { ok: false; motivo: "limite" | "indisponivel" | "apple_recusado" | "google_recusado" };
export type ResultadoTrocaPkce =
  | { ok: true; sessao: Sessao; precisaDefinirSenha: boolean }
  | { ok: false; motivo: FalhaTrocaPkce };

/** Validação runtime fail-closed para qualquer resposta de sessão recebida do Supabase Auth. */
function ehSessaoValida(valor: unknown): valor is Sessao {
  if (typeof valor !== "object" || valor === null) return false;
  const obj = valor as Record<string, unknown>;
  return (
    typeof obj.access_token === "string" &&
    obj.access_token.trim().length > 0 &&
    typeof obj.refresh_token === "string" &&
    obj.refresh_token.trim().length > 0 &&
    typeof obj.token_type === "string" &&
    obj.token_type.trim().length > 0 &&
    typeof obj.expires_in === "number" &&
    Number.isFinite(obj.expires_in) &&
    obj.expires_in > 0
  );
}

export function criarAuth(
  ambiente: AmbienteDoSupabase,
  opcoes: { fetch?: typeof fetch; prazoMs?: number; chavesIp?: ChavesDoIp } = {},
) {
  const cabecalhos = { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${ambiente.chavePublicavel}` };
  const buscar = opcoes.fetch ?? fetch;
  const prazo = () => AbortSignal.timeout(opcoes.prazoMs ?? PRAZO_DO_AUTH_MS);
  const auth = createClient<paths>({ baseUrl: `${ambiente.url}/auth/v1`, headers: cabecalhos, fetch: opcoes.fetch });
  const funcoes = createClient<paths>({ baseUrl: `${ambiente.url}/functions/v1`, headers: cabecalhos, fetch: opcoes.fetch });

  const cabecalhosComIp = async (
    base: Record<string, string>,
    ipOpcoes: { visitante?: string | null; acesso?: string },
  ): Promise<Record<string, string>> => {
    if (!opcoes.chavesIp || !ipOpcoes.visitante) return base;
    const assinados = ipOpcoes.acesso
      ? await cabecalhosDoIp(opcoes.chavesIp, ipOpcoes.visitante, ipOpcoes.acesso)
      : await cabecalhosDoIpAnonimo(opcoes.chavesIp, ipOpcoes.visitante);
    return assinados ? { ...base, ...assinados } : base;
  };

  const motivoDe = (status: number): FalhaDeEntrada =>
    status === 429 ? "limite" : status >= 400 && status < 500 ? "codigo_invalido" : "indisponivel";

  const pedirCodigoRecuperacao = async (email: string): Promise<ResultadoRecuperacao> => {
    try {
      const resposta = await buscar(`${ambiente.url}/auth/v1/otp`, {
        method: "POST",
        headers: {
          ...cabecalhos,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, create_user: false }),
        signal: prazo(),
      });
      if (resposta.ok) {
        await resposta.body?.cancel();
        return { ok: true, enviado: true };
      }
      if (resposta.status === 429) {
        await resposta.body?.cancel();
        return { ok: false, motivo: "limite" };
      }
      // 422 (Signups not allowed for otp) ou 400/403/404: o usuário não existe ou é social-only
      if (resposta.status >= 400 && resposta.status < 500) {
        await resposta.body?.cancel();
        return { ok: true, enviado: false };
      }
      await resposta.body?.cancel();
      return { ok: false, motivo: "indisponivel" };
    } catch {
      return { ok: false, motivo: "indisponivel" };
    }
  };

  return {
    /** Pede o código por e-mail. Por padrão permite criar o usuário (cadastro com OTP). */
    async pedirCodigo(
      email: string,
      opcoesCodigo: { criarUsuario?: boolean } = {},
    ): Promise<{ ok: true } | { ok: false; motivo: "limite" | "indisponivel" }> {
      try {
        if (opcoesCodigo.criarUsuario === false) {
          const recuperacao = await pedirCodigoRecuperacao(email);
          if (recuperacao.ok) return { ok: true };
          return { ok: false, motivo: recuperacao.motivo };
        }
        const { response } = await auth.POST("/otp", {
          body: { email, create_user: opcoesCodigo.criarUsuario ?? true } as { email: string },
          signal: prazo(),
        });
        if (response.ok) return { ok: true };
        return { ok: false, motivo: response.status === 429 ? "limite" : "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Solicitação de OTP exclusiva para recuperação/migração de conta existente (create_user: false).
     * Nunca cria usuário novo no Supabase Auth.
     * Retorna { ok: true, enviado: true } se a conta existe e o código foi enviado.
     * Retorna { ok: true, enviado: false } se a identidade não existe ou é social-only (resposta neutra anti-enumeração).
     */
    pedirCodigoRecuperacao,

    /** Login habitual por e-mail e senha (POST /auth/v1/token?grant_type=password). */
    async entrarComSenha(email: string, senha: string): Promise<ResultadoDeEntrada> {
      try {
        const resposta = await buscar(`${ambiente.url}/auth/v1/token?grant_type=password`, {
          method: "POST",
          headers: {
            ...cabecalhos,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ email, password: senha }),
          signal: prazo(),
        });
        if (resposta.ok) {
          const dados: unknown = await resposta.json();
          if (!ehSessaoValida(dados)) {
            return { ok: false, motivo: "indisponivel" };
          }
          return { ok: true, sessao: dados };
        }
        await resposta.body?.cancel();
        if (resposta.status === 429) {
          return { ok: false, motivo: "limite" };
        }
        // Resposta neutra para qualquer erro 4xx (invalid_credentials, invalid_grant, user_not_found)
        if (resposta.status >= 400 && resposta.status < 500) {
          return { ok: false, motivo: "credenciais_invalidas" };
        }
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Login habitual por senha com validação server-side de dispositivo confiável (30 dias)
     * via Edge Function `POST /functions/v1/autenticar-senha` (contrato 0.2.112 + B-116 `anon`).
     */
    async autenticarSenha(params: {
      email: string;
      senha: string;
      deviceToken?: string | null;
      visitante?: string | null;
    }): Promise<ResultadoAutenticarSenha> {
      try {
        const headers = await cabecalhosComIp(
          { ...cabecalhos, "Content-Type": "application/json" },
          { visitante: params.visitante },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/autenticar-senha`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            email: params.email,
            senha: params.senha,
            plataforma: "web",
            device_token: params.deviceToken ?? null,
          }),
          signal: prazo(),
        });
        if (resposta.ok) {
          const dados = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
          if (dados?.status === "autenticado" && ehSessaoValida(dados.sessao)) {
            return {
              ok: true,
              status: "autenticado",
              sessao: dados.sessao,
              precisaDefinirSenha: dados.precisa_definir_senha === true,
            };
          }
          if (dados?.status === "desafio_otp" && typeof dados.desafio_id === "string" && dados.desafio_id.length > 0) {
            const reenviarEmSegundos =
              typeof dados.reenviar_em_segundos === "number" &&
              Number.isFinite(dados.reenviar_em_segundos) &&
              dados.reenviar_em_segundos > 0
                ? Math.floor(dados.reenviar_em_segundos)
                : undefined;
            return {
              ok: true,
              status: "desafio_otp",
              desafioId: dados.desafio_id,
              descartarDeviceToken: dados.descartar_device_token === true,
              ...(reenviarEmSegundos !== undefined ? { reenviarEmSegundos } : {}),
            };
          }
          return { ok: false, motivo: "indisponivel" };
        }
        await resposta.body?.cancel();
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 401) return { ok: false, motivo: "credenciais_invalidas" };
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Confirma o código OTP de 6 dígitos (desafio de dispositivo, cadastro ou recuperação)
     * via `POST /functions/v1/confirmar-dispositivo-otp` (contrato 0.2.112 + B-116 `anon`).
     */
    async confirmarDispositivoOtp(
      params:
        | { tipo: "login_dispositivo"; desafioId: string; codigo: string; lembrarDispositivo: boolean; visitante?: string | null }
        | { tipo: "cadastro" | "recuperacao"; email: string; codigo: string; lembrarDispositivo: boolean; visitante?: string | null },
    ): Promise<ResultadoConfirmarDispositivo> {
      try {
        const headers = await cabecalhosComIp(
          { ...cabecalhos, "Content-Type": "application/json" },
          { visitante: params.visitante },
        );
        const corpo =
          params.tipo === "login_dispositivo"
            ? {
                tipo: "login_dispositivo",
                desafio_id: params.desafioId,
                codigo: params.codigo,
                plataforma: "web",
                lembrar_dispositivo: params.lembrarDispositivo,
              }
            : {
                tipo: params.tipo,
                email: params.email,
                codigo: params.codigo,
                plataforma: "web",
                lembrar_dispositivo: params.lembrarDispositivo,
              };
        const resposta = await buscar(`${ambiente.url}/functions/v1/confirmar-dispositivo-otp`, {
          method: "POST",
          headers,
          body: JSON.stringify(corpo),
          signal: prazo(),
        });
        if (resposta.ok) {
          const dados = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
          if (!dados || !ehSessaoValida(dados.sessao)) {
            return { ok: false, motivo: "indisponivel" };
          }
          return {
            ok: true,
            sessao: dados.sessao,
            precisaDefinirSenha: dados.precisa_definir_senha === true,
            deviceToken: typeof dados.device_token === "string" && dados.device_token.length > 0 ? dados.device_token : null,
          };
        }
        await resposta.body?.cancel();
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 401) return { ok: false, motivo: "codigo_invalido" };
        if (resposta.status === 409) return { ok: false, motivo: "desafio_ja_usado" };
        if (resposta.status === 410) return { ok: false, motivo: "desafio_expirado" };
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Reenvia o código OTP de um desafio `login_dispositivo` ativo mantendo o mesmo `desafio_id`
     * via `POST /functions/v1/reenviar-dispositivo-otp` (contrato 0.2.112 + B-116 `anon`).
     */
    async reenviarDispositivoOtp(params: {
      desafioId: string;
      visitante?: string | null;
    }): Promise<ResultadoReenviarDispositivo> {
      try {
        const headers = await cabecalhosComIp(
          { ...cabecalhos, "Content-Type": "application/json" },
          { visitante: params.visitante },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/reenviar-dispositivo-otp`, {
          method: "POST",
          headers,
          body: JSON.stringify({ desafio_id: params.desafioId }),
          signal: prazo(),
        });
        if (resposta.ok) {
          const dados = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
          const seg = typeof dados?.reenviar_em_segundos === "number" ? dados.reenviar_em_segundos : 60;
          return { ok: true, reenviarEmSegundos: seg };
        }
        await resposta.body?.cancel();
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 409) return { ok: false, motivo: "desafio_ja_usado" };
        if (resposta.status === 410) return { ok: false, motivo: "desafio_expirado" };
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Define ou altera a senha na sessão ativa via `POST /functions/v1/definir-senha` (contrato 0.2.112 + B-116 `uid`).
     * Limpa a trava `precisa_definir_senha` no servidor, revoga dispositivos confiáveis e devolve `Sessao` atualizada se `refreshToken` for enviado.
     */
    async definirSenha(params: {
      acesso: string;
      novaSenha: string;
      manterDispositivoAtual: boolean;
      deviceTokenAtual?: string | null;
      refreshToken?: string | null;
      visitante?: string | null;
    }): Promise<ResultadoDefinirSenha> {
      try {
        const headers = await cabecalhosComIp(
          {
            apikey: ambiente.chavePublicavel,
            Authorization: `Bearer ${params.acesso}`,
            "Content-Type": "application/json",
          },
          { visitante: params.visitante, acesso: params.acesso },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/definir-senha`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            nova_senha: params.novaSenha,
            manter_dispositivo_atual: params.manterDispositivoAtual,
            device_token_atual: params.deviceTokenAtual ?? null,
            refresh_token: params.refreshToken ?? null,
          }),
          signal: prazo(),
        });
        if (resposta.ok) {
          const dados = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
          if (!dados || dados.ok !== true) {
            return { ok: false, motivo: "indisponivel" };
          }
          if (dados.sessao !== null && dados.sessao !== undefined) {
            if (!ehSessaoValida(dados.sessao)) return { ok: false, motivo: "indisponivel" };
            return { ok: true, sessao: dados.sessao };
          }
          return { ok: true, sessao: null };
        }
        const erroJson = (await resposta.json().catch(() => ({}))) as Record<string, unknown>;
        const code = String(erroJson.code ?? erroJson.error_code ?? "").toLowerCase();
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 401 || resposta.status === 403) {
          if (code === "reautenticacao_necessaria" || code === "reauthentication_needed") {
            return { ok: false, motivo: "reautenticacao_necessaria" };
          }
          return { ok: false, motivo: "sessao_invalida" };
        }
        if (resposta.status === 422) {
          if (code === "senha_igual" || code === "same_password") return { ok: false, motivo: "senha_igual" };
          if (code === "senha_fraca" || code === "weak_password") return { ok: false, motivo: "senha_fraca" };
        }
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Ação explícita "Sair de todos os dispositivos" via `POST /functions/v1/revogar-dispositivos` (contrato 0.2.112 + B-116 `uid`).
     */
    async revogarDispositivos(params: {
      acesso: string;
      visitante?: string | null;
    }): Promise<ResultadoRevogarDispositivos> {
      try {
        const headers = await cabecalhosComIp(
          {
            apikey: ambiente.chavePublicavel,
            Authorization: `Bearer ${params.acesso}`,
            "Content-Type": "application/json",
          },
          { visitante: params.visitante, acesso: params.acesso },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/revogar-dispositivos`, {
          method: "POST",
          headers,
          body: "{}",
          signal: prazo(),
        });
        await resposta.body?.cancel();
        if (resposta.ok) return { ok: true };
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 401 || resposta.status === 403) return { ok: false, motivo: "sessao_invalida" };
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Define ou atualiza a senha na sessão autenticada atual (PUT /auth/v1/user),
     * preservando rigorosamente o mesmo auth.uid.
     */
    async atualizarSenha(acesso: string, novaSenha: string): Promise<ResultadoAtualizarSenha> {
      try {
        const resposta = await buscar(`${ambiente.url}/auth/v1/user`, {
          method: "PUT",
          headers: {
            apikey: ambiente.chavePublicavel,
            Authorization: `Bearer ${acesso}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ password: novaSenha }),
          signal: prazo(),
        });
        if (resposta.ok) {
          await resposta.body?.cancel();
          return { ok: true };
        }
        if (resposta.status === 401 || resposta.status === 403) {
          await resposta.body?.cancel();
          return { ok: false, motivo: "sessao_invalida" };
        }
        if (resposta.status === 429) {
          await resposta.body?.cancel();
          return { ok: false, motivo: "limite" };
        }
        if (resposta.status === 422) {
          const dados = (await resposta.json().catch(() => ({}))) as Record<string, unknown>;
          const codigo = dados.error_code ?? dados.code;
          if (codigo === "same_password") {
            return { ok: false, motivo: "senha_igual" };
          }
          if (codigo === "reauthentication_needed") {
            return { ok: false, motivo: "reautenticacao_necessaria" };
          }
          return { ok: false, motivo: "senha_fraca" };
        }
        await resposta.body?.cancel();
        return { ok: false, motivo: "indisponivel" };
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
        if (response.ok) {
          return ehSessaoValida(data) ? { ok: true, sessao: data } : { ok: false, motivo: "indisponivel" };
        }
        return { ok: false, motivo: motivoDe(response.status) };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /** Porta da conta de demonstração (só e-mail declarado; o servidor recusa qualquer outro). */
    async entrarDemonstracao(email: string, codigo: string): Promise<ResultadoDeEntrada> {
      try {
        const { data, response } = await funcoes.POST("/entrar-demonstracao", { body: { email, codigo }, signal: prazo() });
        if (response.ok) {
          return ehSessaoValida(data) ? { ok: true, sessao: data } : { ok: false, motivo: "indisponivel" };
        }
        return { ok: false, motivo: motivoDe(response.status) };
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
        if (response.ok) {
          return ehSessaoValida(data) ? { ok: true, sessao: data } : { ok: false, motivo: "indisponivel" };
        }
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

    /**
     * Encerra a sessão no Auth (só esta sessão). `ok` só com a revogação confirmada: 204, ou 401, 403 e 404, que dizem
     * que a sessão já não existe. Falha do Auth (5xx, rede, prazo) não é saída: a sessão seguiria viva no Auth.
     */
    async encerrar(acesso: string): Promise<{ ok: boolean }> {
      try {
        // Rota padrão do Supabase Auth; não está no contrato do Frila porque não tem regra do produto.
        const resposta = await buscar(`${ambiente.url}/auth/v1/logout?scope=local`, {
          method: "POST",
          headers: { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${acesso}` },
          signal: prazo(),
        });
        await resposta.body?.cancel();
        return { ok: resposta.ok || resposta.status === 401 || resposta.status === 403 || resposta.status === 404 };
      } catch {
        return { ok: false };
      }
    },

    /**
     * Inicia transação OAuth PKCE server-side via Edge Function `POST /functions/v1/autenticar-social`
     * (`fluxo: "iniciar_pkce"`, contrato 0.2.117), vinculando provedor + code_challenge + callback.
     */
    async iniciarLoginSocialPkce(params: {
      provedor: "apple" | "google";
      codeChallenge: string;
      redirectTo: string;
      visitante?: string | null;
    }): Promise<ResultadoIniciarSocialPkce> {
      try {
        const headers = await cabecalhosComIp(
          { ...cabecalhos, "Content-Type": "application/json" },
          { visitante: params.visitante },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/autenticar-social`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            provedor: params.provedor,
            fluxo: "iniciar_pkce",
            plataforma: "web",
            code_challenge: params.codeChallenge,
            redirect_to: params.redirectTo,
          }),
          signal: prazo(),
        });
        const corpo = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
        if (resposta.ok) {
          const transacaoId = typeof corpo?.transacao_id === "string" ? corpo.transacao_id : "";
          const urlAutorizacao = typeof corpo?.url_autorizacao === "string" ? corpo.url_autorizacao : "";
          if (!transacaoId || !urlAutorizacao) return { ok: false, motivo: "indisponivel" };
          return { ok: true, transacaoId, urlAutorizacao };
        }
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        if (resposta.status === 403 || resposta.status >= 500) return { ok: false, motivo: "indisponivel" };
        return { ok: false, motivo: `${params.provedor}_recusado` };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Conclui login social PKCE via Edge Function `POST /functions/v1/autenticar-social` (`fluxo: "pkce"`),
     * garantindo verificação da transação server-side, gravação em `privado.sessoes_verificadas` e JWT renovado.
     * Nunca registra código, verifier ou tokens.
     */
    async concluirLoginSocialPkce(params: {
      provedor: "apple" | "google";
      transacaoId: string;
      codigo: string;
      codeVerifier: string;
      visitante?: string | null;
    }): Promise<ResultadoTrocaPkce> {
      try {
        const headers = await cabecalhosComIp(
          { ...cabecalhos, "Content-Type": "application/json" },
          { visitante: params.visitante },
        );
        const resposta = await buscar(`${ambiente.url}/functions/v1/autenticar-social`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            provedor: params.provedor,
            fluxo: "pkce",
            plataforma: "web",
            transacao_id: params.transacaoId,
            codigo: params.codigo,
            code_verifier: params.codeVerifier,
          }),
          signal: prazo(),
        });
        const corpo = (await resposta.json().catch(() => null)) as Record<string, unknown> | null;
        if (resposta.ok) {
          if (!ehSessaoValida(corpo?.sessao)) return { ok: false, motivo: "indisponivel" };
          return {
            ok: true,
            sessao: corpo.sessao,
            precisaDefinirSenha: corpo?.precisa_definir_senha === true,
          };
        }
        if (resposta.status === 429) return { ok: false, motivo: "limite" };
        const codigoErro = String(corpo?.code ?? corpo?.error_code ?? "").toLowerCase();
        if (resposta.status === 409 && codigoErro === "conflito_identidade") {
          return { ok: false, motivo: "conflito_identidade" };
        }
        if (resposta.status === 403 || resposta.status >= 500) {
          return { ok: false, motivo: "indisponivel" };
        }
        if (resposta.status >= 400 && resposta.status < 500) {
          return { ok: false, motivo: `${params.provedor}_recusado` };
        }
        return { ok: false, motivo: "indisponivel" };
      } catch {
        return { ok: false, motivo: "indisponivel" };
      }
    },

    /**
     * Revoga outras sessões ativas no Auth pós-redefinição de senha (`scope=others`),
     * mantendo apenas a sessão atual válida. Best-effort: nunca lança.
     */
    async encerrarOutrasSessoes(acesso: string): Promise<{ ok: boolean }> {
      try {
        const resposta = await buscar(`${ambiente.url}/auth/v1/logout?scope=others`, {
          method: "POST",
          headers: { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${acesso}` },
          signal: prazo(),
        });
        await resposta.body?.cancel();
        return { ok: resposta.ok };
      } catch {
        return { ok: false };
      }
    },
  };
}

export type Auth = ReturnType<typeof criarAuth>;
