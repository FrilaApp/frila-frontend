package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.Base64
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class SincronizadorDeTokenTest {

    private val sessaoDeTeste = Sessao(
        accessToken = "access",
        refreshToken = "refresh",
        tokenType = "bearer",
        expiresIn = 3600,
        vinculoId = "vinculo-antigo",
    )

    private fun servicoComEngine(engine: MockEngine): ServicoDispositivo {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return ServicoDispositivo(cliente)
    }

    @Test
    fun `com sessao ativa e vinculo_id novo, atualiza a sessao guardada`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-novo"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDeTeste) }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals("vinculo-novo", armazenamento.obterSessao()?.vinculoId)
        // Resto da sessão (tokens) não é tocado pela sincronização de vínculo.
        assertEquals(sessaoDeTeste.accessToken, armazenamento.obterSessao()?.accessToken)
    }

    @Test
    fun `sem sessao ativa, nao tenta salvar nada (nao ha a quem vincular)`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-novo"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria()

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertFalse(armazenamento.estaAutenticado())
        assertNull(armazenamento.obterSessao())
    }

    @Test
    fun `backend anterior a 0_2_30 sem vinculo_id nao sobrescreve o vinculo guardado`() = runTest {
        val servico = servicoComEngine(
            MockEngine {
                respond(
                    content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDeTeste) }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals("vinculo-antigo", armazenamento.obterSessao()?.vinculoId)
    }

    // ── Cartão O9aPbBR2: o registro lê a sessão ANTES da rede e só grava se ela ainda é a de quem pediu ────────────────

    private fun jwtDa(conta: String) =
        "cab.${Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$conta"}""".toByteArray())}.ass"

    private fun sessaoDe(conta: String, refresh: String, vinculoId: String? = null) = Sessao(
        accessToken = jwtDa(conta),
        refreshToken = refresh,
        tokenType = "bearer",
        expiresIn = 3600,
        vinculoId = vinculoId,
    )

    /** O servidor devolve [vinculo] depois de rodar [duranteAChamada], que mexe no armazenamento como se a pessoa o fizesse enquanto a rede esperava. */
    private fun servicoQueMexeNoArmazenamento(vinculo: String, duranteAChamada: () -> Unit): ServicoDispositivo = servicoComEngine(
        MockEngine {
            duranteAChamada()
            respond(
                content = """{"plataforma":"android","atualizado_em":"2026-11-27T10:00:00Z","vinculo_id":"$vinculo"}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        },
    )

    @Test
    fun `se a conta B entra durante o registro, a sessao de B nao recebe o vinculo_id de A`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDe("conta-a", "refresh-a")) }
        val sessaoDeB = sessaoDe("conta-b", "refresh-b", vinculoId = "vinculo-de-b")
        val servico = servicoQueMexeNoArmazenamento("vinculo-do-aparelho-de-a") {
            armazenamento.limparSessao()
            armazenamento.salvarSessao(sessaoDeB)
        }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals(sessaoDeB, armazenamento.obterSessao(), "a sessão de B fica exatamente como entrou")
    }

    @Test
    fun `se B entra durante o registro e as sessoes nao tem JWT legivel, tambem nao grava`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDeTeste) }
        val sessaoDeB = sessaoDeTeste.copy(accessToken = "access-b", refreshToken = "refresh-b", vinculoId = null)
        val servico = servicoQueMexeNoArmazenamento("vinculo-do-aparelho-de-a") {
            armazenamento.limparSessao()
            armazenamento.salvarSessao(sessaoDeB)
        }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals(sessaoDeB, armazenamento.obterSessao())
    }

    @Test
    fun `se a propria conta renova o token durante o registro, o vinculo_id vai para a sessao renovada`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDe("conta-a", "refresh-a")) }
        val renovada = sessaoDe("conta-a", "refresh-a-2")
        val servico = servicoQueMexeNoArmazenamento("vinculo-novo") { armazenamento.salvarSessao(renovada) }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertEquals(renovada.copy(vinculoId = "vinculo-novo"), armazenamento.obterSessao(), "a renovação não é desfeita")
    }

    @Test
    fun `se a pessoa sai durante o registro, nada e gravado`() = runTest {
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessaoDe("conta-a", "refresh-a")) }
        val servico = servicoQueMexeNoArmazenamento("vinculo-novo") { armazenamento.limparSessao() }

        sincronizarNovoToken("token-fcm-novo-de-teste-20chars", servico, armazenamento)

        assertNull(armazenamento.obterSessao())
    }
}
