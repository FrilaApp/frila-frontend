package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.ExclusaoDeContaDto
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.TurnoDto

/** Status da tela de perfil. */
enum class StatusPerfil { CARREGANDO, SUCESSO, ERRO }

/** Status do fluxo de exclusão de conta (RF25/RN15/RNF08, UC16). */
enum class StatusExclusao { OCIOSO, DIALOGO_ABERTO, EXCLUINDO, SUCESSO, ERRO }

/**
 * Resumo de remunerações acordadas (RF16): soma dos valores de [TurnoDto.valorAcordadoCentavos]
 * dos turnos `cumprida` (concluído) e `confirmada` (pendente) do profissional. Turnos `cancelada`
 * nunca entram nesta soma. O Frila não é parte do pagamento (RN09 / Zero Escrow) — este resumo é
 * só a leitura dos valores combinados diretamente entre profissional e estabelecimento, nunca um
 * saldo, carteira ou extrato de uma conta mantida pelo app.
 */
data class ResumoFinanceiroPerfil(
    val totalConcluidoCentavos: Long,
    val totalPendenteCentavos: Long,
    val turnosCumpridosQtd: Int,
    val turnosAgendadosQtd: Int,
) {
    val totalGeralCentavos: Long get() = totalConcluidoCentavos + totalPendenteCentavos

    val totalConcluidoFormatado: String get() = Dinheiro(totalConcluidoCentavos).formatado()
    val totalPendenteFormatado: String get() = Dinheiro(totalPendenteCentavos).formatado()
    val totalGeralFormatado: String get() = Dinheiro(totalGeralCentavos).formatado()

    val temHistorico: Boolean get() = (turnosCumpridosQtd + turnosAgendadosQtd) > 0

    companion object {
        val VAZIO = ResumoFinanceiroPerfil(
            totalConcluidoCentavos = 0,
            totalPendenteCentavos = 0,
            turnosCumpridosQtd = 0,
            turnosAgendadosQtd = 0,
        )
    }
}

/** Estado da tela de perfil do profissional (RF02/RF03/RF16/RF25). */
data class EstadoPerfil(
    val status: StatusPerfil = StatusPerfil.CARREGANDO,
    val perfil: PerfilProfissionalDto? = null,
    val mensagemErro: String? = null,
    val resumoFinanceiro: ResumoFinanceiroPerfil? = null,
    /** RF16/RNF10: turnos usados para montar o extrato em PDF (mesma lista de [resumoFinanceiro]). */
    val turnosExtrato: List<TurnoDto> = emptyList(),
    val statusExclusao: StatusExclusao = StatusExclusao.OCIOSO,
    val mensagemErroExclusao: String? = null,
    val resultadoExclusao: ExclusaoDeContaDto? = null,
    val bio: String = "",
    val bioEmEdicao: String = "",
    val estaEditandoBio: Boolean = false,
    val especialidadesDisponiveis: List<String> = ESPECIALIDADES_PADRAO,
    val especialidadesSelecionadas: Set<String> = emptySet(),
) {
    val caracteresRestantesBio: Int
        get() = LIMITE_MAXIMO_BIO - bioEmEdicao.length

    companion object {
        const val LIMITE_MAXIMO_BIO = 280

        val ESPECIALIDADES_PADRAO: List<String> = listOf(
            "Coquetelaria clássica",
            "Barista e cafés especiais",
            "Vinhos e sommellerie",
            "Parrilla e churrasco",
            "Eventos corporativos",
            "Casamentos e celebrações",
            "Buffet volante",
            "Confeitaria e sobremesas",
            "Cozinha quente",
            "Cozinha internacional",
        )
    }
}
