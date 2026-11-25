import { env } from "cloudflare:workers";

import { ambienteDoSupabase, listaDeEmailsDeDemonstracao } from "./ambiente";
import { criarAuth } from "./auth";
import { criarFuncoesDoUsuario } from "./conta/dados";
import { fotoDoPerfil } from "./contratante/foto-do-perfil";
import { chavesDoIp, criarApiDoUsuario } from "./saida-rest";
import type { SessaoAtual } from "./sessao";

/** Cliente do Auth com as variáveis deste Worker. `null` quando o ambiente está sem o endereço do Supabase. */
export function authDesteAmbiente() {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarAuth(ambiente, { chavesIp: chavesDoIpDesteAmbiente() }) : null;
}

/**
 * Chaves da assinatura do IP do visitante (B-116, `saida-rest.ts`): secret opcional `IP_VISITANTE_HMAC` e var
 * `IP_VISITANTE_HMAC_ID`. Sem o secret (local, testes), a chamada sai sem os cabeçalhos.
 */
export function chavesDoIpDesteAmbiente() {
  return chavesDoIp(env as { IP_VISITANTE_HMAC?: string; IP_VISITANTE_HMAC_ID?: string });
}

/** Cliente da API com o token de quem entrou e o IP do visitante assinado na saída (a sessão leva os dois). */
export function apiDoUsuario(sessao: SessaoAtual) {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarApiDoUsuario(ambiente, sessao, { chaves: chavesDoIpDesteAmbiente() }) : null;
}

/** Edge Functions com o token de quem entrou (exportar os dados, excluir a conta). */
export function funcoesDoUsuario(acesso: string) {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? criarFuncoesDoUsuario(ambiente, acesso) : null;
}

/** A miniatura do perfil do profissional, como `data:` (o Worker busca; o token do link não vai ao navegador). */
export async function fotoDoProfissional(sessao: SessaoAtual, profissionalId: string): Promise<string | null> {
  const ambiente = ambienteDoSupabase(env);
  return ambiente ? fotoDoPerfil(ambiente, sessao, profissionalId, { chaves: chavesDoIpDesteAmbiente() }) : null;
}

/** E-mails da conta de demonstração aceitos neste ambiente: vêm do segredo opcional EMAILS_DE_DEMONSTRACAO (sem ele, lista vazia). */
export function emailsDeDemonstracao(): Set<string> {
  return listaDeEmailsDeDemonstracao((env as { EMAILS_DE_DEMONSTRACAO?: string }).EMAILS_DE_DEMONSTRACAO);
}
