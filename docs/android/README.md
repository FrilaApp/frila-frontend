# Android — Guia Mestre da Plataforma (v1.1)

**Cartão Trello:** `XTijdYVk` (`v1.1 · Android · Criar o projeto Android (Kotlin) com o domínio e
o cliente da API`) · **Status:** Documentação normativa para o alicerce do projeto

---

## O que é isto

Esta pasta é a especificação técnica e normativa para a inicialização do ecossistema Android do
Frila. Não há núcleo compartilhado multiplataforma: o domínio é reescrito nativamente em Kotlin,
replicando a mesma forma de domínio e os mesmos tokens de design já validados no app iOS, contra
o mesmo contrato OpenAPI usado por todas as plataformas.

Fontes de origem desta documentação:

- `docs/proposta-android.md` — proposta arquitetural original (Trovão, Engenharia Mobile)
- `iOS/Sources/Apresentacao/DesignTokens.swift` — tokens de design já em produção no iOS
- `iOS/Contrato/openapi.yaml` — contrato normativo da API (versão medida: 0.2.45)

## Documentos

| # | Documento | Cobre |
|---|---|---|
| 01 | [Arquitetura e Módulos](01-arquitetura-e-modulos.md) | Estrutura multi-módulo Gradle, Clean Architecture + MVI/StateFlow, Koin, isolamento de dependências |
| 02 | [Tokens e Material 3](02-tokens-material3.md) | Mapeamento de `FrilaCor`/`FrilaEspaco`/`FrilaRaio`/`FrilaTipo`/`FrilaMetrica` para `ColorScheme`/`Typography`/`Shapes` do Compose; alvo mínimo 48dp |
| 03 | [Contrato e API](03-contrato-e-api.md) | Cliente Ktor + Kotlinx Serialization, DTOs contra `openapi.yaml`, enum `CodigoErroAPI`, gate `contrato-android-confere` |
| 04 | [Segurança e Sessão](04-seguranca-e-sessao.md) | Android Keystore + `EncryptedSharedPreferences`, regras de bloqueio de exportação (LGPD/RN15), modo demo Play Store |
| 05 | [Pipeline de CI](05-ci-pipeline.md) | GitHub Actions em `ubuntu-latest`, JDK 17, ktlint, detekt, gate de contrato, orçamento de 3 minutos |

## Escopo do cartão `XTijdYVk` e roteiro de épicos

O cartão estabelece os alicerces do projeto Android: arquitetura, domínio, cliente de API e
segurança. Escopo estrito: **Épicos E1 e E2**.

| Épico | Escopo | Esforço | Status |
|---|---|:---:|:---:|
| **E1 — Base do Projeto e Módulos** | Subpasta `android/`, estrutura multi-módulo Gradle, CI no GitHub Actions, tokens Material 3 em Compose | 4 dias | Escopo do cartão `XTijdYVk` |
| **E2 — Domínio, Contrato e Sessão** | Regras puras em `:core:dominio`, DTOs OpenAPI, cliente PostgREST, gate de contrato, armazenamento seguro no Keystore | 5 dias | Escopo do cartão `XTijdYVk` |
| **E3 — Entrada e Cadastro** | Telas OTP (e-mail + 6 dígitos), modo demo Play Store, cadastro do profissional (RN20) | 6 dias | Cartão seguinte v1.1 |
| **E4 — Feed de Vagas e Detalhes** | Listagem com distância (Haversine), filtros, detalhe e candidatura | 7 dias | Cartão seguinte v1.1 |
| **E5 — Push FCM e Background** | Serviço FCM nativo, `vinculo_id`, roteamento de toques | 4 dias | Cartão seguinte v1.1 |
| **E6 — Homologação e Performance** | Prova em aparelho real (Android 9, 2 GB RAM), auditoria de bateria e TalkBack | 4 dias | Cartão seguinte v1.1 |

Subtotal do cartão `XTijdYVk` (E1+E2): **9 dias úteis** — alicerce técnico e domínio testado na
CI, sem nenhuma tela de feature ainda implementada.

## Decisões já fechadas por esta documentação

A proposta original (`docs/proposta-android.md` §9) deixava em aberto DI e cliente HTTP. Esta
documentação os fecha para efeito do alicerce do cartão `XTijdYVk`:

- **Injeção de dependência:** Koin (não Hilt) — ver `01-arquitetura-e-modulos.md` §5.
- **Cliente HTTP:** Ktor Client (não Retrofit) — ver `03-contrato-e-api.md` §1.

## Decisões ainda em aberto para o Dono

1. **Estrutura de repositório:** monorepo em subpasta `android/` (assumido como referência nesta
   documentação) vs. repositório dedicado `frila-android`.
2. **Google Play Console:** cadastro da conta de desenvolvedor institucional e segredos de upload
   no GitHub Secrets.

## Requisito não funcional de referência (RNF04)

Perfil mínimo de homologação: Android 9.0 (API 28), 2 GB de RAM, tela 720p — sem consumo
excessivo de memória nem perda de quadros na rolagem. Esse é o alvo de prova de performance do
Épico E6, não um requisito que os Épicos E1/E2 precisem validar em hardware físico.

## Preferências locais — cartão 64

`:core:preferencias` fornece `FabricaPreferencias.criar(arquivo, escopo, migracoes)` com a engine real de
Preferences DataStore e `ReplaceFileCorruptionHandler`: conteúdo corrompido é substituído por
preferências vazias, e os consumidores aplicam seus padrões na ausência de chaves. Erros de I/O
não são escondidos. Use uma instância por arquivo privado `.preferences_pb`, um escopo com o
ciclo de vida apropriado e somente dados não sensíveis; sessão continua no armazenamento seguro.

A dependência nova `androidx.datastore:datastore-preferences-core:1.1.1` implementa o pedido do
cartão sem exigir atualização do Kotlin 2.0.20, do AGP ou de outros módulos. É a variante JVM do
Preferences DataStore, [documentada pelo Android](https://developer.android.com/jetpack/androidx/releases/datastore).
O app injeta uma instância por processo, com escopo de I/O encerrado pelo Koin. O adaptador
Android usa também `androidx.datastore:datastore-preferences:1.1.1` para a
[migração oficial](https://developer.android.com/reference/androidx/datastore/preferences/SharedPreferencesMigrationKt).
Migra as três chaves de `preferencias_filtros_vagas` antes da primeira leitura para
`files/datastore/filtros.preferences_pb`, preserva valores já existentes no DataStore e remove
as chaves antigas após gravar com sucesso. Leituras/escritas do feed são suspensas; a restauração
tem prazo de 2 segundos e as gravações respeitam a ordem das interações, sem bloquear a UI.

Notificações permanecem em `preferencias_notificacoes`: pendência **depende do #527**, por decisão
do Orquestrador no N-021, para não colidir com o PR de outra pessoa. Nenhuma mudança em
`ProcessadorDePush` nem no teste dele. Sessão/biometria continuam criptografadas no armazenamento
seguro e não fazem parte desta migração. O cartão 64 permanece parcial por causa das notificações.

Prova local (JDK 17): `cd android && ./gradlew :core:preferencias:testDebugUnitTest :feature:vagas:testDebugUnitTest :app:testDebugUnitTest`.
Os testes usam a engine DataStore com arquivos temporários reais e escopos encerrados entre
instâncias. `MigracaoPreferenciasTest` exercita SharedPreferences do Robolectric, migração,
reabertura sem duplicação, persistência/limpeza e corrupção. Nenhum emulador é necessário.
