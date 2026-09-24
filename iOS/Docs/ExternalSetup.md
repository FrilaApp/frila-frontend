# Dependências externas do Sprint 0

Estado das dependências externas da fundação iOS, conferido em 23/09/2026:

1. Concluído: bundle ID definitivo `com.frila.org.app`, Team ID `8B7F7G3Y2U`.
2. Concluído: App ID com Push Notifications. Evidência: o build assinado para `generic/platform=iOS` usa o perfil de equipe de `com.frila.org.app`, com `aps-environment`.
3. Concluído: app `Frila: Turnos e Vagas` criado no App Store Connect, Apple ID `6815311991` (o app iOS do Firebase `frila-dev` aponta para esse App Store ID).
4. Firebase `frila-dev`: app iOS `com.frila.org.app` conferido pelo MCP do Firebase; o plist Dev corresponde a esse app.
5. Firebase `frila-prod`: o plist Prod declara `PROJECT_ID` `frila-prod` e o bundle `com.frila.org.app`, mas o projeto não é visível para a conta `frila.org@gmail.com` usada pelo MCP. A existência do app iOS lá não foi conferida por ferramenta.
6. Informado pelo responsável, sem conferência por ferramenta: chave APNs `.p8` de ID `89CNDKBL96` ligada aos slots de desenvolvimento e produção do FCM nos dois projetos Firebase.
7. Pendente operacional: transferir a chave `.p8` para o cofre da organização. Até lá, a cópia de trabalho permanece somente em `Secrets/APNs/`, diretório ignorado pelo Git; o conteúdo da chave não deve ser registrado no repositório nem na documentação.
8. Concluído: Supabase `frila-dev`, na organização do Frila, região `sa-east-1`. URL e chave publicável estão nos segredos `FRILA_SUPABASE_DEV_*` da CI.
9. Pendente externo: Supabase `frila-prod`. A criação foi recusada porque um administrador da organização já atingiu o limite de dois projetos gratuitos ativos. Destravar exige pausar ou remover um projeto desse membro, ou mudar o plano, decisão da organização. Depois: criar `frila-prod` em `sa-east-1`, rodar `Scripts/generate-supabase-secrets.sh` e cadastrar `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`. Até lá, o build de Prod falha na CI de propósito.
10. Pendente: sincronizar o cliente iOS com o contrato publicado. As fixtures e DTOs seguem o snapshot `0.2.0`; `meusTurnos()` continua bloqueado no cliente real e não presume o schema de `meus_turnos` nem `contato_visivel_ate`.

Os dois plists foram cadastrados no GitHub Actions como `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`. A CI os injeta usando `Scripts/inject-firebase-config.sh`; eles nunca devem entrar no Git. A fase `Select Firebase configuration` copia somente o plist do ambiente ativo para o bundle.

Nesta fundação, o Firebase fica restrito ao transporte de push via FCM. O SDK/runtime de recebimento de notificações será integrado no Sprint 2, conforme o cartão de infraestrutura. O ícone definitivo foi adiado e não faz parte desta entrega.

Responsável, organização Apple, conta Firebase e política de rotação devem constar no gestor de segredos da equipe, não neste repositório.
