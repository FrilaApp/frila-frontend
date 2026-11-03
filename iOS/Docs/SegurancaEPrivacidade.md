Revisado pelo Jurídico do time (agente de IA, skill leis-do-brasil) em 31/10/2026, com pendências operacionais e de comprovação documental registradas. Não é parecer de advogado.

# Segurança e privacidade do app iOS

Auditoria feita em 03/10/2026 sobre o `main` (`c7084f4`) antes do TestFlight externo (#203/#66), com
leitura dos PRs abertos onde indicado. Cada achado tem arquivo:linha conferido no arquivo. Gravidade:
**alta** vaza dado ou segredo; **média** reduz a proteção de um dado pessoal; **baixa** é endurecimento.

Regra desta auditoria: nenhum arquivo de segredo foi aberto (`Secrets.xcconfig`,
`GoogleService-Info.plist`); conferiu-se só que o código não os registra nem os embute.

## Resumo

| Gravidade | Achados | Corrigidos neste PR | Pendentes (arquivo ocupado por PR aberto) |
|---|---|---|---|
| Alta | 0 | — | — |
| Média | 3 | 3 (A1, A2, A3) | — |
| Baixa | 6 | 3 (A4; A5; A6) | A7–A9 sem ação |

## Achados

| # | Grav. | Onde | O que | Estado |
|---|---|---|---|---|
| A1 | média | `iOS/Sources/Apresentacao/Fluxos/Perfil/ExportarDadosViewModel.swift:112` | O JSON de `exportar-meus-dados` (tudo o que o servidor sabe da pessoa) era gravado em `tmp/` com `.atomic` só, na classe padrão `completeUntilFirstUserAuthentication`: legível com o aparelho bloqueado depois do primeiro desbloqueio, e ficava no disco se o app morresse com a folha aberta (só a próxima exportação limpa). | **Corrigido:** `[.atomic, .completeFileProtection]`. `SegurancaDoCodigoTests` passa a reprovar qualquer `.write(to:` em `Sources/` sem a opção (o simulador não tem proteção de dados; a conferência é no código). |
| A2 | média | supabase-swift 2.55.2; ligado em `iOS/Sources/Dados/SupabaseApiCliente.swift:29` | A sessão (token de acesso e de renovação) vai ao Keychain pelo `KeychainLocalStorage` do SDK em `kSecAttrAccessibleAfterFirstUnlock`, **sem** `ThisDeviceOnly`: o item entra no backup cifrado e é restaurado em outro iPhone, levando a sessão junto. O token de push já usa `AfterFirstUnlockThisDeviceOnly` (`iOS/Sources/Infraestrutura/ArmazenamentoKeychain.swift:17`). | **Classe pronta e testada:** `iOS/Sources/Dados/SessaoNoKeychainDoAparelho.swift` (mesmo serviço e chave do SDK: a sessão guardada continua sendo lida e é regravada na classe nova na próxima renovação, sem nova entrada). **Ligada** em `SupabaseApiCliente.swift:30` (autorizado pelo Nick Fury em 03/10, com o #106 e o #73 ainda abertos; só esse trecho). |
| A3 | média | `iOS/Sources/Apresentacao/Fluxos/Perfil/HistoricoDeTurnosViewModel.swift` (`:169`, vindo do #106) | O CSV/PDF do histórico de turnos (endereços, valores, nomes) tem o mesmo problema do A1. | **Corrigido** (depois de o #106 entrar no `main`): `HistoricoDeTurnosViewModel.gravar` usa `[.atomic, .completeFileProtection]`; coberto pela conferência estática do `SegurancaDoCodigoTests`. |
| A4 | baixa | `iOS/Sources/App/FrilaApp.swift` (raiz da `WindowGroup`) | Telefone da outra parte, endereço do turno, relato de denúncia e a tela de exportação ficam na foto que o sistema tira para o seletor de apps (e grava em disco) quando o app sai de `.active`. Um overlay da raiz deixava folhas e telas modais descobertas. | **Corrigido:** `iOS/Sources/Apresentacao/CortinaDePrivacidade.swift` cria uma `UIWindow` da cena da raiz, com nível `.alert + 1`, acima das folhas e de `fullScreenCover`. Os avisos síncronos `willDeactivate`, `didEnterBackground` e `willEnterForeground` cobrem a cena; somente `didActivate` esconde a janela. A superfície mantém `FrilaCor.fundo`, nunca se torna chave e fica fora do VoiceOver. Ligação na raiz fora de qualquer `#if`, inclusive em Release. Custo aceito: cobre também a central de notificações. `SegurancaDoCodigoTests.cortinaLigadaNaRaiz` confere o mecanismo; `CortinaDePrivacidadeTests.cobreApresentacaoModal` apresenta folha/tela cheia UIKit e verifica opacidade, nível, cobertura, foco preservado e restauração. |
| A5 | baixa | `iOS/Sources/Dados/DTOsContrato.swift:588` (`ContatoDTO.dominio()`); aberto em `TelaMeuTurno.swift:119`, `MinhasVagas.swift:590`, `TelasDaCandidatura.swift:261` | O app abre o `whatsapp_url` como vem do servidor, sem conferir esquema e host. Hoje é `https://wa.me/<telefone>` (contrato 0.2.x); um valor errado numa linha do banco abriria qualquer URL ou esquema de app. | **Corrigido:** `ContatoDTO.dominio()` passa o link só se for `https` em `wa.me` ou `api.whatsapp.com`; fora disso o troca por `https://wa.me/` + dígitos do telefone E.164 e registra `whatsapp_url_saneado` no log (sem número nem link). Sem erro, de propósito: `candidatar` e `escolher_candidato` já gravaram no servidor quando a resposta chega, e um erro faria a ação parecer falha (e a repetição, 409). Testes nas três rotas em `WhatsAppDoTurnoTests`. |
| A6 | baixa | `iOS/Scripts/conferir-release.sh` (ocupado por #95) | O script não confere ATS, compartilhamento de arquivos e esquemas de URL: hoje o bundle não tem nenhum dos três (conferido no `Frila-Beta` deste PR), mas nada impede que entrem. | **Corrigido** (depois de o #95 entrar no `main`): o script reprova `NSAppTransportSecurity`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` e `CFBundleURLTypes`; quatro casos novos no `teste-conferir-release.sh`. |
| A7 | baixa | `iOS/Sources/App/FrilaApp.swift:39`, `iOS/Sources/App/ConfiguracaoAmbiente.swift:116` | O log de início imprime a URL do projeto Supabase com `privacy: .public`. | Sem ação: a URL já está no `Info.plist` do bundle, não é segredo; a chave nunca vai ao log (`ConfiguracaoAmbiente.swift:112`). |
| A8 | baixa | `iOS/Sources/Dados/AparelhoDePush.swift:208` | Depois da saída, o Keychain do push guarda `contaAnterior` (id da conta que saiu) para a carência da troca de conta (#162). | Sem ação: id opaco, no Keychain só deste aparelho, apagado no próximo registro de outra conta; é o que impede o push de quem saiu de abrir para quem entrou. |
| A9 | baixa | `iOS/Sources/NotificationService/NotificationService.swift:29` | A extensão loga o `tipo` do payload com `.public`. | Sem ação: o payload vem do servidor pelo APNs e `tipo` é um de dezoito valores fixos (`AvisoDePush.swift:4`); nenhum id, texto ou `vinculo_id` vai ao log. |

## O que foi conferido e está em ordem

1. **Logs.** Oito interpolações com `privacy: .public` em `Sources/`, todas de tipo de erro, código, nome
   de tela ou milissegundos (`AppDelegate.swift:45`, `FrilaApp.swift:32,39,52`,
   `NotificationService.swift:29`, `MedicaoDeDesempenho.swift:61,67`, `MedicaoDeAbertura.swift:30`).
   Nenhum `print`/`NSLog`/`os_log` (`SegurancaDoCodigoTests`). Erros da API chegam ao log e ao
   Crashlytics só como código (`DecodificadorErroAPI.swift`, `SupabaseApiCliente.swift:490` registra
   apenas o nome do tipo do erro). Crashlytics recebe só `codigo`, `rpc` e `duracao_ns`
   (`TelemetriaCrashlytics.swift:44-47`); sem `setUserID`, sem `log`, sem valores customizados.
2. **Armazenamento.**
   - Keychain do app (token de push + vínculo): `AfterFirstUnlockThisDeviceOnly`
     (`ArmazenamentoKeychain.swift:17`). Sessão do SDK: ver A2.
   - `UserDefaults` padrão: destino da conta (enum, `DestinoGuardado.swift`), resposta de avaliação por
     `conta_turno` (`AvaliacaoTurnoViewModel.swift:27-60`), medições só com números. Tudo apagado na saída.
   - App Group (`group.com.frila.org.app`): só o `vinculo_id`, opaco (`VinculoDoPush.swift:13-16`);
     escrito junto com o vínculo e apagado com ele (`AparelhoDePush.swift:225-227`).
   - SwiftData (`Application Support/Frila/Frila.store`): turnos com o contato da outra parte, funções,
     sessão (`usuarioID` + perfil, sem token: `Modelos.swift:13-21`) e fila offline (sem coordenada:
     `Cache.swift:49-60`, só `distanciaMetros`). Pasta em `completeUntilFirstUserAuthentication`
     (`CacheSwiftData.swift:70-73`). O contato expirado sai da leitura (`CacheSwiftData.swift:133`) e o
     turno é apagado 24 h depois do fim (`:123-127`), antes dos 7 dias do `visivel_ate`.
   - Arquivos temporários: ver A1/A3; apagados ao fechar a folha (`ExportarDadosViewModel.swift:83-89`)
     e os residuais na próxima exportação (`:91-100`).
   - **Saída da conta** (`SaidaDaConta.swift:74-91`): avaliações, vínculo do push (e com ele o App
     Group), entrega de push suspensa, central de notificações limpa, cache + fila do SwiftData,
     destino guardado; `signOut` do SDK apaga a sessão do Keychain. O encerramento por 401 faz o mesmo
     (`:68-72`). A exclusão de conta só limpa depois do 202 (`:50-55`).
3. **Rede.** Bundle `Frila-Beta` sem `NSAppTransportSecurity` (ATS padrão, só HTTPS). A URL do Supabase
   só aceita `https` fora do `local` com loopback (`ConfiguracaoAmbiente.swift:140-144`); chave
   `sb_secret_`/`service_role` é recusada no build (`:155-163`). Token só em cabeçalho, pelo SDK; o app
   não monta `URLRequest`. Sem `WKWebView`.
4. **Entradas externas.** O app não tem `CFBundleURLTypes` nem `associated-domains`: nenhum deep link
   nem universal link. Push: `tipo` em lista fechada, ids só se forem UUID (`AvisoDePush.swift:44-48`);
   push de outra conta ou de antes do vínculo não abre nada (`RoteadorDePush.swift:170-190`); nenhuma
   URL sai do payload. Extensão (#253): compara `vinculo_id` com o App Group e neutraliza o aviso de
   outra conta, inclusive quando o tempo acaba (`NotificationService.swift:38-43`). Links que o app abre:
   `tel:` com o telefone filtrado a dígitos (`MinhasVagas.swift:583-585`), Apple Maps com o endereço em
   query (`MeuTurnoViewModel.swift:132-136`), `https://frila.app/...` fixos; `whatsapp_url`: ver A5.
5. **Tela.** Código de e-mail com `.textContentType(.oneTimeCode)` (`TelaCodigo.swift:59`,
   `Componentes.swift:101`). Nada vai sozinho à área de transferência: o único `UIPasteboard` é o
   relatório de medições, dentro de `#if DEBUG || FRILA_MEDICAO` (`RelatorioDeMedicoes.swift:63`), que o
   `conferir-release.sh` barra. Seletor de apps: ver A4.
6. **Release.** `conferir-release.sh` rodado no `Frila-Beta` deste PR: OK. Os ganchos de desenvolvimento
   estão em `#if DEBUG`, o dublê em memória não chega ao Release (`FrilaApp.swift:78-84`), os logs não
   têm nível verboso em Release (não há `debug`/`trace`). Segredos fora do git (`iOS/.gitignore:1-2`),
   nenhum `Secrets.xcconfig`/`.p8` no bundle, scripts sem `set -x` e sem `echo` de chave. Faltas: nenhuma (A6 corrigida).
## Rótulo de Privacidade da App Store (App Privacy e Diretriz 5.1.2)

Dossiê técnico consolidado para o Cartão do Trello [#81](https://trello.com/c/iWfyZwdu) ("App Privacy preenchido e coerente com a política, com o manifesto de privacidade e com o banco"), alinhando a taxonomia do App Store Connect, o manifesto `PrivacyInfo.xcprivacy` (`iOS/Resources/PrivacyInfo.xcprivacy`) e o comportamento do código em `Sources/`, em estrita conformidade com as Diretrizes 5.1.1 e 5.1.2 da Apple.

### 1. Ausência de Rastreamento (Tracking: False)

- **`NSPrivacyTracking`:** Declarado como `<false/>`.
- **`NSPrivacyTrackingDomains`:** Lista vazia (`<array/>`).
- **Frameworks e descrições:** O app não inclui nem vincula o framework `AppTrackingTransparency.framework`, não define `NSUserTrackingUsageDescription` no `Info.plist` e não acessa identificadores publicitários como o IDFA (`advertisingIdentifier`).
- **Conformidade com a Diretriz 5.1.2:** Nenhum dado coletado pelo app é compartilhado com corretores de dados (data brokers) ou cruzado com bases de dados de terceiros para fins de publicidade direcionada, retargeting ou mensuração de campanhas.

### 2. Mapeamento dos Dados Coletados (Taxonomia App Store Connect)

| Categoria App Store Connect | Tipo de Dado (`PrivacyInfo.xcprivacy`) | Origem no Código e Banco | Vinculado ao Usuário (`Linked`) | Usado para Rastreamento | Finalidade Declarada |
|---|---|---|:---:|:---:|---|
| **Dados de Contato** (Contact Info) | **Nome** (`NSPrivacyCollectedDataTypeName`) | Cadastro da conta (`CadastroConta` em `iOS/Sources/Dominio/Portas.swift:3`, RPC `criar_conta` em `iOS/Sources/Dados/SupabaseApiCliente.swift:102`). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Dados de Contato** (Contact Info) | **Endereço de E-mail** (`NSPrivacyCollectedDataTypeEmailAddress`) | Autenticação sem senha via OTP do Supabase Auth (`iOS/Sources/Dados/SupabaseApiCliente.swift:49`). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Dados de Contato** (Contact Info) | **Número de Telefone** (`NSPrivacyCollectedDataTypePhoneNumber`) | Cadastro inicial e exibição do contato da outra parte após confirmação do turno (`ContatoDTO.dominio()`). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Dados de Contato** (Contact Info) | **Endereço Físico** (`NSPrivacyCollectedDataTypePhysicalAddress`) | Cadastro do estabelecimento contratante (`CadastroEstabelecimento.swift:105`, RPC `cadastrar_estabelecimento` em `iOS/Sources/Dados/SupabaseApiCliente.swift:144`). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Localização** (Location) | **Localização Precisa** (`NSPrivacyCollectedDataTypePreciseLocation`) | 1) `ponto_base` do perfil profissional: endereço/coordenada de referência escolhido pelo profissional (`PerfilProfissionalViewModel.swift:108-112`) para calcular proximidade com vagas.<br>2) Leitura pontual de presença: CoreLocation (`LeitorDeLocalizacaoDoSistema.swift:45`) acionado exclusivamente no momento do check-in/check-out. | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Identificadores** (Identifiers) | **ID do Usuário** (`NSPrivacyCollectedDataTypeUserID`) | Identificador único da conta (`usuarioID` / `conta_id` do Supabase Auth). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Identificadores** (Identifiers) | **ID do Dispositivo** (`NSPrivacyCollectedDataTypeDeviceID`) | Token de push APNs/FCM registrado na RPC `registrar_dispositivo` (`iOS/Sources/Dados/AparelhoDePush.swift:208`) e identificador anônimo do Firebase Crashlytics. | Sim (Push) / Não (Crashlytics) | Não | Funcionalidade do App (`App Functionality`) |
| **Conteúdo do Usuário** (User Content) | **Outro Conteúdo do Usuário** (`NSPrivacyCollectedDataTypeOtherUserContent`) | Relatos de suporte (`FolhaSuporteTurno.swift`), contestação de conta suspensa (`ContaSuspensaViewModel.swift`) e avaliações de turno. | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Outros Dados** (Other Data Types) | **Outros Tipos de Dados** (`NSPrivacyCollectedDataTypeOtherDataTypes`) | Data de nascimento informada no cadastro para validação mandatória de maioridade legal (requisito de elegibilidade de trabalho). | Sim | Não | Funcionalidade do App (`App Functionality`) |
| **Diagnósticos** (Diagnostics) | **Dados de Falhas** (`NSPrivacyCollectedDataTypeCrashData`) | Firebase Crashlytics (`iOS/Sources/Infraestrutura/TelemetriaCrashlytics.swift`). | Não | Não | Funcionalidade do App (`App Functionality`) |
| **Diagnósticos** (Diagnostics) | **Outros Dados de Diagnóstico** (`NSPrivacyCollectedDataTypeOtherDiagnosticData`) | Telemetria técnica mínima de erros da API (`codigo`, `rpc`, `duracao_ns` em `TelemetriaCrashlytics.swift:44-47`). | Não | Não | Funcionalidade do App (`App Functionality`) |

### 3. Minimização e Salvaguardas Técnicas (Diretriz 5.1.2)

1. **Localização Estritamente Pontual e Sem Coordenadas no Servidor:**
   - O aplicativo solicita exclusivamente autorização "Ao Usar o App" (`requestWhenInUseAuthorization()`). Não existe solicitação de localização em segundo plano ("Sempre" / `Always`) nem monitoramento de geofencing permanente no sistema (`LeitorDeLocalizacaoDoSistema.swift:5-7`).
   - A leitura do GPS no check-in e check-out é pontual (`lerUmaVez`). A coordenada geográfica do dispositivo (latitude/longitude) é processada **apenas localmente** para calcular a distância física até o estabelecimento contratante.
   - Para o backend Supabase, o app envia somente `distanciaMetros` (`SupabaseApiCliente.swift:521-524`). Nenhuma coordenada crua do aparelho trafega pela rede ou fica armazenada no banco para comprovação de presença.
   - O feed de vagas não lê a localização do aparelho: as oportunidades são consultadas contra o `ponto_base` fixado no perfil (`FeedVagasViewModel.swift:100`), evitando qualquer coleta de localização aproximada em tempo real (`Coarse Location: Não coletada`).

2. **Isolamento de Diagnósticos e Ausência de Identificação Pessoal no Crashlytics:**
   - O Firebase Crashlytics é inicializado somente se o arquivo `GoogleService-Info.plist` estiver presente (`RelatorioDeFalhas.iniciarSeConfigurado`).
   - Não há chamada a `Crashlytics.setUserID()`, nem envio de chaves personalizadas com nomes, e-mails, telefones ou documentos (`TelemetriaCrashlytics.swift:42-47`).
   - Os eventos limitam-se ao código de erro da API, nome do RPC e duração em nanossegundos, caracterizando dados desvinculados da identidade do usuário (`Linked: false`).

3. **APIs com Motivo Declarado (Required Reason APIs):**
   - **`UserDefaults` (`NSPrivacyAccessedAPICategoryUserDefaults`):**
     - App Principal: Motivo `CA92.1` (acesso a armazenamento de preferências e estado do app).
     - Notification Service Extension: Motivo `1C8F.1` (acesso exclusivo às informações compartilhadas no App Group `group.com.frila.org.app` para conferência do `vinculo_id`).
   - Nenhuma API das categorias restritas (espaço em disco, timestamp de arquivos, uptime de inicialização ou teclados ativos) é utilizada no código-fonte.
   - O manifesto da extensão de push (`iOS/Resources/Frameworks/PrivacyInfo.xcprivacy`) declara ausência total de coleta própria de dados.

4. **Direito de Eliminação e Saída de Dados:**
   - Em conformidade com a Diretriz 5.1.1(v), o app fornece fluxo completo de exclusão de conta (`ExclusaoDeContaViewModel.swift`), que invoca a RPC correspondente e purga chaves do Keychain, caches do SwiftData e dados no `UserDefaults` (`SaidaDaConta.swift:74-91`).

## Direitos de Conteúdo e Diretrizes da App Store

Consolidação para submissão do build 1.0 à App Store e preenchimento dos formulários regulatórios no App Store Connect:

1. **Conformidade com a Diretriz 1.2 da Apple (User-Generated Content):**
   - **Filtro de termos ofensivos:** Validação prévia em todos os campos livres (`observacoes`, `traje`, `responsavel_local` em `publicar_vaga`, relatos de contestação e perfis). O backend rejeita termos ofensivos com erro 422 `campo_invalido` (`supabase/tests/510_moderacao_do_texto.sql`).
   - **Canal de denúncia acessível:** Acesso direto à denúncia no fluxo do profissional, localizado exclusivamente na tela de detalhe da vaga (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift` — sem pontos de denúncia em perfis nem no contratante no build atual), com seleção de motivo categorizado (`iOS/Sources/Dominio/Modelos.swift`: `assedio`, `discriminacao`, `riscoSeguranca`, `outro`) e geração de protocolo rastreável de ocorrência (`denunciar` em `iOS/Sources/Dominio/Portas.swift` e `iOS/Sources/Dados/SupabaseApiCliente.swift`).
   - **Bloqueio mútuo de usuários:** Mecanismo ativo e imediato de bloqueio disponível na tela de detalhe da vaga do profissional (`iOS/Sources/Apresentacao/Fluxos/Profissional/TelaDetalheVaga.swift`, via protocolo `bloquear` em `iOS/Sources/Dominio/Portas.swift` e implementação em `iOS/Sources/Dados/SupabaseApiCliente.swift`), impedindo que as duas partes voltem a se cruzar em vagas, candidaturas ou notificações.
   - **Moderação e prazo de atendimento:** Fila operacional dedicada (`privado.moderacao_pendente()`), com atendimento o mais breve possível, com triagem em até 5 dias úteis e resposta formal em até 15 dias corridos (decisão do Cauê em 15/10/2026). A equipe pode ocultar administrativamente conteúdo reportado (`privado.operacao_moderar_texto`), sem prejudicar a vaga ou turnos já confirmados.
2. **Declaração de Direitos de Conteúdo e Propriedade Intelectual:**
   - O aplicativo declara não conter, não reproduzir e não exibir conteúdo de terceiros protegido por direitos autorais ou marcas sem a devida autorização ou licenciamento legal.
   - Todo conteúdo textual ou imagético do aplicativo é de titularidade própria do Frila ou gerado pelos próprios usuários autenticados sob os Termos de Uso da plataforma.
   - O catálogo de dependências externas de código aberto é auditado e exportado via `iOS/Scripts/gerar-licencas.py`, com 100% dos pacotes do `Package.resolved` mapeados e atribuídos em `iOS/Resources/Licencas.json` (licenças Apache-2.0, BSD, MIT, Zlib) e validados na tela de licenças do app (`TelaLicencas.swift`, `LicencasTests.swift`, `LicencasUITests.swift`).
3. **Uso de Marcas da Apple, Selo Oficial e Mockups Autorizados:**
   - Cumprimento estrito das Diretrizes de Identidade da Apple (Apple Identity Guidelines).
   - Uso exclusivo do selo oficial "Download on the App Store" / "Baixar na App Store" nas peças de divulgação e landing pages, mantendo dimensões, cores, tipografia e área de respiro obrigatória conforme o guia da Apple.
   - Uso de molduras de aparelhos (mockups) exclusivamente derivados dos modelos e especificações oficiais disponibilizados no Apple Design Resources, sem modificação, distorção ou inclusão de elementos gráficos de terceiros no hardware ilustrado.

## Requisitos de Envio da Apple: Manifestos e Criptografia (Diretrizes 2.1 e 5.1.2)

Consolidação para submissão do app à App Store e TestFlight, garantindo conformidade regulatória contínua e eliminando questionários manuais de conformidade de exportação:

1. **Declaração e Isenção de Criptografia (`ITSAppUsesNonExemptEncryption` — Diretriz 2.1):**
   - **Embasamento regulatório (EAR e Diretriz 2.1 da Apple):** O aplicativo utiliza exclusivamente criptografia padrão de transporte (HTTPS/TLS) disponibilizada pelo sistema operacional iOS via `URLSession` para comunicação com os serviços backend (`SupabaseApiCliente.swift`) e Firebase (`TelemetriaCrashlytics.swift`), além de APIs nativas do Keychain (`Security.framework`, `ArmazenamentoKeychain.swift`, `SessaoNoKeychainDoAparelho.swift`) para guarda de tokens. O aplicativo não implementa algoritmos criptográficos proprietários, cifras customizadas ou recursos não isentos sob as normas de exportação dos EUA (EAR, Categoria 5, Parte 2, Nota 4) e regras da Apple.
   - **Configuração no projeto:**
     - `iOS/Sources/App/Info.plist`: chave `ITSAppUsesNonExemptEncryption` definida com o valor booleano `<false/>`.
     - `iOS/project.yml`: configuração de build `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` no target principal `Frila`.
   - **Validação automatizada de release:** O script `iOS/Scripts/conferir-release.sh` (linhas 47–54) inspeciona o `Info.plist` do pacote compilado e reprova o build caso `ITSAppUsesNonExemptEncryption` esteja ausente ou diferente do booleano `false`.
   - **Resultado operacional:** O TestFlight e o App Store Connect dispensam a cada novo upload perguntas manuais sobre conformidade de exportação de criptografia e não exigem código ERN/CCATS.

2. **Manifesto de Privacidade (`PrivacyInfo.xcprivacy` — Diretriz 5.1.2):**
   - **Empacotamento nos alvos:** O manifesto de privacidade é incluído tanto no bundle da aplicação principal (`iOS/Resources/PrivacyInfo.xcprivacy`, vinculado via `project.yml:170`) quanto em cada framework dinâmico e extensão (`iOS/Resources/Frameworks/PrivacyInfo.xcprivacy`, vinculado aos targets `FrilaDominio`, `FrilaDados`, `FrilaApresentacao`, `FrilaInfraestrutura` e `FrilaNotificationService` em `project.yml:67,82,105,120,146`).
   - **Rastreamento (`NSPrivacyTracking`):** Definido como `false` e lista `NSPrivacyTrackingDomains` vazia em todos os manifestos. O app não utiliza IDFA, não inclui o framework AppTrackingTransparency (`NSUserTrackingUsageDescription` ausente) e não compartilha dados de usuários com terceiros para fins de publicidade direcionada ou rastreamento entre apps e sites.
   - **Inventário de Dados Coletados (`NSPrivacyCollectedDataTypes`):**
     - `Name`: Nome civil do usuário no cadastro (`CadastroConta`), vinculado à identidade, sem rastreamento, para funcionamento do app (`AppFunctionality`).
     - `Email Address`: E-mail de autenticação por código OTP (`SupabaseApiCliente.swift:45`), vinculado, sem rastreamento (`AppFunctionality`).
     - `Phone Number`: Telefone para contato operacional e segurança dos turnos confirmados, vinculado, sem rastreamento (`AppFunctionality`).
     - `Physical Address`: Endereço de realização das vagas do estabelecimento contratante (`CadastroEstabelecimento.swift`), vinculado, sem rastreamento (`AppFunctionality`).
     - `Precise Location`: Ponto base escolhido pelo profissional em seu perfil (`PerfilProfissionalViewModel.swift:108-110`). O GPS no momento do check-in/check-out não é enviado ao servidor nem transmitido pela rede; apenas a distância calculada localmente (`distanciaMetros`) é enviada (`SupabaseApiCliente.swift:435-443`).
     - `User ID`: Identificadores UUID de autenticação e conta (`usuarioID`/`conta_id`), vinculados, sem rastreamento (`AppFunctionality`).
     - `Other User Content`: Relatos de denúncia, contestação e avaliações mútuas entre profissionais e contratantes, vinculados, sem rastreamento (`AppFunctionality`).
     - `Other Data Types`: Data de nascimento para validação de maioridade legal, vinculada, sem rastreamento (`AppFunctionality`).
     - `Crash Data` e `Other Diagnostic Data`: Diagnósticos e registros de travamento via Firebase Crashlytics (`TelemetriaCrashlytics.swift`), sem identificador de usuário (`setUserID` não utilizado), não vinculados e sem rastreamento (`AppFunctionality`).
     - `Device ID`: Identificador FCM/APNs do aparelho para envio de notificações transacionais de turnos e ID de instalação do Crashlytics, vinculado à conta para entrega do push, sem rastreamento (`AppFunctionality`).
   - **Auditoria de APIs com Motivos Requeridos (Required Reason APIs — `NSPrivacyAccessedAPITypes`):**
     - `NSPrivacyAccessedAPICategoryUserDefaults`: Categoria utilizada e declarada com os motivos `CA92.1` (leitura/gravação de dados acessíveis exclusivamente pelo app: `UserDefaultsArmazenamentoAvaliacoes` em `AvaliacaoTurnoViewModel.swift:28`, `DestinoGuardado.swift:16`, `DestinoAposEntrada.swift:66`, `MedicaoDeDesempenho.swift:47`) e `1C8F.1` (compartilhamento de dados via App Group `group.com.frila.org.app` para sincronização do `vinculo_id` do push com a Notification Service Extension em `VinculoDoPush.swift:13,27` e `NotificationService.swift:38`).
     - `NSPrivacyAccessedAPICategoryFileTimestamp`: Categoria auditada e **não utilizada** (nenhum uso de `creationDate`, `modificationDate`, `fileModificationDate`, `stat` ou `getattrlist` em `iOS/Sources/`).
     - `NSPrivacyAccessedAPICategorySystemBootTime`: Categoria auditada e **não utilizada** (nenhum uso de `systemUptime`, `mach_absolute_time` ou `sysctl` em `iOS/Sources/`).
     - `NSPrivacyAccessedAPICategoryDiskSpace`: Categoria auditada e **não utilizada** (nenhum uso de `volumeAvailableCapacity`, `volumeTotalCapacity` ou `statfs` em `iOS/Sources/`).
     - `NSPrivacyAccessedAPICategoryActiveKeyboards`: Categoria auditada e **não utilizada** (nenhum uso de `activeInputModes` ou APIs de teclados ativos em `iOS/Sources/`).
   - **Verificação contínua:** `iOS/Scripts/conferir-release.sh:100` valida a presença física do `PrivacyInfo.xcprivacy` no bundle de release, e `iOS/Tests/Unitarios/CanalDePushTests.swift:101-111` testa programaticamente a conformidade das propriedades do manifesto.

## Como repetir

```sh
# antes de rodar, se o projeto ainda não foi gerado nesta pasta/branch:
Scripts/gerar-projeto.sh  # gera o Frila.xcodeproj via XcodeGen e restaura o Package.resolved versionado

# Suíte afetada
xcodebuild test -project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:FrilaTests/SegurancaDoCodigoTests -only-testing:FrilaTests/SessaoNoKeychainDoAparelhoTests \
  -only-testing:FrilaTests/ExportarDadosViewModelTests -only-testing:FrilaTests/CortinaDePrivacidadeTests
# Bundle de Release
xcodebuild build -project Frila.xcodeproj -scheme Frila-Beta -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath build/beta
Scripts/conferir-release.sh build/beta/Build/Products/Release-Beta-iphonesimulator/Frila.app
# Logs de execução (depois de usar o app no simulador)
Scripts/auditar-logs-sensiveis.sh <UDID> 5
```
