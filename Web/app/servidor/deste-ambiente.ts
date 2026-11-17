import { env } from "cloudflare:workers";

import { ambienteDoSupabase } from "./ambiente";
import { criarApi } from "./api";
import { criarAuth } from "./auth";

/** Cliente do Auth com as variáveis deste Worker. `null` quando o ambiente está sem o endereço do Supabase. */
export function authDesteAmbiente() {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarAuth(ambiente) : null;
}

/** Cliente da API com o token de quem entrou. */
export function apiDoUsuario(acesso: string) {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarApi(ambiente, { token: acesso }) : null;
}

/** E-mails da conta de demonstração aceitos neste ambiente (só o de dev declara; em produção a lista é vazia). */
export function emailsDeDemonstracao(): Set<string> {
  const bruto = (env as { EMAILS_DE_DEMONSTRACAO?: string }).EMAILS_DE_DEMONSTRACAO ?? "";
  return new Set(bruto.split(",").map((email) => email.trim().toLowerCase()).filter(Boolean));
}
