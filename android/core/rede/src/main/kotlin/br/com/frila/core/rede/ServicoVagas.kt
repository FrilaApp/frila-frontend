package br.com.frila.core.rede

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
     * `GET /rpc/vagas_abertas` (RF05/RF07/RN02). Nunca leva `latitude` nem `longitude`: a posição do aparelho não sai
     * daqui, e o backend ordena pelo `ponto_base` do perfil, como no iOS. `distanciaMaxKm` filtra no servidor; a
     * tela ainda refiltra localmente em `aplicarFiltros()` para resposta imediata ao toque.
     *
     * Paginada (contrato: `limite` de 1 a 100, padrão 30; `deslocamento` a partir de 0): uma página de [limite] vagas a
     * partir da posição [deslocamento] da ordem do servidor. Página com menos de [limite] vagas é a última.
     */
    suspend fun listarVagasAbertas(
        distanciaMaxKm: Double? = null,
        limite: Int = TAMANHO_DA_PAGINA_DO_FEED,
        deslocamento: Int = 0,
    ): List<VagaAbertaDto> {
        require(limite in 1..100) { "limite fora de 1..100: $limite" }
        require(deslocamento >= 0) { "deslocamento negativo: $deslocamento" }
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas")) {
            distanciaMaxKm?.let { parameter("distancia_max_km", it) }
            parameter("limite", limite)
            parameter("deslocamento", deslocamento)
        }
        return cliente.corpoOuErro(resposta)
    }

    companion object {
        /** O tamanho da página do feed, o mesmo do iOS (`tamanhoDaPagina`) e o padrão do contrato. */
        const val TAMANHO_DA_PAGINA_DO_FEED = 30
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

    /**
     * `POST /rest/v1/rpc/publicar_escala` (0.2.96, RF19): um evento e de 1 a 10 vagas numa transação só, tudo ou nada.
     * Idempotente pela `chave` da [escala]. Erros esperados: `422 campo_obrigatorio` e `422 campo_invalido` (o caminho
     * do campo em `details`: `evento.nome`, `vagas[2].valor_centavos`, `vagas`, `posicoes`), `422 horario_invalido` e
     * `422 selecao_sem_antecedencia` (`details: vagas[<i>]`), `422 perfil_incompativel`, `403 sem_permissao` (com
     * `details: conta_suspensa` para conta suspensa), `401 nao_autenticado`.
     */
    suspend fun publicarEscala(escala: NovaEscalaDto): EscalaPublicadaDto {
        val resposta = cliente.http.post(cliente.urlRpc("publicar_escala")) {
            contentType(ContentType.Application.Json)
            setBody(escala)
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

    // --- Lote 2 (L2-0): vagas da casa e vaga do profissional. Tudo em POST, como no iOS; erros chegam como [ErroDaApi]. ---

    /**
     * `POST /rest/v1/rpc/cancelar_vaga` (RN12): cancela as posições abertas e as confirmadas, com motivo (mínimo de
     * 3 caracteres). Não gera falta para ninguém. Reenvio pelo mesmo autor devolve `200` com a vaga já cancelada
     * (0.2.35). Erros esperados: `409 vaga_encerrada` (já começou, ou cancelada por outro autor),
     * `422 campo_obrigatorio` e `422 campo_invalido` (`details: motivo`), `404 nao_encontrado` (não existe ou é de
     * outra casa), `422 perfil_incompativel` (conta de profissional), `403 sem_permissao` (`details: conta_suspensa`).
     */
    suspend fun cancelarVaga(vagaId: String, motivo: String): VagaCanceladaDto {
        val resposta = cliente.http.post(cliente.urlRpc("cancelar_vaga")) {
            contentType(ContentType.Application.Json)
            setBody(CancelarVagaDto(vagaId = vagaId, motivo = motivo))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/republicar_vaga` (RF05): copia a vaga de origem e muda só [inicio] e [fim], enviados em UTC
     * com precisão de segundo (RN18). Idempotente pela [chave]. Mesmas recusas de `publicar_vaga`
     * (`422 horario_invalido`, `422 selecao_sem_antecedencia`, `422 campo_invalido`...), mais `404 nao_encontrado`
     * (origem inexistente), `403 sem_permissao` (vaga de outra casa; `details: conta_suspensa`),
     * `422 perfil_incompativel` (conta de profissional) e `422 vaga_oculta` (origem ocultada pela moderação).
     */
    suspend fun republicarVaga(vagaId: String, inicio: Instant, fim: Instant, chave: String): VagaPublicadaDto {
        val resposta = cliente.http.post(cliente.urlRpc("republicar_vaga")) {
            contentType(ContentType.Application.Json)
            setBody(
                RepublicarVagaDto(
                    vagaId = vagaId,
                    inicioEm = inicio.truncatedTo(ChronoUnit.SECONDS).toString(),
                    fimEm = fim.truncatedTo(ChronoUnit.SECONDS).toString(),
                    chave = chave,
                ),
            )
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/republicar_posicoes_restantes` (D1-C): publica em urgência, para o mesmo turno e valor, as
     * posições que a seleção deixou vazias. Idempotente pela [chave]. Erros esperados:
     * `422 republicacao_indisponivel` com o motivo em `details` (`nao_e_selecao`, `selecao_em_curso`,
     * `vaga_cancelada`, `ja_comecou`, `sem_posicoes_restantes`, `ja_republicada`), `422 vaga_oculta`,
     * `422 perfil_incompativel`, `403 sem_permissao` (outra casa; `details: conta_suspensa`), `404 nao_encontrado`.
     */
    suspend fun republicarPosicoesRestantes(vagaId: String, chave: String): VagaPublicadaDto {
        val resposta = cliente.http.post(cliente.urlRpc("republicar_posicoes_restantes")) {
            contentType(ContentType.Application.Json)
            setBody(RepublicarPosicoesRestantesDto(vagaId = vagaId, chave = chave))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `detalhe_vaga` (UC03): a vaga inteira, lida do servidor (é o que abre por link ou aviso). Depois do início
     * continua respondendo `200` com o `estado` real. Erros esperados: `404 nao_encontrado` (não existe, bloqueio
     * entre as partes, ocultada sem vínculo, ou vaga de chamada direta para quem não é da casa nem tem turno nela),
     * `422 perfil_incompativel` (conta de contratante), `403 sem_permissao` (`details: conta_suspensa`).
     */
    suspend fun detalheVaga(vagaId: String): VagaDto {
        val resposta = cliente.http.post(cliente.urlRpc("detalhe_vaga")) {
            contentType(ContentType.Application.Json)
            setBody(DetalheVagaParametrosDto(vagaId = vagaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/retirar_candidatura` (RN24): sem penalidade, antes de ser escolhido. Retirar de novo devolve
     * a mesma candidatura retirada. Erros esperados: `409 candidatura_indisponivel` (recusada ou expirada; a já
     * escolhida vira `cancelar_posicao`), `422 perfil_incompativel` (conta de contratante), `422 campo_obrigatorio`
     * (`details: candidatura_id`), `404 nao_encontrado`, `403 sem_permissao` (`details: conta_suspensa`).
     */
    suspend fun retirarCandidatura(candidaturaId: String): CandidaturaDto {
        val resposta = cliente.http.post(cliente.urlRpc("retirar_candidatura")) {
            contentType(ContentType.Application.Json)
            setBody(RetirarCandidaturaDto(candidaturaId = candidaturaId))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `minhas_candidaturas`: as candidaturas do profissional; [estado] filtra (`pendente`, `aceita`, `recusada`,
     * `retirada`, `expirada`) e, nulo, não vai no corpo. A `aceita` traz `turno_id` (0.2.32). Lista vazia é resposta
     * legítima. Erros esperados: `422 perfil_incompativel` (conta de contratante), `403 sem_permissao`
     * (`details: conta_suspensa`), `401 nao_autenticado`.
     */
    suspend fun minhasCandidaturas(estado: String? = null): List<CandidaturaDto> {
        val resposta = cliente.http.post(cliente.urlRpc("minhas_candidaturas")) {
            contentType(ContentType.Application.Json)
            setBody(MinhasCandidaturasParametrosDto(estado = estado))
        }
        return cliente.corpoOuErro(resposta)
    }
}
