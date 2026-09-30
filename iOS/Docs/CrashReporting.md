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
  distribuído e o `upload-symbols` já caiu com Segmentation fault no runner. Sem plist, inclusive
  em build de CI sem esse segredo, a fase avisa e sai com sucesso. Um framework novo entra na
  lista do script e nos `inputFiles` da fase, porque o sandbox de scripts só lê o que está
  declarado.
- Em Debug, o Catálogo de design system tem a ação **Forçar falha**. Ela não é compilada em Beta
  ou Prod. Para testar: abra o app **sem depurador** (`xcrun simctl launch`, ou um teste de UI
  que toque em `forcar-falha-crashlytics`), porque o Crashlytics ignora falhas com depurador
  anexado; depois abra o app de novo, sem reinstalar, para o relatório ser enviado. Medido em
  30/09: a falha apareceu com símbolos no painel do frila-dev cerca de 2 minutos depois do envio.
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
rastreamento e sem vínculo à pessoa:

- **Crash Data**: pilhas e estado de falhas.
- **Device ID**: identificadores aleatórios de instalação do Crashlytics/Firebase.
- **Other Diagnostic Data**: versão do app, aparelho e sistema operacional usados no diagnóstico.

No App Store Connect, registrar esses mesmos três tipos em *App Privacy* como coletados, não
vinculados à identidade, sem uso para tracking e com a finalidade *App Functionality*. Reavaliar
essa declaração antes de adicionar Analytics, logs/breadcrumbs ou chaves customizadas.
