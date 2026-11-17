package br.com.frila.core.rede

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

// DTOs do perfil do profissional (L1-0a). Ficam fora do `Dtos.kt` para não disputar a fila D. Campos opcionais de corpo usam
// `@EncodeDefault(NEVER)`: omitido deixa o campo como está, e só `JsonNull` o limpa quando o contrato diz que `null` limpa.

/**
 * Corpo de `POST /rest/v1/rpc/criar_perfil_profissional` (schema `DadosDoPerfilProfissional`).
 * Funções (ids do catálogo), ponto base e grade semanal (RF01/RF03/RN05/RN25). `disponibilidades: []` é aceita:
 * o perfil nasce sem janela, e o app avisa que assim ele não recebe notificação.
 */
@Serializable
data class DadosDoPerfilProfissionalDto(
    @SerialName("funcoes") val funcoes: List<String>,
    @SerialName("ponto_base") val pontoBase: CoordenadaDto,
    @SerialName("disponibilidades") val disponibilidades: List<JanelaDeDisponibilidadeDto>,
)

/**
 * Corpo de `POST /rest/v1/rpc/atualizar_perfil_profissional` (schema `AlteracaoDoPerfilProfissional`, `minProperties: 1`).
 * O que é enviado **substitui** o atual; o omitido fica como está. `disponibilidades: []` limpa a grade; `funcoes: []` é
 * `422 campo_obrigatorio`. Sem nenhum campo o servidor recusa com `422 campo_obrigatorio` (`details: nenhum_campo`).
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class AlteracaoDoPerfilProfissionalDto(
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("funcoes") val funcoes: List<String>? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("ponto_base") val pontoBase: CoordenadaDto? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("disponibilidades") val disponibilidades: List<JanelaDeDisponibilidadeDto>? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/atualizar_apresentacao_profissional` (schema `ApresentacaoDoProfissional`, 0.2.53,
 * `minProperties: 1`). Os campos enviados substituem os atuais, os omitidos ficam como estão e **`null` limpa o campo**.
 * Por isso [apresentacao], [ondeTrabalhei] e [experienciaFaixa] são [JsonElement]: Kotlin `null` = ausente (não mexe),
 * `JsonNull` = limpa, `JsonPrimitive("...")` = grava (como `DefinirPreferenciaChamadasDto.pausadoAte`). Com `String?` e
 * `EncodeDefault(NEVER)` o `null` seria descartado e a pessoa nunca conseguiria apagar o "Sobre mim". [cursos] (até 5, 80 caracteres) e
 * [idiomas] não aceitam `null`: lista vazia limpa. Texto livre passa pelos filtros de termos e de contato do servidor (RN38).
 */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ApresentacaoDoProfissionalDto(
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("apresentacao") val apresentacao: JsonElement? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("onde_trabalhei") val ondeTrabalhei: JsonElement? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("experiencia_faixa") val experienciaFaixa: JsonElement? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("cursos") val cursos: List<String>? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) @SerialName("idiomas") val idiomas: List<String>? = null,
)

/**
 * Corpo de `POST /rest/v1/rpc/definir_regioes_atendidas` (0.2.53; corpo inline, sem schema nomeado).
 * Substitui as regiões marcadas (ids de `GET /regiao_administrativa`). Com [atendeTodoDf] ligado, a lista é ignorada e gravada vazia.
 */
@Serializable
data class DefinirRegioesAtendidasDto(
    @SerialName("regioes") val regioes: List<Int>,
    @SerialName("atende_todo_df") val atendeTodoDf: Boolean,
)
