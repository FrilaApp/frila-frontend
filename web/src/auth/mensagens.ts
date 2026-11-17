import type { Falha } from './cliente.ts'

/**
 * Texto provisório para a tela (o texto final é do design). Nunca inclui o e-mail nem o código
 * digitado: a falha também não os carrega.
 */
export function mensagemDaFalha(falha: Falha): string {
  switch (falha.motivo) {
    case 'codigo_invalido':
      return 'O código não confere ou expirou. Confira o código recebido ou peça um novo.'
    case 'limite_excedido':
      return `Muitas tentativas. Tente de novo em ${falha.esperaSegundos} s.`
    case 'email_invalido':
      return 'Esse e-mail não parece válido. Confira e tente de novo.'
    case 'rede':
      return 'Sem conexão com o servidor. Verifique a internet e tente de novo.'
    case 'erro_do_servidor':
      return 'Algo deu errado do nosso lado. Tente de novo em instantes.'
  }
}
