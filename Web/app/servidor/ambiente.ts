/**
 * Lê do Worker o endereço e a chave publicável do Supabase.
 * A web só conversa com o Supabase pelo servidor, sempre com a chave PUBLICÁVEL e, quando houver
 * sessão, o token do usuário. Chave de serviço é recusada aqui, antes de qualquer pedido.
 */
export type AmbienteDoSupabase = { url: string; chavePublicavel: string };

export class ChaveProibida extends Error {
  constructor() {
    super("SUPABASE_CHAVE_PUBLICAVEL não é uma chave publicável. A web nunca usa chave de serviço.");
  }
}

export function ambienteDoSupabase(variaveis: {
  SUPABASE_URL?: string;
  SUPABASE_CHAVE_PUBLICAVEL?: string;
}): AmbienteDoSupabase | null {
  const url = variaveis.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const chavePublicavel = variaveis.SUPABASE_CHAVE_PUBLICAVEL?.trim();
  if (!url || !chavePublicavel) {
    return null;
  }
  if (ehChaveDeServico(chavePublicavel)) {
    throw new ChaveProibida();
  }
  return { url, chavePublicavel };
}

export function ehChaveDeServico(chave: string): boolean {
  if (chave.startsWith("sb_secret_")) {
    return true;
  }
  const corpo = chave.split(".")[1];
  if (!corpo) {
    return false;
  }
  try {
    const dados: unknown = JSON.parse(atob(corpo.replace(/-/g, "+").replace(/_/g, "/")));
    return typeof dados === "object" && dados !== null && "role" in dados && dados.role !== "anon";
  } catch {
    return false;
  }
}

/** Lista de e-mails de demonstração a partir do texto do segredo (separado por vírgula). Sem o segredo, a lista é vazia. */
export function listaDeEmailsDeDemonstracao(bruto: string | undefined): Set<string> {
  return new Set((bruto ?? "").split(",").map((email) => email.trim().toLowerCase()).filter(Boolean));
}
