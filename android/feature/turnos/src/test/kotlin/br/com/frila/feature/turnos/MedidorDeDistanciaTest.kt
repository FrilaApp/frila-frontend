package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** L1-4: a distância até a vaga, medida no toque e só quando a leitura vale como prova (como o iOS). */
class MedidorDeDistanciaTest {

    private val vaga = Coordenada(latitude = -15.7942, longitude = -47.8822)
    private val aUns111Metros = Coordenada(latitude = -15.7932, longitude = -47.8822)

    private fun provedor(
        permissao: Boolean = true,
        gps: Boolean = true,
        leitura: LeituraDeLocalizacao? = LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 10f, simulada = false),
    ): ProvedorDeLocalizacao {
        val p = mockk<ProvedorDeLocalizacao>()
        every { p.temPermissaoDeLocalizacao() } returns permissao
        every { p.isGpsAtivado() } returns gps
        coEvery { p.lerParaCheckin() } returns leitura
        return p
    }

    @Test
    fun `com leitura boa devolve a distancia em metros ate a vaga`() = runBlocking {
        val distancia = MedidorDeDistancia(provedor(), vaga).medir()

        assertEquals(111, distancia)
    }

    @Test
    fun `sem permissao nao le a localizacao e devolve nulo`() = runBlocking {
        val p = provedor(permissao = false)

        assertNull(MedidorDeDistancia(p, vaga).medir())
        coVerify(exactly = 0) { p.lerParaCheckin() }
    }

    @Test
    fun `com o GPS desligado nao le a localizacao e devolve nulo`() = runBlocking {
        val p = provedor(gps = false)

        assertNull(MedidorDeDistancia(p, vaga).medir())
        coVerify(exactly = 0) { p.lerParaCheckin() }
    }

    @Test
    fun `sem leitura no prazo devolve nulo`() = runBlocking {
        assertNull(MedidorDeDistancia(provedor(leitura = null), vaga).medir())
    }

    @Test
    fun `leitura com erro acima de 100 m nao prova nada e devolve nulo`() = runBlocking {
        val imprecisa = LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 100.5f, simulada = false)

        assertNull(MedidorDeDistancia(provedor(leitura = imprecisa), vaga).medir())
    }

    @Test
    fun `leitura com erro de exatamente 100 m ainda vale`() = runBlocking {
        val limite = LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 100f, simulada = false)

        assertEquals(111, MedidorDeDistancia(provedor(leitura = limite), vaga).medir())
    }

    @Test
    fun `sem o ponto da vaga nao ha distancia`() = runBlocking {
        assertNull(MedidorDeDistancia(provedor(), coordenadaDaVaga = null).medir())
    }

    @Test
    fun `falha do provedor vira nulo, nunca derruba o toque`() = runBlocking {
        val p = mockk<ProvedorDeLocalizacao>()
        every { p.temPermissaoDeLocalizacao() } returns true
        every { p.isGpsAtivado() } returns true
        coEvery { p.lerParaCheckin() } throws SecurityException("permissão revogada no meio")

        assertNull(MedidorDeDistancia(p, vaga).medir())
    }
}
