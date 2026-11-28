package br.com.frila.feature.chamadas.casa

import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão pegbbZsk (item 250): na busca da casa, a conta suspensa e o "sem permissão" têm texto próprio, como no iOS
 * (`BuscaDeProfissionaisViewModel.swift:396-399`, `TextosBuscaDeProfissionais.swift`), e não mais "Verifique sua conexão". O contrato
 * (`buscarProfissionais`, 0.2.88) manda a conta suspensa como `403 sem_permissao` com `details: conta_suspensa`; o código puro
 * `conta_suspensa` também é tratado, como no iOS. `recurso_desligado` e `termos_pendentes` continuam à frente. Fora: o "carregar mais".
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class BuscaErrosDeContaTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val garcom = "33333333-3333-3333-3333-333333333333"

    private fun buscaComRecusa(status: HttpStatusCode, codigo: String, detalhes: String? = null): BuscaDeProfissionaisViewModel {
        val rede = RedeDeTeste().apply { recusa("buscar_profissionais", status, codigo, detalhes) }
        var contador = 0
        val vm = BuscaDeProfissionaisViewModel(
            estabelecimentoId = casa,
            recursoHabilitado = { true },
            buscarProfissionais = rede.chamadas::buscarProfissionais,
            chamarProfissional = rede.chamadas::chamarProfissional,
            aceitarTermos = rede.chamadas::aceitarTermos,
            minhasChamadas = { estado, cursor -> rede.chamadas.minhasChamadas(estado = estado, cursor = cursor) },
            detalheChamada = rede.chamadas::detalheChamada,
            novaChave = { "chave-${++contador}" },
            prazoMs = 5_000,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.definirFuncao(garcom)
        runBlocking { vm.buscar().join() }
        return vm
    }

    @Test
    fun `os textos sao os do iOS`() {
        assertEquals("Sua conta está suspensa e não pode buscar profissionais agora.", TextosChamadaCasa.BUSCA_CONTA_SUSPENSA)
        assertEquals("Sua conta não tem permissão para buscar profissionais.", TextosChamadaCasa.BUSCA_SEM_PERMISSAO)
    }

    @Test
    fun `403 sem_permissao com details conta_suspensa mostra o texto de conta suspensa`() {
        val vm = buscaComRecusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa")

        assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_CONTA_SUSPENSA), vm.estado.value.estado)
        assertTrue(vm.estado.value.resultados.isEmpty())
        assertTrue(vm.estado.value.podeBuscar)
    }

    @Test
    fun `403 sem_permissao puro mostra o texto de sem permissao, e outro details tambem`() {
        for (detalhes in listOf(null, "outra_coisa", "")) {
            val vm = buscaComRecusa(HttpStatusCode.Forbidden, "sem_permissao", detalhes)

            assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_SEM_PERMISSAO), vm.estado.value.estado, "details=$detalhes")
            assertTrue(vm.estado.value.podeBuscar, "details=$detalhes")
        }
    }

    @Test
    fun `conta_suspensa como codigo puro mostra o texto de conta suspensa`() {
        val vm = buscaComRecusa(HttpStatusCode.Forbidden, "conta_suspensa")

        assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_CONTA_SUSPENSA), vm.estado.value.estado)
    }

    @Test
    fun `recurso desligado e termos pendentes continuam a frente do sem permissao`() {
        assertEquals(EstadoDaBusca.Indisponivel, buscaComRecusa(HttpStatusCode.Forbidden, "sem_permissao", "recurso_desligado").estado.value.estado)
        assertTrue(buscaComRecusa(HttpStatusCode.Forbidden, "sem_permissao", "termos_pendentes").estado.value.estado is EstadoDaBusca.TermosPendentes)
    }

    @Test
    fun `limite de buscas e o erro generico continuam com os seus textos`() {
        assertEquals(
            EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS),
            buscaComRecusa(HttpStatusCode.TooManyRequests, "limite_excedido").estado.value.estado,
        )
        for ((status, codigo) in listOf(
            HttpStatusCode.InternalServerError to "erro_interno",
            HttpStatusCode.Unauthorized to "nao_autenticado",
            HttpStatusCode.UnprocessableEntity to "campo_invalido",
            HttpStatusCode.Conflict to "codigo_que_o_app_nao_conhece",
        )) {
            assertEquals(
                EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO),
                buscaComRecusa(status, codigo).estado.value.estado,
                "$status $codigo",
            )
        }
    }

    @Test
    fun `os tres textos de erro de conta sao diferentes entre si e do de conexao`() {
        val textos = listOf(
            TextosChamadaCasa.BUSCA_CONTA_SUSPENSA, TextosChamadaCasa.BUSCA_SEM_PERMISSAO,
            TextosChamadaCasa.BUSCA_ERRO, TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS,
        )
        assertEquals(textos.size, textos.toSet().size)
    }
}
