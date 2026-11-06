package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.ConsentimentoBiometriaLGPD
import br.com.frila.core.dominio.modelo.StatusVerificacaoIdentidade
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RegraSeloConfiancaTest {

    private val statusQueAceitamEnvio = setOf(
        StatusVerificacaoIdentidade.NAO_EXIGIDA,
        StatusVerificacaoIdentidade.PENDENTE,
        StatusVerificacaoIdentidade.REJEITADA,
    )

    private fun consentimento(consentido: Boolean = true, versao: String = "2026-11") =
        ConsentimentoBiometriaLGPD(consentido = consentido, versaoTermo = versao, dataHoraIso = "2026-11-06T12:00:00Z")

    @Test
    fun `maior de idade em estado que aceita envio pode solicitar`() {
        statusQueAceitamEnvio.forEach { status ->
            assertTrue(RegraSeloConfianca.podeSolicitarVerificacao(status, idade = 30), "status=$status")
        }
    }

    @Test
    fun `exatamente 18 anos pode solicitar e 17 nao`() {
        assertTrue(RegraSeloConfianca.podeSolicitarVerificacao(StatusVerificacaoIdentidade.NAO_EXIGIDA, idade = 18))
        assertFalse(RegraSeloConfianca.podeSolicitarVerificacao(StatusVerificacaoIdentidade.NAO_EXIGIDA, idade = 17))
    }

    @Test
    fun `menor de idade nao solicita em nenhum estado`() {
        StatusVerificacaoIdentidade.entries.forEach { status ->
            assertFalse(RegraSeloConfianca.podeSolicitarVerificacao(status, idade = 17), "status=$status")
        }
    }

    @Test
    fun `em analise e aprovada nao solicitam mesmo sendo adulto`() {
        assertFalse(RegraSeloConfianca.podeSolicitarVerificacao(StatusVerificacaoIdentidade.EM_ANALISE, idade = 30))
        assertFalse(RegraSeloConfianca.podeSolicitarVerificacao(StatusVerificacaoIdentidade.APROVADA, idade = 30))
    }

    @Test
    fun `confirmar envio vale nos estados que aceitam envio e em analise`() {
        val aceitos = statusQueAceitamEnvio + StatusVerificacaoIdentidade.EM_ANALISE
        StatusVerificacaoIdentidade.entries.forEach { status ->
            assertEquals(
                status in aceitos,
                RegraSeloConfianca.podeConfirmarEnvio(status),
                "status=$status",
            )
        }
    }

    @Test
    fun `confirmar envio e idempotente em analise e recusado apenas quando aprovada`() {
        assertTrue(RegraSeloConfianca.podeConfirmarEnvio(StatusVerificacaoIdentidade.EM_ANALISE))
        assertFalse(RegraSeloConfianca.podeConfirmarEnvio(StatusVerificacaoIdentidade.APROVADA))
    }

    @Test
    fun `sem consentimento registrado exige consentimento`() {
        assertTrue(RegraSeloConfianca.precisaConsentimentoLgpd(null))
    }

    @Test
    fun `consentimento recusado exige consentimento`() {
        assertTrue(RegraSeloConfianca.precisaConsentimentoLgpd(consentimento(consentido = false)))
    }

    @Test
    fun `consentimento sem versao do termo exige consentimento`() {
        assertTrue(RegraSeloConfianca.precisaConsentimentoLgpd(consentimento(versao = "")))
        assertTrue(RegraSeloConfianca.precisaConsentimentoLgpd(consentimento(versao = "  ")))
    }

    @Test
    fun `consentimento dado com versao do termo nao exige de novo`() {
        assertFalse(RegraSeloConfianca.precisaConsentimentoLgpd(consentimento()))
    }
}
