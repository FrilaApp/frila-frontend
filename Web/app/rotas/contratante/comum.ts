import { faixaDeAvisoDoValor, valorEmCentavos } from "../../servidor/contratante/publicar-vaga";
import { textos } from "../../textos/pt-BR";

/** Aviso não bloqueante para o campo de valor digitado (B-124). */
export function avisoDoValor(bruto: string): string | undefined {
  const faixa = faixaDeAvisoDoValor(valorEmCentavos(bruto.trim()));
  if (faixa === "baixo") return textos.contratante.publicar.avisos.valorBaixo;
  if (faixa === "alto") return textos.contratante.publicar.avisos.valorAlto;
  return undefined;
}

/** Troca `{chave}` pelos valores: o catálogo guarda só texto, a tela põe os números. */
export const preencher = (modelo: string, valores: Record<string, number | string>) =>
  modelo.replace(/\{(\w+)\}/g, (_, chave: string) => String(valores[chave] ?? ""));

/**
 * Este formulário é o que está em andamento? A tela tem vários formulários e o `navigation.state` é um só:
 * o texto de "Cancelando…" ou "Publicando…" só vale para o botão que a pessoa tocou (e, entre os candidatos, para o escolhido).
 */
export function enviandoEste(navegacao: { formData?: FormData }, intencao: string, candidatura?: string): boolean {
  const enviado = navegacao.formData;
  if (!enviado || enviado.get("intencao") !== intencao) return false;
  return candidatura === undefined || enviado.get("candidatura_id") === candidatura;
}

/** "Republicar 1 lugar" no singular, "Republicar 2 lugares" no plural: cada forma é uma frase do catálogo. */
export const rotuloDosRestantes = (n: number) =>
  n === 1 ? textos.contratante.acoes.restantesUm : preencher(textos.contratante.acoes.restantes, { n });
