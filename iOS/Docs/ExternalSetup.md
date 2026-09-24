# Dependências externas do Sprint 0

Estado das dependências externas da fundação iOS, atualizado em 24/09/2026. O que foi conferido por ferramenta está marcado como tal; o resto foi informado pelo Cauê.

1. Concluído: bundle ID definitivo `com.frila.org.app`, Team ID `8B7F7G3Y2U`.
2. Concluído: App ID com Push Notifications. Evidência: o build assinado para `generic/platform=iOS` usa o perfil de equipe de `com.frila.org.app`, com `aps-environment`.
3. Concluído: app `Frila: Turnos e Vagas` criado no App Store Connect, Apple ID `6815311991`, bundle `com.frila.org.app`, idioma principal pt-BR, versão 1.0 em preparação para envio. O app iOS do Firebase `frila-dev` aponta para esse App Store ID (conferido pelo MCP). Free Apps e Paid Apps Agreement ativos e o acordo mais recente do Apple Developer Program aceito (informado).
3a. Concluído: acesso da equipe no App Store Connect. João Paulo e Teteufs foram convidados como App Manager (o papel Admin não pode ser limitado a um app), e os convites de Developer antigos foram revogados. Por decisão do Cauê, o envio dos convites conclui a etapa.
4. Firebase `frila-dev`: app iOS `com.frila.org.app` conferido pelo MCP do Firebase; o plist Dev corresponde a esse app.
5. Firebase `frila-prod`: o plist Prod declara `PROJECT_ID` `frila-prod` e o bundle `com.frila.org.app`, mas o projeto não é visível para a conta `frila.org@gmail.com` usada pelo MCP. A existência do app iOS lá não foi conferida por ferramenta.
6. Chave APNs `.p8` de ID `89CNDKBL96` (Team `8B7F7G3Y2U`): conferida no console do `frila-prod`, nos campos de desenvolvimento e produção do FCM (informado). Falta a mesma conferência no `frila-dev`. O MCP do Firebase não expõe a configuração de APNs.
7. Concluído: a `.p8` está no cofre KeePassXC da equipe (`Frila-Team.kdbx`), guardado no Drive da conta da organização; a senha mestra foi passada aos membros fora do repositório. As cópias locais em texto puro foram mantidas por decisão do Cauê em `Secrets/Senhas/Apagar/`, e só devem ser apagadas com autorização dele. `*.p8` e `*.kdbx` são ignorados pelo `.gitignore` da raiz do repositório, e `Secrets/` pelo de `iOS/`. Nada da chave vai para o repositório nem para a documentação.
8. Concluído: Supabase `frila-dev`, na organização do Frila, região `sa-east-1`. URL e chave publicável estão nos segredos `FRILA_SUPABASE_DEV_*` da CI.
9. Pendente externo: Supabase `frila-prod`. A criação foi recusada porque um administrador da organização já atingiu o limite de dois projetos gratuitos ativos. Destravar exige pausar ou remover um projeto desse membro, ou mudar o plano, decisão da organização. Depois: criar `frila-prod` em `sa-east-1`, rodar `Scripts/generate-supabase-secrets.sh` e cadastrar `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`. Até lá, o build de Prod falha na CI de propósito.
10. Concluído no iOS: cliente sincronizado com o contrato `0.2.4` publicado no frila-docs (commit `641c440`), com `meusTurnos()` chamando `meus_turnos`.
11. Pendente externo, do backend: em 24/09 o `frila-dev` só tem as funções `criar_conta` e `minha_conta`. As demais operações do contrato, inclusive `meus_turnos` e `configuracao_do_app`, respondem `404 PGRST202` até as migrações serem aplicadas no projeto remoto. Sem sessão, `criar_conta` e `minha_conta` respondem `401` com `42501`, que o app trata como não autenticado.
12. Não configurado, por decisão: o secret `FRILA_DOCS_TOKEN`. Sem ele, a CI confere só a integridade do espelho do contrato e avisa que não comparou com o original do frila-docs.

Os dois plists foram cadastrados no GitHub Actions como `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64` e `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`. A CI os injeta usando `Scripts/inject-firebase-config.sh`; eles nunca devem entrar no Git. A fase `Select Firebase configuration` copia somente o plist do ambiente ativo para o bundle.

Sem o plist, o build falha na CI com `missing Firebase configuration for <ambiente>`, e a injeção falha com `CI secret … is not configured`; localmente, sai só um aviso.

Nesta fundação, o Firebase fica restrito ao transporte de push via FCM: não é banco, autenticação nem backend, e o app ainda não importa o SDK. O SDK/runtime de recebimento de notificações será integrado no Sprint 2, conforme o cartão de infraestrutura. O ícone definitivo foi adiado e não faz parte desta entrega.

Responsável, organização Apple, conta Firebase e política de rotação devem constar no gestor de segredos da equipe, não neste repositório.
