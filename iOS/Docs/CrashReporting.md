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
- A última fase de build executa o `run` do Crashlytics para enviar dSYMs. Releases usam
  `dwarf-with-dsym`. Sem plist, inclusive em build de CI sem esse segredo, a fase avisa e sai
  com sucesso.
- Em Debug, o Catálogo de design system tem a ação **Forçar falha**. Após a falha, abra o app de
  novo para permitir o envio do relatório. Ela não é compilada em Beta ou Prod.

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
