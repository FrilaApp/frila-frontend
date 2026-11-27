package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.net.UnknownHostException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CadastroViewModelTest {

    private val hojeFixo = DataCivil.de(2026, 11, 16)

    private fun preencherCamposObrigatorios(viewModel: CadastroViewModel, nascimento: DataCivil) {
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("52998224725") // CPF válido
        viewModel.aoMudarTelefone("11987654321") // Celular válido
        viewModel.aoMudarNascimento(nascimento)
        viewModel.aoMudarAceiteDeTermos(true)
    }

    @Test
    fun `telemetria de cadastro so emite depois de criar conta sem dados pessoais`() = runBlocking {
        val eventos = mutableListOf<Triple<EventoDeTelemetria, String?, String?>>()
        val vm = viewModelComServidor(Envios(), registrarEvento = { evento, vaga, turno -> eventos += Triple(evento, vaga, turno) })
        preencherCamposObrigatorios(vm, DataCivil(java.time.LocalDate.of(2000, 6, 15)))
        vm.concluirCadastro()!!.join()
        assertEquals(listOf(Triple(EventoDeTelemetria.CADASTRO_CONCLUIDO, null, null)), eventos)
        val recusado = viewModelComServidor(Envios(), registrarEvento = { evento, vaga, turno -> eventos += Triple(evento, vaga, turno) },
            resposta = erroDaApi("campo_invalido", HttpStatusCode.UnprocessableEntity))
        preencherCamposObrigatorios(recusado, DataCivil(java.time.LocalDate.of(2000, 6, 15)))
        recusado.concluirCadastro()!!.join()
        assertEquals(1, eventos.size)
    }

    @Test
    fun `aoMudarNascimento com menor de 18 anos expoe a mensagem de bloqueio em tempo real`() {
        val viewModel = CadastroViewModel(hoje = { hojeFixo })
        val nascimentoDeMenor = DataCivil.de(2015, 1, 1)

        viewModel.aoMudarNascimento(nascimentoDeMenor)

        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.nascimentoValido)
    }

    @Test
    fun `aoMudarNascimento com maior de 18 anos nao expoe erro`() {
        val viewModel = CadastroViewModel(hoje = { hojeFixo })
        val nascimentoDeMaior = DataCivil.de(1995, 5, 10)

        viewModel.aoMudarNascimento(nascimentoDeMaior)

        assertEquals(null, viewModel.estado.value.erro)
        assertTrue(viewModel.estado.value.nascimentoValido)
    }

    @Test
    fun `aoMudarCpf com 11 digitos invalidos exibe erro em tempo real`() {
        val viewModel = CadastroViewModel()

        viewModel.aoMudarCpf("11111111111") // repetido

        assertEquals(MENSAGEM_CPF_INVALIDO, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.cpfValido)
    }

    @Test
    fun `aoMudarCpf com cpf valido limpa erro`() {
        val viewModel = CadastroViewModel()

        viewModel.aoMudarCpf("52998224725")

        assertEquals(null, viewModel.estado.value.erro)
        assertTrue(viewModel.estado.value.cpfValido)
    }

    @Test
    fun `aoMudarTelefone com formato invalido exibe erro em tempo real`() {
        val viewModel = CadastroViewModel()

        viewModel.aoMudarTelefone("00987654321") // DDD 00 inválido

        assertEquals(MENSAGEM_TELEFONE_INVALIDO, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.telefoneValido)
    }

    @Test
    fun `concluirCadastro bloqueia menor de 18 anos mesmo com todos os outros campos validos (RN20)`() {
        val viewModel = CadastroViewModel(hoje = { hojeFixo })
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2010, 1, 1))

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
    }

    private val corpoUsuario =
        """{"id":"u1","perfil":"profissional","nome":"Profissional de Teste","telefone":"+5511987654321","email":"p@exemplo.com","nascimento":"2000-06-15","estado":"ativa"}"""

    private class Envios {
        val caminhos = mutableListOf<String>()
        val corpos = mutableListOf<String>()
    }

    private fun viewModelComServidor(
        envios: Envios,
        termosVersao: String = TERMOS_VERSAO_ATUAL,
        registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
        resposta: suspend MockRequestHandleScope.() -> HttpResponseData = {
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        },
    ): CadastroViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                envios.caminhos += request.url.encodedPath
                envios.corpos += (request.body as TextContent).text
                resposta()
            },
        )
        return CadastroViewModel(
            servicoConta = ServicoConta(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            termosVersao = termosVersao,
            hoje = { hojeFixo },
            registrarEvento = registrarEvento,
        )
    }

    private fun erroDaApi(codigo: String, status: HttpStatusCode, detalhes: String? = null): suspend MockRequestHandleScope.() -> HttpResponseData = {
        val details = detalhes?.let { "\"$it\"" } ?: "null"
        respond(
            """{"code":"$codigo","message":"recusa","details":$details}""",
            status,
            headersOf(HttpHeaders.ContentType, "application/json"),
        )
    }

    @Test
    fun `concluirCadastro aceita maior de 18 anos com todos os campos validos e cria a conta (RN20)`() = runBlocking {
        val envios = Envios()
        val viewModel = viewModelComServidor(envios)
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertTrue(viewModel.estado.value.concluido)
        assertFalse(viewModel.estado.value.enviando)
        assertEquals(null, viewModel.estado.value.erro)
        assertEquals(listOf("/rest/v1/rpc/criar_conta"), envios.caminhos)
        assertEquals(
            """{"perfil":"profissional","nome":"Profissional de Teste","telefone":"+5511987654321","nascimento":"2000-06-15","termos_versao":"2026-11-16"}""",
            envios.corpos.single(),
        )
    }

    @Test
    fun `escolher casa manda contratante em criar_conta`() = runBlocking {
        val envios = Envios()
        val viewModel = viewModelComServidor(envios)
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))
        viewModel.aoEscolherPerfil(PerfilDaConta.CONTRATANTE)

        viewModel.concluirCadastro()!!.join()

        assertTrue(viewModel.estado.value.concluido)
        assertTrue(envios.corpos.single().startsWith("""{"perfil":"contratante","""), envios.corpos.single())
    }

    @Test
    fun `voltar para profissional depois de escolher casa manda profissional`() = runBlocking {
        val envios = Envios()
        val viewModel = viewModelComServidor(envios)
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))
        viewModel.aoEscolherPerfil(PerfilDaConta.CONTRATANTE)
        viewModel.aoEscolherPerfil(PerfilDaConta.PROFISSIONAL)

        viewModel.concluirCadastro()!!.join()

        assertTrue(envios.corpos.single().startsWith("""{"perfil":"profissional","""), envios.corpos.single())
    }

    @Test
    fun `o perfil comeca em profissional, como no iOS`() {
        assertEquals(PerfilDaConta.PROFISSIONAL, CadastroViewModel().estado.value.perfil)
    }

    @Test
    fun `trocar o perfil com criar_conta em voo nao muda o que foi enviado`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val envios = Envios()
        val viewModel = viewModelComServidor(envios, resposta = {
            liberar.await()
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        })
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))
        viewModel.aoEscolherPerfil(PerfilDaConta.CONTRATANTE)

        val envio = viewModel.concluirCadastro()!!
        viewModel.aoEscolherPerfil(PerfilDaConta.PROFISSIONAL)
        liberar.complete(Unit)
        envio.join()

        assertEquals(PerfilDaConta.CONTRATANTE, viewModel.estado.value.perfil)
        assertTrue(envios.corpos.single().startsWith("""{"perfil":"contratante","""))
    }

    @Test
    fun `concluirCadastro envia a versao dos termos configurada`() = runBlocking {
        val envios = Envios()
        val viewModel = viewModelComServidor(envios, termosVersao = TERMOS_VERSAO_ANTERIOR)
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertTrue(envios.corpos.single().contains(""""termos_versao":"2026-11-13""""))
    }

    @Test
    fun `concluirCadastro com 422 menor_de_idade mostra a mensagem de idade e nao conclui`() = runBlocking {
        val viewModel = viewModelComServidor(Envios(), resposta = erroDaApi("menor_de_idade", HttpStatusCode.UnprocessableEntity, "nascimento"))
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertFalse(viewModel.estado.value.concluido)
        assertFalse(viewModel.estado.value.enviando)
        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro com 422 campo_invalido de nome pede um nome valido`() = runBlocking {
        val viewModel = viewModelComServidor(Envios(), resposta = erroDaApi("campo_invalido", HttpStatusCode.UnprocessableEntity, "nome"))
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Informe um nome válido.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro com 409 conta_existente orienta a entrar com o codigo`() = runBlocking {
        val viewModel = viewModelComServidor(Envios(), resposta = erroDaApi("conta_existente", HttpStatusCode.Conflict))
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Já existe uma conta com este e-mail. Entre com o código para continuar.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro com 409 perfil_ja_existe cai no mesmo texto de conta existente`() = runBlocking {
        val viewModel = viewModelComServidor(Envios(), resposta = erroDaApi("perfil_ja_existe", HttpStatusCode.Conflict))
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertFalse(viewModel.estado.value.concluido)
        assertFalse(viewModel.estado.value.enviando)
        // O texto exato da conta existente (e não o genérico de cadastro indisponível): o 409 de perfil tem de chegar a esse ramo.
        assertEquals("Já existe uma conta com este e-mail. Entre com o código para continuar.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro com erro de rede mostra a mensagem de conexao e nao conclui`() = runBlocking {
        val viewModel = viewModelComServidor(Envios()) { throw UnknownHostException("sem rede") }
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()!!.join()

        assertFalse(viewModel.estado.value.concluido)
        assertFalse(viewModel.estado.value.enviando)
        assertEquals("Sem conexão. Confira a internet e tente de novo.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro durante um envio em voo nao envia a conta duas vezes`() = runBlocking {
        val envios = Envios()
        val liberar = CompletableDeferred<Unit>()
        val viewModel = viewModelComServidor(envios) {
            liberar.await()
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        val primeiro = viewModel.concluirCadastro()!!
        assertTrue(viewModel.estado.value.enviando)
        assertNull(viewModel.concluirCadastro())
        liberar.complete(Unit)
        primeiro.join()

        assertEquals(1, envios.caminhos.size)
        assertTrue(viewModel.estado.value.concluido)
    }

    @Test
    fun `concluirCadastro nao chama a rede quando a validacao local recusa`() = runBlocking {
        val envios = Envios()
        val viewModel = viewModelComServidor(envios)
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))
        viewModel.aoMudarAceiteDeTermos(false)

        assertNull(viewModel.concluirCadastro())

        assertTrue(envios.caminhos.isEmpty())
        assertFalse(viewModel.estado.value.concluido)
    }

    @Test
    fun `concluirCadastro sem servico de conta nunca marca concluido`() {
        val viewModel = CadastroViewModel()
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        assertNull(viewModel.concluirCadastro())

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Não foi possível concluir o cadastro. Tente de novo em instantes.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige nome preenchido`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarCpf("52998224725")
        viewModel.aoMudarTelefone("11987654321")
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Informe seu nome.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige CPF valido`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("12345678900") // dígitos verificadores errados
        viewModel.aoMudarTelefone("11987654321")
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals(MENSAGEM_CPF_INVALIDO, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige telefone valido com DDD`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("52998224725")
        viewModel.aoMudarTelefone("11887654321") // 11 dígitos sem 9 inicial
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals(MENSAGEM_TELEFONE_INVALIDO, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige aceite dos termos`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("52998224725")
        viewModel.aoMudarTelefone("11987654321")
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Você precisa aceitar os termos para continuar.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro sem data de nascimento pede a data, nunca passa direto`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("52998224725")
        viewModel.aoMudarTelefone("11987654321")
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Informe sua data de nascimento.", viewModel.estado.value.erro)
    }
}
