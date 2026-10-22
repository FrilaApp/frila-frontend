# 03 — Contrato e API (Android v1.1)

**Status:** Normativo · **Fonte:** `iOS/Contrato/openapi.yaml`, `iOS/Sources/Dominio/ErrosDaAPI.swift`

> **Nota de versão.** A proposta original (`docs/proposta-android.md`) cita o contrato como
> OpenAPI 0.2.43. MEDIDO em `iOS/Contrato/openapi.yaml` (campo `info.version`): a versão atual do
> contrato é **0.2.45**. Este documento normatiza contra a versão medida, não contra o texto da
> proposta; o Android deve sempre gerar seus DTOs contra o `openapi.yaml` presente no repositório
> no momento do build, nunca contra um número fixado em prosa.

---

## 1. Cliente HTTP — Ktor

Decisão fechada para o alicerce do cartão `XTijdYVk`: **Ktor Client**, não Retrofit. Integração
nativa com Kotlinx Serialization, sem geração de adapter via anotação de interface.

```kotlin
val clienteHttp = HttpClient(OkHttp) {
    install(ContentNegotiation) { json(jsonFrila) }
    install(HttpTimeout) {
        requestTimeoutMillis = 15_000   // igual ao iOS: 15s por requisição
        connectTimeoutMillis = 60_000   // igual ao iOS: 60s conjunto
    }
    defaultRequest {
        url(BuildConfig.SUPABASE_URL)
        header("apikey", BuildConfig.SUPABASE_ANON_KEY)
        header("Authorization", "Bearer ${sessao.accessToken}")
    }
}
```

Timeouts replicam exatamente os do iOS (15s por requisição, 60s para o conjunto), especificado em
`docs/proposta-android.md` §2.

## 2. Serialização — Kotlinx Serialization

Sem reflexão em tempo de execução; toda a conversão DTO↔domínio é gerada em tempo de compilação
via plugin `kotlinx-serialization`. Campos do backend chegam em `snake_case` (convenção Postgres);
DTOs usam `@SerialName` para expor nome idiomático em `camelCase` no domínio:

```kotlin
@Serializable
data class VagaDTO(
    @SerialName("estado") val estado: String,
    @SerialName("regiao_administrativa") val regiaoAdministrativa: String,
    @SerialName("local") val local: String,
)
```

## 3. Geração de DTOs contra `openapi.yaml`

- Fonte única de verdade: `iOS/Contrato/openapi.yaml` (compartilhado entre as três plataformas —
  o contrato não é duplicado por plataforma).
- MEDIDO: o contrato define **44 operações RPC** (`/rpc/<nome>`), todas sob o padrão PostgREST do
  Supabase: `POST /rest/v1/rpc/<nome>` para regra de negócio (escrita), `GET` para leitura — nunca
  escrita direta em tabela pelos clientes.
- Geração de DTOs é estática e versionada: cada tipo gerado referencia o `info.version` do
  contrato no comentário gerado, para que uma divergência silenciosa de versão apareça no `git
  diff` do DTO.
- DTOs são sempre imutáveis (`data class` com `val`), nunca `var`.

## 4. Envelope de resposta PostgREST

Igual ao iOS, para as 44 RPCs:

| Situação | Formato |
|---|---|
| Sucesso (200/204) | Payload JSON direto, mapeado para DTO `@Serializable` imutável |
| Recusa (4xx) | Envelope `{ code, message, details?, hint? }`; só `code` (`snake_case`) é mapeado para domínio |

```kotlin
@Serializable
data class EnvelopeErroAPI(
    val code: String,
    val message: String,
    val details: String? = null,
    val hint: String? = null,
)
```

**Regra inegociável:** `message` é texto de diagnóstico do Postgres/PostgREST, nunca localizado,
nunca estável entre versões do backend. Vai estritamente para log (`Log.w` / ferramenta de
observabilidade), nunca para a tela do usuário. Só `code` decide o que a UI mostra.

## 5. `CodigoErroAPI` — enum fechado

Tradução Kotlin do enum já validado no iOS (`iOS/Sources/Dominio/ErrosDaAPI.swift`, MEDIDO, 42
casos incluindo `inelegivel` e `desconhecido` sem valor bruto customizado):

