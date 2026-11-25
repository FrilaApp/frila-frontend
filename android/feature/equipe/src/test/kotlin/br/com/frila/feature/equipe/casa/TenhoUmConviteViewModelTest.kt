package br.com.frila.feature.equipe.casa

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MembroAdicionadoDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class TenhoUmConviteViewModelTest {

    // Token sintético de teste (64 hex), não é segredo.
    private val token = "ef".repeat(32)

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(
        tokens: MutableList<String> = mutableListOf(),
        resposta: () -> MembroAdicionadoDto = { MembroAdicionadoDto("membro_adicionado", "m1", "casa-1", "u1", "operador") },
    ) = TenhoUmConviteViewModel(
        aceitar = { tokens += it; resposta() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    // ---- O token, do link ou do codigo ----

    @Test
    fun `extrai o token do link inteiro da web`() {
        assertEquals(token, extrairTokenDoConvite("https://frilabr.com/app/convite#$token"))
    }

    @Test
    fun `extrai o token do codigo puro, com espaco e quebra de linha em volta, e aceita maiuscula`() {
        assertEquals(token, extrairTokenDoConvite(token))
        assertEquals(token, extrairTokenDoConvite("  $token \n"))
        assertEquals(token, extrairTokenDoConvite(token.uppercase()))
        assertEquals(token, extrairTokenDoConvite("  https://frilabr.com/app/convite#$token\n"))
        assertEquals(token, extrairTokenDoConvite("https://frila-web-dev.frilabr.workers.dev/app/convite#$token"))
    }

    @Test
    fun `nao extrai de texto sem token`() {
        assertNull(extrairTokenDoConvite(""))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#abc123"))
        // 63 e 65 caracteres hexadecimais não são um token.
        assertNull(extrairTokenDoConvite(token.dropLast(1)))
        assertNull(extrairTokenDoConvite(token + "a"))
        assertNull(extrairTokenDoConvite("g".repeat(64)))
    }

    // Parecer do Lince Codex no #998: só vale o link do convite inteiro ou só o código, nada recortado de um texto maior.

    @Test
    fun `token no miolo de um identificador maior nao e convite`() {
        assertNull(extrairTokenDoConvite("zz${token}zz"))
        assertNull(extrairTokenDoConvite("zz$token"))
        assertNull(extrairTokenDoConvite("${token}zz"))
    }

    @Test
    fun `dois codigos diferentes nao escolhem um em silencio`() {
        val outro = "ab".repeat(32)
        assertNull(extrairTokenDoConvite("$token $outro"))
        assertNull(extrairTokenDoConvite("$token\n$outro"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#$token https://frilabr.com/app/convite#$outro"))
    }

    @Test
    fun `texto com mais caracteres em volta do link ou do codigo nao e convite`() {
        assertNull(extrairTokenDoConvite("Convite: https://frilabr.com/app/convite#$token\nValido por 7 dias."))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#${token}zz"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#$token&x=1"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#$token#outro"))
        assertNull(extrairTokenDoConvite("codigo: $token"))
        assertNull(extrairTokenDoConvite("${token.take(32)} ${token.drop(32)}"))
    }

    @Test
    fun `link que nao e de convite nao vale mesmo com 64 hex no fim`() {
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/entrar#$token"))
        assertNull(extrairTokenDoConvite("frilabr.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("javascript:alert(1)//convite#$token"))
    }

    // ---- Aceitar ----

    @Test
    fun `link colado chama aceitar_convite_membro com o token e mostra a casa`() = runBlocking {
        val tokens = mutableListOf<String>()
        val vm = viewModel(tokens)
        vm.editar("https://frilabr.com/app/convite#$token")

        vm.aceitarConvite().join()

        assertEquals(listOf(token), tokens)
        val aceito = vm.estado.value.aceito!!
        assertEquals("casa-1", aceito.estabelecimentoId)
        assertEquals(PapelMembro.OPERADOR, aceito.papel)
        assertFalse(vm.estado.value.enviando)
        assertNull(vm.estado.value.erro)
        assertEquals("", vm.estado.value.texto)
    }

    @Test
    fun `texto ambiguo ou recortado nunca chega a rede`() = runBlocking {
        val outro = "ab".repeat(32)
        listOf("zz${token}zz", "$token $outro", "Convite: https://frilabr.com/app/convite#$token ate sexta").forEach { colado ->
            val tokens = mutableListOf<String>()
            val vm = viewModel(tokens)
            vm.editar(colado)
            vm.aceitarConvite().join()
            assertTrue(tokens.isEmpty(), colado)
            assertEquals(TextosEquipeDaCasa.CONVITE_INVALIDO, vm.estado.value.erro, colado)
            assertNull(vm.estado.value.aceito)
        }
    }

    @Test
    fun `codigo puro tambem vale`() = runBlocking {
        val tokens = mutableListOf<String>()
        val vm = viewModel(tokens)
        vm.editar(token)

        vm.aceitarConvite().join()

        assertEquals(listOf(token), tokens)
        assertTrue(vm.estado.value.aceito != null)
    }

    @Test
    fun `texto sem token nao chega a rede e mostra convite invalido junto ao botao`() = runBlocking {
        val tokens = mutableListOf<String>()
        val vm = viewModel(tokens)
        vm.editar("https://frilabr.com/app/convite")

        vm.aceitarConvite().join()

        assertTrue(tokens.isEmpty())
        assertEquals(TextosEquipeDaCasa.CONVITE_INVALIDO, vm.estado.value.erro)
        vm.editar("outro texto")
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `cada recusa do servidor vira a mensagem certa e libera o botao`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.CONVITE_INVALIDO) to TextosEquipeDaCasa.CONVITE_INVALIDO,
            erro(CodigoErroAPI.CONVITE_DE_OUTRO_EMAIL) to TextosEquipeDaCasa.CONVITE_DE_OUTRO_EMAIL,
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to TextosEquipeDaCasa.CONVITE_PERFIL_INCOMPATIVEL,
            erro(CodigoErroAPI.NAO_AUTENTICADO) to TextosEquipeDaCasa.SESSAO,
            erro(CodigoErroAPI.SEM_REDE) to TextosEquipeDaCasa.SEM_REDE,
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosEquipeDaCasa.CONTA_SUSPENSA,
            erro(CodigoErroAPI.DESCONHECIDO) to TextosEquipeDaCasa.CONVITE_INCERTO,
            IllegalStateException("corpo não é JSON") to TextosEquipeDaCasa.CONVITE_INCERTO,
        )
        casos.forEach { (falha, mensagem) ->
            val vm = viewModel(resposta = { throw falha })
            vm.editar(token)
            vm.aceitarConvite().join()
            assertEquals(mensagem, vm.estado.value.erro, falha.toString())
            assertFalse(vm.estado.value.enviando)
            assertNull(vm.estado.value.aceito)
            // O que a pessoa colou fica no campo, para ela ver e tentar de novo.
            assertEquals(token, vm.estado.value.texto)
        }
    }

    @Test
    fun `403 convite_de_outro_email mostra exatamente a mensagem do contrato 0_2_115`() = runBlocking {
        val vm = viewModel(resposta = { throw erro(CodigoErroAPI.CONVITE_DE_OUTRO_EMAIL) })
        vm.editar(token)

        vm.aceitarConvite().join()

        assertEquals(
            "Este convite foi feito para outro e-mail. Entre com o e-mail que recebeu o convite.",
            vm.estado.value.erro,
        )
        assertNull(vm.estado.value.aceito)
    }

    @Test
    fun `depois de aceito um segundo toque nao aceita de novo`() = runBlocking {
        val tokens = mutableListOf<String>()
        val vm = viewModel(tokens)
        vm.editar(token)
        vm.aceitarConvite().join()

        vm.editar(token)
        vm.aceitarConvite().join()

        assertEquals(1, tokens.size)
    }

    // ---- Trocar de casa ----

    @Test
    fun `trocar de casa lista as casas da conta com o papel e falha com erro`() = runBlocking {
        var falhar = true
        val vm = TrocarDeCasaViewModel(
            listar = {
                if (falhar) throw IllegalStateException("sem rede")
                listOf(
                    EstabelecimentoDaContaDto("c1", "Bar da Lia", "administrador"),
                    EstabelecimentoDaContaDto("c2", "Buffet Sol", "operador"),
                    EstabelecimentoDaContaDto("c3", "Outra", "papel-novo"),
                )
            },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.carregar().join()
        assertEquals(ListaDeCasas.Erro, vm.estado.value)

        falhar = false
        vm.carregar().join()
        val casas = (vm.estado.value as ListaDeCasas.Conteudo).casas
        assertEquals(listOf("Bar da Lia", "Buffet Sol", "Outra"), casas.map { it.nome })
        assertEquals(listOf(PapelMembro.ADMINISTRADOR, PapelMembro.OPERADOR, null), casas.map { it.papel })
    }
}
