package br.com.frila.core.dominio.modelo

import br.com.frila.core.dominio.modelo.CodigoErroAPI.CAMPO_INVALIDO
import br.com.frila.core.dominio.modelo.CodigoErroAPI.CAMPO_OBRIGATORIO
import br.com.frila.core.dominio.modelo.CodigoErroAPI.CONTA_SUSPENSA
import br.com.frila.core.dominio.modelo.CodigoErroAPI.FUNCAO_INCOMPATIVEL
import br.com.frila.core.dominio.modelo.CodigoErroAPI.HORARIO_INVALIDO
import br.com.frila.core.dominio.modelo.CodigoErroAPI.NAO_ENCONTRADO
import br.com.frila.core.dominio.modelo.CodigoErroAPI.PERFIL_INCOMPATIVEL
import br.com.frila.core.dominio.modelo.CodigoErroAPI.POSICAO_NAO_CANCELAVEL
import br.com.frila.core.dominio.modelo.CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA
import br.com.frila.core.dominio.modelo.CodigoErroAPI.SEM_PERMISSAO
import br.com.frila.core.dominio.modelo.CodigoErroAPI.VAGA_ENCERRADA
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão lUQlql8s (item 230): a tabela das recusas definitivas da fila offline, espelho de `ErrosDaAPI.swift:120-141` do iOS
 * (`recusaDefinitivaDePublicacao` e `recusaDefinitivaDeCancelamento`). Uma recusa definitiva sai da fila com aviso; o que ficar
 * de fora é tratado como transitório e a ação é reenviada. Antes não havia teste: tirar `PERFIL_INCOMPATIVEL`, `CONTA_SUSPENSA`
 * ou `CAMPO_OBRIGATORIO` de um dos conjuntos passava, e a ação ficaria na fila para sempre.
 *
 * Os testes percorrem TODOS os códigos do enum, não só os esperados: um código novo que entre num conjunto sem decisão, ou um que saia,
 * derruba o teste.
 */
class RecusasDefinitivasTest {

    /** Dentro: iguais, código a código, ao `switch` do iOS (`recusaDefinitivaDePublicacao`). */
    private val publicacaoDefinitiva = setOf(
        CAMPO_OBRIGATORIO, CAMPO_INVALIDO, HORARIO_INVALIDO, FUNCAO_INCOMPATIVEL,
        PERFIL_INCOMPATIVEL, SELECAO_SEM_ANTECEDENCIA, SEM_PERMISSAO, CONTA_SUSPENSA,
        NAO_ENCONTRADO,
    )

    /** Dentro: iguais, código a código, ao `switch` do iOS (`recusaDefinitivaDeCancelamento`). */
    private val cancelamentoDefinitivo = setOf(
        POSICAO_NAO_CANCELAVEL, VAGA_ENCERRADA, NAO_ENCONTRADO, CAMPO_OBRIGATORIO,
        CAMPO_INVALIDO, SEM_PERMISSAO, PERFIL_INCOMPATIVEL, CONTA_SUSPENSA,
    )

    @Test
    fun `publicacao, cada codigo do enum esta dentro ou fora exatamente como na tabela`() {
        for (codigo in CodigoErroAPI.entries) {
            assertEquals(codigo in publicacaoDefinitiva, codigo.recusaDefinitivaDePublicacao, "publicação: $codigo")
        }
        assertEquals(9, CodigoErroAPI.entries.count { it.recusaDefinitivaDePublicacao })
    }

    @Test
    fun `cancelamento, cada codigo do enum esta dentro ou fora exatamente como na tabela`() {
        for (codigo in CodigoErroAPI.entries) {
            assertEquals(codigo in cancelamentoDefinitivo, codigo.recusaDefinitivaDeCancelamento, "cancelamento: $codigo")
        }
        assertEquals(8, CodigoErroAPI.entries.count { it.recusaDefinitivaDeCancelamento })
    }

    @Test
    fun `os tres codigos de sessao e de dado que o batedor apontou estao nos dois conjuntos`() {
        for (codigo in listOf(PERFIL_INCOMPATIVEL, CONTA_SUSPENSA, CAMPO_OBRIGATORIO)) {
            assertEquals(true, codigo.recusaDefinitivaDePublicacao, "publicação: $codigo")
            assertEquals(true, codigo.recusaDefinitivaDeCancelamento, "cancelamento: $codigo")
        }
    }

    @Test
    fun `os conjuntos diferem so no que cada operacao tem de proprio`() {
        // Só da publicação: o que a publicação valida e o cancelamento não tem como falhar.
        assertEquals(
            setOf(HORARIO_INVALIDO, FUNCAO_INCOMPATIVEL, SELECAO_SEM_ANTECEDENCIA),
            publicacaoDefinitiva - cancelamentoDefinitivo,
        )
        // Só do cancelamento: a posição que não cancela mais e a vaga já encerrada.
        assertEquals(setOf(POSICAO_NAO_CANCELAVEL, VAGA_ENCERRADA), cancelamentoDefinitivo - publicacaoDefinitiva)
    }

    @Test
    fun `erros transitorios e de rede nunca sao recusa definitiva, em nenhuma das duas operacoes`() {
        val transitorios = listOf(
            CodigoErroAPI.LIMITE_EXCEDIDO, CodigoErroAPI.SEM_REDE, CodigoErroAPI.RESPOSTA_INVALIDA,
            CodigoErroAPI.DESCONHECIDO, CodigoErroAPI.NAO_AUTENTICADO,
        )
        for (codigo in transitorios) {
            assertEquals(false, codigo.recusaDefinitivaDePublicacao, "publicação: $codigo")
            assertEquals(false, codigo.recusaDefinitivaDeCancelamento, "cancelamento: $codigo")
        }
    }
}
