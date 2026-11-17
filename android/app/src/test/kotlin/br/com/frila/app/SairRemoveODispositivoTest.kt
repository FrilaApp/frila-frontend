package br.com.frila.app

import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.perfil.PerfilViewModel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module

/**
 * C0-10 (P2 do Lince no #855): o "Sair" do Perfil, montado pelo grafo real do Koin, tem de pedir `remover_dispositivo`
 * com o token do FCM e o token de acesso de quem saiu. A limpeza local continua na hora: a tela navega logo depois.
 */
class SairRemoveODispositivoTest {

    @Test
    fun `Sair do perfil limpa a sessao na hora e remove o aparelho com o token de quem saiu`() {
        val servico = mockk<ServicoDispositivo>(relaxed = true)
        mockkStatic(::lerTokenDoFcm)
        coEvery { lerTokenDoFcm() } returns "token-fcm-sintetico-para-teste"
        val koin = startKoin {
            modules(moduloSeguranca, moduloRede, moduloNotificacoes, moduloFeatures, moduloDestinoDaConta, module {
                single<ServicoDispositivo> { servico }
            })
        }.koin
        try {
            val armazenamento = koin.get<ArmazenamentoDeSessao>()
            armazenamento.salvarSessao(Sessao("access-A", "refresh-A", "bearer", 3600, "vinculo-A"))

            koin.get<PerfilViewModel>().aoDeslogar()

            assertNull(armazenamento.obterSessao())
            coVerify(exactly = 1, timeout = 5_000) { servico.removerDispositivo("token-fcm-sintetico-para-teste", "access-A") }
        } finally {
            koin.get<GestorClienteKtor>().close()
            stopKoin()
            unmockkAll()
        }
    }
}
