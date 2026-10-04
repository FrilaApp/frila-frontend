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
| A1 | média | `Sources/Apresentacao/Fluxos/Perfil/ExportarDadosViewModel.swift:112` | O JSON de `exportar-meus-dados` (tudo o que o servidor sabe da pessoa) era gravado em `tmp/` com `.atomic` só, na classe padrão `completeUntilFirstUserAuthentication`: legível com o aparelho bloqueado depois do primeiro desbloqueio, e ficava no disco se o app morresse com a folha aberta (só a próxima exportação limpa). | **Corrigido:** `[.atomic, .completeFileProtection]`. `SegurancaDoCodigoTests` passa a reprovar qualquer `.write(to:` em `Sources/` sem a opção (o simulador não tem proteção de dados; a conferência é no código). |
| A2 | média | supabase-swift 2.55.2, `Sources/Auth/Internal/Keychain.swift:86`; ligado em `Sources/Dados/SupabaseApiCliente.swift:29` | A sessão (token de acesso e de renovação) vai ao Keychain pelo `KeychainLocalStorage` do SDK em `kSecAttrAccessibleAfterFirstUnlock`, **sem** `ThisDeviceOnly`: o item entra no backup cifrado e é restaurado em outro iPhone, levando a sessão junto. O token de push já usa `AfterFirstUnlockThisDeviceOnly` (`Sources/Infraestrutura/ArmazenamentoKeychain.swift:17`). | **Classe pronta e testada:** `Sources/Dados/SessaoNoKeychainDoAparelho.swift` (mesmo serviço e chave do SDK: a sessão guardada continua sendo lida e é regravada na classe nova na próxima renovação, sem nova entrada). **Ligada** em `SupabaseApiCliente.swift:30` (autorizado pelo Nick Fury em 03/10, com o #106 e o #73 ainda abertos; só esse trecho). |
| A3 | média | `Sources/Apresentacao/Fluxos/Perfil/HistoricoDeTurnosViewModel.swift` (`:169`, vindo do #106) | O CSV/PDF do histórico de turnos (endereços, valores, nomes) tem o mesmo problema do A1. | **Corrigido** (depois de o #106 entrar no `main`): `HistoricoDeTurnosViewModel.gravar` usa `[.atomic, .completeFileProtection]`; coberto pela conferência estática do `SegurancaDoCodigoTests`. |
| A4 | baixa | `Sources/App/FrilaApp.swift` (raiz da `WindowGroup`) | Telefone da outra parte, endereço do turno, relato de denúncia e a tela de exportação ficam na foto que o sistema tira para o seletor de apps (e grava em disco) quando o app sai de `.active`. | **Corrigido:** `Sources/Apresentacao/CortinaDePrivacidade.swift` (superfície opaca fora de `.active`) **ligado** na raiz do app, logo após o `Group { switch inicializacao … }`, fora de qualquer `#if` (vale em Release). Custo aceito: a tela fica coberta também com a central de notificações puxada. `SegurancaDoCodigoTests.cortinaLigadaNaRaiz` reprova o `FrilaApp.swift` sem a ligação. |
| A5 | baixa | `Sources/Dados/DTOsContrato.swift:588` (`ContatoDTO.dominio()`); aberto em `TelaMeuTurno.swift:119`, `MinhasVagas.swift:590`, `TelasDaCandidatura.swift:261` | O app abre o `whatsapp_url` como vem do servidor, sem conferir esquema e host. Hoje é `https://wa.me/<telefone>` (contrato 0.2.x); um valor errado numa linha do banco abriria qualquer URL ou esquema de app. | **Corrigido:** `ContatoDTO.dominio()` passa o link só se for `https` em `wa.me` ou `api.whatsapp.com`; fora disso o troca por `https://wa.me/` + dígitos do telefone E.164 e registra `whatsapp_url_saneado` no log (sem número nem link). Sem erro, de propósito: `candidatar` e `escolher_candidato` já gravaram no servidor quando a resposta chega, e um erro faria a ação parecer falha (e a repetição, 409). Testes nas três rotas em `WhatsAppDoTurnoTests`. |
| A6 | baixa | `Scripts/conferir-release.sh` (ocupado por #95) | O script não confere ATS, compartilhamento de arquivos e esquemas de URL: hoje o bundle não tem nenhum dos três (conferido no `Frila-Beta` deste PR), mas nada impede que entrem. | **Corrigido** (depois de o #95 entrar no `main`): o script reprova `NSAppTransportSecurity`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` e `CFBundleURLTypes`; quatro casos novos no `teste-conferir-release.sh`. |
| A7 | baixa | `Sources/App/FrilaApp.swift:39`, `Sources/App/ConfiguracaoAmbiente.swift:116` | O log de início imprime a URL do projeto Supabase com `privacy: .public`. | Sem ação: a URL já está no `Info.plist` do bundle, não é segredo; a chave nunca vai ao log (`ConfiguracaoAmbiente.swift:112`). |
| A8 | baixa | `Sources/Dados/AparelhoDePush.swift:208` | Depois da saída, o Keychain do push guarda `contaAnterior` (id da conta que saiu) para a carência da troca de conta (#162). | Sem ação: id opaco, no Keychain só deste aparelho, apagado no próximo registro de outra conta; é o que impede o push de quem saiu de abrir para quem entrou. |
| A9 | baixa | `Sources/NotificationService/NotificationService.swift:29` | A extensão loga o `tipo` do payload com `.public`. | Sem ação: o payload vem do servidor pelo APNs e `tipo` é um de dezoito valores fixos (`AvisoDePush.swift:4`); nenhum id, texto ou `vinculo_id` vai ao log. |

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
7. **Privacidade declarada** (`Resources/PrivacyInfo.xcprivacy`, para o App Privacy do #81):

   | Tipo declarado | De onde vem no código | Vinculado | Rastreio |
   |---|---|---|---|
   | Name | `criar_conta` (`CadastroConta`) | sim | não |
   | Email Address | `signInWithOTP` (`SupabaseApiCliente.swift:45`) | sim | não |
   | Phone Number | cadastro e contato do turno | sim | não |
   | Physical Address | estabelecimento (`CadastroEstabelecimento.swift`) | sim | não |
   | Precise Location | `ponto_base` do perfil: endereço que a pessoa escolhe (`PerfilProfissionalViewModel.swift:108-110`). O GPS do check-in **não** sai do aparelho: só `distanciaMetros` (`SupabaseApiCliente.swift:435-443`), como diz o `NSLocationWhenInUseUsageDescription`. | sim | não |
   | User ID | `usuarioID`/`conta_id` | sim | não |
   | Other User Content | relato de denúncia, contestação, avaliação | sim | não |
   | Other Data Types | data de nascimento | sim | não |
   | Crash Data, Other Diagnostic Data | Crashlytics (`TelemetriaCrashlytics.swift`) | não | não |
   | Device ID | token FCM (`registrar_dispositivo`), id de instalação do Crashlytics | sim | não |

   `NSPrivacyTracking` falso, sem domínios de rastreio, sem `NSUserTrackingUsageDescription`.
   APIs com motivo: `UserDefaults` CA92.1 (app) e 1C8F.1 (App Group, extensão). Nenhum uso de
   timestamp de arquivo, uptime, espaço em disco ou teclados ativos em `Sources/`. A extensão não
   coleta nada por conta própria (`Resources/Frameworks/PrivacyInfo.xcprivacy`). Coarse Location não
   é coletada: o feed usa o `ponto_base` do servidor, nunca a posição do aparelho
   (`FeedVagasViewModel.swift:100`).

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
