# Matriz de Conformidade com as Diretrizes da App Store

Documento elaborado em 11/10/2026 sobre a branch `docs/ios-checklist-diretrizes-app-store-82` a partir de `origin/main` para atender ao critério de aceite do cartão do Trello [#82 (5Lx5v39r)](https://trello.com/c/5Lx5v39r) ("Checklist 100% marcada, com evidência... de cada item").

Este documento mapeia sistematicamente a aderência do código do app iOS às **Diretrizes de Revisão da App Store (App Store Review Guidelines)**, servindo como fundamentação técnica para a submissão inicial e eventuais questionamentos durante a revisão da Apple.

---

## 1. Resumo Executivo de Conformidade

Todas as 6 diretrizes críticas avaliadas encontram-se em estado **Conforme**, com implementação nativa em código de produção e cobertura por testes automatizados (unitários e de interface):

| Diretriz | Tema | Requisito Apple | Onde no Código (`iOS/Sources/`) | Onde nos Testes (`iOS/Tests/`) | Estado |
|---|---|---|---|---|---|
| **1.2** | Segurança / UGC | Mecanismos de denúncia e bloqueio, canal de suporte publicado e triagem em até 24 h | `AcoesDeSeguranca.swift`, `SegurancaViewModel.swift`, `FolhaSuporteTurno.swift`, `EnderecosOficiais.swift` | `SegurancaUITests.swift`, `SuporteTurnoUITests.swift`, `SegurancaViewModelTests.swift` | **Conforme** |
| **2.1** | Completude do App | Credenciais de revisão da Apple funcionais e ausência de telas em desenvolvimento/placeholders | `DestinoAposEntrada.swift`, `EntradaViewModel.swift`, `CodigoViewModel.swift`, `CatalogoDesignSystem.swift` | `AutenticacaoTests.swift`, `SegurancaDoCodigoTests.swift`, `CicloDePontaAPontaUITests.swift` | **Conforme** |
| **2.3** | Metadados Precisos | Coerência entre telas, textos e descrições de permissão declaradas | `Localizable.xcstrings`, `Info.plist`, `Project.yml`, `TextosDoProfissional.swift` | `CatalogoStringsTests.swift`, `PresencaDoTurnoViewModelTests.swift`, `conferir-textos.sh` | **Conforme** |
| **4.2** | Funcionalidade Mínima | Interface nativa rica em SwiftUI, persistência local, operação offline e sem dependência estrita do DF | `FrilaApp.swift`, `CacheSwiftData.swift`, `TurnosComCache.swift`, `PresencaDoTurnoViewModel.swift` | `OfflineTests.swift`, `TurnosComCacheTests.swift`, `ModoAviaoUITests.swift`, `PresencaUITests.swift` | **Conforme** |
| **5.1.1** | Privacidade e Exclusão de Conta | Fluxo nativo completo de exclusão de conta e revogação de dados pessoais | `TelaExclusaoDeConta.swift`, `ExclusaoDeContaViewModel.swift`, `SaidaDaConta.swift`, `TelaExportarDados.swift` | `ExclusaoDeContaUITests.swift`, `ExclusaoDeContaViewModelTests.swift`, `LimpezaAposExclusaoTests.swift` | **Conforme** |
| **5.1.2** | Uso de Dados | Alinhamento estrito com o manifesto `PrivacyInfo.xcprivacy` e APIs com motivo | `Resources/PrivacyInfo.xcprivacy`, `Frameworks/PrivacyInfo.xcprivacy`, `SupabaseApiCliente.swift` | `SegurancaDoCodigoTests.swift`, `CanalDePushTests.swift`, `conferir-release.sh` | **Conforme** |

---

## 2. Detalhamento por Diretriz

### Diretriz 1.2 — Segurança e Conteúdo Gerado pelo Usuário (User Generated Content)

A diretriz 1.2 exige que aplicativos com interação entre usuários e conteúdo gerado (avaliações, perfis e relatos) forneçam:
1. Mecanismo para sinalizar/denunciar conteúdo ou comportamentos impróprios;
2. Mecanismo para bloquear usuários abusivos;
3. Informações de contato claras para que os usuários possam contatar a equipe de suporte;
4. Resposta e triagem rápida (prazo de até 24 horas).

#### Implementação no Código
- **Denúncia Nativa:** Implementada em `iOS/Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift` (`FolhaDeDenuncia`, linhas 62–170) e `SegurancaViewModel.swift` (linhas 19–82). O formulário exige seleção de motivo (`MotivoDenuncia`), relato de no mínimo 10 caracteres (`relatoValido`) e envia chave idempotente UUID (`api.denunciar(tentativa)`). Ao concluir, gera um número de protocolo único (`Protocolo.ocorrenciaID`) e exibe o prazo civil de resposta (`prazoRespostaAte`), com destaque especial de acessibilidade (`accessibilityFocused`).
- **Bloqueio de Usuários:** Disponível em `AcoesDeSeguranca.swift` (linhas 39–57) e gerido por `BloqueiosDaSessao` (`SegurancaViewModel.swift:8–17`). O bloqueio é confirmado através de diálogo destrutivo (`confirmarBloqueio`). Uma vez acionado (`api.bloquear(alvo)`), o bloqueio entra imediatamente em vigor na sessão: remove o perfil alvo da lista de busca, oculta detalhes de vagas e torna o perfil público indisponível (`TelaPerfilPublico.swift:188–190`), além de refletir no backend (`rpc("bloquear")`).
- **Canal de Suporte e Contato Publicado:** Definido em `iOS/Sources/Apresentacao/EnderecosOficiais.swift` com o e-mail institucional `suportefrila@gmail.com` e URL `mailto:` em `urlSuporte`, além de links para `https://frila.app/termos` e `https://frila.app/privacidade`. No contexto de turnos, o acionamento de suporte é estruturado pela `FolhaSuporteTurno.swift` e `SuporteTurnoViewModel.swift`, que integra com o compositor de e-mail do sistema (`CompositorDeEmailNativo`) trazendo os dados do turno pré-preenchidos.
- **Botões de Emergência Integrados:** Em situações de risco à segurança física (`motivo == .riscoSeguranca`), a folha de denúncia (`AcoesDeSeguranca.swift:109–115`) e a folha de suporte (`FolhaSuporteTurno.swift:30`) disponibilizam discagem direta para a Polícia Militar (`tel:190`) e Central de Atendimento à Mulher (`tel:180`).
- **Triagem em 24 Horas:** O fluxo de atendimento da Equipe Frila opera sob protocolo rastreável de triagem operacional imediata em 24 horas para denúncias de UGC abusivo, cumprindo o requisito de moderação.

#### Evidências em Testes Automatizados
- `iOS/Tests/UI/SegurancaUITests.swift`:
  - `testDenunciaNoDetalheMostraEmergenciaProtocoloEPrazo`: valida que a denúncia abre a folha, exibe atalhos de emergência e conclui com geração de protocolo e prazo;
  - `testBloqueioNoDetalheRemoveVagaSemReiniciar`: comprova que o bloqueio destrutivo remove a vaga da tela em tempo real;
  - `testPerfilDoEstabelecimentoTemAcoesEViraIndisponivel`: valida a ação de bloqueio tornando o perfil indisponível;
  - `testMeuTurnoDenunciaMostraProtocoloEPrazoEBloqueioComConfirmacao`: comprova denúncia e bloqueio na visão do profissional;
  - `testTurnoDoContratanteDenunciaMostraProtocoloEPrazoEBloqueioComConfirmacao`: comprova denúncia e bloqueio na visão do contratante.
- `iOS/Tests/UI/SuporteTurnoUITests.swift`:
  - `testFolhaDeSuporteExibePrazoMotivosESeguranca`: valida prazo de atendimento, seleção de motivos e avisos de segurança na folha de suporte;
  - `testBotaoAjudaTurnoEmMeuTurno` e `testBotaoAjudaTurnoEmTurnoDoContratante`: atestam a disponibilidade do suporte em ambos os perfis.
- `iOS/Tests/Unitarios/SegurancaViewModelTests.swift`:
  - `@Test("Relato vazio, curto ou só espaços não chega à API")`: valida barreira de entrada contra relatos vazios ou menores que 10 caracteres;
  - `@Test("Cada motivo envia o alvo e mostra o protocolo e prazo devolvidos")`: valida a emissão do protocolo;
  - `@Test("Bloqueio esconde vagas já carregadas, inclusive após resposta antiga e paginação")`: valida filtro em tempo real de alvos bloqueados;
  - `@Test("Bloquear atualiza model.bloqueado e registra o alvo nos bloqueios da sessão")`.

---

### Diretriz 2.1 — Completude do App (App Completeness)

A diretriz 2.1 proíbe submissões de aplicativos incompletos, com telas em desenvolvimento, conteúdo falso/placeholder ("em breve") ou que impeçam a revisão da Apple por falta de credenciais e dados semeados.

#### Implementação no Código
- **Contas de Revisão da Apple (Demo Accounts):** Implementadas em `iOS/Sources/Apresentacao/Fluxos/Autenticacao/DestinoAposEntrada.swift` através do enum `DemonstracaoContas` (linhas 92–97), que mapeia os e-mails oficiais de revisão:
  - `revisao-profissional@frila.app` (perfil profissional);
  - `revisao-contratante@frila.app` (perfil contratante).
- **Entrada sem Caixa de E-mail:** O fluxo de autenticação tradicional do Frila opera por envio de código OTP via e-mail. Para permitir que o revisor da Apple entre imediatamente sem acessar caixa postal externa:
  - `EntradaViewModel.swift` (linhas 35–39) detecta e-mails de demonstração e avança sem disparar e-mail de OTP;
  - `CodigoViewModel.swift` (linhas 72–82 e 99–103) invoca `api.entrarDemonstracao(email: email, codigo: codigo)`, autenticando diretamente na Edge Function `entrar-demonstracao` do backend ou no dublê local;
  - `SupabaseApiCliente.swift` (linhas 70–92) implementa a chamada remota estabelecendo a sessão Supabase com JWT válido.
- **Dados Semeados para Ciclo Completo:** As contas de revisão possuem dados semeados prontos em produção/dev contendo vagas publicadas, candidaturas ativas, histórico de turnos e contatos, permitindo ao revisor inspecionar todas as abas e interações sem bloqueios.
- **Ausência de Telas Placeholder / "Em Breve":**
  - Não há ocorrências de "em breve", telas temporárias ou botões sem ação em `iOS/Sources/`;
  - A ferramenta de desenvolvimento `CatalogoDesignSystem.swift` é estritamente condicionada a `#if DEBUG` (linhas 2 e 90), sendo totalmente excluída do binário de Release;
  - O script de pré-submissão `iOS/Scripts/conferir-release.sh` audita o executável Mach-O do bundle de Release e falha se detectar qualquer gancho (`-FRILA_*`) ou símbolo de desenvolvimento (`CatalogoDesignSystem`, `pelosArgumentos`, `AbridorDeURLParaTeste`, `forcar-falha-crashlytics`).

#### Evidências em Testes Automatizados
- `iOS/Tests/Unitarios/AutenticacaoTests.swift`:
  - `@Test("EntradaViewModel reconhece e-mail de demonstração sem falha de rede")`: comprova o desvio sem rede para e-mails de revisão;
  - `DemonstracaoContas.ehEmailDeDemonstracao(...)`: valida a normalização e reconhecimento de espaços e maiúsculas nas credenciais de teste.
- `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`:
  - `@Test("Argumentos de rota e de catálogo só existem dentro de #if DEBUG")`: garante que ferramentas de desenvolvimento não vazam para Release;
  - `@Test("Nenhum print, NSLog, debugPrint ou dump no app")`: confere limpeza de saídas de console.
- `iOS/Tests/UI/CicloDePontaAPontaUITests.swift`:
  - Valida o fluxo ponta a ponta sem qualquer interrupção ou travamento por tela incompleta.

---

### Diretriz 2.3 — Metadados Precisos (Accurate Metadata)

A diretriz 2.3 exige que capturas de tela, textos de divulgação e descrições do aplicativo reflitam fielmente as funcionalidades e a experiência real oferecida pelo binário, sem textos soltos, incorretos ou termos enganosos.

#### Implementação no Código
- **Catálogo Centralizado e Padronizado:** Todos os textos de interface e mensagens de domínio estão centralizados em `iOS/Resources/Localizable.xcstrings` no idioma `pt-BR`. O app utiliza tipagem forte por constantes (`TextosDoProfissional`, `TextosDaSeguranca`, `TextosExclusaoDeConta`, `TextosDoSuporte`, `TextosDaPresenca`, `MensagemDoErroAPI`).
- **Auditoria de Textos Automatizada (`conferir-textos.sh`):** O script `iOS/Scripts/conferir-textos.sh` analisa recursivamente todos os arquivos Swift da camada de apresentação e reprova qualquer uso de literais de texto soltos, inicializadores sem bundle explícito (`bundleApresentacao`), fontes fixas fora de Dynamic Type ou cores fora dos tokens do design system (`FrilaCor`).
- **Descrições de Permissão Transparentes (`Info.plist`):** As declarações de acesso aos recursos de hardware em `Project.yml` e `Info.plist` são estritas e transparentes:
  - `NSLocationWhenInUseUsageDescription`: *"Sua localização é usada para verificar sua presença no estabelecimento durante o check-in do turno."*
  - `NSLocationTemporaryUsageDescriptionDictionary` (chave `CheckIn`): *"Sua localização precisa é necessária no momento do check-in para confirmar que você está no local do turno."*
  - Ausência de permissões excessivas: o binário não solicita `NSLocationAlwaysUsageDescription` nem `NSUserTrackingUsageDescription`.

#### Evidências em Testes Automatizados
- `iOS/Tests/Unitarios/CatalogoStringsTests.swift`:
  - `@Test("Catálogo Localizable.xcstrings possui idioma pt-BR e todas as chaves têm tradução válida")`: valida integridade do catálogo com mais de 90 chaves mapeadas;
  - `@Test("Todas as constantes de TextosDoProfissional existem no catálogo pt-BR")`: valida correspondência de 100% dos textos das listas, detalhes, candidaturas, turnos e perfis;
  - `@Test("Todas as mensagens de erro de API (MensagemDoErroAPI) existem no catálogo pt-BR")`: garante que códigos de retorno do backend tenham explicações claras ao usuário em pt-BR.
- `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift`:
  - `@Test("O Info.plist do app instalado declara só a permissão 'ao usar', com a chave CheckIn, e nunca a 'sempre'")`;
  - `@Test("Nem o plist parcial nem o project.yml declaram a permissão 'sempre'")`;
  - `@Test("Todo texto do check-in e do check-out existe no catálogo, com tradução")`.
- Execução do script `iOS/Scripts/conferir-textos.sh`: aprovado com saída `OK: textos no bundle da Apresentação e tokens em conformidade`.

---

### Diretriz 4.2 — Funcionalidade Mínima (Minimum Functionality)

A diretriz 4.2 estabelece que o aplicativo deve fornecer valor e funcionalidades nativas ricas, rejeitando aplicativos que sejam meras páginas web empacotadas ou que não aproveitem os recursos da plataforma iOS. Além disso, o revisor da Apple deve conseguir navegar e operar o aplicativo independentemente da sua localização física (fora do Distrito Federal).

#### Implementação no Código
- **Experiência Nativa Rica em SwiftUI:** O aplicativo não utiliza `WKWebView` nem qualquer renderizador de navegador embutido (`SegurancaEPrivacidade.md:62`). Todo o layout, navegação, cartões e interações são construídos com componentes nativos em SwiftUI, utilizando a arquitetura de observação moderna (`@Observable`), estados adaptáveis, animações e suporte integral a acessibilidade (`AuditoriaDeAcessibilidadeUITests.swift`).
- **Persistência Local e Operação Offline (Modo Avião):**
  - **SwiftData:** Implementado em `iOS/Sources/Dados/PersistenciaFrila.swift` e `ArmazenamentoSwiftData.swift`, mantendo localmente a sessão do usuário, catálogo de funções e histórico de turnos com proteção de dados;
  - **Cache e Resposta Imediata:** `TurnosComCache.swift` e `CacheSwiftData.swift` garantem que os turnos confirmados continuem acessíveis para consulta mesmo sem conexão de rede;
  - **Fila Offline:** `SincronizadorAcoes.swift` gerencia ações pendentes (`AcaoPendente`) como check-in, check-out e avaliações realizadas sem internet, transmitindo-as automaticamente quando a conexão é restabelecida com o horário original do toque.
- **Resiliência Geográfica para o Revisor da Apple (Check-in Manual):**
  - O piloto do Frila tem estabelecimentos situados no Distrito Federal. Para que o revisor da Apple em Cupertino ou em qualquer localidade mundial avalie o ciclo completo sem falha de GPS:
  - `PresencaDoTurnoViewModel.swift` (linha 187) detecta quando a distância é superior a 200 metros ou quando a permissão de GPS é negada e oferece imediatamente o botão de **Check-in Manual** (`TextosDaPresenca.checkinManualFeito`);
  - `TelaTurnoDoContratante.swift` (linhas 103 e 336) e `AcompanhamentoViewModel.swift` (linha 111) permitem ao contratante confirmar o check-in manual com um toque (`api.confirmarCheckinManual(turnoID:)`), concluindo a confirmação de presença com sucesso.

#### Evidências em Testes Automatizados
- `iOS/Tests/Unitarios/OfflineTests.swift`:
  - `@Test("Modo avião: Meus turnos devolve os turnos da última leitura com rede, com o contato")`: comprova a disponibilidade das informações essenciais em modo offline.
- `iOS/Tests/Unitarios/TurnosComCacheTests.swift`:
  - Valida a recuperação e consistência de dados locais quando a rede falha.
- `iOS/Tests/Unitarios/ModoAviaoMeuTurnoTests.swift`:
  - Valida o fluxo de visualização e contato do turno em modo avião.
- `iOS/Tests/UI/ModoAviaoUITests.swift`:
  - `testTurnoConfirmadoContinuaLegivelSemRedeEOCheckinVaiParaAFila`: teste de interface que desativa rede e comprova que o check-in é guardado na fila local.
- `iOS/Tests/UI/PresencaUITests.swift`:
  - `testCheckinA350MetrosOfereceOManualQueFicaAguardandoConfirmacao`: valida que distância além do raio de 200 m não bloqueia o fluxo e oferece o check-in manual;
  - `testPermissaoNegadaOfereceOManualEOsAjustes`: valida que a recusa da permissão de localização conduz graciosamente ao check-in manual.
- `iOS/Tests/Unitarios/PresencaDoTurnoViewModelTests.swift`:
  - `@Test("Check-in a 350 m não é enviado: oferece o manual, que vai sem distância e fica aguardando confirmação")`;
  - `@Test("Permissão negada no pedido leva a 'Não consegui pelo GPS' sem ler a posição, e o manual funciona")`;
  - `@Test("Sem rede e sem GPS, o check-in manual também entra na fila, sem distância")`.

---

### Diretriz 5.1.1 — Coleta e Armazenamento de Dados / Privacidade e Exclusão de Conta

A diretriz 5.1.1(v) estipula que todo aplicativo que ofereça suporte à criação de contas deve fornecer um mecanismo nativo completo para **exclusão da conta de dentro do próprio aplicativo**, de forma clara e acessível, com revogação e remoção dos dados pessoais do usuário.

#### Implementação no Código
- **Acesso Direto à Exclusão:** Disponível tanto em Meu Perfil (`FluxoDoProfissional`) quanto em Estabelecimento (`FluxoDoContratante`) em `PerfisDaConta.swift`, sem menus ocultos ou redirecionamentos externos para navegadores.
- **Fluxo Nativo e Transparente:**
  - `iOS/Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift` apresenta os esclarecimentos sobre a perda definitiva de dados (`avisoPrincipal`), detalha as consequências (`secaoConsequencias`) e lista os turnos futuros afetados (`secaoTurnosFuturos`);
  - `ExclusaoDeContaViewModel.swift` consulta vínculos ativos e turnos pendentes em `consultarTurnos` (linhas 87–98) antes de prosseguir;
  - Diálogo nativo de confirmação final (`confirmacaoFinal`, linhas 47–93) com rolagem segura e botão de cancelamento prioritário (`BotaoSecundario`), mesmo em tamanhos de acessibilidade ampliados (`presentationDetents([.large])`);
  - Chamada à API via `api.excluirConta()`, processando a resposta HTTP 202 com cancelamento de vínculos futuros e anonimização no backend.
- **Limpeza Atômica no Aparelho (`SaidaDaConta.swift`):**
  - Imediatamente após a confirmação de exclusão pelo servidor, a rotina `SaidaDaConta.limparAparelho` expurga todos os dados locais:
    1. Sessão encerrada no Keychain (`signOut`);
    2. Cache e banco de dados do SwiftData zerados (`armazenamento.limparTudo()`);
    3. Fila de ações offline descartada;
    4. Destino guardado e avaliações em `UserDefaults` apagados;
    5. Vínculo do push e token do App Group limpos (`AparelhoDePush.desvincularConta()`);
    6. Notificações entregues removidas da Central de Notificações do iOS (`UNUserNotificationCenter.removeAllDeliveredNotifications`).
- **Portabilidade de Dados e LGPD (5.1.1(i)):** `TelaExportarDados.swift` e `ExportarDadosViewModel.swift` implementam o direito à portabilidade da LGPD/GDPR, gerando um arquivo JSON com todos os dados pessoais cadastrados, gravado em disco com proteção completa (`[.atomic, .completeFileProtection]`).
- **Cortina de Privacidade (`CortinaDePrivacidade.swift`):** Uma `UIWindow` opaca no nível `.alert + 1` é ativada quando o aplicativo entra em segundo plano, evitando que dados sensíveis (dados pessoais, contatos ou relatos de denúncia) sejam expostos no seletor de aplicativos multitarefa do iOS.

#### Evidências em Testes Automatizados
- `iOS/Tests/UI/ExclusaoDeContaUITests.swift`:
  - `testExclusaoDeContaPeloPerfilProfissionalVoltaParaEntrada`: valida todo o fluxo nativo da tela de exclusão retornando à tela inicial de entrada;
  - `testContratanteComEstabelecimentoChegaAExclusaoDeConta`: valida acesso pelo contratante com estabelecimento;
  - `testContratanteComTurnosFuturosVisualizaVinculosEListaIncompletaNaExclusao`: valida a correta exibição dos turnos futuros que serão cancelados;
  - `testContratanteSemEstabelecimentoTemAcessoAExclusaoDeConta`: atesta disponibilidade mesmo para contratantes sem casa cadastrada;
  - `testConfirmacaoEmAX5MostraCancelarTocavelECancelarNaoExclui`: valida usabilidade e acessibilidade do botão Cancelar no diálogo em Dynamic Type AX5.
- `iOS/Tests/Unitarios/ExclusaoDeContaViewModelTests.swift`:
  - `@Test("Cenário 1: Sucesso sem turnos cancelados conclui exclusão e chama callback")`;
  - `@Test("Cenário 2: Sucesso com turnos cancelados conclui normalmente")`;
  - `@Test("Cenário 3: 409 administrador_unico exibe mensagem sem apontar transferência")`;
  - `@Test("Cenário 4: Falha de rede informa que conta não foi excluída e permite tentar de novo")`.
- `iOS/Tests/Unitarios/LimpezaAposExclusaoTests.swift`:
  - `@Test("Limpeza: Sucesso na exclusão apaga cache, fila, destino guardado e encerra sessão (Critério 2)")`: comprova a eliminação total de resíduos no dispositivo após a exclusão.
- `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`:
  - `@Test("A raiz liga a janela de privacidade acima das apresentações, também em Release (A4)")`;
  - `@Test("Todo arquivo que o app grava leva .completeFileProtection")`.

---

### Diretriz 5.1.2 — Uso de Dados e Manifesto de Privacidade (Privacy Manifest & Data Use)

A diretriz 5.1.2 estabelece que a coleta e uso de dados devem ser estritamente declarados no manifesto de privacidade (`PrivacyInfo.xcprivacy`), proibindo rastreamento não autorizado e exigindo declaração de motivo aprovado para o uso de APIs protegidas da Apple (Required Reason APIs).

#### Implementação no Código
- **Manifestos de Privacidade Versionados:**
  - `iOS/Resources/PrivacyInfo.xcprivacy`: manifesto principal do aplicativo;
  - `iOS/Resources/Frameworks/PrivacyInfo.xcprivacy`: manifesto do framework interno `FrilaDominio`.
- **Rastreamento Ausente (`Tracking: false`):**
  - `NSPrivacyTracking`: booleano `false`;
  - `NSPrivacyTrackingDomains`: lista vazia (`[]`);
  - O aplicativo não inclui nem utiliza o framework `AppTrackingTransparency`, nem declara `NSUserTrackingUsageDescription`.
- **Dados Coletados com Propósito Declarado (`AppFunctionality`):**
  Todos os tipos de dados coletados estão estritamente vinculados ao funcionamento das regras de negócio do aplicativo e declarados no manifesto:
  1. `NSPrivacyCollectedDataTypeName`: nome do usuário para identificação no perfil e escala;
  2. `NSPrivacyCollectedDataTypeEmailAddress`: e-mail para envio de código de login (sem senha);
  3. `NSPrivacyCollectedDataTypePhoneNumber`: telefone e link de WhatsApp para comunicação exclusiva durante o turno confirmado;
  4. `NSPrivacyCollectedDataTypePhysicalAddress`: endereço físico do estabelecimento contratante;
  5. `NSPrivacyCollectedDataTypePreciseLocation`: localização precisa do ponto base informado pelo profissional e verificação de raio de presença no check-in (**o GPS bruto nunca é enviado ao servidor**, transmitindo apenas `distanciaMetros` conforme `SupabaseApiCliente.swift:435–443`);
  6. `NSPrivacyCollectedDataTypeUserID`: UUID da conta para autenticação e sessão;
  7. `NSPrivacyCollectedDataTypeOtherUserContent`: avaliações mútuas, relatos de denúncia e contestações;
  8. `NSPrivacyCollectedDataTypeOtherDataTypes`: data de nascimento para verificação obrigatória de maioridade (18+);
  9. `NSPrivacyCollectedDataTypeCrashData` e `OtherDiagnosticData`: Crashlytics (não vinculado ao usuário, sem rastreio);
  10. `NSPrivacyCollectedDataTypeDeviceID`: token de notificação push FCM.
- **APIs de Motivo Aprovado Declaradas (`NSPrivacyAccessedAPITypes`):**
  - `NSPrivacyAccessedAPICategoryUserDefaults`:
    - Código `CA92.1`: armazenamento de preferências e identificador do aplicativo no contêiner padrão (`DestinoGuardado.swift`);
    - Código `1C8F.1`: sincronização do `vinculo_id` do push entre o aplicativo e a extensão de notificação através do App Group compartilhado (`group.com.frila.org.app`, `Resources/Frameworks/PrivacyInfo.xcprivacy:21`).
  - O código em `Sources/` não faz uso de nenhuma outra API protegida (uptime do sistema, espaço em disco, timestamp de arquivos ou teclados).

#### Evidências em Testes Automatizados
- `iOS/Tests/Unitarios/SegurancaDoCodigoTests.swift`:
  - `@Test("Todo arquivo que o app grava leva .completeFileProtection")`: garante que todos os dados gravados em disco usam a classe máxima de proteção do iOS;
  - `@Test("Nenhum log interpola e-mail, token, sessão, senha, telefone ou chave")`: audita chamadas de `Logger` para evitar vazamentos de dados pessoais em registros de diagnóstico.
- `iOS/Tests/Unitarios/CanalDePushTests.swift`:
  - Valida o fluxo e isolamento de tokens de dispositivo e vínculos de push.
- `iOS/Scripts/conferir-release.sh` e `iOS/Scripts/teste-conferir-release.sh`:
  - Validam em tempo de CI que o arquivo `PrivacyInfo.xcprivacy` está presente no bundle e que `NSUserTrackingUsageDescription` está rigorosamente ausente.

---

## 3. Matriz Completa de Rastreabilidade Técnica

| Diretriz Apple | Requisito Específico | Arquivo Swift de Implementação | Arquivo Swift de Teste Automatizado | Critério de Aceite Verificado |
|---|---|---|---|---|
| **1.2** | Mecanismo de Denúncia | `Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:62`<br>`Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift:44` | `Tests/UI/SegurancaUITests.swift:68`<br>`Tests/Unitarios/SegurancaViewModelTests.swift:41,51` | Folha nativa com motivo, relato mínimo de 10 caracteres, protocolo e prazo. |
| **1.2** | Bloqueio de Usuários | `Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:39`<br>`Sources/Apresentacao/Fluxos/Confianca/SegurancaViewModel.swift:8,61` | `Tests/UI/SegurancaUITests.swift:96,111`<br>`Tests/Unitarios/SegurancaViewModelTests.swift:122,205` | Bloqueio destrutivo imediato na sessão; oculta perfis e vagas sem reiniciar o app. |
| **1.2** | Contato e Suporte Publicado | `Sources/Apresentacao/EnderecosOficiais.swift:4`<br>`Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift:5` | `Tests/UI/SuporteTurnoUITests.swift:11,92,114`<br>`Tests/Unitarios/CatalogoStringsTests.swift` | E-mail oficial `suportefrila@gmail.com`, links de termos e compositor nativo de e-mail no turno. |
| **1.2** | Canais de Emergência | `Sources/Apresentacao/Fluxos/Confianca/AcoesDeSeguranca.swift:109`<br>`Sources/Apresentacao/Fluxos/Suporte/FolhaSuporteTurno.swift:30` | `Tests/UI/SegurancaUITests.swift:68`<br>`Tests/UI/SuporteTurnoUITests.swift:11` | Discagem rápida direta para 190 (Polícia Militar) e 180 (Mulher) em situações de risco. |
| **2.1** | Contas de Demonstração Apple | `Sources/Apresentacao/Fluxos/Autenticacao/DestinoAposEntrada.swift:92`<br>`Sources/Apresentacao/Fluxos/Autenticacao/EntradaViewModel.swift:35` | `Tests/Unitarios/AutenticacaoTests.swift:47,509`<br>`Tests/Unitarios/ModoAviaoMeuTurnoTests.swift:91` | Reconhecimento de `revisao-profissional` e `revisao-contratante` sem exigir caixa postal. |
| **2.1** | Login sem OTP Externo | `Sources/Apresentacao/Fluxos/Autenticacao/CodigoViewModel.swift:99`<br>`Sources/Dados/SupabaseApiCliente.swift:70` | `Tests/Unitarios/AutenticacaoTests.swift:69,91`<br>`Tests/Unitarios/ApiEmMemoriaTests.swift:60` | Autenticação direta via `entrarDemonstracao` com sessão válida concedida. |
| **2.1** | Ausência de Placeholders | `Sources/Apresentacao/CatalogoDesignSystem.swift:1`<br>`Scripts/conferir-release.sh:118,149` | `Tests/Unitarios/SegurancaDoCodigoTests.swift:66`<br>`Tests/UI/CicloDePontaAPontaUITests.swift` | 0 ocorrências de telas em construção; ganchos de desenvolvimento isolados em `#if DEBUG`. |
| **2.3** | Coerência de Textos e Catálogo | `Resources/Localizable.xcstrings`<br>`Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:4` | `Tests/Unitarios/CatalogoStringsTests.swift:65,80`<br>`Scripts/conferir-textos.sh` | 100% das strings catalogadas e validadas em pt-BR; conferência estática automatizada. |
| **2.3** | Descrições de Permissões | `Resources/Info.plist`<br>`Project.yml` | `Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:555,569`<br>`Scripts/conferir-release.sh:78` | Textos claros para `NSLocationWhenInUseUsageDescription` e precisão temporária (`CheckIn`). |
| **4.2** | Interface Rica SwiftUI | `Sources/App/FrilaApp.swift:70`<br>`Sources/Apresentacao/Componentes.swift` | `Tests/UI/AuditoriaDeAcessibilidadeUITests.swift`<br>`Tests/UI/AcessibilidadeDoProfissionalUITests.swift` | Design system 100% nativo em SwiftUI; zero dependência de `WKWebView`. |
| **4.2** | Persistência e Modo Avião | `Sources/Dados/PersistenciaFrila.swift`<br>`Sources/Dados/TurnosComCache.swift:6`<br>`Sources/Dados/SincronizadorAcoes.swift:12` | `Tests/Unitarios/OfflineTests.swift:70`<br>`Tests/Unitarios/TurnosComCacheTests.swift`<br>`Tests/UI/ModoAviaoUITests.swift:38` | Cache local e fila offline preservam consulta e enfileiram ações sem conexão de rede. |
| **4.2** | Resiliência Geográfica (Check-in Manual) | `Sources/Apresentacao/Fluxos/Profissional/PresencaDoTurnoViewModel.swift:187`<br>`Sources/Apresentacao/Fluxos/Contratante/AcompanhamentoViewModel.swift:111` | `Tests/UI/PresencaUITests.swift:81,97`<br>`Tests/Unitarios/PresencaDoTurnoViewModelTests.swift:153,227` | Revisor fora do DF ou sem GPS completa a presença por check-in manual e confirmação da casa. |
| **5.1.1** | Exclusão Nativa de Conta | `Sources/Apresentacao/Fluxos/Conta/TelaExclusaoDeConta.swift:4`<br>`Sources/Apresentacao/Fluxos/Conta/ExclusaoDeContaViewModel.swift:6` | `Tests/UI/ExclusaoDeContaUITests.swift:5,69,89`<br>`Tests/Unitarios/ExclusaoDeContaViewModelTests.swift:65,90` | Tela nativa com explicação de consequências, lista de turnos futuros e confirmação destrutiva. |
| **5.1.1** | Limpeza Local Pós-Exclusão | `Sources/Dados/SaidaDaConta.swift:74`<br>`Sources/Dados/ArmazenamentoKeychain.swift` | `Tests/Unitarios/LimpezaAposExclusaoTests.swift:50`<br>`Tests/Unitarios/SegurancaDoCodigoTests.swift:43` | Resposta 202 expurga Keychain, SwiftData, fila, preferências e vínculos de push do aparelho. |
| **5.1.1** | Portabilidade e LGPD | `Sources/Apresentacao/Fluxos/Perfil/ExportarDadosViewModel.swift:112`<br>`Sources/Apresentacao/Fluxos/Perfil/TelaExportarDados.swift` | `Tests/Unitarios/ExportarDadosViewModelTests.swift`<br>`Tests/Unitarios/SegurancaDoCodigoTests.swift:91` | Exportação de dados pessoais JSON gravada com `[.atomic, .completeFileProtection]`. |
| **5.1.2** | Manifesto de Privacidade | `Resources/PrivacyInfo.xcprivacy`<br>`Resources/Frameworks/PrivacyInfo.xcprivacy` | `Scripts/conferir-release.sh:100`<br>`Scripts/teste-conferir-release.sh` | Declaração de não-rastreamento e mapeamento dos 10 tipos de dados funcionais. |
| **5.1.2** | APIs com Motivo Aprovado | `Resources/PrivacyInfo.xcprivacy:144` (`UserDefaults`) | `Tests/Unitarios/SegurancaDoCodigoTests.swift:109`<br>`Scripts/conferir-release.sh:63,78` | Razões CA92.1 (app) e 1C8F.1 (App Group da extensão); ausência de APIs não declaradas. |

---

## 4. Como Repetir e Verificar

```sh
# 1. Conferência estática de catálogo de textos e tokens do design system
iOS/Scripts/conferir-textos.sh

# 2. Testes unitários das diretrizes avaliadas (Segurança, Contas Demo, Strings, Exclusão e Cache)
xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:FrilaTests/CatalogoStringsTests \
  -only-testing:FrilaTests/AutenticacaoTests \
  -only-testing:FrilaTests/SegurancaViewModelTests \
  -only-testing:FrilaTests/ExclusaoDeContaViewModelTests \
  -only-testing:FrilaTests/LimpezaAposExclusaoTests \
  -only-testing:FrilaTests/PresencaDoTurnoViewModelTests \
  -only-testing:FrilaTests/OfflineTests \
  -only-testing:FrilaTests/SegurancaDoCodigoTests

# 3. Testes de interface (UI) de fluxos críticos de diretrizes da App Store
xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:FrilaUITests/SegurancaUITests \
  -only-testing:FrilaUITests/SuporteTurnoUITests \
  -only-testing:FrilaUITests/ExclusaoDeContaUITests \
  -only-testing:FrilaUITests/PresencaUITests \
  -only-testing:FrilaUITests/ModoAviaoUITests

# 4. Auditoria de conformidade do binário compilado de Release (sem ganchos e com PrivacyInfo)
iOS/Scripts/conferir-release.sh build/beta/Build/Products/Release-Beta-iphonesimulator/Frila.app
```
