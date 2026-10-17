# Checklist Oficial de Conformidade com as Diretrizes da App Store (Cartão 5Lx5v39r)

**Data:** 15/10/2026  
**Cartão Trello:** [5Lx5v39r](https://trello.com/c/5Lx5v39r) (S3 · QA · Regressão final e checklist das diretrizes da App Store)  
**Escopo:** Mapeamento integral das **Diretrizes de Revisão da App Store (App Store Review Guidelines)** contra o código-fonte (`iOS/Sources/`), testes automatizados (`iOS/Tests/`), documentos normativos (`iOS/Docs/`) e PRs entregues pelo time (#298, #299, #300, #301, #302).

---

## 1. Matriz Consolidada de Conformidade por Diretriz

| Diretriz Apple | Tema / Requisito | Evidência no Código (`iOS/Sources/`) | Evidência nos Testes (`iOS/Tests/`) | Documentação / PR | Estado | Lacuna / Ação Necessária |
|---|---|---|---|---|:---:|---|
| **1.1 / 1.1.1** | Conteúdo Impróprio / Ofensivo | Proibição de conteúdo ofensivo e difamatório nos termos e moderação ativa. | `SegurancaDoCodigoTests.swift` | `GuiaDeVoz.md`<br>`termos.md` | **Conforme** | Nenhuma no código. |
| **1.2** | Conteúdo Gerado pelo Usuário (UGC): Denúncia e Bloqueio | `AcoesDeSeguranca.swift:20–150`<br>`SegurancaViewModel.swift:45–95` | `SegurancaUITests.swift`<br>`SegurancaViewModelTests.swift` | `FichaAppStore.md:182, 201`<br>`SegurancaEPrivacidade.md` | **Conforme** | Procedimento operacional de moderação com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (decisão do Cauê de 15/10/2026). |
| **1.2** | Termos de Serviço Aceitos no Cadastro | `TelaCadastro.swift:131–145`<br>`CadastroViewModel.swift:67–70` | `AutenticacaoTests.swift:275`<br>`EntradaECadastroBordasTests.swift` | `Classificacao18ECA.md` | **Conforme** | Checkbox obrigatório travando avanço sem aceite expresso. |
| **1.5** | Suporte ao Desenvolvedor / Contato Publicado | `PerfisDaConta.swift:390`<br>`EnderecosOficiais.swift:22` (`suportefrila@gmail.com`) | `CatalogoStringsTests.swift`<br>`AppPrivacyTests.swift:45–65` (PR #301) | `FichaAppStore.md:118`<br>PR #301 | **Pendente (aguarda merge do PR #301)** | Canal oficial in-app (`suportefrila@gmail.com`) e página pública `https://frila.netlify.app/suporte` (conforme `FichaAppStore.md:118`). Teste automatizado de URL depende do merge do PR #301. |
| **2.1** | Contas de Demonstração para App Review | `DestinoAposEntrada.swift:92–97` (`DemonstracaoContas`)<br>`EntradaViewModel.swift:37` | `AutenticacaoTests.swift:115–140`<br>`SegurancaDoCodigoTests.swift` | `FichaAppStore.md:165–188` | **Pendente (Backend/Ambiente)** | Contas demo continuam `[A DEFINIR]` na ficha da loja; depende de cartão do backend para OTP fixo e validação de credenciais de homologação/produção. |
| **2.1** | Ausência de Telas Provisórias / Placeholders | `CatalogoDesignSystem.swift` restrito a `#if DEBUG` | `SegurancaDoCodigoTests.swift:68–91`<br>`conferir-textos.sh` | `DiretrizesAppStore.md:34–43` | **Conforme** | Zero flags ou rotas de teste expostas em compilações de Release. |
| **2.3 / 2.3.1** | Metadados Precisos e Coerência de Telas | Catálogo `Localizable.xcstrings` auditado; descrições sem promessas inverificáveis. | `CatalogoStringsTests.swift`<br>`conferir-textos.sh` | `FichaAppStore.md:11–108`<br>`GuiaDeVoz.md` | **Conforme** | Nenhuma menção a "comissão", "em minutos" ou contagem de toques. |
| **2.3.7** | Nome, Subtítulo e Palavras-chave | Nome: 21 caracteres (`Frila: Turnos e Vagas`); Subtítulo: 25 caracteres; Keywords: 97 bytes. | `conferir-textos.sh` | `FichaAppStore.md:11, 31–53` | **Conforme** | Sem palavras proibidas ("grátis", "free"), sem marcas de concorrentes (pós-PR #312). |
| **3.1.1 / 3.1.3(e)** | In-App Purchase (IAP) Dispensado (Serviços fora do app) | Intermediação de serviços no mundo físico (bares/eventos) com pagamento direto no local; o Frila não cobra comissão sobre o turno (RN01). Exceção expressa da Diretriz 3.1.3(e). | `MinhasVagasTests.swift`<br>`TurnoContrato0231Tests.swift` | `FichaAppStore.md:17`<br>`termos.md` | **Conforme** | App 100% gratuito para download e uso na versão 1.0; sem compras internas. |
| **4.0 / 4.2** | Design Nativo, Acessibilidade e Alvo de Toque | Layouts adaptativos SwiftUI, Dynamic Type, Reduzir Movimento, alvos $\ge$ 44x44 pt. | `AcessibilidadeEstadoECorTests.swift`<br>`AuditoriaDeAcessibilidadeUITests.swift`<br>`conferir-movimento.sh` | `Acessibilidade.md`<br>PR #298 | **Pendente (aguarda merge do PR #298 e teste em aparelho)** | Alvos $\ge$ 44x44 pt, rótulos e Dynamic Type cobertos por testes automatizados (PR #298); pendente de merge do PR #298 e de teste manual com VoiceOver ativo em aparelho físico (conforme `Acessibilidade.md`). |
| **4.2** | Padrões de Estado e Resiliência Geográfica | `EstadoCarregando`, `EstadoVazio`, `EstadoErro`, `EstadoOffline`, `EstadoPendente`. | `PadroesDeEstadoTests.swift`<br>`ModoAviaoUITests.swift` | `PadroesDeEstado.md`<br>PR #300 | **Conforme** | Acesso ao feed, acompanhamento e check-in manual garantido fora do DF / sem GPS. |
| **5.1.1(i)** | Política de Privacidade no App e na Ficha | `EnderecosOficiais.swift:21`<br>`PerfisDaConta.swift:415–429` | `AppPrivacyTests.swift:45–65` (PR #301) | `FichaAppStore.md:120`<br>`AppPrivacyAppStoreConnect.md`<br>PR #301 | **Pendente (aguarda merge do PR #301)** | Página pública `https://frila.netlify.app/privacidade` cadastrada na ficha (com `https://frila.app/privacidade` respondendo HTTP 200). Validação automatizada depende do merge do PR #301. |
| **5.1.1(v)** | Exclusão de Conta In-App (Account Deletion) | `TelaExclusaoDeConta.swift`<br>`PerfisDaConta.swift:201, 306`<br>`SaidaDaConta.swift` | `ExclusaoDeContaUITests.swift`<br>`LimpezaAposExclusaoTests.swift` | `AuditoriaExclusaoDeConta.md`<br>`DiretrizesAppStore.md:64–73` | **Conforme** | Exclusão direta no nível raiz em ambos os perfis, confirmação em duas etapas e expurgo local auditados; pendente validação ponta a ponta com a API do servidor. |
| **5.1.1(iii)** | Minimização de Dados e Permissões Opcionais | Push e Localização solicitados no momento oportuno; fallback manual completo. | `PresencaUITests.swift`<br>`PermissaoDePushTests.swift` | `Push.md`<br>`SegurancaEPrivacidade.md` | **Conforme** | O app opera plenamente mesmo se push e localização forem negados (Diretriz 5.1.1(iii)). |
| **5.1.2** | Manifesto de Privacidade e Sem Rastreamento | `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, array de domínios vazio, 11 tipos funcionais. | `conferir-release.sh`<br>`AppPrivacyTests.swift:15–44` (PR #301) | `AppPrivacyAppStoreConnect.md`<br>PR #301 | **Pendente (aguarda merge do PR #301)** | Manifesto configurado no código (`PrivacyInfo.xcprivacy` com `UserDefaults` / `CA92.1`, `1C8F.1`), mas laudo e testes automatizados (`AppPrivacyTests.swift`) dependem do merge do PR #301. |
| **Menores / ECA** | Restrição Rigorosa 18+ (ECA Digital) | `VerificadorDeIdadeDoSistema.swift`<br>`CadastroViewModel.swift:72–89` | `MaioridadeEVerificacaoDeIdadeTests.swift`<br>`AutenticacaoTests.swift:265–305` | `Classificacao18ECA.md`<br>PR #302 | **Conforme** | Bloqueio preventivo de menores via `DeclaredAgeRange` e corte aos 18 anos civis (integrado na main via PR #302). |
| **Notificações** | Segregação e Neutralização no Push | `NotificationService.swift`<br>`VinculoDoPush.swift:68` (`FiltroDoPushPorVinculo`) | `NotificationServiceTests.swift`<br>`PushUITests.swift` | `Push.md`<br>PR #291 | **Conforme** | Neutralização do payload caso o vínculo da notificação não corresponda à sessão local. |
| **RNF16** | Ausência de Publicidade e Banners Pagos | Código isento de SDKs de monetização ou espaços patrocinados. | `SegurancaDoCodigoTests.swift`<br>`conferir-release.sh` | `SegurancaEPrivacidade.md:160`<br>`PaginaPublica/privacidade.md:42` | **Conforme** | Sem anúncios de terceiros ou promoção paga de vagas. |

---

## 2. Lacunas e Ações Não-Programáticas (Fora do Código)

As pendências identificadas não constituem falhas no código-fonte do cliente iOS, mas ações operacionais de plataforma, infraestrutura ou cadastrais no App Store Connect:

1. **Contas de Demonstração em Homologação / Produção (Diretriz 2.1):**
   - **Responsável:** Lead Técnico / Cauê.
   - **Ação:** Definição dos e-mails oficiais de revisão e suporte ao mecanismo de OTP fixo no backend (atualmente marcados como `[A DEFINIR]` na `FichaAppStore.md:165–188`), além de semear os dados de teste (vagas e turnos no DF).
2. **Preenchimento Manual no App Store Connect (Diretrizes 2.3 e 5.1.2):**
   - **Responsável:** Dono da conta Apple / Cauê.
   - **Ação:** Inserção dos metadados textuais (`FichaAppStore.md`), questionário de classificação 18+ (`Classificacao18ECA.md`) e declaração de dados do App Privacy (`AppPrivacyAppStoreConnect.md`).
3. **Validação do Parecer Formal dos Mentores (ECA Digital / Maioridade):**
   - **Responsável:** João Paulo / Cauê.
   - **Ação:** Ratificação formal pelos mentores da Academy da suficiência do mecanismo híbrido de autodeclaração registrada com fallback seguro da `DeclaredAgeRange`.
4. **Criação e Habilitação de App Group no Apple Developer Portal (Push Extension):**
   - **Responsável:** Dono da conta Apple (João Paulo).
   - **Ação:** Criar o grupo `group.com.frila.org.app` no Developer Portal e habilitá-lo nos App IDs do aplicativo principal e da Notification Service Extension.

---

## 3. Síntese de Auditoria e Prontidão para Submissão

O cliente iOS (`frila-frontend`) apresenta conformidade técnica verificada em testes automatizados e análises estáticas, restando a conclusão dos merges pendentes e validações operacionais/físicas:
- **Exclusão de conta in-app (5.1.1(v)):** Fluxo implementado na interface e limpeza de resíduos locais auditada via testes (`ExclusaoDeContaUITests.swift`, `LimpezaAposExclusaoTests.swift`, `AuditoriaExclusaoDeConta.md`), pendente de validação ponta a ponta com a API do servidor;
- **Privacidade e Manifesto (5.1.2):** Manifesto `PrivacyInfo.xcprivacy` configurado com `NSPrivacyTracking = false` e APIs de motivo obrigatório justificadas; laudo e testes automatizados estruturados no PR #301 (`AppPrivacyTests.swift`);
- **Maioridade 18+ (ECA Digital):** Mecanismo de corte com autodeclaração e integração com `DeclaredAgeRange` validado em testes unitários (`MaioridadeEVerificacaoDeIdadeTests.swift`, `AutenticacaoTests.swift:265–305`, integrado via PR #302);
- **Acessibilidade e Usabilidade (4.0 / 4.2):** Alvos de toque $\ge 44 \times 44$ pt, rótulos e suporte a Dynamic Type/Reduzir Movimento verificados via scripts e testes automatizados (`conferir-movimento.sh`, `AcessibilidadeEstadoECorTests.swift`, PR #298), pendente de teste manual com VoiceOver ativo em aparelho físico (conforme `Acessibilidade.md`);
- **Resiliência e Ausência de IAP (3.1.3(e) / 4.2):** Operação e resiliência offline validadas em testes (`PadroesDeEstadoTests.swift`), com enquadramento de liquidação física no local sem cobrança de comissão (RN01), dispensando IAP conforme a Diretriz 3.1.3(e).
