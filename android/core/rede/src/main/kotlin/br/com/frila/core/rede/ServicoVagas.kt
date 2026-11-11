package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.Coordenada
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.parameter
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.CancellationException

/**
 * Leitura de vagas abertas, candidatura, publicação e escolha de candidato (`/rpc/vagas_abertas`,
 * `/rpc/candidatar`, `/rpc/publicar_vaga`, `/rpc/candidatos_da_vaga`, `/rpc/escolher_candidato`) e o
 * painel do estabelecimento (`/rpc/painel_estabelecimento`).
 */
class ServicoVagas(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()


    /**
     * `GET /rpc/vagas_abertas` (RF05/RF07/RN02). `coordenada` é opcional — sem ela, o backend usa
     * o `ponto_base` do perfil (openapi.yaml:2092-2122). `distanciaMaxKm` filtra no servidor; a
     * tela ainda refiltra localmente em `aplicarFiltros()` para resposta imediata ao toque.
     */
    suspend fun listarVagasAbertas(
        coordenada: Coordenada? = null,
        distanciaMaxKm: Double? = null,
    ): List<VagaAbertaDto> {
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas")) {
            coordenada?.let {
                parameter("latitude", it.latitude)
                parameter("longitude", it.longitude)
            }
            distanciaMaxKm?.let { parameter("distancia_max_km", it) }
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/candidatar`. Modo urgência confirma na hora (RN19) e já devolve turno
     * e contato (RN10); modo seleção fica pendente. Erros esperados (RF08/RF09/RN21):
     * `409 posicao_ja_preenchida`, `409 vaga_encerrada`, `422 inelegivel`.
     */
    suspend fun candidatar(vagaId: String): ResultadoCandidaturaDto {
        val resposta = cliente.http.post(cliente.urlRpc("candidatar")) {
            contentType(ContentType.Application.Json)
            setBody(CandidatarDto(vagaId = vagaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/publicar_vaga` (RF04/RN02/RN24). Idempotente pela `chave` do corpo.
     * Recusas: `422 campo_obrigatorio`/`campo_invalido` (campo em `details`), `422 horario_invalido`,
     * `422 selecao_sem_antecedencia`, `422 perfil_incompativel`, `403 sem_permissao` (com
     * `details: conta_suspensa` para conta suspensa), `401 nao_autenticado`.
     */
    suspend fun publicarVaga(vaga: NovaVagaDto): VagaPublicadaDto {
        val resposta = cliente.http.post(cliente.urlRpc("publicar_vaga")) {
            contentType(ContentType.Application.Json)
            setBody(vaga)
        }
        return cliente.corpoOuErro(resposta)
    }

    /** `GET /rest/v1/funcao`: catálogo fechado de funções ativas (RN05), para o seletor de publicação. */
    suspend fun listarFuncoes(): List<FuncaoDto> {
        val resposta = cliente.http.get(cliente.urlCompleta("/rest/v1/funcao")) {
            parameter("select", "id,nome,categoria")
            parameter("ativo", "eq.true")
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/candidatos_da_vaga` (RF09/RN06/UC04): candidatos pendentes de uma vaga em modo
     * seleção, em ordem de chegada. Vai por POST porque a função do banco é VOLÁTIL (plpgsql sem
     * `STABLE`) e o PostgREST só aceita POST nesse caso; o contrato descreve GET com `vaga_id` na query.
     * Conta de profissional recebe `422 perfil_incompativel`; quem não é da casa, `403 sem_permissao`.
     */
    suspend fun candidatosDaVaga(vagaId: String): List<CandidatoDto> {
        val resposta = cliente.http.post(cliente.urlRpc("candidatos_da_vaga")) {
            contentType(ContentType.Application.Json)
            setBody(CandidatosDaVagaParametrosDto(vagaId = vagaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/escolher_candidato` (RF09/RF10/RN19/RN21). Não é idempotente: escolher de novo
     * a candidatura já escolhida responde `409 candidatura_indisponivel`. Erros esperados:
     * `409 posicao_ja_preenchida`, `409 candidatura_indisponivel`, `409 vaga_encerrada` (seleção fechada
     * pelas 24 horas, vaga cancelada ou encerrada), `422 inelegivel` (`details: turno_sobreposto`),
     * `422 vaga_oculta`, `403 sem_permissao` (também candidatura inexistente, de outra casa ou com
     * bloqueio mútuo), `401 nao_autenticado`.
     */
    suspend fun escolherCandidato(candidaturaId: String): ResultadoConfirmacaoDto {
        val resposta = cliente.http.post(cliente.urlRpc("escolher_candidato")) {
            contentType(ContentType.Application.Json)
            setBody(EscolherCandidatoDto(candidaturaId = candidaturaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/painel_estabelecimento` (RF20/UC07): as vagas do estabelecimento entre [de] e
     * [ate], com candidatos pendentes, posições e alertas. Vai por POST porque a função do banco é
     * VOLÁTIL (plpgsql sem `STABLE`) e o PostgREST só aceita POST nesse caso; o contrato descreve GET com
     * query. Só membro do estabelecimento lê: quem não é recebe `403 sem_permissao`.
     *
     * Devolve [Result]: qualquer falha (recusa do servidor, sem rede, corpo que não é JSON) vira
     * `Result.failure`, e só o cancelamento da corrotina propaga.
     */
    suspend fun painelEstabelecimento(estabelecimentoId: String, de: Instant, ate: Instant): Result<PainelDto> =
        try {
            val resposta = cliente.http.post(cliente.urlRpc("painel_estabelecimento")) {
                contentType(ContentType.Application.Json)
                setBody(
                    PainelParametrosDto(
                        estabelecimentoId = estabelecimentoId,
                        de = de.truncatedTo(ChronoUnit.SECONDS).toString(),
                        ate = ate.truncatedTo(ChronoUnit.SECONDS).toString(),
                    ),
                )
            }
            Result.success(cliente.corpoOuErro<PainelDto>(resposta))
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            Result.failure(erro)
        }
}
