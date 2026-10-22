package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CadastroViewModelTest {

    private fun preencherCamposObrigatorios(viewModel: CadastroViewModel, nascimento: DataCivil) {
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarTelefone("+5561999990000")
        viewModel.aoMudarNascimento(nascimento)
        viewModel.aoMudarAceiteDeTermos(true)
    }

    @Test
    fun `aoMudarNascimento com menor de 18 anos expoe a mensagem de bloqueio em tempo real`() {
        val viewModel = CadastroViewModel()
        val nascimentoDeMenor = DataCivil.de(2015, 1, 1) // 11 anos em 2026-10-22

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
    fun `concluirCadastro bloqueia menor de 18 anos mesmo com todos os outros campos validos (RN20)`() {
        val viewModel = CadastroViewModel()
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2010, 1, 1)) // 16 anos

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals(MENSAGEM_MENOR_DE_IDADE, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro aceita maior de 18 anos com todos os campos validos (RN20)`() {
        val viewModel = CadastroViewModel()
        preencherCamposObrigatorios(viewModel, nascimento = DataCivil.de(2000, 6, 15)) // maior de idade

        viewModel.concluirCadastro()

        assertTrue(viewModel.estado.value.concluido)
        assertEquals(null, viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige nome preenchido`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarTelefone("+5561999990000")
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Informe seu nome.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro exige aceite dos termos`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarTelefone("+5561999990000")
        viewModel.aoMudarNascimento(DataCivil.de(2000, 1, 1))

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Você precisa aceitar os termos para continuar.", viewModel.estado.value.erro)
    }

    @Test
    fun `concluirCadastro sem data de nascimento pede a data, nunca passa direto`() {
        val viewModel = CadastroViewModel()
        viewModel.aoMudarNome("Profissional de Teste")
        viewModel.aoMudarTelefone("+5561999990000")
        viewModel.aoMudarAceiteDeTermos(true)

        viewModel.concluirCadastro()

        assertFalse(viewModel.estado.value.concluido)
        assertEquals("Informe sua data de nascimento.", viewModel.estado.value.erro)
    }
}
