package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.MotivoDeCancelamentoDaCasa
import br.com.frila.core.dominio.modelo.TextosDoCancelamento

/** Textos de cancelar a vaga inteira (paridade com `TextosDoCancelamento` do iOS, lado do contratante). */
object TextosCancelarVaga {
    const val NA_FILA = TextosDoCancelamento.NA_FILA_SEM_CONEXAO
    const val RECUSADA = "O cancelamento não foi aceito. Atualize a tela e tente de novo."
    const val TITULO = "Cancelar vaga"
    const val CANCELAR_VAGA_DE = "Cancelar a vaga de %s"
    const val MOTIVO_TITULO = "Qual é o motivo?"
    const val DETALHES_OPCIONAIS = "Quer explicar melhor? (opcional)"
    const val DETALHES_OBRIGATORIOS = "Descreva o motivo (pelo menos 3 caracteres)"
    const val CONFIRMAR = "Confirmar"
    const val VOLTAR = "Voltar"
    const val FECHAR = "Fechar"
    const val ENVIANDO = "Enviando o cancelamento…"
    const val FALTAM_PARA_O_INICIO = "Faltam %s para o início."
    const val MENOS_DE_UMA_HORA = "menos de 1 h"
    const val HORAS = "%d h"
    const val JA_COMECOU = "O turno já começou."
    const val EFEITO = "Todas as posições serão canceladas, e os profissionais confirmados serão avisados. Não conta como falta para ninguém."
    const val EFEITO_COMECADA =
        "Todas as posições serão canceladas, sem reabertura, e os profissionais confirmados serão avisados. Não conta como falta para ninguém."
    const val CANCELADA = "Vaga cancelada. Os profissionais confirmados foram avisados."
    const val SEM_REDE = "Sem conexão. O cancelamento não foi enviado; tente de novo quando a internet voltar."
    const val FALHA_GENERICA = "Não foi possível cancelar. Tente de novo."
    const val VAGA_JA_FECHADA = "Esta vaga já foi cancelada ou encerrada."
    const val MOTIVO_RECUSADO = "O motivo tem termos que o Frila não aceita. Reescreva com outras palavras e confirme de novo."
    const val SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente para continuar."
    const val CONTA_NAO_PODE = "Sua conta não pode realizar esta ação."
    // Os motivos vivem em `:core:dominio` (a posição usa os mesmos); aqui só os nomes que as telas e os testes da vaga já usam.
    const val MOTIVO_MOVIMENTO_MENOR = MotivoDeCancelamentoDaCasa.Textos.MOVIMENTO_MENOR
    const val MOTIVO_PREENCHIDA_FORA = MotivoDeCancelamentoDaCasa.Textos.PREENCHIDA_FORA
    const val MOTIVO_MUDANCA_DE_PLANOS = MotivoDeCancelamentoDaCasa.Textos.MUDANCA_DE_PLANOS
    const val MOTIVO_PROBLEMA_NO_LOCAL = MotivoDeCancelamentoDaCasa.Textos.PROBLEMA_NO_LOCAL
    const val MOTIVO_OUTRO = MotivoDeCancelamentoDaCasa.Textos.OUTRO
}
