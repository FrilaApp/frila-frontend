package br.com.frila.feature.chamadas.profissional

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * "Aceito chamadas diretas" é o registro do aceite do titular (LGPD). O servidor guarda a versão do texto que a pessoa viu
 * (`versao_texto_busca`); o contrato 0.2.102 registra `busca-1`, e o iOS (`PreferenciasChamadaViewModel.versaoDoTextoDaBusca`)
 * e a web mandam a mesma. Estas strings são fixas de propósito: mudar uma delas aqui sem mudar o contrato e as outras
 * plataformas grava no servidor uma versão que não existe ou um texto diferente do registrado.
 */
class TextoDoAceiteDaBuscaTest {

    @Test
    fun `a versao do texto da busca e a registrada no contrato, igual a do iOS`() {
        assertEquals("busca-1", TextosChamadaProfissional.VERSAO_TEXTO_BUSCA)
    }

    @Test
    fun `o titulo e a explicacao do aceite sao os do contrato 0_2_102, iguais aos do iOS`() {
        assertEquals("Aceito chamadas diretas", TextosChamadaProfissional.ACEITO_TEXTO)
        assertEquals("Aceito chamadas diretas", TextosChamadaProfissional.ACEITO_TITULO)
        assertEquals(
            "Quem contrata pode te achar na busca e te chamar direto, sem publicar uma vaga.",
            TextosChamadaProfissional.ACEITO_EXPLICACAO,
        )
    }
}
