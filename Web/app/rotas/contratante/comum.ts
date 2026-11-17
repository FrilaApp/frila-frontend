/** Troca `{chave}` pelos valores: o catálogo guarda só texto, a tela põe os números. */
export const preencher = (modelo: string, valores: Record<string, number | string>) =>
  modelo.replace(/\{(\w+)\}/g, (_, chave: string) => String(valores[chave] ?? ""));
