package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * Extrato CSV gerado no aparelho: a mesma neutralização de fórmula e a mesma citação do backend
 * (`exportar-turnos/index.ts`, `neutralizarFormulaCsv` e `escaparCelulaCsv`), a ordem e o fuso de Brasília.
 */
class GeradorExtratoCsvTest {

    @get:Rule
    val pasta = TemporaryFolder()

    private val cabecalho = "data,funcao,checkin,checkout,valor_acordado,contraparte,verificacao"
    private val valor = "\"${Dinheiro(16_000L).formatado()}\""

    private fun turno(
        id: String = "t1",
        funcao: String = "garçom",
        contraparte: String = "Bar do Zé",
        verificacao: String = "pendente",
        inicioEm: String = "2026-11-01T21:00:00Z",
        checkinEm: String? = null,
        checkoutEm: String? = null,
    ) = TurnoDto(
        id = id,
        posicaoId = "posicao-$id",
        vaga = VagaResumoDto(
            id = "vaga-$id",
            funcao = funcao,
            local = "SQN 108",
            regiaoAdministrativa = "Asa Norte",
            inicioEm = inicioEm,
            fimEm = "2026-11-02T03:00:00Z",
            valorCentavos = 16_000L,
        ),
        contraparte = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = contraparte,
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        checkinEm = checkinEm,
        checkoutEm = checkoutEm,
        verificacao = verificacao,
        valorAcordadoCentavos = 16_000L,
        podeAvaliar = false,
        estado = "cumprida",
    )

    private fun gerar(vararg turnos: TurnoDto): String =
        GeradorExtratoCsv.gerar(pasta.root, turnos.toList(), "extrato.csv").readText(Charsets.UTF_8)

    /** A única linha de dados, sem cabeçalho e sem a quebra final (o `\r` dentro do campo não é quebra de linha aqui). */
    private fun linhaUnica(turno: TurnoDto): String {
        val texto = gerar(turno)
        val prefixo = "$cabecalho\n"
        check(texto.startsWith(prefixo) && texto.endsWith("\n")) { texto }
        return texto.removePrefix(prefixo).removeSuffix("\n")
    }

    @Test
    fun `tab seguido de formula ganha o apostrofo e nao vai entre aspas`() {
        assertEquals("2026-11-01,'\t=1,,,$valor,Bar do Zé,pendente", linhaUnica(turno(funcao = "\t=1")))
    }

    @Test
    fun `nome com retorno de carro vai entre aspas`() {
        assertEquals("2026-11-01,garçom,,,$valor,\"Bar\rdo Zé\",pendente", linhaUnica(turno(contraparte = "Bar\rdo Zé")))
    }

    @Test
    fun `retorno de carro no inicio ganha o apostrofo e as aspas`() {
        assertEquals("2026-11-01,garçom,,,$valor,\"'\r=1\",pendente", linhaUnica(turno(contraparte = "\r=1")))
    }

    @Test
    fun `virgula e aspas citam o campo e dobram as aspas internas`() {
        assertEquals(
            "2026-11-01,garçom,,,$valor,\"Bar \"\"do\"\" Zé, Asa Norte\",pendente",
            linhaUnica(turno(contraparte = "Bar \"do\" Zé, Asa Norte")),
        )
    }

    @Test
    fun `cada caractere de formula do backend ganha o apostrofo`() {
        for (formula in listOf("=SOMA(A1)", "+5561", "-1", "@x", "\tx", "\rx")) {
            assertEquals(formula, "'$formula", GeradorExtratoCsv.escaparCsv(formula).removeSurrounding("\""))
        }
    }

    @Test
    fun `os marcadores de ausencia - e -- ficam como estao, como no backend`() {
        assertEquals("-", GeradorExtratoCsv.escaparCsv("-"))
        assertEquals("--", GeradorExtratoCsv.escaparCsv("--"))
        assertEquals("", GeradorExtratoCsv.escaparCsv(""))
        assertEquals("garçom", GeradorExtratoCsv.escaparCsv("garçom"))
    }

    @Test
    fun `turnos saem do mais recente para o mais antigo`() {
        val texto = gerar(
            turno(id = "a", funcao = "antigo", inicioEm = "2026-10-01T21:00:00Z"),
            turno(id = "c", funcao = "recente", inicioEm = "2026-11-20T21:00:00Z"),
            turno(id = "b", funcao = "meio", inicioEm = "2026-11-01T21:00:00Z"),
        )

        val funcoes = texto.trimEnd('\n').split("\n").drop(1).map { it.split(",")[1] }
        assertEquals(listOf("recente", "meio", "antigo"), funcoes)
    }

    @Test
    fun `fuso de Sao Paulo - 02h30Z sai como o dia anterior, as 23h30`() {
        val linha = linhaUnica(
            turno(inicioEm = "2026-11-02T02:30:00Z", checkinEm = "2026-11-02T02:30:00Z", checkoutEm = "2026-11-02T08:15:00Z"),
        )

        assertEquals("2026-11-01,garçom,23:30,05:15,$valor,Bar do Zé,pendente", linha)
    }
}
