package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import br.com.frila.core.dominio.modelo.TipoDocumentoIdentidade
import br.com.frila.core.dominio.modelo.TipoParteEvidencia
import br.com.frila.core.dominio.modelo.VerificacaoIdentidade
import br.com.frila.core.dominio.regra.RegraSeloConfianca
import br.com.frila.core.dominio.regra.ValidadorMaioridade

/** Carga do estado da verificação (`minha_identidade_status`). */
enum class StatusCargaVerificacao { CARREGANDO, PRONTO, ERRO }

/** Envio das evidências (solicitar upload, PUT das partes, confirmar). */
enum class StatusEnvioVerificacao { OCIOSO, ENVIANDO, SUCESSO, ERRO }

/**
 * Termo de consentimento específico para biometria facial (LGPD art. 11, I, RN15). Mudar o texto
 * da tela exige trocar [VERSAO]: é ela que o servidor e a moderação usam para saber o que o
 * profissional leu.
 */
object TermoBiometria {
    const val VERSAO = "2026-11-08"
}

/**
 * Estado do selo "Identidade Verificada" (RN14/RN15). As imagens nunca ficam aqui: só quais partes
 * já foram escolhidas ([partesEscolhidas]). Os bytes vivem no [VerificacaoIdentidadeViewModel] até o
 * envio ou até a tela sair, e não vão para log nem para o estado observável (RN15).
 */
data class EstadoVerificacaoIdentidade(
    val carga: StatusCargaVerificacao = StatusCargaVerificacao.CARREGANDO,
    val verificacao: VerificacaoIdentidade? = null,
    /** Só em memória: sem endpoint de consentimento no contrato, cada sessão pede de novo. */
    val consentimento: ConsentimentoBiometriaLGPD? = null,
    val documento: TipoDocumentoIdentidade = TipoDocumentoIdentidade.RG,
    val partesEscolhidas: Set<TipoParteEvidencia> = emptySet(),
    val envio: StatusEnvioVerificacao = StatusEnvioVerificacao.OCIOSO,
    val mensagemErro: String? = null,
    /** O cadastro já barra menor de 18 (RN20); o perfil não traz a data, então vale o piso. */
    val idade: Int = ValidadorMaioridade.IDADE_MINIMA_ANOS,
) {
    val precisaConsentimento: Boolean
        get() = RegraSeloConfianca.precisaConsentimentoLgpd(consentimento)

    val podeSolicitar: Boolean
        get() = verificacao?.let { RegraSeloConfianca.podeSolicitarVerificacao(it.status, idade) } == true

    val aprovada: Boolean
        get() = verificacao?.status == StatusVerificacaoIdentidade.APROVADA

    val todasAsPartesEscolhidas: Boolean
        get() = partesEscolhidas.containsAll(TipoParteEvidencia.entries)

    val podeEnviar: Boolean
        get() = podeSolicitar && !precisaConsentimento && todasAsPartesEscolhidas &&
            envio != StatusEnvioVerificacao.ENVIANDO
}
