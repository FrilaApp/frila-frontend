package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade

/**
 * Elegibilidade do selo voluntário "Identidade Verificada" (RN14) e consentimento de biometria
 * (RN15). Regras puras: o servidor segue como autoridade e recusa o que o cliente deixar passar
 * (`409 verificacao_indisponivel`, `403 sem_permissao`).
 */
object RegraSeloConfianca {

    /** Estados em que `solicitar_upload_verificacao` é aceito: sem exigência, exigida ou recusada. */
    private val STATUS_QUE_ACEITAM_ENVIO = setOf(
        StatusVerificacaoIdentidade.NAO_EXIGIDA,
        StatusVerificacaoIdentidade.PENDENTE,
        StatusVerificacaoIdentidade.REJEITADA,
    )

    /** Maior de idade (RN20) e em estado que aceita um novo envio de evidências. */
    fun podeSolicitarVerificacao(status: StatusVerificacaoIdentidade, idade: Int): Boolean =
        idade >= ValidadorMaioridade.IDADE_MINIMA_ANOS && status in STATUS_QUE_ACEITAM_ENVIO

    /** Estados em que `confirmar_envio_verificacao` é aceito: os do envio, mais `em_analise` (idempotente). */
    private val STATUS_QUE_ACEITAM_CONFIRMACAO = STATUS_QUE_ACEITAM_ENVIO + StatusVerificacaoIdentidade.EM_ANALISE

    /**
     * Confirmar de novo com a análise em curso devolve o mesmo estado, sem reabrir a análise
     * (contrato 0.2.50). Com a verificação aprovada o servidor devolve `409 verificacao_indisponivel`.
     * Quem chama garante que as URLs de upload já foram pedidas e usadas nesta sessão.
     */
    fun podeConfirmarEnvio(status: StatusVerificacaoIdentidade): Boolean =
        status in STATUS_QUE_ACEITAM_CONFIRMACAO

    /** Sem registro, recusado ou sem versão do termo: a coleta de biometria não pode começar. */
    fun precisaConsentimentoLgpd(consentimento: ConsentimentoBiometriaLGPD?): Boolean =
        consentimento == null || !consentimento.consentido || consentimento.versaoTermo.isBlank()
}
