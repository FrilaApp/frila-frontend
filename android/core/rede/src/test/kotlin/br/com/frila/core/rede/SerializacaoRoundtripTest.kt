package br.com.frila.core.rede

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test

/**
 * Teste de roundtrip JSON em classes e DTOs serializáveis (RF03/RF07/RF13/RNF04).
 * Valida que o R8 / Proguard preserva @Serializable, @SerialName e Companion.serializer().
 */
class SerializacaoRoundtripTest {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    @Test
    fun `roundtrip VagaAbertaDto preserva campos e nomes serializados`() {
        val original = VagaAbertaDto(
            id = "vaga-123",
            funcao = FuncaoDto(id = "f1", nome = "bartender", categoria = "Bar"),
            estabelecimento = PerfilPublicoDto(
                id = "est-456",
                tipo = "estabelecimento",
                nome = "Bar do Lago",
                funcoes = listOf("bartender"),
                reputacao = ReputacaoDto(
                    positivas = 10,
                    total = 10,
                    taxaComparecimento = 1.0,
                    turnosConsiderados = 10,
                    turnosRealizados = 10,
                ),
            ),
            inicioEm = "2026-11-01T20:00:00Z",
            fimEm = "2026-11-02T02:00:00Z",
            local = "Asa Sul",
            regiaoAdministrativa = "Plano Piloto",
            distanciaKm = 3.5,
            valorCentavos = 18_000L,
            posicoesAbertas = 2,
            inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
            modo = "urgencia",
        )

        val encoded = json.encodeToString(original)
        val decoded = json.decodeFromString<VagaAbertaDto>(encoded)

        assertEquals(original, decoded)
        assertEquals("bartender", decoded.funcao.nome)
        assertEquals(18_000L, decoded.valorCentavos)
        assertEquals(3.5, decoded.distanciaKm)
    }

    @Test
    fun `roundtrip PerfilProfissionalDto com coordenadas e disponibilidade`() {
        val original = PerfilProfissionalDto(
            id = "prof-1",
            usuarioId = "usr-1",
            funcoes = listOf(FuncaoDto("f1", "garçom", "Salão")),
            pontoBase = CoordenadaDto(latitude = -15.7942, longitude = -47.8822),
            disponibilidades = listOf(
                JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00"),
            ),
            reputacao = ReputacaoDto(
                positivas = 5,
                total = 6,
                taxaComparecimento = 0.9,
                turnosConsiderados = 6,
                turnosRealizados = 6,
            ),
        )

        val encoded = json.encodeToString(original)
        val decoded = json.decodeFromString<PerfilProfissionalDto>(encoded)

        assertEquals(original, decoded)
        assertEquals(-15.7942, decoded.pontoBase?.latitude)
        assertEquals(1, decoded.disponibilidades.size)
    }

    @Test
    fun `roundtrip TurnoDto com checkin e avaliacao`() {
        val original = TurnoDto(
            id = "11111111-1111-1111-1111-111111111111",
            posicaoId = "33333333-3333-3333-3333-333333333333",
            vaga = VagaResumoDto(
                id = "22222222-2222-2222-2222-222222222222",
                funcao = "cozinheiro",
                local = "CLN 201 Bloco B",
                regiaoAdministrativa = "Plano Piloto",
                inicioEm = "2026-11-01T12:00:00Z",
                fimEm = "2026-11-01T18:00:00Z",
                valorCentavos = 15_000L,
            ),
            contraparte = PerfilPublicoDto(
                id = "c-1",
                tipo = "estabelecimento",
                nome = "Restaurante Central",
                reputacao = ReputacaoDto(3, 3, 1.0, 3, 3),
            ),
            contatoVisivelAte = "2026-11-08T18:00:00Z",
            aCaminhoEm = "2026-11-01T11:30:00Z",
            checkinEm = "2026-11-01T11:55:00Z",
            checkinTipo = "geolocalizado",
            checkinDistanciaM = 45,
            checkinConfirmadoEm = "2026-11-01T11:55:05Z",
            checkoutEm = null,
            checkoutDistanciaM = null,
            verificacao = "verificado",
            valorAcordadoCentavos = 15_000L,
            podeAvaliar = false,
            estado = "confirmada",
            avaliacao = AvaliacaoDto(turnoId = "11111111-1111-1111-1111-111111111111", resposta = true, criadaEm = "2026-11-01T18:10:00Z"),
            cancelamento = null,
        )

        val encoded = json.encodeToString(original)
        val decoded = json.decodeFromString<TurnoDto>(encoded)

        assertEquals(original, decoded)
        assertEquals(45, decoded.checkinDistanciaM)
        assertEquals("geolocalizado", decoded.checkinTipo)
        assertEquals(true, decoded.avaliacao?.resposta)
        assertEquals("cozinheiro", decoded.vaga.funcao)
    }

    @Test
    fun `roundtrip ResultadoRegistroDto de checkin presencial`() {
        val original = ResultadoRegistroDto(
            turnoId = "t-123",
            tipo = "geolocalizado",
            verificacao = "verificado",
            registradoEm = "2026-11-01T19:50:00Z",
            distanciaM = 32,
        )

        val encoded = json.encodeToString(original)
        val decoded = json.decodeFromString<ResultadoRegistroDto>(encoded)

        assertEquals(original, decoded)
        assertEquals(32, decoded.distanciaM)
        assertEquals("verificado", decoded.verificacao)
    }

    @Test
    fun `roundtrip SessaoDto e ExclusaoDeContaDto`() {
        val sessao = SessaoDto(
            accessToken = "jwt-access-token",
            refreshToken = "jwt-refresh-token",
            tokenType = "bearer",
            expiresIn = 3600L,
        )
        val sessaoDecoded = json.decodeFromString<SessaoDto>(json.encodeToString(sessao))
        assertEquals(sessao, sessaoDecoded)

        val exclusao = ExclusaoDeContaDto(
            perfilRemovidoEm = "2026-11-01T10:00:00Z",
            dadosApagadosAte = "2026-11-16",
            turnosCancelados = 2,
        )
        val exclusaoDecoded = json.decodeFromString<ExclusaoDeContaDto>(json.encodeToString(exclusao))
        assertEquals(exclusao, exclusaoDecoded)
    }

    @Test
    fun `desserializacao e resiliente a chaves adicionais desconhecidas`() {
        val jsonComCamposExtras = """
            {
                "id": "vaga-999",
                "funcao": {"id": "f9", "nome": "garçom", "categoria": "Salão", "campo_extra": "ignorado"},
                "estabelecimento": {
                    "id": "e9", "tipo": "estabelecimento", "nome": "Bar Teste",
                    "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
                },
                "inicio_em": "2026-11-01T10:00:00Z",
                "fim_em": "2026-11-01T14:00:00Z",
                "local": "Asa Norte",
                "regiao_administrativa": "Plano Piloto",
                "distancia_km": 1.2,
                "valor_centavos": 10000,
                "posicoes_abertas": 1,
                "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
                "modo": "selecao",
                "campo_futuro_api": {"chave": 123}
            }
        """.trimIndent()

        val decoded = json.decodeFromString<VagaAbertaDto>(jsonComCamposExtras)
        assertNotNull(decoded)
        assertEquals("vaga-999", decoded.id)
    }
}
