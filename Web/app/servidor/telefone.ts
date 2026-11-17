/**
 * Converte o telefone digitado (com ou sem +55, com qualquer pontuação) para o formato do contrato (E.164).
 * Só confere o formato de um número do Brasil: DDD de 2 dígitos + 8 ou 9 dígitos. Quem valida de verdade é o servidor.
 */
export function telefoneParaE164(digitado: string): string | null {
  let digitos = digitado.replace(/\D/g, "");
  // Zero antes do DDD ("061 9...").
  if ((digitos.length === 11 || digitos.length === 12) && digitos.startsWith("0")) {
    digitos = digitos.slice(1);
  }
  // Código do país. Só com 12 ou 13 dígitos, para não confundir com o DDD 55.
  if ((digitos.length === 12 || digitos.length === 13) && digitos.startsWith("55")) {
    digitos = digitos.slice(2);
  }
  if (!/^[1-9][0-9]{9,10}$/.test(digitos)) {
    return null;
  }
  return `+55${digitos}`;
}
