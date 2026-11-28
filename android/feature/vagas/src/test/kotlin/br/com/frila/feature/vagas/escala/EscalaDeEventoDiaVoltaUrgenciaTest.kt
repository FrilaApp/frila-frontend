package br.com.frila.feature.vagas.escala

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import java.time.LocalDate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão 1ZasKsGz (item 231): mudar o dia do evento leva as vagas junto; a vaga em SELEÇÃO que, no dia novo, perdeu as 24 h de
 * antecedência (RN24) volta para URGÊNCIA, como no iOS (`PublicarEscalaViewModel.deslocarVagas`, que usa `selecaoDisponivel`).
 * Antes ela ficava em SELEÇÃO com o chip desabilitado e só o Publicar mostrava o erro. A limpeza das marcas de início e modo ao mudar
 * o dia também não tinha teste. Fora: `editarInicio`, que já reverte.
 */
class EscalaDeEventoDiaVoltaUrgenciaTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val funcoesJson = """[{"id":"f1","nome":"Garçom","categoria":"Salão"},{"id":"f2","nome":"Cozinheiro","categoria":"Cozinha"}]"""

    /** Quarta-feira, 12h em Brasília: o evento nasce daqui a 7 dias (17/11), a vaga às 18h. */
    private var agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun viewModel(publicar: (() -> Pair<HttpStatusCode, String>)? = null): EscalaDeEventoViewModel {
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("/funcao")) {
                respond(funcoesJson, HttpStatusCode.OK, json)
            } else {
                val (status, corpo) = publicar!!()
                respond(corpo, status, json)
            }
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        var chaves = 0
        return EscalaDeEventoViewModel(
            estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
            buscarFuncoes = servico::listarFuncoes,
            enviarEscala = servico::publicarEscala,
            relogio = { agora },
            novaChave = { "chave-${++chaves}" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    /** Duas vagas na data de hoje + 7: a primeira em seleção, a segunda em urgência. */
    private fun EscalaDeEventoViewModel.comDuasVagas(): Pair<Int, Int> {
        runBlocking { carregarFuncoes().join() }
        editarNome("Formatura de Direito")
        val primeira = estado.value.itens.single().id
        escolherFuncao(primeira, "f1"); editarValor(primeira, "180"); editarPosicoes(primeira, "4"); editarResponsavel(primeira, "Lia")
        escolherModo(primeira, ModoDaVaga.SELECAO)
        adicionarVaga()
        val segunda = estado.value.itens.last().id
        escolherFuncao(segunda, "f2"); editarValor(segunda, "220,50"); editarPosicoes(segunda, "2")
        escolherModo(segunda, ModoDaVaga.URGENCIA)
        return primeira to segunda
    }

    private fun EscalaDeEventoViewModel.modoDe(id: Int) = estado.value.itens.first { it.id == id }.modo

    @Test
    fun `mudar o dia para hoje volta a vaga em selecao para urgencia, e a em urgencia segue em urgencia`() {
        val vm = viewModel()
        val (selecao, urgencia) = vm.comDuasVagas()
        assertEquals(ModoDaVaga.SELECAO, vm.modoDe(selecao))

        vm.editarData(LocalDate.of(2026, 11, 10))

        assertEquals(ModoDaVaga.URGENCIA, vm.modoDe(selecao), "perdeu as 24 h: volta para urgência")
        assertEquals(ModoDaVaga.URGENCIA, vm.modoDe(urgencia))
        assertTrue(vm.estado.value.itens.none { it.modo == ModoDaVaga.SELECAO && !vm.estado.value.copy(agora = agora).selecaoDisponivel(it) })
    }

    @Test
    fun `mudar o dia para um dia ainda com mais de 24 horas mantem a selecao`() {
        val vm = viewModel()
        val (selecao, _) = vm.comDuasVagas()

        vm.editarData(LocalDate.of(2026, 11, 12))

        assertEquals(ModoDaVaga.SELECAO, vm.modoDe(selecao))
        val item = vm.estado.value.itens.first { it.id == selecao }
        assertEquals(Instant.parse("2026-11-12T21:00:00Z"), item.inicio)
        // O fim anda junto: a duração (4 h) não muda.
        assertEquals(Instant.parse("2026-11-13T01:00:00Z"), item.fim)
    }

    @Test
    fun `a fronteira e exata, inicio igual a agora mais 24 horas ja nao e selecao e um segundo depois e`() {
        // O início do dia 11/11 às 18h de Brasília é 21:00Z. Com agora = 10/11 21:00Z, o início é agora + 24 h exatos: não passa.
        agora = Instant.parse("2026-11-10T21:00:00Z")
        val no = viewModel()
        val (selecaoNo, _) = no.comDuasVagas()
        no.editarData(LocalDate.of(2026, 11, 11))
        assertEquals(ModoDaVaga.URGENCIA, no.modoDe(selecaoNo), "início = agora + 24 h")

        agora = Instant.parse("2026-11-10T20:59:59Z")
        val antes = viewModel()
        val (selecaoAntes, _) = antes.comDuasVagas()
        antes.editarData(LocalDate.of(2026, 11, 11))
        assertEquals(ModoDaVaga.SELECAO, antes.modoDe(selecaoAntes), "início = agora + 24 h + 1 s")
    }

    @Test
    fun `o dia para tras tambem volta e o dia para frente nunca promove urgencia a selecao`() {
        val vm = viewModel()
        val (_, urgencia) = vm.comDuasVagas()

        vm.editarData(LocalDate.of(2026, 11, 25))

        assertEquals(ModoDaVaga.URGENCIA, vm.modoDe(urgencia), "urgência escolhida pela pessoa fica")
    }

    // ---- a limpeza das marcas ao mudar o dia ----

    private fun recusa(codigo: String, detalhes: String) =
        HttpStatusCode.UnprocessableEntity to """{"code":"$codigo","message":"x","details":"$detalhes"}"""

    @Test
    fun `mudar o dia apaga as marcas de inicio e de modo da vaga, e so elas`() {
        for ((codigo, detalhes, marcas) in listOf(
            Triple("selecao_sem_antecedencia", "vagas[0]", setOf(CampoDoItem.INICIO, CampoDoItem.MODO)),
            Triple("campo_invalido", "vagas[0].valor_centavos", setOf(CampoDoItem.VALOR)),
        )) {
            val vm = viewModel(publicar = { recusa(codigo, detalhes) })
            val (primeira, _) = vm.comDuasVagas()
            runBlocking { vm.publicar().join() }
            assertEquals(marcas, vm.estado.value.errosDosItens[primeira]?.keys, "$codigo antes de mudar o dia")

            vm.editarData(LocalDate.of(2026, 11, 20))

            val depois = vm.estado.value.errosDosItens[primeira].orEmpty().keys
            val esperado = marcas - setOf(CampoDoItem.INICIO, CampoDoItem.MODO)
            assertEquals(esperado, depois, "$codigo depois de mudar o dia")
        }
    }

    @Test
    fun `mudar o dia apaga a marca da data do evento`() {
        val vm = viewModel(publicar = { recusa("campo_invalido", "evento.data") })
        vm.comDuasVagas()
        runBlocking { vm.publicar().join() }
        assertEquals(setOf(CampoDoEvento.DATA), vm.estado.value.errosDoEvento.keys)

        vm.editarData(LocalDate.of(2026, 11, 20))

        assertTrue(vm.estado.value.errosDoEvento.isEmpty())
    }
}
