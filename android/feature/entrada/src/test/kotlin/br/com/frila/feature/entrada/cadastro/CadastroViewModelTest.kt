package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CadastroViewModelTest {

    private fun preencherCamposObrigatorios(viewModel: CadastroViewModel, nascimento: DataCivil) {
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarCpf("52998224725") // CPF válido
        viewModel.aoMudarTelefone("11987654321") // Celular válido
        viewModel.aoMudarNascimento(nascimento)
        viewModel.aoMudarAceiteDeTermos(true)
    }

    @Test
    fun `aoMudarNascimento com menor de 18 anos expoe a mensagem de bloqueio em tempo real`() {
        val viewModel = CadastroViewModel()
        val nascimentoDeMenor = DataCivil.de(2015, 1, 1)

        viewModel.aoMudarNascimento(nascimentoDeMenor)

        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
        assertFalse(viewModel.estado.value.nascimentoValido)
    }

    @Test
    fun `aoMudarNascimento com maior de 18 anos nao expoe erro`() {
        val viewModel = CadastroViewModel()
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
        val viewModel = CadastroViewModel()
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2010, 1, 1))

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro aceita maior de 18 anos com todos os campos validos (RN20)`() {
        val viewModel = CadastroViewModel()
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15))

        viewModel.concluirCadastro()

        assertTrue(viewModel.estado.value.concluido)
        assertEquals(null, viewModel.estado.value.erro)
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
