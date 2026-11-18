package br.com.frila.core.rede

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

class DemonstracaoContasTest {
    @Test
    fun `debug aceita o dominio de teste normalizado`() {
        assertTrue(DemonstracaoContas.ehContaDeDemonstracao("qualquer@frila.test", permitirDominioDeTeste = true))
        assertTrue(DemonstracaoContas.ehContaDeDemonstracao("  Qualquer@FRILA.TEST  ", permitirDominioDeTeste = true))
    }

    @Test
    fun `release e configuracao padrao nao aceitam o dominio de teste`() {
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao("qualquer@frila.test", permitirDominioDeTeste = false))
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao("  Qualquer@FRILA.TEST  ", permitirDominioDeTeste = false))
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao("qualquer@frila.test"))
    }

    @ParameterizedTest
    @ValueSource(booleans = [true, false])
    fun `contas de revisao existentes continuam aceitas nas duas configuracoes`(permitirDominioDeTeste: Boolean) {
        assertTrue(DemonstracaoContas.ehContaDeDemonstracao(DemonstracaoContas.EMAIL_PROFISSIONAL, permitirDominioDeTeste))
        assertTrue(DemonstracaoContas.ehContaDeDemonstracao(DemonstracaoContas.EMAIL_CONTRATANTE, permitirDominioDeTeste))
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao("outra@frila.app", permitirDominioDeTeste))
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao("revisao-outra@frila.app", permitirDominioDeTeste))
    }

    @ParameterizedTest
    @ValueSource(strings = ["qualquer@frila.test.exemplo.com", "qualquer@outrofrila.test", "qualquer@exemplo.com"])
    fun `debug nao inclui dominios parecidos nem contas comuns`(email: String) {
        assertFalse(DemonstracaoContas.ehContaDeDemonstracao(email, permitirDominioDeTeste = true))
    }
}