```kotlin
@Serializable
enum class CodigoErroAPI {
    @SerialName("nao_autenticado") NaoAutenticado,
    @SerialName("sem_permissao") SemPermissao,
    @SerialName("contato_expirado") ContatoExpirado,
    @SerialName("nao_encontrado") NaoEncontrado,
    @SerialName("posicao_ja_preenchida") PosicaoJaPreenchida,
    @SerialName("vaga_encerrada") VagaEncerrada,
    @SerialName("checkin_pendente") CheckinPendente,
    @SerialName("checkin_ja_confirmado") CheckinJaConfirmado,
    @SerialName("posicao_nao_cancelavel") PosicaoNaoCancelavel,
    @SerialName("candidatura_indisponivel") CandidaturaIndisponivel,
    @SerialName("avaliacao_ja_registrada") AvaliacaoJaRegistrada,
    @SerialName("conta_existente") ContaExistente,
    @SerialName("documento_ja_cadastrado") DocumentoJaCadastrado,
    @SerialName("administrador_unico") AdministradorUnico,
    @SerialName("perfil_ja_existe") PerfilJaExiste,
    @SerialName("campo_obrigatorio") CampoObrigatorio,
    @SerialName("campo_invalido") CampoInvalido,
    @SerialName("intervalo_maximo_excedido") IntervaloMaximoExcedido,
    @SerialName("fora_da_janela") ForaDaJanela,
    @SerialName("a_caminho_fora_da_janela") ACaminhoForaDaJanela,
    @SerialName("registro_no_futuro") RegistroNoFuturo,
    @SerialName("menor_de_idade") MenorDeIdade,
    @SerialName("perfil_incompativel") PerfilIncompativel,
    @SerialName("selecao_sem_antecedencia") SelecaoSemAntecedencia,
    @SerialName("vaga_oculta") VagaOculta,
    @SerialName("horario_invalido") HorarioInvalido,
    Inelegivel,
    @SerialName("funcao_incompativel") FuncaoIncompativel,
    @SerialName("avaliacao_indisponivel") AvaliacaoIndisponivel,
    @SerialName("reabertura_antes_da_tolerancia") ReaberturaAntesDaTolerancia,
    @SerialName("sem_suspensao_ativa") SemSuspensaoAtiva,
    @SerialName("contestacao_ja_aberta") ContestacaoJaAberta,
    @SerialName("limite_excedido") LimiteExcedido,
    @SerialName("republicacao_indisponivel") RepublicacaoIndisponivel,
    @SerialName("conta_suspensa") ContaSuspensa,
    @SerialName("sem_rede") SemRede,
    @SerialName("resposta_invalida") RespostaInvalida,
    Desconhecido,
}
```

Regras de uso (idênticas às do iOS, replicadas como extensões no domínio Kotlin):

- `recusaDefinitivaDePublicacao`: `CAMPO_OBRIGATORIO`, `CAMPO_INVALIDO`, `HORARIO_INVALIDO`,
  `FUNCAO_INCOMPATIVEL`, `PERFIL_INCOMPATIVEL`, `SELECAO_SEM_ANTECEDENCIA`, `SEM_PERMISSAO`,
  `CONTA_SUSPENSA`, `NAO_ENCONTRADO` — repetir a mesma solicitação não pode virar sucesso.
- `recusaDefinitivaDeCancelamento`: `POSICAO_NAO_CANCELAVEL`, `VAGA_ENCERRADA`, `NAO_ENCONTRADO`,
  `CAMPO_OBRIGATORIO`, `CAMPO_INVALIDO`, `SEM_PERMISSAO`, `PERFIL_INCOMPATIVEL`, `CONTA_SUSPENSA`.
- Um `code` desconhecido do backend decodifica para `Desconhecido`, nunca derruba o parse do
  envelope inteiro — decodificação de enum é tolerante a valor desconhecido
  (`JsonNamingStrategy`/`@Serializable(with = ...)` com fallback), igual ao
  `CaseIterable`-safe do Swift.

## 6. Gate de deriva de contrato — `contrato-android-confere`

Equivalente Android do gate já existente para iOS (`scripts/contrato-ios-confere.sh` →
`iOS/Scripts/conferir-contrato-ios.py`, MEDIDO). Tarefa Gradle (`./gradlew
contratoAndroidConfere`) executada antes da suíte de testes unitários, tanto localmente quanto na
CI (job `gate-contrato`, ver `05-ci-pipeline.md`):

1. Carrega `iOS/Contrato/openapi.yaml` (fonte única, não duplicada para Android).
2. Enumera as 44 operações RPC do contrato e confere que cada uma usada pelo app tem um DTO
   gerado e um nome de caso de uso correspondente em `:core:dominio`.
3. Confere que todo valor de `CodigoErroAPI` presente nas respostas de erro do contrato tem um
   caso correspondente no enum Kotlin — enum sem caso novo falha o gate, não falha em silêncio
   como `Desconhecido`.
4. Confere campos obrigatórios de cada schema de request contra os parâmetros exigidos pelo
   cliente Ktor.
5. Sai com código de saída não-zero e lista humanamente legível de divergências se qualquer
   checagem falhar — a CI trata esse exit code como falha dura do job, não como aviso.

Este documento **não** propõe reescrever o validador Python existente (`conferir-contrato-ios.py`)
em Kotlin; a tarefa Gradle do Android deve, no mínimo para o alicerce do cartão `XTijdYVk`,
reusar/chamar o mesmo validador Python contra os artefatos Android, estendendo-o apenas onde a
forma do DTO Kotlin divergir da forma do DTO Swift. Decisão de implementação (reuso vs. port
completo) cabe a quem planejar o Épico E2.
