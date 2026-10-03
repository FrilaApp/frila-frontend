# Relatório de falhas e privacidade

Decisão do cartão #198: **Firebase Crashlytics** substitui MetricKit + Organizer do Xcode.
`ColetorMetricKit` foi removido para não duplicar a coleta de diagnósticos nem manter um
relatório local que não chegava ao time. O único produto Firebase integrado é
`FirebaseCrashlytics`; Analytics e Messaging não fazem parte desta integração.

## Inicialização e símbolos

- Dev, Beta (que aponta para Dev) e Prod copiam o `GoogleService-Info.plist` do ambiente pela
  fase `Select Firebase configuration`. Os plists são segredos e não entram no Git.
- Local não tem plist: `RelatorioDeFalhas` não chama `FirebaseApp.configure()` e o Crashlytics
  permanece inativo, preservando o dublê e os testes locais.
- Debug-Dev, Release-Beta e Release-Prod usam `dwarf-with-dsym` em **todos os targets**, e não
  só no app. O código roda nos quatro frameworks (`FrilaDominio`, `FrilaDados`,
  `FrilaApresentacao`, `FrilaInfraestrutura`), e o Crashlytics **retém a falha fatal** enquanto
  falta o dSYM de algum binário da pilha: ela não aparece no painel, nem como "sem símbolos".
- A última fase de build chama o `upload-symbols` com o dSYM do app e o de cada framework, e
  grava a saída em `DerivedSources/crashlytics-upload-symbols.log`. Não usa o `Crashlytics/run`:
  ele envia só o dSYM do app e descarta a saída do envio em segundo plano. No archive
  (`ACTION=install`) o envio é síncrono, tenta duas vezes e quebra o archive se falhar; nos outros
  builds roda em segundo plano; na CI (`$CI`) não roda, porque o build de simulador da CI não é
  distribuído e o `upload-symbols` já caiu com Segmentation fault no runner. O build do TestFlight,
  que também sai da CI, manda os símbolos pelo `Scripts/enviar-testflight.sh`, depois do archive e
  antes do envio ([CI](CI.md#mandar-um-build-ao-testflight)). Sem plist, inclusive
  em build de CI sem esse segredo, a fase avisa e sai com sucesso. Um framework novo entra na
  lista do script e nos `inputFiles` da fase, porque o sandbox de scripts só lê o que está
  declarado.
- Em Debug, o Catálogo de design system tem a ação **Forçar falha**. Ela não é compilada em Beta
  ou Prod. Para testar: abra o app **sem depurador** (`xcrun simctl launch`, ou um teste de UI
  que toque em `forcar-falha-crashlytics`), porque o Crashlytics ignora falhas com depurador
  anexado; depois abra o app de novo, sem reinstalar, para o relatório ser enviado. Medido em
  30/09: a falha apareceu com símbolos no painel do frila-dev cerca de 2 minutos depois do envio.
- No build distribuído, a prova é o ensaio de falha do TestFlight: um build só para teste interno
  com o botão **Forçar falha (ensaio)** ([CI](CI.md#ensaio-de-falha-critério-do-203-antes-de-2010)).
- Os erros não fatais usam o domínio `frila.api.<codigo>`: uma issue por código de erro no painel.

## Dados permitidos nos eventos não fatais

`TelemetryReporter` registra apenas `codigo`, `rpc` e `duracao_ns` em erros da API. Não usar
`setUserID`, `setCustomValue` ou logs com nome, e-mail, telefone, token, corpo de resposta,
coordenada ou qualquer outro dado pessoal. O SDK usa somente seu identificador de instalação
aleatório; o app não associa esse identificador a uma pessoa.

Por padrão, Crashlytics também reúne pilha/estado da falha, versão e identificador do app e
informações de aparelho e sistema para diagnóstico. Sem Analytics não há breadcrumbs. Consulte
as páginas oficiais de [coleta do Firebase](https://firebase.google.com/support/privacy) e
[dados do SDK Apple](https://firebase.google.com/docs/ios/app-store-data-collection) ao atualizar
o SDK ou incluir outro produto Firebase.

## App Privacy e manifesto

`Resources/PrivacyInfo.xcprivacy` declara, para finalidade **App Functionality**, sem
rastreamento e sem vínculo à pessoa, o que vem do Crashlytics:

- **Crash Data**: pilhas e estado de falhas.
- **Other Diagnostic Data**: versão do app, aparelho e sistema operacional usados no diagnóstico.

No App Store Connect, registrar esses dois tipos em *App Privacy* como coletados, não
vinculados à identidade, sem uso para tracking e com a finalidade *App Functionality*. Reavaliar
essa declaração antes de adicionar Analytics, logs/breadcrumbs ou chaves customizadas.

O **Device ID** é declarado **vinculado à pessoa**, também só para *App Functionality* e sem
tracking. Ele cobre o identificador de instalação do Crashlytics/Firebase, que o app não associa a
ninguém, e o token de push (#8), que o app registra no servidor para a conta
(`registrar_dispositivo`) e guarda no aparelho junto com ela. Como o tipo é um só no manifesto e no
rótulo, vale a declaração mais forte. No *App Privacy* do App Store Connect, o Device ID passa de
"não vinculado" para "vinculado à identidade"; o que muda no rótulo está em [Push](Push.md).

O mesmo manifesto declara os dados da conta, estes vinculados à pessoa e também só para *App
Functionality* (#96): nome, e-mail, telefone, endereço do estabelecimento, ponto escolhido no mapa
(*Precise Location*), identificador da conta, conteúdo escrito pela pessoa (observações da vaga e
avaliações) e outros dados (data de nascimento e CPF ou CNPJ). O *App Privacy* do App Store
Connect precisa repetir essa lista. O uso de `UserDefaults` vai com o motivo `CA92.1`, no
manifesto do app e no de cada framework (`Resources/Frameworks/PrivacyInfo.xcprivacy`).
