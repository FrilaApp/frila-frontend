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
