package br.com.frila.app

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * QBAAgKth: o acompanhamento da casa lê a avaliação que ela já deu de `meus_turnos` da casa (o painel não a traz). O ViewModel só lê quando
 * recebe `lerAvaliacaoDaCasa`; sem a fiação no Koin o turno avaliado voltaria a mostrar "Avaliar turno" sem nenhum teste vermelho.
 */
class AvaliacaoDaCasaNoKoinTest {

    @Test
    fun `o Koin liga o acompanhamento da casa a meus_turnos da casa`() {
        val relativo = "src/main/kotlin/br/com/frila/app/ModulosKoin.kt"
        val fonte = listOf(File(relativo), File("app/$relativo")).first { it.exists() }.readText()
        val bloco = fonte.substring(fonte.indexOf("AcompanhamentoContratanteViewModel("))
        assertTrue(
            "o acompanhamento da casa precisa do `lerAvaliacaoDaCasa` ligado a listarMeusTurnosDaCasa",
            bloco.contains("lerAvaliacaoDaCasa = { turnoId, casa -> turnos.listarMeusTurnosDaCasa(casa).firstOrNull { it.id == turnoId }?.avaliacao?.resposta }"),
        )
    }
}
