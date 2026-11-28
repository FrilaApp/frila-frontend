package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.QuemRecebeDasVagas
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlin.reflect.full.memberProperties
import kotlin.reflect.jvm.isAccessible
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertSame
import org.junit.jupiter.api.Test
import org.koin.dsl.koinApplication
import org.koin.dsl.module

/**
 * Cartão QpgRwPFM: a fiação real do "Quem recebe" dos turnos agendados. O cache vive na sessão (um só, o mesmo do view model) e o
 * logout, a troca de conta e a expiração (`limparSessao`, ponto único) o esvaziam: o responsável lido é dado da conta que saiu.
 */
class KoinQuemRecebeDosTurnosTest {

    private val modulos = listOf(
        moduloSeguranca, moduloRede, moduloNotificacoes, moduloFeatures, moduloDestinoDaConta,
        module { single<ProvedorDeLocalizacao> { mockk(relaxed = true) } },
    )

    private fun servicoDeVagas(): ServicoVagas {
        val detalhe = mockk<VagaDto> { every { responsavelLocal } returns "Carlos Silva" }
        return mockk { coEvery { detalheVaga("v1") } returns detalhe }
    }

    @Test
    fun `o view model dos turnos recebe o mesmo cache da sessao, e ele le o responsavel pelo detalhe_vaga do grafo`() {
        val app = koinApplication { modules(modulos + module { single { servicoDeVagas() } }) }
        try {
            val cache = app.koin.get<QuemRecebeDasVagas>()
            val viewModel = app.koin.get<MeusTurnosViewModel>()

            val propriedade = MeusTurnosViewModel::class.memberProperties.single { it.name == "quemRecebeDasVagas" }
            propriedade.isAccessible = true
            assertSame(cache, propriedade.get(viewModel), "sem este registro o Quem recebe some sem crash nem log")
            assertEquals("Carlos Silva", runBlocking { cache.de("v1") }?.valor)
        } finally {
            app.close()
        }
    }

    @Test
    fun `o logout esvazia o cache do responsavel pelo ponto unico de limpeza da sessao`() {
        val app = koinApplication { modules(modulos + module { single { servicoDeVagas() } }) }
        try {
            val cache = app.koin.get<QuemRecebeDasVagas>()
            runBlocking { cache.de("v1") }
            assertNotNull(cache.noCache("v1"), "o responsável foi guardado")

            app.koin.get<ArmazenamentoDeSessao>().limparSessao()

            assertNull(cache.noCache("v1"), "o logout esvazia o que é da conta que saiu")
        } finally {
            app.close()
        }
    }
}
