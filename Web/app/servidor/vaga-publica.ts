/**
 * A vaga pelo link, sem login (vaga_publica): só os campos publicáveis. A web chama SEM o token de quem entrou,
 * só com a chave publicável. Endereço exato e contato nunca saem por aqui (decisão do Cauê): só para quem foi aceito.
 */
import type { components } from "../contrato/tipos.gerado";
import type { Api } from "./api";

export type VagaPublica = components["schemas"]["VagaPublica"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type LeituraDaVagaPublica = { estado: "ok"; vaga: VagaPublica } | { estado: "nao_encontrada" } | { estado: "indisponivel" };

export async function lerVagaPublica(api: Api | null, vagaId: string): Promise<LeituraDaVagaPublica> {
  if (!UUID.test(vagaId)) return { estado: "nao_encontrada" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/vaga_publica", { params: { query: { vaga_id: vagaId } }, signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", vaga: data };
    return { estado: response.status === 404 ? "nao_encontrada" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** Encerrada para a web (regra do contrato): não publicada, sem lugar aberto ou já começada. */
export function vagaEncerrada(vaga: VagaPublica, agora: Date = new Date()): boolean {
  return vaga.estado !== "publicada" || vaga.posicoes_abertas <= 0 || new Date(vaga.inicio_em) <= agora;
}

/** Entra no índice dos buscadores só com a chave ligada E a vaga aberta. */
export function podeIndexar(vaga: VagaPublica, chave: string | undefined, agora: Date = new Date()): boolean {
  return chave === "1" && !vagaEncerrada(vaga, agora);
}

/** Removida para o link (410): cancelada, encerrada ou já começada. A preenchida que ainda vai acontecer continua (200). */
export function vagaRemovida(vaga: VagaPublica, agora: Date = new Date()): boolean {
  return vaga.estado === "cancelada" || vaga.estado === "encerrada" || new Date(vaga.inicio_em) <= agora;
}

/**
 * JobPosting (schema.org) só com o que a página mostra: função, valor, data e horário, região e o nome da casa.
 * Nunca endereço, coordenada, contato, documento ou id de pessoa. Sem o nome (casa com CPF), quem anuncia é o
 * Frila (contrato 0.2.101). `datePosted` e `validThrough` são exigidos pelo esquema e não são dado pessoal.
 */
export function dadosEstruturados(vaga: VagaPublica, descricao: string) {
  return {
    "@context": "https://schema.org",
    "@type": "JobPosting",
    title: vaga.funcao.nome,
    description: descricao,
    datePosted: vaga.publicado_em,
    validThrough: vaga.inicio_em,
    employmentType: "TEMPORARY",
    hiringOrganization: { "@type": "Organization", name: vaga.estabelecimento_nome ?? "Frila" },
    jobLocation: {
      "@type": "Place",
      address: {
        "@type": "PostalAddress",
        ...(vaga.regiao_administrativa ? { addressLocality: vaga.regiao_administrativa } : {}),
        addressRegion: "DF",
        addressCountry: "BR",
      },
    },
    // O valor é do turno (diária): "DAY" é a unidade do esquema que mais se aproxima.
    baseSalary: { "@type": "MonetaryAmount", currency: "BRL", value: { "@type": "QuantitativeValue", value: vaga.valor_centavos / 100, unitText: "DAY" } },
  };
}
