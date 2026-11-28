package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.CodigoErroAPI.FORA_DA_JANELA
import java.io.File
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/**
 * Cartão xkry1xwQ (item 226): uma tentativa aceita só encerra os avisos de recusa da MESMA operação, ou seja, mesmo tipo, conta,
 * turno, vaga e estabelecimento (`FilaDeAcoes.resolverRecusas`; iOS `Cache.swift:146-148`). O teste antigo só variava a conta, e tirar
 * o filtro de tipo ou de estabelecimento passava. Aqui há um teste por campo do filtro: a operação que difere SÓ naquele campo
 * mantém o seu aviso; a que é igual em todos os campos perde o dela.
 */
class FilaDeAcoesResolverRecusasTest {
    @TempDir lateinit var diretorio: File
    private val fila by lazy { FilaDeAcoes(File(diretorio, "acoes/fila.json")) }

    private val instante = "2026-11-23T12:00:00Z"

    private fun checkin(conta: String = "conta-a", turno: String? = "turno-1", tipo: TipoAcaoPendente = TipoAcaoPendente.CHECKIN) =
        AcaoPendente(tipo, conta, instante, turnoId = turno, distanciaMetros = 42)

    private fun republicacao(vaga: String, conta: String = "conta-a") = AcaoPendente(
        TipoAcaoPendente.REPUBLICACAO_VAGA, conta, instante,
        republicacao = RepublicarVagaDto(vagaId = vaga, inicioEm = "2026-12-01T10:00:00Z", fimEm = "2026-12-01T14:00:00Z", chave = "chave-$vaga"),
    )

    private fun publicacao(estabelecimento: String, conta: String = "conta-a") = AcaoPendente(
        TipoAcaoPendente.PUBLICACAO_VAGA, conta, instante,
        publicacao = NovaVagaDto(
            estabelecimentoId = estabelecimento, funcaoId = "funcao-1", inicioEm = "2026-12-01T10:00:00Z", fimEm = "2026-12-01T14:00:00Z",
            local = "SQN 108", regiaoAdministrativa = "Asa Norte", ponto = CoordenadaDto(-15.78, -47.93), valorCentavos = 16_000L,
            posicoes = 1, incluiRefeicao = false, incluiTransporte = false, exigeMaterialProprio = false, responsavelLocal = "Ana",
            modo = "urgencia", chave = "chave-$estabelecimento",
        ),
    )

    private fun recusar(acao: AcaoPendente) {
        fila.enfileirar(acao)
        fila.recusar(acao, FORA_DA_JANELA)
    }

    /** Enfileira [nova], a tentativa aceita, e devolve os ids dos avisos que sobram. */
    private fun avisosDepoisDeAceitar(nova: AcaoPendente): List<String> {
        fila.enfileirar(nova)
        fila.resolverRecusas(nova)
        return fila.recusadas(incluirReconhecidas = true).map { it.id }
    }

    @Test fun `a mesma operacao, igual em todos os campos, perde o aviso`() {
        val antiga = checkin(); recusar(antiga)

        assertEquals(emptyList<String>(), avisosDepoisDeAceitar(checkin()))
    }

    @Test fun `tipo diferente mantem o aviso`() {
        val checkout = checkin(tipo = TipoAcaoPendente.CHECKOUT); recusar(checkout)

        assertEquals(listOf(checkout.id), avisosDepoisDeAceitar(checkin(tipo = TipoAcaoPendente.CHECKIN)))
    }

    @Test fun `conta diferente mantem o aviso`() {
        val deB = checkin(conta = "conta-b"); recusar(deB)

        assertEquals(listOf(deB.id), avisosDepoisDeAceitar(checkin(conta = "conta-a")))
    }

    @Test fun `turno diferente mantem o aviso`() {
        val doTurno2 = checkin(turno = "turno-2"); recusar(doTurno2)

        assertEquals(listOf(doTurno2.id), avisosDepoisDeAceitar(checkin(turno = "turno-1")))
    }

    @Test fun `turno ausente num lado e presente no outro mantem o aviso`() {
        val semTurno = checkin(turno = null); recusar(semTurno)

        assertEquals(listOf(semTurno.id), avisosDepoisDeAceitar(checkin(turno = "turno-1")))
    }

    @Test fun `vaga diferente mantem o aviso e a mesma vaga perde`() {
        val daVaga2 = republicacao("vaga-2"); recusar(daVaga2)
        val daVaga1 = republicacao("vaga-1"); recusar(daVaga1)

        assertEquals(listOf(daVaga2.id), avisosDepoisDeAceitar(republicacao("vaga-1")))
    }

    @Test fun `estabelecimento diferente mantem o aviso e o mesmo perde`() {
        val doEstab2 = publicacao("estab-2"); recusar(doEstab2)
        val doEstab1 = publicacao("estab-1"); recusar(doEstab1)

        assertEquals(listOf(doEstab2.id), avisosDepoisDeAceitar(publicacao("estab-1")))
    }

    @Test fun `so a operacao igual perde o aviso quando ha varias recusadas diferentes em cada campo`() {
        val igual = checkin(); recusar(igual)
        val outroTipo = checkin(tipo = TipoAcaoPendente.CHECKOUT); recusar(outroTipo)
        val outraConta = checkin(conta = "conta-b"); recusar(outraConta)
        val outroTurno = checkin(turno = "turno-2"); recusar(outroTurno)

        assertEquals(listOf(outroTipo.id, outraConta.id, outroTurno.id), avisosDepoisDeAceitar(checkin()))
    }

    @Test fun `o aviso ja reconhecido da mesma operacao tambem e encerrado`() {
        val antiga = checkin(); recusar(antiga)
        fila.reconhecerRecusa(antiga.id)

        assertEquals(emptyList<String>(), avisosDepoisDeAceitar(checkin()))
    }
}
