package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Perfil de profissional do chamador (RF03/RF16/RF25/RN15/RNF08, UC09/UC16). */
class ServicoPerfil(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()


    /** `GET /rest/v1/rpc/meu_perfil_profissional`. Perfil com reputação agregada (RF03/RF16). */
    suspend fun obterMeuPerfilProfissional(): PerfilProfissionalDto {
        val resposta = cliente.http.get(cliente.urlRpc("meu_perfil_profissional"))
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /functions/v1/excluir-conta`. Edge Function que anonimiza os dados em `usuario`,
     * cancela turnos futuros sem gerar falta e apaga a credencial no Supabase Auth
     * (RF25/RN15/UC16). Idempotente: reenviar em conta já anonimizada devolve 202 de novo com
     * `turnos_cancelados: 0`. Erros: `409 administrador_unico` (precisa transferir a
     * administração do estabelecimento antes), `401 nao_autenticado`.
     */
    suspend fun excluirConta(): ExclusaoDeContaDto {
        val resposta = cliente.http.post(cliente.urlFunction("excluir-conta")) {
            contentType(ContentType.Application.Json)
            setBody(ConfirmarExclusaoDto(confirmar = true))
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/criar_perfil_profissional`.
     * Declara funções, ponto base e disponibilidade (RF01/RF03/RN05/RN25, UC09).
     * Erros: `409 perfil_ja_existe`, `401 nao_autenticado`, `403 conta_suspensa`, `422 perfil_incompativel`, `422 campo_invalido`.
     */
    suspend fun criarPerfilProfissional(dados: DadosDoPerfilProfissionalDto): PerfilProfissionalDto {
        val resposta = cliente.http.post(cliente.urlRpc("criar_perfil_profissional")) {
            contentType(ContentType.Application.Json)
            setBody(dados)
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/atualizar_perfil_profissional`.
     * Altera funções, ponto base ou disponibilidade (RF03, UC09).
     * Erros: `401 nao_autenticado`, `403 conta_suspensa`, `404 nao_encontrado`, `422 campo_obrigatorio`, `422 campo_invalido`.
     */
    suspend fun atualizarPerfilProfissional(alteracao: AlteracaoDoPerfilProfissionalDto): PerfilProfissionalDto {
        val resposta = cliente.http.post(cliente.urlRpc("atualizar_perfil_profissional")) {
            contentType(ContentType.Application.Json)
            setBody(alteracao)
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/atualizar_apresentacao_profissional`.
     * Altera "Sobre mim", experiência, cursos e idiomas (RN26/RN38/RN39/RN25).
     * Erros: `401 nao_autenticado`, `403 sem_permissao` (recurso_desligado) ou `conta_suspensa`, `404 nao_encontrado`, `422 campo_obrigatorio`, `422 campo_invalido`, `422 perfil_incompativel`.
     */
    suspend fun atualizarApresentacaoProfissional(apresentacao: ApresentacaoDoProfissionalDto): PerfilProfissionalDetalhadoDto {
        val resposta = cliente.http.post(cliente.urlRpc("atualizar_apresentacao_profissional")) {
            contentType(ContentType.Application.Json)
            setBody(apresentacao)
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/definir_regioes_atendidas`.
     * Define as regiões administrativas onde atende (RN26/RN44).
     * Erros: `401 nao_autenticado`, `403 sem_permissao` (recurso_desligado) ou `conta_suspensa`, `404 nao_encontrado`, `422 campo_invalido`.
     */
    suspend fun definirRegioesAtendidas(dados: DefinirRegioesAtendidasDto): PerfilProfissionalDetalhadoDto {
        val resposta = cliente.http.post(cliente.urlRpc("definir_regioes_atendidas")) {
            contentType(ContentType.Application.Json)
            setBody(dados)
        }
        return cliente.corpoOuErro(resposta)
    }
}
