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
