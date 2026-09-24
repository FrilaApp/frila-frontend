# Dependências externas do Sprint 0

Estado das dependências externas da fundação iOS:

1. Concluído: bundle ID definitivo `com.frila.org.app`.
2. Concluído: App ID registrado no Apple Developer com Push Notifications.
3. Concluído: app `Frila: Turnos e Vagas` criado no App Store Connect, Apple ID `6815311991`.
4. Concluído: projetos Firebase `frila-dev` e `frila-prod` criados na conta da organização, ambos com o app iOS `com.frila.org.app` e App Store ID `6815311991`.
5. Concluído: chave APNs `.p8` de ID `89CNDKBL96` ligada aos slots de desenvolvimento e produção do FCM nos projetos `frila-dev` e `frila-prod`.
6. Pendente operacional: transferir a chave `.p8` para o cofre da organização. Até lá, a cópia de trabalho permanece somente em `Secrets/APNs/`, diretório ignorado pelo Git; o conteúdo da chave não deve ser registrado no repositório nem na documentação.
7. Pendente externo: confirmar o contrato OpenAPI 0.2.1. O snapshot disponível é 0.2.0 e ainda não descreve `contato_visivel_ate`/retorno final de `meus_turnos`.

Os dois plists foram validados e cadastrados no GitHub Actions como `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`. A CI os injeta usando `Scripts/inject-firebase-config.sh`; eles nunca devem entrar no Git. A fase `Select Firebase configuration` copia somente o plist do ambiente ativo para o bundle.

Nesta fundação, o Firebase fica restrito ao transporte de push via FCM. A integração da chave APNs com os dois projetos está concluída; o SDK/runtime de recebimento de notificações será integrado no Sprint 2, conforme o cartão de infraestrutura.

Responsável, organização Apple, conta Firebase e política de rotação devem constar no gestor de segredos da equipe, não neste repositório.
