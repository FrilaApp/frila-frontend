/**
 * A foto do perfil do profissional, embutida na página pelo Worker. O contrato só manda `foto_url` quando o
 * perfil_publico é chamado por POST (0.2.82), e o link é da `ler-midia`, com um token opaco de 1 h no próprio
 * endereço. O Worker pede o perfil e a miniatura no servidor e manda a imagem como `data:`. Assim a CSP não muda
 * (img-src 'self' data:) e o token do link nunca chega ao navegador. A página já sai com Cache-Control
 * private, no-store. Qualquer coisa fora do esperado vira "sem foto".
 */
import type { AmbienteDoSupabase } from "../ambiente";
import { restDoUsuario, type ChavesDoIp, type OrigemDaSaida } from "../saida-rest";

export const LIMITE_DA_FOTO = 256 * 1024;
const TIPOS = new Set(["image/jpeg", "image/png", "image/webp"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Só o link da ler-midia do próprio Supabase, em https (nada de outro endereço que o servidor mandasse). */
function linkDaLerMidia(ambiente: AmbienteDoSupabase, link: unknown): URL | null {
  if (typeof link !== "string") return null;
  try {
    const url = new URL(link);
    const base = new URL(ambiente.url);
    return url.protocol === "https:" && url.origin === base.origin && url.pathname === "/functions/v1/ler-midia" ? url : null;
  } catch {
    return null;
  }
}

/** Lê o corpo até o limite e desiste se passar (sem depender do Content-Length). */
async function lerAteOLimite(resposta: Response): Promise<Uint8Array | null> {
  const leitor = resposta.body?.getReader();
  if (!leitor) return null;
  const partes: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await leitor.read();
    if (done) break;
    total += value.length;
    if (total > LIMITE_DA_FOTO) {
      await leitor.cancel();
      return null;
    }
    partes.push(value);
  }
  const bytes = new Uint8Array(total);
  let posicao = 0;
  for (const parte of partes) {
    bytes.set(parte, posicao);
    posicao += parte.length;
  }
  return bytes;
}

function emBase64(bytes: Uint8Array): string {
  let texto = "";
  for (let i = 0; i < bytes.length; i += 0x8000) texto += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(texto);
}

export async function fotoDoPerfil(
  ambiente: AmbienteDoSupabase,
  sessao: OrigemDaSaida,
  profissionalId: string,
  opcoes: { buscar?: typeof fetch; chaves?: ChavesDoIp } = {},
): Promise<string | null> {
  if (!UUID.test(profissionalId)) return null;
  const buscar = opcoes.buscar ?? ((entrada: RequestInfo | URL, inicio?: RequestInit) => fetch(entrada, inicio));
  // O perfil sai pelo ponto único da API com token (saida-rest.ts: token e IP do visitante assinado); a miniatura é do link da ler-midia, sem nada disso.
  const rest = restDoUsuario(ambiente, sessao, { chaves: opcoes.chaves ?? {}, fetch: buscar });
  try {
    const perfil = await rest("/rpc/perfil_publico", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: profissionalId }),
      signal: AbortSignal.timeout(5000),
    });
    if (!perfil.ok) return null;
    const link = linkDaLerMidia(ambiente, ((await perfil.json()) as { foto_url?: unknown }).foto_url);
    if (!link) return null;
    const foto = await buscar(link, { signal: AbortSignal.timeout(5000) });
    const tipo = (foto.headers.get("Content-Type") ?? "").split(";")[0]?.trim() ?? "";
    if (!foto.ok || !TIPOS.has(tipo) || Number(foto.headers.get("Content-Length") ?? 0) > LIMITE_DA_FOTO) return null;
    const bytes = await lerAteOLimite(foto);
    if (!bytes || bytes.length === 0) return null;
    return `data:${tipo};base64,${emBase64(bytes)}`;
  } catch {
    return null;
  }
}
