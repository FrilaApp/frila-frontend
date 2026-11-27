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
    fun `dois links ou dois codigos nao escolhem um em silencio`() {
        val outro = "ab".repeat(32)
        val link1 = "https://frilabr.com/app/convite#$token"
        val link2 = "https://frilabr.com/app/convite#$outro"
        assertNull(extrairTokenDoConvite("$token $outro"))
        assertNull(extrairTokenDoConvite("$token\n$outro"))
        assertNull(extrairTokenDoConvite("$link1 $link2"))
        assertNull(extrairTokenDoConvite("$link1\n$link1"))
        assertNull(extrairTokenDoConvite("$link1 https://outro.com/app/convite#$outro"))
        assertNull(extrairTokenDoConvite("$link1 http://frilabr.com/app/convite#$outro"))
    }

    @Test
    fun `extrai o token da mensagem inteira do convite, com e sem prazo, e de link no meio do texto`() {
        val linkProd = "https://frilabr.com/app/convite#$token"
        val linkDev = "https://frila-web-dev.frilabr.workers.dev/app/convite#${token.uppercase()}"
        val msgComPrazo = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bistrô Ipê",
            papel = PapelMembro.OPERADOR,
            email = "ana@frilabr.com",
            prazo = "18/11/2026 12:00",
            link = linkProd,
        )
        val msgSemPrazo = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bistrô Ipê",
            papel = PapelMembro.ADMINISTRADOR,
            email = "ana@frilabr.com",
            prazo = null,
            link = linkDev,
        )
        assertEquals(token, extrairTokenDoConvite(msgComPrazo))
        assertEquals(token, extrairTokenDoConvite(msgSemPrazo))
        assertEquals(token, extrairTokenDoConvite("Convite: $linkProd\nValido por 7 dias."))
        assertEquals(token, extrairTokenDoConvite("Olha o convite $linkDev para entrar hoje"))
    }

    @Test
    fun `texto invalido com caracteres colados no token ou no codigo nao e convite`() {
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#${token}zz"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#$token&x=1"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/convite#$token#outro"))
        assertNull(extrairTokenDoConvite("codigo: $token"))
        assertNull(extrairTokenDoConvite("${token.take(32)} ${token.drop(32)}"))
    }

    @Test
    fun `link de outro dominio, host parecido, caminho diferente ou http sem s nao vale`() {
        assertNull(extrairTokenDoConvite("https://outro.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com.exemplo.org/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://exemplofrilabr.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/outra#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/convite#$token"))
        assertNull(extrairTokenDoConvite("http://frilabr.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("http://frila-web-dev.frilabr.workers.dev/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app/entrar#$token"))
        assertNull(extrairTokenDoConvite("frilabr.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("javascript:alert(1)//convite#$token"))
    }

    @Test
    fun `aceita host e hex em maiusculas, tab ou quebra de linha antes do link e link da Politica antes`() {
        val link = "https://frilabr.com/app/convite#$token"
        assertEquals(token, extrairTokenDoConvite("https://FRILABR.COM/app/convite#${token.uppercase()}"))
        assertEquals(token, extrairTokenDoConvite("oi\t$link"))
        assertEquals(token, extrairTokenDoConvite("oi\n$link"))
        assertEquals(token, extrairTokenDoConvite("https://frilabr.com/privacidade\n$link"))
        assertEquals(token, extrairTokenDoConvite("\u00A0$link\u00A0"))
    }

    @Test
    fun `recusa porta, userinfo, ponto no host, IDN cirilico, barras extras, barra codificada e outro caminho com convite`() {
        assertNull(extrairTokenDoConvite("https://frilabr.com:443/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com@evil.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com./app/convite#$token"))
        // 'а' cirílico (U+0430) no lugar de 'a' latino: ataque homógrafo.
        assertNull(extrairTokenDoConvite("https://fril\u0430br.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app%2Fconvite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com//app/convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/app//convite#$token"))
        assertNull(extrairTokenDoConvite("https://frilabr.com/outro/convite#$token"))
    }

    @Test
    fun `recusa a mais aceitavel para esquema maiusculo, pontuacao colada e NBSP no meio do texto`() {
        val link = "https://frilabr.com/app/convite#$token"
        assertNull(extrairTokenDoConvite("HTTPS://frilabr.com/app/convite#$token"))
        assertNull(extrairTokenDoConvite("($link)"))
        assertNull(extrairTokenDoConvite("$link."))
        assertNull(extrairTokenDoConvite("oi\u00A0$link"))
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
        listOf(
            "zz${token}zz",
            "$token $outro",
            "https://frilabr.com/app/convite#${token}zz",
            "https://frilabr.com/app/convite#$token https://frilabr.com/app/convite#$token",
            "https://outro.com/app/convite#$token",
        ).forEach { colado ->
            val tokens = mutableListOf<String>()
            val vm = viewModel(tokens)
            vm.editar(colado)
            vm.aceitarConvite().join()
            assertTrue(tokens.isEmpty(), colado)
            assertEquals(TextosEquipeDaCasa.CONVITE_FORMATO_INVALIDO, vm.estado.value.erro, colado)
            assertNull(vm.estado.value.aceito)
        }
    }

    @Test
    fun `mensagem inteira do convite colada aceita pelo ViewModel com o token certo`() = runBlocking {
        val tokens = mutableListOf<String>()
        val vm = viewModel(tokens)
        val mensagem = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bistrô Ipê",
            papel = PapelMembro.OPERADOR,
            email = "ana@frilabr.com",
            prazo = "18/11/2026 12:00",
            link = "https://frilabr.com/app/convite#$token",
        )
        vm.editar(mensagem)

        vm.aceitarConvite().join()

        assertEquals(listOf(token), tokens)
        assertTrue(vm.estado.value.aceito != null)
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
        assertEquals(TextosEquipeDaCasa.CONVITE_FORMATO_INVALIDO, vm.estado.value.erro)
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

    // ---- Formato inválido e tempo esgotado (fN6OPSSd) ----

    @Test
    fun `texto sem forma de convite diz que o link ou codigo e invalido, e nao que o convite venceu`() = runBlocking {
        listOf("oi", "   ", "https://frilabr.com/app/convite", "abc123").forEach { colado ->
            val tokens = mutableListOf<String>()
            val vm = viewModel(tokens)
            vm.editar(colado)
            vm.aceitarConvite().join()

            assertTrue(tokens.isEmpty(), colado)
            assertEquals("Link ou código inválido. Cole o link inteiro do convite, ou só o código, sem mais nada.", vm.estado.value.erro, colado)
            assertFalse(vm.estado.value.erro!!.contains("não vale mais"), colado)
        }
    }

    @Test
    fun `o convite que o servidor recusa por invalido segue dizendo que nao vale mais`() = runBlocking {
        val vm = viewModel(resposta = { throw erro(CodigoErroAPI.CONVITE_INVALIDO) })
        vm.editar(token)
        vm.aceitarConvite().join()
        assertEquals(TextosEquipeDaCasa.CONVITE_INVALIDO, vm.estado.value.erro)
    }

    @Test
    fun `tempo esgotado depois de enviar vira incerto e nunca Sem conexao`() = runBlocking {
        val esgotado = ErroDaApi(CodigoErroAPI.SEM_REDE, ErroDaApi.CODIGO_TEMPO_ESGOTADO, null, "timeout")
        val vm = viewModel(resposta = { throw esgotado })
        vm.editar(token)

        vm.aceitarConvite().join()

        assertEquals(TextosEquipeDaCasa.CONVITE_INCERTO, vm.estado.value.erro)
        assertTrue(vm.estado.value.erro!!.contains("a casa aparece na sua conta"))
        assertFalse(vm.estado.value.erro!!.contains("Sem conexão"))
        assertFalse(vm.estado.value.enviando)
        assertNull(vm.estado.value.aceito)
        // O convite é de uso único: o que foi colado fica no campo, e a pessoa decide (conferir a conta ou tentar de novo).
        assertEquals(token, vm.estado.value.texto)
    }

    @Test
    fun `falha de rede antes de enviar segue sendo Sem conexao`() = runBlocking {
        val vm = viewModel(resposta = { throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "sem rota") })
        vm.editar(token)
        vm.aceitarConvite().join()
        assertEquals(TextosEquipeDaCasa.SEM_REDE, vm.estado.value.erro)
    }

    @Test
    fun `depois do incerto um novo toque envia de novo`() = runBlocking {
        var chamadas = 0
        val vm = viewModel(resposta = {
            chamadas++
            if (chamadas == 1) throw ErroDaApi(CodigoErroAPI.SEM_REDE, ErroDaApi.CODIGO_TEMPO_ESGOTADO, null, "timeout")
            MembroAdicionadoDto(estabelecimentoId = "casa-1", usuarioId = "u1", papel = "operador")
        })
        vm.editar(token)
        vm.aceitarConvite().join()
        assertEquals(TextosEquipeDaCasa.CONVITE_INCERTO, vm.estado.value.erro)

        vm.aceitarConvite().join()

        assertEquals(2, chamadas)
        assertNull(vm.estado.value.erro)
        assertEquals("casa-1", vm.estado.value.aceito?.estabelecimentoId)
    }
}
