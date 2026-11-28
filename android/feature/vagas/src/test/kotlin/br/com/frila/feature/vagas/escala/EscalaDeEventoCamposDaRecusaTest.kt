package br.com.frila.feature.vagas.escala

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão K2xXrnQP (item 229): cada `details` da recusa do servidor marca o campo certo (`aplicarRecusa`, `aplicarCampo`,
 * `CAMPOS_DO_ITEM`; iOS `PublicarEscalaViewModel.swift:363-365,388-440`). O teste antigo só prendia `vagas[1].valor_centavos`,
 * `vagas[2].responsavel_local`, `evento.nome`, `evento.local`, `vagas` e `posicoes`: apagar traje, observações ou função do mapa,
 * trocar início por fim, apagar o ramo `evento.data` ou trocar o campo de um código passava. Aqui a tabela é inteira.
 */
class EscalaDeEventoCamposDaRecusaTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val funcoesJson = """[{"id":"f1","nome":"Garçom","categoria":"Salão"},{"id":"f2","nome":"Cozinheiro","categoria":"Cozinha"}]"""

    /** Publica uma escala de duas vagas e devolve o ViewModel depois da recusa [codigo] com [detalhes]. */
    private fun recusada(
        codigo: String,
        detalhes: String?,
        status: HttpStatusCode = HttpStatusCode.UnprocessableEntity,
        semRede: Boolean = false,
    ): EscalaDeEventoViewModel {
        val corpo = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}"""
        val engine = MockEngine { request ->
            when {
                request.url.encodedPath.endsWith("/funcao") -> respond(funcoesJson, HttpStatusCode.OK, json)
                semRede -> throw ConnectTimeoutException("sem rede")
                else -> respond(corpo, status, json)
            }
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        var chaves = 0
        val vm = EscalaDeEventoViewModel(
            estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
            buscarFuncoes = servico::listarFuncoes,
            enviarEscala = servico::publicarEscala,
            relogio = { Instant.parse("2026-11-10T15:00:00Z") },
            novaChave = { "chave-${++chaves}" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        runBlocking { vm.carregarFuncoes().join() }
        vm.editarNome("Formatura de Direito")
        val primeira = vm.estado.value.itens.single().id
        vm.escolherFuncao(primeira, "f1"); vm.editarValor(primeira, "180"); vm.editarPosicoes(primeira, "4"); vm.editarResponsavel(primeira, "Lia")
        vm.adicionarVaga()
        val segunda = vm.estado.value.itens.last().id
        vm.escolherFuncao(segunda, "f2"); vm.editarValor(segunda, "220,50"); vm.editarPosicoes(segunda, "2")
        runBlocking { vm.publicar().join() }
        return vm
    }

    private val camposDoItem = listOf(
        "funcao_id" to CampoDoItem.FUNCAO,
        "inicio_em" to CampoDoItem.INICIO,
        "fim_em" to CampoDoItem.FIM,
        "valor_centavos" to CampoDoItem.VALOR,
        "posicoes" to CampoDoItem.POSICOES,
        "modo" to CampoDoItem.MODO,
        "responsavel_local" to CampoDoItem.RESPONSAVEL,
        "traje" to CampoDoItem.TRAJE,
        "observacoes" to CampoDoItem.OBSERVACOES,
    )

    @Test
    fun `campo_invalido e campo_obrigatorio em cada campo da vaga marcam esse campo, nessa vaga, com a mensagem do codigo`() {
        for ((campoDoServidor, campo) in camposDoItem) {
            for ((codigo, mensagem) in listOf("campo_invalido" to TextosEscala.CAMPO_INVALIDO, "campo_obrigatorio" to TextosEscala.CAMPO_OBRIGATORIO)) {
                val vm = recusada(codigo, "vagas[1].$campoDoServidor")

                val estado = vm.estado.value
                val segunda = estado.itens[1].id
                assertEquals(mapOf(segunda to mapOf(campo to mensagem)), estado.errosDosItens, "$codigo vagas[1].$campoDoServidor")
                assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, estado.erro, "$codigo vagas[1].$campoDoServidor")
            }
        }
    }

    @Test
    fun `o indice do details e da posicao na lista, a primeira vaga e o indice 0`() {
        val vm = recusada("campo_invalido", "vagas[0].valor_centavos")

        assertEquals(setOf(vm.estado.value.itens[0].id), vm.estado.value.errosDosItens.keys)
    }

    @Test
    fun `campo da vaga que o app nao conhece, ou vaga fora da lista, vira o erro geral sem apontar vaga nenhuma`() {
        for (detalhes in listOf("vagas[0].campo_que_nao_existe", "vagas[7].valor_centavos", "vagas[1]")) {
            val vm = recusada("campo_invalido", detalhes)

            assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, vm.estado.value.erro, detalhes)
            assertTrue(vm.estado.value.errosDosItens.isEmpty(), detalhes)
        }
    }

    @Test
    fun `evento data marca a data, evento nome marca o nome`() {
        val data = recusada("campo_invalido", "evento.data").estado.value
        assertEquals(mapOf(CampoDoEvento.DATA to TextosEscala.DATA_CAMPO), data.errosDoEvento)
        assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, data.erro)

        val nome = recusada("campo_obrigatorio", "evento.nome").estado.value
        assertEquals(mapOf(CampoDoEvento.NOME to TextosEscala.NOME_CAMPO), nome.errosDoEvento)
        assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, nome.erro)
    }

    @Test
    fun `endereco, regiao e ponto do evento mandam consertar no cadastro da casa, sem marcar campo da tela`() {
        for (detalhes in listOf("evento.local", "evento.regiao_administrativa", "evento.ponto")) {
            val estado = recusada("campo_invalido", detalhes).estado.value

            assertEquals(ErroGlobalEscala.CADASTRO_DA_CASA, estado.erro, detalhes)
            assertTrue(estado.errosDoEvento.isEmpty(), detalhes)
        }
    }

    @Test
    fun `vagas e posicoes sao erros gerais proprios, e o resto desconhecido ou sem details vira confira os campos`() {
        assertEquals(ErroGlobalEscala.QUANTIDADE, recusada("campo_invalido", "vagas").estado.value.erro)
        assertEquals(ErroGlobalEscala.SOMA_DE_POSICOES, recusada("campo_invalido", "posicoes").estado.value.erro)
        for (detalhes in listOf("evento.campo_que_nao_existe", null)) {
            val estado = recusada("campo_invalido", detalhes).estado.value
            assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, estado.erro, "$detalhes")
            assertTrue(estado.errosDoEvento.isEmpty() && estado.errosDosItens.isEmpty(), "$detalhes")
        }
    }

    @Test
    fun `funcao incompativel marca a funcao da vaga, horario invalido marca inicio e fim, selecao sem antecedencia marca inicio e modo`() {
        val funcao = recusada("funcao_incompativel", "vagas[1]").estado.value
        assertEquals(mapOf(funcao.itens[1].id to mapOf(CampoDoItem.FUNCAO to TextosEscala.CAMPO_INVALIDO)), funcao.errosDosItens)

        val horario = recusada("horario_invalido", "vagas[1]").estado.value
        assertEquals(
            mapOf(horario.itens[1].id to mapOf(CampoDoItem.INICIO to TextosEscala.QUANDO_CAMPO_INICIO, CampoDoItem.FIM to TextosEscala.QUANDO_CAMPO_FIM)),
            horario.errosDosItens,
        )

        val selecao = recusada("selecao_sem_antecedencia", "vagas[1]").estado.value
        assertEquals(
            mapOf(
                selecao.itens[1].id to mapOf(
                    CampoDoItem.INICIO to TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO,
                    CampoDoItem.MODO to TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO,
                ),
            ),
            selecao.errosDosItens,
        )
    }

    @Test
    fun `recusa de vaga sem details da vaga vira erro geral confira os campos`() {
        for (codigo in listOf("funcao_incompativel", "horario_invalido", "selecao_sem_antecedencia")) {
            val estado = recusada(codigo, null).estado.value

            assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, estado.erro, codigo)
            assertTrue(estado.errosDosItens.isEmpty(), codigo)
        }
    }

    @Test
    fun `cada codigo sem campo vira o seu erro geral`() {
        val h = HttpStatusCode
        assertEquals(ErroGlobalEscala.PERFIL_INCOMPATIVEL, recusada("perfil_incompativel", null).estado.value.erro)
        assertEquals(ErroGlobalEscala.CONTA_SUSPENSA, recusada("conta_suspensa", null).estado.value.erro)
        assertEquals(ErroGlobalEscala.SEM_PERMISSAO, recusada("sem_permissao", null, h.Forbidden).estado.value.erro)
        assertEquals(ErroGlobalEscala.CONTA_SUSPENSA, recusada("sem_permissao", "conta_suspensa", h.Forbidden).estado.value.erro)
        assertEquals(ErroGlobalEscala.SESSAO_EXPIRADA, recusada("nao_autenticado", null, h.Unauthorized).estado.value.erro)
        assertEquals(ErroGlobalEscala.LIMITE_EXCEDIDO, recusada("limite_excedido", null, h.TooManyRequests).estado.value.erro)
        assertEquals(ErroGlobalEscala.SEM_REDE, recusada("sem_rede", null, semRede = true).estado.value.erro)
        assertEquals(ErroGlobalEscala.GENERICO, recusada("codigo_que_o_app_nao_conhece", null, h.InternalServerError).estado.value.erro)
    }

    @Test
    fun `uma recusa de campo nunca deixa erro de item de uma recusa anterior`() {
        val vm = recusada("campo_invalido", "evento.nome")

        assertNull(vm.estado.value.errosDosItens.values.firstOrNull())
    }
}
