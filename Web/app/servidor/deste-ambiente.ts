import { env } from "cloudflare:workers";

import { ambienteDoSupabase, listaDeEmailsDeDemonstracao } from "./ambiente";
import { criarApi } from "./api";
import { criarAuth } from "./auth";
import { criarFuncoesDoUsuario } from "./conta/dados";
import { fotoDoPerfil } from "./contratante/foto-do-perfil";

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

/** Edge Functions com o token de quem entrou (exportar os dados, excluir a conta). */
export function funcoesDoUsuario(acesso: string) {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarFuncoesDoUsuario(ambiente, acesso) : null;
}

/** A miniatura do perfil do profissional, como `data:` (o Worker busca; o token do link não vai ao navegador). */
export async function fotoDoProfissional(acesso: string, profissionalId: string): Promise<string | null> {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? fotoDoPerfil(ambiente, acesso, profissionalId) : null;
}

/** E-mails da conta de demonstração aceitos neste ambiente: vêm do segredo opcional EMAILS_DE_DEMONSTRACAO (sem ele, lista vazia). */
export function emailsDeDemonstracao(): Set<string> {
  return listaDeEmailsDeDemonstracao((env as { EMAILS_DE_DEMONSTRACAO?: string }).EMAILS_DE_DEMONSTRACAO);
}
