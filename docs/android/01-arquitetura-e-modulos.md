# 01 — Arquitetura e Módulos (Android v1.1)

**Cartão:** `XTijdYVk` · **Status:** Normativo · **Baseado em:** `docs/proposta-android.md` (§2, §3)

---

## 1. Princípio arquitetural

O app Android é um domínio **nativo e independente**, não um alvo de core compartilhado
multiplataforma (sem KMP, Flutter ou React Native). As regras de negócio vivem no backend
PostgreSQL/Supabase e são expressas pelo contrato normativo OpenAPI (ver
`03-contrato-e-api.md`). O que o app Android replica em Kotlin é a mesma **forma** do domínio já
validada no cliente iOS — entidades imutáveis, casos de uso puros, portas de domínio — nunca o
código em si.

Camadas, de fora para dentro, seguem Clean Architecture com fluxo estritamente unidirecional:

```
Apresentação (Compose + ViewModel/StateFlow)
        │ consome casos de uso
        ▼
Domínio (entidades, casos de uso, portas — Kotlin puro)
        ▲ implementa portas
        │
Dados (repositórios, cliente Ktor, cache, fila de sincronização)
```

Nenhuma camada interna conhece uma externa. `:core:dominio` não importa `android.*` nem
bibliotecas de terceiros fora de `kotlin-stdlib` e corrotinas — é testável em JVM puro, sem
emulador, sem Robolectric.

## 2. Estrutura multi-módulo Gradle

```
:app
 ├─▶ :feature:entrada
 ├─▶ :feature:cadastro
 ├─▶ :feature:vagas
 └─▶ :core:dados

:feature:entrada   ─▶ :core:designsystem, :core:dominio
:feature:cadastro  ─▶ :core:designsystem, :core:dominio
:feature:vagas     ─▶ :core:designsystem, :core:dominio

:core:dados        ─▶ :core:dominio, :core:rede, :core:seguranca
:core:dominio      ─▶ (nenhuma dependência de módulo do projeto)
:core:designsystem ─▶ (nenhuma dependência de módulo do projeto)
:core:seguranca    ─▶ (nenhuma dependência de módulo do projeto)
```

### Regra de isolamento de dependências

- `:core:dominio` é um módulo Kotlin puro (`kotlin("jvm")`, não `com.android.library`). Não pode
  depender de nenhum outro módulo do projeto. Garante que regras de negócio (RN02, RN15, RN20,
  RN21) sejam testadas sem tocar o framework Android.
- `:core:designsystem` e `:core:seguranca` não dependem de `:core:dominio` nem entre si — são
  utilitários de plataforma, não lógica de produto.
- `:feature:*` nunca depende de `:core:dados` diretamente nem de outro `:feature:*`. Toda
  comunicação entre telas passa por navegação declarada em `:app`, nunca por import cruzado.
- `:app` é o único módulo que conhece todos os outros. É onde Koin monta o grafo completo.
- Build Gradle usa **version catalogs** (`libs.versions.toml`) compartilhado entre módulos; nenhum
  módulo declara versão de dependência solta no seu próprio `build.gradle.kts`.

Esse isolamento é o que permite builds incrementais rápidos na CI (módulo que não mudou não
recompila) e impede que uma biblioteca de UI ou de rede vaze para dentro do domínio de regras de
negócio.

## 3. Detalhamento dos módulos

