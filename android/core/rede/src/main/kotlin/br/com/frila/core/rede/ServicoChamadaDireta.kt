package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.serialization.json.JsonObject

/**
 * Contratação direta e busca de profissionais (contrato 0.2.88, frila-documentacao#259): perfil público e
 * rico, serviços com preço, preferências "aceito chamadas", busca, chamada direta (chamar, responder,
 * cancelar, listar, detalhar) e publicar a vaga a partir de uma chamada.
 *
 * Todas as operações vão em `POST /rest/v1/rpc/<nome>` com os parâmetros no corpo, mesmo as que o contrato
 * descreve como `GET` (`perfil_publico`, `meu_perfil_detalhado`, `minhas_chamadas`, `detalhe_chamada`): o
 * PostgREST só aceita `GET` para função estável, e várias delas são voláteis (a busca grava o contador do
 * limite; `perfil_publico` assina a foto). O iOS faz o mesmo. Erros chegam como [ErroDaApi].
 *
 * Os recursos `busca_profissionais` e `chamada_direta` podem estar desligados no servidor: a operação responde
 * `403 sem_permissao` com `details: recurso_desligado` e o app esconde a entrada (RN46).
 */
class ServicoChamadaDireta(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()

    private suspend inline fun <reified Corpo : Any, reified Resposta> rpc(nome: String, corpo: Corpo): Resposta {
        val resposta = cliente.http.post(cliente.urlRpc(nome)) {
            contentType(ContentType.Application.Json)
            setBody(corpo)
        }
        return cliente.corpoOuErro(resposta)
    }

    // --- Perfil e preferências do profissional -------------------------------------------------

    /**
     * `perfil_publico`: o perfil de um profissional ou estabelecimento, com o perfil rico (serviços, regiões,
     * apresentação). `nome` vem só com primeiro nome e inicial do sobrenome para a casa sem candidatura, turno
     * ou equipe com o profissional (0.2.88). Bloqueio entre as partes ou id inexistente: `404 nao_encontrado`.
     */
    suspend fun perfilPublico(id: String): PerfilPublicoDto =
        rpc("perfil_publico", PerfilPublicoParametrosDto(id = id))

    /**
     * `meu_perfil_detalhado`: o próprio perfil do profissional, com serviços, regiões e preferências. Conta de
     * contratante: `422 perfil_incompativel`; sem perfil: `404`; `perfil_rico` desligado: `403 recurso_desligado`.
     */
    suspend fun meuPerfilDetalhado(): PerfilProfissionalDetalhadoDto =
        rpc("meu_perfil_detalhado", JsonObject(emptyMap()))

    /**
     * `definir_servicos`: **substitui** o conjunto de serviços (lista vazia limpa), até 10. Erros esperados:
     * `422 funcao_nao_marcada` (`details`: o `funcao_id`), `422 campo_invalido` (função repetida em `servicos`,
     * campo fora da unidade, `valor_max_centavos` menor que `valor_centavos`), `403` (`recurso_desligado`,
     * `conta_suspensa`).
     */
    suspend fun definirServicos(servicos: List<ServicoOferecidoDto>): PerfilProfissionalDetalhadoDto =
        rpc("definir_servicos", DefinirServicosDto(servicos = servicos))

    /**
     * `definir_preferencia_chamadas`: campo enviado substitui, omitido fica como está. Ligar `aceita_chamadas`
     * exige `versao_texto_busca` (`422 campo_obrigatorio`); sem nenhum campo, `422 campo_obrigatorio`
     * (`nenhum_campo`). A resposta traz `pendencias_para_busca`, o que ainda impede de aparecer na busca.
     */
    suspend fun definirPreferenciaChamadas(preferencias: DefinirPreferenciaChamadasDto): PreferenciaChamadasDto =
        rpc("definir_preferencia_chamadas", preferencias)

    // --- Busca ---------------------------------------------------------------------------------

    /**
     * `buscar_profissionais`: até 20 por página, por cursor opaco ([BuscarProfissionaisDto.cursor]); sem foto.
     * Só membro do estabelecimento busca (`403 sem_permissao`). Erros esperados: `429 limite_excedido` (60
     * buscas por hora; só a primeira página conta), `422 cursor_invalido` (o app refaz a busca), `422
     * campo_obrigatorio` (`regiao_id`, quando a região da casa não casa com o catálogo).
     */
    suspend fun buscarProfissionais(busca: BuscarProfissionaisDto): PaginaDeProfissionaisDto =
        rpc("buscar_profissionais", busca)

    /**
     * `aceitar_termos` (0.2.90): registra o aceite de [termosVersao] pela conta que já existe; o servidor carimba o
     * instante. Repetir a mesma versão devolve o aceite que já existe (idempotente). Erros: `422 campo_obrigatorio`
     * (versão vazia) e `422 campo_invalido` (fora do formato `AAAA-MM-DD`, fora da lista de versões publicadas ou
     * anterior à já aceita); sem conta, `404 nao_encontrado`. O uso é a busca: `403 sem_permissao`
     * (`details: termos_pendentes`) leva o app a pedir o aceite por aqui e a repetir a busca.
     */
    suspend fun aceitarTermos(termosVersao: String): AceiteDeTermosDto =
        rpc("aceitar_termos", AceitarTermosDto(termosVersao = termosVersao))

    // --- Chamada direta ------------------------------------------------------------------------

    /**
     * `chamar_profissional`: cria a vaga direta e a chamada, idempotente pela `chave`. Erros esperados:
     * `409 chamada_ja_aberta`, `409 recorrencia_nao_confirmada` (reenviar com `confirmoRecorrencia = true`
     * depois do aviso, J7), `422 profissional_indisponivel` (`details`: `nao_aceita_chamadas`, `pausado`,
     * `par_em_pausa`, `par_bloqueado_temporariamente`, `antecedencia_insuficiente`, `agenda_cheia`), `422
     * limite_de_chamadas` (`details`: `por_vaga`, `abertas`, `por_dia`, `conta_nova`), `404 nao_encontrado`
     * (também bloqueio), `409 vaga_encerrada`, `422 campo_invalido` (`regiao_id`).
     */
    suspend fun chamarProfissional(pedido: ChamarProfissionalDto): ChamadaDto =
        rpc("chamar_profissional", pedido)

    /**
     * `responder_chamada`: só o profissional chamado. [resposta] vale `aceitar` ou `recusar`; [motivoRecusa]
     * (`agenda`, `distancia`, `valor`, `tipo_de_servico`, `outro`) só conta na recusa. Erros esperados: `409
     * chamada_indisponivel` (`details`: `expirada`, `encerrada`; resposta diferente da já dada), `422
     * inelegivel` (`details`: `funcao_incompativel`, `turno_sobreposto`), `404`, `403 conta_suspensa`.
     */
    suspend fun responderChamada(chamadaId: String, resposta: String, motivoRecusa: String? = null): ResultadoChamadaDto =
        rpc("responder_chamada", ResponderChamadaDto(chamadaId = chamadaId, resposta = resposta, motivoRecusa = motivoRecusa))

    /**
     * `cancelar_chamada`: qualquer membro do estabelecimento cancela uma chamada `aberta`. Idempotente para o
     * mesmo autor; chamada em outro estado é `409 chamada_indisponivel`.
     */
    suspend fun cancelarChamada(chamadaId: String): ChamadaDto =
        rpc("cancelar_chamada", CancelarChamadaDto(chamadaId = chamadaId))

    /**
     * `minhas_chamadas`: para o profissional, as recebidas; para o contratante, as de todos os seus
     * estabelecimentos. Da mais nova para a mais antiga, até 20 por página; [estado] filtra. Cursor de outra
     * lista ou adulterado: `422 cursor_invalido`.
     */
    suspend fun minhasChamadas(estado: String? = null, cursor: String? = null, limite: Int? = null): PaginaDeChamadasDto =
        rpc("minhas_chamadas", MinhasChamadasParametrosDto(estado = estado, cursor = cursor, limite = limite))

    /**
     * `detalhe_chamada`: só as partes (outra conta, ou partes bloqueadas: `404`). `local`, `ponto` e
     * `responsavel_local` só vêm com `estado = aceita` (RN36); nunca telefone.
     */
    suspend fun detalheChamada(chamadaId: String): ChamadaDetalheDto =
        rpc("detalhe_chamada", DetalheChamadaParametrosDto(chamadaId = chamadaId))

    /**
     * `publicar_a_partir_da_chamada`: converte a vaga direta numa vaga normal **nova**, despachada como
     * qualquer vaga; a direta e as chamadas abertas dela vão a `encerrada`. Idempotente pela [chave] e pela vaga
     * direta. [modo] vale `urgencia` (padrão) ou `selecao`. Erros esperados: `409 vaga_encerrada` (fora da
     * janela, já preenchida ou cancelada), `422 selecao_sem_antecedencia`.
     */
    suspend fun publicarAPartirDaChamada(vagaId: String, chave: String, modo: String? = null): VagaPublicadaDto =
        rpc("publicar_a_partir_da_chamada", PublicarAPartirDaChamadaDto(vagaId = vagaId, chave = chave, modo = modo))
}
