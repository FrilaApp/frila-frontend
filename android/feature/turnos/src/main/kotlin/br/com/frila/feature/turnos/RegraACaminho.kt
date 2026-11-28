package br.com.frila.feature.turnos

import java.time.Duration
import java.time.Instant

/**
 * US14, RF12: o aviso vale de 3 horas antes do início até 15 minutos depois de greatest(início, confirmação) (contrato 0.2.106; o
 * servidor confere, `422 a_caminho_fora_da_janela`). Sem `confirmado_em` (servidor anterior), o fim é 15 minutos depois do início.
 */
private val ANTECEDENCIA_DO_A_CAMINHO: Duration = Duration.ofHours(3)
private val TOLERANCIA_DO_A_CAMINHO: Duration = Duration.ofMinutes(15)

/**
 * O "Estou a caminho" só se oferece no turno confirmado, dentro da janela, sem check-in e ainda sem aviso
 * (paridade com `MeuTurnoViewModel.podeAvisarACaminho` do iOS). As bordas da janela estão dentro.
 */
fun podeAvisarACaminho(turno: ItemTurno, agora: Instant): Boolean {
    if (turno.estado != "confirmada") return false
    if (turno.aCaminhoEm != null) return false
    if (turno.comprovante != null) return false
    // Cil1zc0C: o substituto confirmado depois do início ganha os mesmos 15 minutos a partir da confirmação; a abertura não muda.
    val baseDoFim = turno.confirmadoEm?.let { maxOf(turno.inicio, it) } ?: turno.inicio
    return !agora.isBefore(turno.inicio.minus(ANTECEDENCIA_DO_A_CAMINHO)) && !agora.isAfter(baseDoFim.plus(TOLERANCIA_DO_A_CAMINHO))
}

/** Textos do "Estou a caminho" (paridade com `TextosDoProfissional.Turnos` do iOS). */
object TextosACaminho {
    const val BOTAO = "Estou a caminho"
    const val AVISANDO = "Avisando…"
    const val ERRO_FORA_DA_JANELA = "O aviso a caminho só pode ser enviado de 3 horas antes até 15 minutos após o início do turno."
    const val ERRO_SEM_REDE = "Sem conexão. Tente de novo quando a internet voltar."
    const val ERRO_CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, o aviso não pode ser enviado."
    const val ERRO_GENERICO = "Não foi possível enviar o aviso. Tente novamente."

    fun avisou(hora: String): String = "Você avisou que está a caminho às $hora."
}
