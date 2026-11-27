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
import org.junit.jupiter.api.Assertions.assertNotNull
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
    private class Servidor(private val respostas: List<Result<EscalaPublicadaDto>>) {
        val corpos = mutableListOf<NovaEscalaDto>()
        val servico: ServicoVagas = mockk {
            coEvery { listarFuncoes() } returns listOf(FuncaoDto("f1", "Garçom", "Salão"))
            coEvery { publicarEscala(any()) } answers {
                corpos += firstArg<NovaEscalaDto>()
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
}
