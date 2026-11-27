package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EscalaPublicadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.NovaEscalaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaPublicadaDto
import br.com.frila.feature.vagas.escala.EscalaDeEventoViewModel
import br.com.frila.feature.vagas.escala.GuardaDaEscala
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.koin.core.parameter.parametersOf
import org.koin.dsl.koinApplication
import org.koin.dsl.module

/**
 * Cartão JJnNU9Vc: publicar a escala com resultado incerto (sem rede, resposta perdida), sair da tela e voltar não pode gerar uma
 * `chave` de idempotência nova, ou o reenvio publicaria a vaga em dobro. `koinViewModel` cria um view model por visita (uma por
 * entrada da pilha de navegação), então cada visita aqui é um `get<EscalaDeEventoViewModel>` da fábrica REAL do `moduloFeatures`.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGuardaDaEscalaTest {

    private val casa = EstabelecimentoDaVaga("casa-1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822))
    private val semRede = ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "sintético")

    /** O servidor falso: as [respostas] em ordem (erro ou publicada); guarda cada corpo recebido. */
    private class Servidor(private val respostas: List<Result<EscalaPublicadaDto>>, private val travarAPrimeira: Boolean = false) {
        val corpos = mutableListOf<NovaEscalaDto>()
        val servico: ServicoVagas = mockk {
            coEvery { listarFuncoes() } returns listOf(FuncaoDto("f1", "Garçom", "Salão"))
            coEvery { publicarEscala(any()) } coAnswers {
                corpos += firstArg<NovaEscalaDto>()
                // A primeira chamada nunca responde: a pessoa sai da tela com o envio em voo.
                if (travarAPrimeira && corpos.size == 1) kotlinx.coroutines.awaitCancellation()
                respostas[corpos.size - 1].getOrThrow()
            }
        }
    }

    private fun publicada(corpo: Int = 1) = EscalaPublicadaDto("ev1", List(corpo) { VagaPublicadaDto("v", listOf("p")) })

    private fun comAplicacao(servidor: Servidor, bloco: suspend (org.koin.core.Koin) -> Unit) = runBlocking {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val app = koinApplication { modules(moduloFeatures, module { single { servidor.servico } }) }
        try { bloco(app.koin) } finally { app.close(); Dispatchers.resetMain() }
    }

    /** Uma visita à tela: um view model novo da fábrica real, com o formulário preenchido como a pessoa faria. */
    private fun visita(koin: org.koin.core.Koin): EscalaDeEventoViewModel =
        koin.get<EscalaDeEventoViewModel> { parametersOf(casa) }

    private suspend fun preencher(vm: EscalaDeEventoViewModel) {
        vm.carregarFuncoes().join()
        val id = vm.estado.value.itens.single().id
        vm.editarNome("Formatura de Direito")
        vm.escolherFuncao(id, "f1")
        vm.editarValor(id, "180")
        vm.editarResponsavel(id, "Lia")
    }

    @Test
    fun `publicacao incerta, sair e voltar reenvia com a mesma chave`() {
        val servidor = Servidor(listOf(Result.failure(semRede), Result.success(publicada())))
        comAplicacao(servidor) { koin ->
            val primeira = visita(koin)
            preencher(primeira)
            primeira.publicar().join()
            assertNotNull(primeira.estado.value.pendente, "o resultado incerto deixa a escala pendente")
            // Sair da tela: o view model da visita some com a entrada da pilha (aqui, a primeira visita é largada).

            val segunda = visita(koin)
            if (segunda.estado.value.pendente == null) preencher(segunda)
            segunda.publicar().join()

            assertEquals(2, servidor.corpos.size)
            assertEquals(servidor.corpos[0].chave, servidor.corpos[1].chave, "a chave da escala não pode mudar entre as visitas")
        }
    }

    @Test
    fun `a segunda visita volta ao formulario pendente, sem edicao, e o reenvio e o mesmo corpo`() {
        val servidor = Servidor(listOf(Result.failure(semRede), Result.success(publicada())))
        comAplicacao(servidor) { koin ->
            val primeira = visita(koin)
            preencher(primeira)
            primeira.publicar().join()

            val segunda = visita(koin)

            assertNotNull(segunda.estado.value.pendente)
            assertEquals("Formatura de Direito", segunda.estado.value.nome)
            assertEquals(false, segunda.estado.value.podeEditar)
            assertEquals(false, segunda.estado.value.enviando)
            segunda.publicar().join()
            assertEquals(servidor.corpos[0], servidor.corpos[1], "o reenvio é exatamente o mesmo corpo")
            assertNotNull(segunda.estado.value.publicada)
        }
    }

    @Test
    fun `depois do sucesso a guarda esvazia e a visita seguinte comeca limpa, com chave nova`() {
        val servidor = Servidor(listOf(Result.failure(semRede), Result.success(publicada()), Result.success(publicada())))
        comAplicacao(servidor) { koin ->
            val primeira = visita(koin)
            preencher(primeira)
            primeira.publicar().join()
            visita(koin).publicar().join() // o reenvio dá certo
            assertNull(koin.get<GuardaDaEscala>().obter(casa.id))

            val terceira = visita(koin)
            assertNull(terceira.estado.value.pendente)
            assertEquals("", terceira.estado.value.nome)
            preencher(terceira)
            terceira.publicar().join()
            assertNotEquals(servidor.corpos[1].chave, servidor.corpos[2].chave, "uma escala nova nasce com chave nova")
        }
    }

    @Test
    fun `recusa definitiva tira a casa da guarda e a visita seguinte comeca limpa`() {
        val recusa = ErroDaApi(CodigoErroAPI.CAMPO_INVALIDO, "campo_invalido", "nome", "x")
        val servidor = Servidor(listOf(Result.failure(recusa)))
        comAplicacao(servidor) { koin ->
            val primeira = visita(koin)
            preencher(primeira)
            primeira.publicar().join()
            assertNull(primeira.estado.value.pendente)
            assertNull(koin.get<GuardaDaEscala>().obter(casa.id))

            assertNull(visita(koin).estado.value.pendente)
        }
    }

    @Test
    fun `a guarda e por casa, a pendencia de uma nao aparece na outra`() {
        val outraCasa = casa.copy(id = "casa-2")
        val servidor = Servidor(listOf(Result.failure(semRede)))
        comAplicacao(servidor) { koin ->
            val daCasa1 = visita(koin)
            preencher(daCasa1)
            daCasa1.publicar().join()

            val daCasa2 = koin.get<EscalaDeEventoViewModel> { parametersOf(outraCasa) }

            assertNull(daCasa2.estado.value.pendente)
            assertNotNull(koin.get<GuardaDaEscala>().obter("casa-1"))
            assertNull(koin.get<GuardaDaEscala>().obter("casa-2"))
        }
    }

    @Test
    fun `o logout esvazia a guarda pelo ponto unico de limpeza da sessao`() {
        val servidor = Servidor(listOf(Result.failure(semRede)))
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val app = koinApplication { modules(moduloSeguranca, moduloFeatures, module { single { servidor.servico } }) }
        try {
            runBlocking {
                val vm = visita(app.koin)
                preencher(vm)
                vm.publicar().join()
                assertNotNull(app.koin.get<GuardaDaEscala>().obter(casa.id), "a pendência foi guardada")

                app.koin.get<br.com.frila.core.seguranca.ArmazenamentoDeSessao>().limparSessao()

                assertNull(app.koin.get<GuardaDaEscala>().obter(casa.id), "o logout esvazia a guarda")
                assertNull(visita(app.koin).estado.value.pendente, "a conta seguinte não herda a escala da que saiu")
            }
        } finally { app.close(); Dispatchers.resetMain() }
    }

    @Test
    fun `sair com o envio em voo volta ao pendente sem envio em curso e reenvia o mesmo corpo`() {
        val servidor = Servidor(listOf(Result.success(publicada()), Result.success(publicada())), travarAPrimeira = true)
        comAplicacao(servidor) { koin ->
            val primeira = visita(koin)
            preencher(primeira)
            primeira.publicar() // não termina: o servidor não responde
            assertEquals(true, primeira.estado.value.enviando)
            assertNotNull(koin.get<GuardaDaEscala>().obter(casa.id), "a pendência já está guardada enquanto o envio está em voo")

            val segunda = visita(koin)

            assertEquals(false, segunda.estado.value.enviando, "o envio interrompido não volta como 'enviando'")
            segunda.publicar().join()
            assertEquals(2, servidor.corpos.size)
            assertEquals(servidor.corpos[0], servidor.corpos[1])
            assertNotNull(segunda.estado.value.publicada)
        }
    }
}
