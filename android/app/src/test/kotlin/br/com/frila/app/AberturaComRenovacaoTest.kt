package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * MENOR 2 da revisão do #818 (C0-2b): junta as duas metades que cada PR provou sozinho. A rede (#811) só apaga a
 * sessão quando o Auth recusa o token; a abertura (#818) só trata um 401 como "sessão vencida" quando a sessão
 * sumiu. Aqui o `ClienteSupabase` é o de verdade, com a rede simulada, e o avaliador é o da produção
 * ([avaliadorDeDestinoDaSessao]): o token de acesso venceu (401 em `minha_conta`) e a renovação responde como o Auth.
 *
 * `runBlocking`, não `runTest`: o Ktor responde em outra thread, e no tempo virtual do `runTest` o prazo de 8 s da
 * abertura venceria na hora, dando "sem conexão" pelo motivo errado.
 */
class AberturaComRenovacaoTest {

    private val sessaoInicial = Sessao(
        accessToken = "access-vencido",
        refreshToken = "refresh-de-teste",
        tokenType = "bearer",
        expiresIn = 3_600L,
    )

    private fun abertura(sessao: ArmazenamentoDeSessaoEmMemoria, respostaDoAuth: HttpStatusCode, corpoDoAuth: String): AvaliadorDeDestino {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-anonima-de-teste",
            armazenamentoDeSessao = sessao,
            engine = MockEngine { pedido ->
                if (pedido.url.encodedPath == "/auth/v1/token") {
                    respond(corpoDoAuth, respostaDoAuth, headersOf(HttpHeaders.ContentType, "application/json"))
                } else {
                    respond(
                        content = """{"code":"PGRST301","message":"JWT expired"}""",
                        status = HttpStatusCode.Unauthorized,
                        headers = headersOf(HttpHeaders.WWWAuthenticate, "Bearer"),
                    )
                }
            },
        )
        val conta = ServicoConta(cliente)
        val perfil = ServicoPerfil(cliente)
        val membros = ServicoMembros(cliente)
        return avaliadorDeDestinoDaSessao(
            sessao = sessao,
            descobrir = {
                avaliarDestinoDaConta(conta::minhaConta, perfil::obterMeuPerfilProfissional, membros::listarMeusEstabelecimentos)
            },
            guardado = DestinoGuardadoEmMemoria(),
        )
    }

    @Test
    fun `Auth fora do ar na renovacao - a abertura diz sem conexao e a sessao fica`() = runBlocking {
        val sessao = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }

        val resultado = abertura(sessao, HttpStatusCode.ServiceUnavailable, "<html>503</html>").avaliar()

        assertEquals(ResultadoDaAbertura.SemConexao, resultado)
        assertEquals(sessaoInicial, sessao.obterSessao(), "falha passageira do Auth não pode apagar a sessão")
    }

    @Test
    fun `Auth recusa o token na renovacao - a abertura diz sessao vencida e a sessao sai`() = runBlocking {
        val sessao = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoInicial) }

        val resultado = abertura(
            sessao,
            HttpStatusCode.BadRequest,
            """{"error":"invalid_grant","error_description":"Invalid Refresh Token"}""",
        ).avaliar()

        assertEquals(ResultadoDaAbertura.SessaoVencida, resultado)
        assertNull(sessao.obterSessao(), "o token recusado pelo Auth encerra a sessão")
    }
}
