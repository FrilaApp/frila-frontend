/**
 * Registro de eventos de uso (6.6, `registrar_evento`): só os do dicionário fechado do contrato e só ids (RN15, nada
 * de texto livre nem dado pessoal). Os mesmos gestos que o app registra, e só depois que deram certo no servidor.
 *
 * Nunca atrasa nem derruba a resposta: o pedido sai pelo `waitUntil` do Worker, com prazo curto, e qualquer falha é
 * ignorada (sem fila: a web não tem uso sem rede). `vaga_vista` fica de fora: o app conta o cartão que apareceu na tela,
 * e a web, sem JavaScript, não sabe o que apareceu.
 *
 * O módulo do Worker é carregado na hora: fora do Worker (nos testes, por exemplo) o registro simplesmente não sai.
 */
import type { components } from "../contrato/tipos.gerado";
import { ambienteDoSupabase } from "./ambiente";
import { chavesDoIp, criarApiDoUsuario } from "./saida-rest";
import type { SessaoAtual } from "./sessao";

export type Evento = components["schemas"]["EventoDeTelemetria"];
type Ids = { vaga_id?: string; turno_id?: string };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PRAZO_MS = 3000;

/** O corpo do pedido: o evento e só os ids que são uuid. A hora fica com o servidor (não há envio atrasado). */
export function corpoDoEvento(evento: Evento, ids: Ids = {}) {
  return {
    evento,
    ...(ids.vaga_id && UUID.test(ids.vaga_id) ? { vaga_id: ids.vaga_id } : {}),
    ...(ids.turno_id && UUID.test(ids.turno_id) ? { turno_id: ids.turno_id } : {}),
  };
}

export function registrarEvento(sessao: SessaoAtual, evento: Evento, ids: Ids = {}): void {
  const corpo = corpoDoEvento(evento, ids);
  // Token e IP do visitante são capturados AGORA, com o pedido vivo e de forma síncrona: o resto roda depois da resposta
  // (import + waitUntil) e não pode depender do que mudar nesse meio tempo. A assinatura sai na hora do envio.
  const origem = { acesso: sessao.acesso, visitante: sessao.visitante };
  import("cloudflare:workers")
    .then(({ env, waitUntil }) => {
      const ambiente = ambienteDoSupabase(env);
      if (!ambiente) return;
      const api = criarApiDoUsuario(ambiente, origem, { chaves: chavesDoIp(env as { IP_VISITANTE_HMAC?: string; IP_VISITANTE_HMAC_ID?: string }) });
      waitUntil(api.POST("/rpc/registrar_evento", { body: corpo, signal: AbortSignal.timeout(PRAZO_MS) }).then(() => undefined, () => undefined));
    })
    .catch(() => undefined);
}
