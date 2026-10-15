# Checklist Oficial de Conformidade com as Diretrizes da App Store (Cartão 5Lx5v39r)

**Data:** 15/10/2026  
**Cartão Trello:** [5Lx5v39r](https://trello.com/c/5Lx5v39r) (S3 · QA · Regressão final e checklist das diretrizes da App Store)  
**Escopo:** Mapeamento integral das **Diretrizes de Revisão da App Store (App Store Review Guidelines)** contra o código-fonte (`iOS/Sources/`), testes automatizados (`iOS/Tests/`), documentos normativos (`iOS/Docs/`) e PRs entregues pelo time (#298, #299, #300, #301, #302).

---

## 1. Matriz Consolidada de Conformidade por Diretriz

| Diretriz Apple | Tema / Requisito | Evidência no Código (`iOS/Sources/`) | Evidência nos Testes (`iOS/Tests/`) | Documentação / PR | Estado | Lacuna / Ação Necessária |
|---|---|---|---|---|:---:|---|
| **1.1 / 1.1.1** | Conteúdo Impróprio / Ofensivo | Proibição de conteúdo ofensivo e difamatório nos termos e moderação ativa. | `SegurancaDoCodigoTests.swift` | `GuiaDeVoz.md`<br>`termos.md` | **Conforme** | Nenhuma no código. |
| **1.2** | Conteúdo Gerado pelo Usuário (UGC): Denúncia e Bloqueio | `AcoesDeSeguranca.swift:20–150`<br>`SegurancaViewModel.swift:45–95` | `SegurancaUITests.swift`<br>`SegurancaViewModelTests.swift` | `FichaAppStore.md:201`<br>`SegurancaEPrivacidade.md` | **Conforme** | Procedimento operacional de triagem em até 24 h pela equipe humana (homologado pelo Cauê). |
| **1.2** | Termos de Serviço Aceitos no Cadastro | `TelaCadastro.swift:131–145`<br>`CadastroViewModel.swift:67–70` | `AutenticacaoTests.swift:275`<br>`EntradaECadastroBordasTests.swift` | `Classificacao18ECA.md` | **Conforme** | Checkbox obrigatório travando avanço sem aceite expresso. |
| **1.5** | Suporte ao Desenvolvedor / Contato Publicado | `PerfisDaConta.swift:390`<br>`EnderecosOficiais.swift:22` (`suportefrila@gmail.com`) | `AppPrivacyTests.swift:45–65`<br>`CatalogoStringsTests.swift` | `FichaAppStore.md:118`<br>PR #301 | **Conforme** | Canal oficial in-app e página pública `https://frila.app/suporte`. |
| **2.1** | Contas de Demonstração para App Review | `DemonstracaoContas.swift:10–40`<br>`EntradaViewModel.swift:55–75` | `AutenticacaoTests.swift:115–140`<br>`SegurancaDoCodigoTests.swift` | `FichaAppStore.md:165–188` | **Pendente (Ambiente)** | Validação das credenciais fixas no ambiente de homologação (`DECISOES.md`). |
| **2.1** | Ausência de Telas Provisórias / Placeholders | `CatalogoDesignSystem.swift` restrito a `#if DEBUG` | `SegurancaDoCodigoTests.swift:68–91`<br>`conferir-textos.sh` | `AUDITORIA-ios.md:30–37` | **Conforme** | Zero flags ou rotas de teste expostas em compilações de Release. |
| **2.3 / 2.3.1** | Metadados Precisos e Coerência de Telas | Catálogo `Localizable.xcstrings` auditado; descrições sem promessas inverificáveis. | `CatalogoStringsTests.swift`<br>`conferir-textos.sh` | `FichaAppStore.md:11–108`<br>`GuiaDeVoz.md` | **Conforme** | Nenhuma menção a "comissão", "em minutos" ou contagem de toques. |
| **2.3.7** | Nome, Subtítulo e Palavras-chave | Nome: 28 caracteres; Subtítulo: 25 caracteres; Keywords: 97 bytes. | `conferir-textos.sh` | `FichaAppStore.md:31–53` | **Conforme** | Sem palavras proibidas ("grátis", "free"), sem marcas de concorrentes. |
| **3.1.1 / 3.1.5** | In-App Purchase (IAP) N/A | Intermediação de serviços no mundo físico (bares/eventos) com pagamento direto no local (RN01). Exceção expressa da Diretriz 3.1.5(a). | `MinhasVagasTests.swift`<br>`TurnoContrato0231Tests.swift` | `FichaAppStore.md:17`<br>`termos.md` | **Conforme** | App 100% gratuito para download e uso na versão 1.0; sem compras internas. |
| **4.0 / 4.2** | Design Nativo, Acessibilidade e Alvo de Toque | Layouts adaptativos SwiftUI, Dynamic Type, Reduzir Movimento, alvos $\ge$ 44x44 pt. | `AcessibilidadeEstadoECorTests.swift`<br>`conferir-movimento.sh` | `Acessibilidade.md`<br>PR #298 | **Conforme** | Nenhum estado usa exclusivamente cor; VoiceOver completo em todas as telas. |
| **4.2** | Padrões de Estado e Resiliência Geográfica | `EstadoCarregando`, `EstadoVazio`, `EstadoErro`, `EstadoOffline`, `EstadoPendente`. | `PadroesDeEstadoTests.swift`<br>`ModoAviaoUITests.swift` | `PadroesDeEstado.md`<br>PR #300 | **Conforme** | Acesso ao feed, acompanhamento e check-in manual garantido fora do DF / sem GPS. |
| **5.1.1(i)** | Política de Privacidade no App e na Ficha | `EnderecosOficiais.swift:21`<br>`PerfisDaConta.swift:415–429` | `AppPrivacyTests.swift:45–65` | `AppPrivacyAppStoreConnect.md`<br>PR #301 | **Conforme** | Link `https://frila.app/privacidade` respondendo HTTP 200 em HTTPS. |
| **5.1.1(v)** | Exclusão de Conta In-App (Account Deletion) | `TelaExclusaoDeConta.swift`<br>`PerfisDaConta.swift:201, 306`<br>`SaidaDaConta.swift` | `ExclusaoDeContaUITests.swift`<br>`LimpezaAposExclusaoTests.swift` | `AuditoriaExclusaoDeConta.md`<br>`DiretrizesAppStore.md:64–73` | **Conforme** | Exclusão direta no nível raiz em ambos os perfis, confirmação em duas etapas e expurgo local. |
| **5.1.2(i)** | Minimização de Dados e Permissões Opcionais | Push e Localização solicitados no momento oportuno; fallback manual completo. | `PresencaUITests.swift`<br>`PermissaoDePushTests.swift` | `Push.md`<br>`SegurancaEPrivacidade.md` | **Conforme** | O app opera plenamente mesmo se push e localização forem negados. |
| **5.1.2** | Manifesto de Privacidade e Sem Rastreamento | `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, array de domínios vazio, 11 tipos funcionais. | `AppPrivacyTests.swift:15–44`<br>`conferir-release.sh` | `AppPrivacyAppStoreConnect.md`<br>PR #301 | **Conforme** | Declaração exata de APIs de motivo obrigatório (`UserDefaults` / `CA92.1`, `1C8F.1`). |
| **Menores / ECA** | Restrição Rigorosa 18+ (ECA Digital) | `VerificadorDeIdadeDoSistema.swift`<br>`CadastroViewModel.swift:72–89` | `MaioridadeEVerificacaoDeIdadeTests.swift`<br>`AutenticacaoTests.swift:265–305` | `Classificacao18ECA.md`<br>PR #302 | **Conforme** | Bloqueio preventivo de menores via `DeclaredAgeRange` e corte aos 18 anos civis. |
| **Notificações** | Segregação e Neutralização no Push | `NotificationService.swift`<br>`FiltroDoPushPorVinculo.swift` | `NotificationServiceTests.swift`<br>`PushUITests.swift` | `Push.md`<br>PR #291 | **Conforme** | Neutralização do payload caso o vínculo da notificação não corresponda à sessão local. |
| **RNF16** | Ausência de Publicidade e Banners Pagos | Código isento de SDKs de monetização ou espaços patrocinados. | `SegurancaDoCodigoTests.swift`<br>`conferir-release.sh` | `AUDITORIA-ios.md:82–89` | **Conforme** | Sem anúncios de terceiros ou promoção paga de vagas. |

---

## 2. Lacunas e Ações Não-Programáticas (Fora do Código)

As pendências identificadas não constituem falhas no código-fonte do cliente iOS, mas ações operacionais de plataforma ou jurídico registradas em `DECISOES.md`:

1. **Contas de Demonstração em Produção / Homologação (Diretriz 2.1):**
   - **Responsável:** Lead Técnico / Cauê.
   - **Ação:** Criação no Supabase das contas `demo-profissional@frila.app` e `demo-contratante@frila.app` com código OTP fixo e dados pré-semeados (vagas abertas e turnos agendados no Plano Piloto).
2. **Preenchimento Manual no App Store Connect (Diretrizes 2.3 e 5.1.2):**
   - **Responsável:** Dono da conta Apple / Cauê.
   - **Ação:** Inserção dos metadados textuais (`FichaAppStore.md`), questionário de classificação 18+ (`Classificacao18ECA.md`) e declaração de dados do App Privacy (`AppPrivacyAppStoreConnect.md`).
3. **Validação do Parecer Formal dos Mentores (ECA Digital / Maioridade):**
   - **Responsável:** João Paulo / Cauê.
   - **Ação:** Ratificação formal pelos mentores da Academy da suficiência do mecanismo híbrido de autodeclaração registrada com fallback seguro da `DeclaredAgeRange`.
4. **Habilitação de App Group no Apple Developer Portal (Push Extension):**
   - **Responsável:** Dono da conta Apple (João Paulo).
   - **Ação:** Conferência da associação do grupo `group.com.frila.org.app` aos App IDs de distribuição.

---

## 3. Síntese de Auditoria e Prontidão para Submissão

O cliente iOS (`frila-frontend`) atende integralmente aos requisitos técnicos das Diretrizes de Revisão da App Store:
- **Exclusão de conta in-app:** 100% implementada e testada conforme a Diretriz 5.1.1(v);
- **Privacidade e Manifesto:** 100% em conformidade com a Diretriz 5.1.2 (`NSPrivacyTracking = false`, APIs justificadas);
- **Maioridade 18+:** Mecanismo preventivo de corte e integração com a API `DeclaredAgeRange` do iOS 26.2+;
- **Acessibilidade e Usabilidade:** 100% de conformidade com padrões de alvo de toque, VoiceOver e redução de movimento;
- **Resiliência e Ausência de IAP:** Operação sem conexão e aderência ao modelo de liquidação física fora do app.
