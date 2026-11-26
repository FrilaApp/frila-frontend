package br.com.frila.feature.equipe.casa

import br.com.frila.core.dominio.modelo.PapelMembro
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class TextosEquipeDaCasaTest {

    private val link = "https://frilabr.com/app/convite#" + "ab".repeat(32)

    @Test
    fun `com prazo monta exatamente o texto esperado com o link na ultima linha`() {
        val mensagem = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bar da Lia",
            papel = PapelMembro.ADMINISTRADOR,
            email = "novo@bar.com",
            prazo = "25/11 às 12:00",
            link = link,
        )

        val esperado =
            "Bar da Lia convidou você para a equipe da casa no Frila, como administrador. " +
                "Para aceitar, abra o link abaixo e entre no Frila com o e-mail novo@bar.com. " +
                "O convite vale uma vez, até 25/11 às 12:00. " +
                "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. " +
                "Política de Privacidade: https://frilabr.com/privacidade\n" +
                link
        assertEquals(esperado, mensagem)
    }

    @Test
    fun `sem prazo usa a frase curta sem validade`() {
        val esperado =
            "Bar da Lia convidou você para a equipe da casa no Frila, como operador. " +
                "Para aceitar, abra o link abaixo e entre no Frila com o e-mail op@bar.com. " +
                "O convite vale uma vez. " +
                "O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. " +
                "Política de Privacidade: https://frilabr.com/privacidade\n" +
                link

        assertEquals(
            esperado,
            TextosEquipeDaCasa.mensagemDoConvite("Bar da Lia", PapelMembro.OPERADOR, "op@bar.com", null, link),
        )
        assertEquals(
            esperado,
            TextosEquipeDaCasa.mensagemDoConvite("Bar da Lia", PapelMembro.OPERADOR, "op@bar.com", "   ", link),
        )
    }

    @Test
    fun `papel sai em minusculo para os dois papeis e email sai aparado`() {
        val admin = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bar da Lia",
            papel = PapelMembro.ADMINISTRADOR,
            email = "  admin@bar.com\t",
            prazo = null,
            link = link,
        )
        val operador = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bar da Lia",
            papel = PapelMembro.OPERADOR,
            email = "\nop@bar.com  ",
            prazo = null,
            link = link,
        )

        assertTrue(admin.contains("como administrador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail admin@bar.com."))
        assertTrue(operador.contains("como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail op@bar.com."))
    }

    @Test
    fun `mensagem nao e so o link, cita a politica e termina no link`() {
        val mensagem = TextosEquipeDaCasa.mensagemDoConvite(
            casa = "Bar da Lia",
            papel = PapelMembro.OPERADOR,
            email = "op@bar.com",
            prazo = "25/11 às 12:00",
            link = link,
        )

        assertNotEquals(link, mensagem)
        assertTrue(mensagem.contains("Política de Privacidade: https://frilabr.com/privacidade"))
        assertTrue(mensagem.endsWith("\n$link"))
    }
}