| Módulo | Tipo de plugin | Conteúdo | Depende de |
|---|---|---|---|
| `:core:dominio` | `kotlin("jvm")` | Entidades (`Conta`, `Vaga`, `Turno`, `Candidatura`), enums de negócio (`ModoPreenchimento`, `EstadoVaga`), objetos de valor (`Dinheiro`, `Coordenada`, `DataCivil`), portas (`ApiCliente`, `ArmazenamentoDeSessao`, `ProvedorDeLocalizacao`), validadores de RN02/RN15/RN20/RN21 | nenhum módulo do projeto |
| `:core:dados` | `com.android.library` | Implementação das portas do domínio; chamadas RPC via Ktor; conversão de payload → domínio; fila de sincronização de estado offline | `:core:dominio`, `:core:rede`, `:core:seguranca` |
| `:core:rede` | `com.android.library` | Cliente Ktor configurado (timeouts, interceptors, serialização), DTOs gerados contra `openapi.yaml` | `:core:dominio` (só para os tipos de porta) |
| `:core:seguranca` | `com.android.library` | Sessão segura via Android Keystore (AES-256-GCM) e `EncryptedSharedPreferences`; ver `04-seguranca-e-sessao.md` | nenhum módulo do projeto |
| `:core:designsystem` | `com.android.library` | Tokens de cor/tipografia/raio/espaçamento mapeados para Compose/Material 3; componentes comuns; ver `02-tokens-material3.md` | nenhum módulo do projeto |
| `:feature:entrada` | `com.android.library` | Login OTP por e-mail, modo demo Play Store | `:core:designsystem`, `:core:dominio` |
| `:feature:cadastro` | `com.android.library` | Onboarding de perfil do profissional (RN20) | `:core:designsystem`, `:core:dominio` |
| `:feature:vagas` | `com.android.library` | Feed de vagas abertas, filtros, detalhe e candidatura | `:core:designsystem`, `:core:dominio` |
| `:app` | `com.android.application` | Composição do grafo Koin, navegação, `Application`, canais de notificação | todos |

## 4. Clean Architecture + MVI/StateFlow na apresentação

Cada tela de `:feature:*` segue o mesmo padrão MVI:

```kotlin
data class EstadoFeed(
    val carregando: Boolean = false,
    val vagas: List<Vaga> = emptyList(),
    val erro: CodigoErroAPI? = null,
)

sealed interface IntencaoFeed {
    data object Recarregar : IntencaoFeed
    data class AplicarFiltro(val filtro: FiltroVaga) : IntencaoFeed
}

class FeedVagasViewModel(
    private val buscarVagas: CasoDeUsoBuscarVagas, // :core:dominio
) : ViewModel() {
    private val _estado = MutableStateFlow(EstadoFeed())
    val estado: StateFlow<EstadoFeed> = _estado.asStateFlow()

    fun processar(intencao: IntencaoFeed) { /* reduz intenção -> novo estado */ }
}
```

- `ViewModel` nunca importa um tipo de `:core:dados` diretamente — só a interface de caso de uso
  exposta por `:core:dominio`.
- Estado é sempre um único `data class` imutável por tela, nunca múltiplos `StateFlow` soltos
  descrevendo a mesma tela.
- Efeitos colaterais (navegação, toast) são emitidos por um canal `Channel<EfeitoFeed>` separado
  do estado, nunca colocados dentro do `data class` de estado.

## 5. Injeção de dependência — Koin

Decisão fechada para o alicerce do cartão `XTijdYVk`: **Koin**, não Hilt. Kotlin puro, sem
geração de código em tempo de compilação, módulo de DI dedicado por módulo Gradle:

```kotlin
val moduloDominio = module {
    factory { CasoDeUsoBuscarVagas(get()) }
}

val moduloDados = module {
    single<ApiCliente> { ApiClienteKtor(get()) }
    single<ArmazenamentoDeSessao> { ArmazenamentoDeSessaoKeystore(androidContext()) }
}

val moduloApp = module {
    viewModel { FeedVagasViewModel(get()) }
}
```

`:app` soma os módulos em `startKoin { modules(moduloDominio + moduloDados + moduloApp) }` dentro
de `Application.onCreate()`. Nenhum módulo de feature chama `startKoin` ou `get()` fora do escopo
de `viewModel { }`/`factory { }` — resolução direta de serviço dentro de composables é proibida.

## 6. Decisão de workspace (aberta no `docs/proposta-android.md`)

A proposta original deixa em aberto monorepo em subpasta `android/` vs. repositório dedicado
`frila-android`. Este documento assume **monorepo em `android/`** como estrutura de referência
para os caminhos de módulo acima, por ser a opção recomendada na proposta; a decisão final cabe
ao Dono do produto (item 3 da seção "Decisões em Aberto").
