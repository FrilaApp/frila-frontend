# Passo a Passo: Upload de Builds do Frila ao TestFlight pela CI

Guia reproduzível para execução do pipeline de envio de compilações ao TestFlight via GitHub Actions, em cumprimento ao Cartão [0jEemYAM](https://trello.com/c/0jEemYAM) (Build 0.4 e 0.5) e alinhado com a arquitetura definida em `iOS/Docs/CI.md`.

---

## 1. Visão Geral e Princípios de Envio

O envio de compilações do Frila iOS ao TestFlight ocorre de forma automatizada pelo workflow `.github/workflows/testflight.yml`, orquestrado pelo script `iOS/Scripts/enviar-testflight.sh`.

- **Determinismo e Assinatura Manual:** A compilação na CI utiliza assinatura estritamente manual (`CODE_SIGN_STYLE=Manual` com certificados `Apple Distribution` e perfis de provisionamento App Store importados dinamicamente). O parâmetro `-allowProvisioningUpdates` é expressamente proibido na CI para impedir a criação indevida de certificados que esgotem os limites da conta Apple.
- **Número do Build Crescente:** O número de build é gerado automaticamente no formato `AAAAMMDD.HHMMSS` em UTC (ex.: `20261101.33000`). Ele é único e estritamente crescente, dispensando consultas remotas prévias à Apple.
- **Criptografia Declarada:** O app define `ITSAppUsesNonExemptEncryption = false` no `Info.plist`, dispensando respostas manuais sobre conformidade de exportação no App Store Connect.

---

## 2. Pré-requisitos Técnicos

Antes de disparar o upload:
1. **Commit na branch `main`:** O envio só é permitido para commits aprovados que estejam integrados na branch `main`.
2. **Gate Local Verde:** O código deve ter passado com sucesso pelos scripts de validação:
   - `Scripts/conferir-textos.sh`
   - `Scripts/conferir-datas-fixas.sh`
   - `Scripts/conferir-movimento.sh`
   - `Scripts/conferir-release.sh`
3. **Segredos Configurados no Repositório:** Todos os segredos listados na seção 3 devem estar presentes no GitHub Secrets.

---

## 3. Onde Ficam os Segredos (Sem Citar Valores)

Todos os segredos necessários para o TestFlight ficam armazenados exclusivamente no GitHub:  
**Caminho no GitHub:** `Configurações do Repositório (Settings) > Secrets and variables > Actions`.

> [!CAUTION]
> Nunca salve certificados, senhas ou arquivos `.p8` dentro do repositório Git, em branches ou em logs de execução. O GitHub mascara automaticamente as variáveis durante o build, e os passos efêmeros da CI removem todos os arquivos sensíveis ao final.

### Lista de Segredos do Workflow:

#### A. Chave da App Store Connect API
- `APP_STORE_CONNECT_API_KEY_P8`: Chave privada da App Store Connect API no formato PEM (`.p8`), incluindo os cabeçalhos `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`.
- `APP_STORE_CONNECT_API_KEY_ID`: O identificador da chave de 10 caracteres gerado pela Apple (Key ID).
- `APP_STORE_CONNECT_API_ISSUER_ID`: O identificador UUID do emissor na conta de desenvolvedor da Apple (Issuer ID).

#### B. Identidade e Assinatura de Distribuição
- `APPLE_DISTRIBUTION_CERT_P12_BASE64`: Certificado oficial `Apple Distribution` com a chave privada correspondente, exportado em `.p12` e codificado em string Base64 (`base64 -i Certificado.p12`).
- `APPLE_DISTRIBUTION_CERT_P12_PASSWORD`: Senha utilizada na proteção e exportação do arquivo `.p12`.
- `APPLE_PROVISIONING_PROFILE_APP_BASE64`: Perfil de provisionamento do tipo App Store para o App ID principal `com.frila.org.app`, codificado em Base64 (`base64 -i Frila_AppStore.mobileprovision`).
- `APPLE_PROVISIONING_PROFILE_NOTIFICATION_SERVICE_BASE64`: Perfil de provisionamento App Store para a extensão de push `com.frila.org.app.notificationservice`, codificado em Base64 (`base64 -i FrilaNotificationService_AppStore.mobileprovision`).

#### C. Configuração dos Ambientes de Backend
- `FRILA_SUPABASE_DEV_URL` e `FRILA_SUPABASE_DEV_PUBLISHABLE_KEY`: Credenciais publicáveis do ambiente `frila-dev` (para o esquema `Frila-Beta`).
- `FRILA_SUPABASE_PROD_URL` e `FRILA_SUPABASE_PROD_PUBLISHABLE_KEY`: Credenciais publicáveis do ambiente `frila-prod` (para o esquema `Frila-Prod`).
- `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_DEV_B64`: Arquivo `GoogleService-Info.plist` do Firebase de Desenvolvimento codificado em Base64.
- `FRILA_FIREBASE_GOOGLE_SERVICE_INFO_PROD_B64`: Arquivo `GoogleService-Info.plist` do Firebase de Produção codificado em Base64.

---

## 4. Como Disparar Manualmente o Fluxo do TestFlight

Para enviar um novo build para testadores sem precisar criar uma tag Git imediatamente:

1. Acesse o repositório **`FrilaApp/frila-frontend`** no GitHub pelo navegador.
2. Clique na aba superior **Actions**.
3. Na barra lateral esquerda (sob *Workflows*), selecione o fluxo **TestFlight**.
4. No canto superior direito, clique no menu suspenso **Run workflow**.
5. Preencha os campos com as opções da compilação:
   - **Use workflow from:** Selecione a branch `main`.
   - **Esquema:**
     - Escolha `Frila-Beta` caso o build deva apontar para a infraestrutura de desenvolvimento (`frila-dev`).
     - Escolha `Frila-Prod` caso o build deva conectar ao ambiente oficial de produção (`frila-prod`).
   - **Versão:** Digite a versão no padrão semântico `X.Y.Z` (exemplo: `0.4.0` ou `0.5.5`).
   - **Ensaio de falha:** Deixe **desmarcado** (`false`). *(Quando marcado como `true`, compila o botão de debug "Forçar falha" e restringe o build estritamente para testes internos).*
   - **Build de medição:** Deixe **desmarcado** (`false`). *(Quando marcado como `true`, habilita o instrumentador de rede do Cartão 84 apenas para uso interno).*
   - **Enviar ao TestFlight:** Deixe **marcado** (`true`) para efetuar o upload real ao App Store Connect. *(Se desmarcado, a CI realiza todo o archive, assinatura e símbolos para validação técnica, mas não envia à Apple).*
6. Clique no botão verde **Run workflow**.
7. O job iniciará sua execução na fila de runners macOS. O tempo médio de compilação, validação e upload é de aproximadamente **15 a 25 minutos**.

---

## 5. O que a CI Executa nos Bastidores

Ao ser acionado, o workflow realiza os seguintes passos em um runner limpo `macos-26` com Xcode fixado:
1. **Configuração de Identidade Efêmera:** Importa o certificado `.p12` em uma Keychain descartável criada sob demanda e instala os perfis de provisionamento em diretório temporário (`Scripts/assinatura-local-ci.py importar`).
2. **Geração do Projeto:** Executa `Scripts/gerar-projeto.sh` via XcodeGen, garantindo integridade dos alvos e do `Package.resolved`.
3. **Injeção de Credenciais de Ambiente:** Constrói os arquivos `Secrets.xcconfig` e os `GoogleService-Info.plist` correspondentes ao esquema escolhido.
4. **Archive e Export:** Executa `xcodebuild -archive` e `xcodebuild -exportArchive` aplicando os perfis manuais validados.
5. **Auditoria de Release:** O script `conferir-release.sh` inspeciona o `.ipa` extraído e confere criptografia, entitlements de produção (`aps-environment = production`), `get-task-allow = false` e ausência de códigos ou hooks de teste.
6. **Upload dos dSYMs ao Crashlytics:** O utilitário `upload-symbols` do SDK do Firebase envia os símbolos de depuração do `Frila.app` e dos frameworks (`FrilaDominio`, `FrilaDados`, `FrilaApresentacao`, `FrilaInfraestrutura`) para o Firebase Crashlytics do ambiente.
7. **Upload do Binário ao App Store Connect:** Executa o upload seguro autenticado pela chave `.p8` da API.
8. **Limpeza Segura Obrigatória:** O passo pós-execução (`always()`) deleta o keychain temporário, remove os perfis instalados, limpa a pasta de DerivedData e apaga as chaves da máquina.

---

## 6. Como Conferir o Processamento no App Store Connect

Após a conclusão verde do workflow no GitHub Actions:

1. Acesse o console da Apple em **[appstoreconnect.apple.com](https://appstoreconnect.apple.com/)**.
2. Faça login com suas credenciais do Apple Developer Program.
3. No painel principal, selecione **Apps** e clique no aplicativo **Frila**.
4. No menu superior, clique na aba **TestFlight**.
5. Na barra lateral esquerda, clique em **iOS** (sob a seção *Compilações* / *Builds*).
6. Localize o build enviado: ele aparecerá identificado pela Versão (ex.: `0.5.5`) e pelo número de build gerado pela data (ex.: `20261101.33000`).
7. **Status do Processamento:**
   - Inicialmente o build exibirá o status **Processando** (*Processing*).
   - O processamento automatizado da Apple para validação de segurança e análise de arquitetura leva entre **5 e 15 minutos**.
   - Atualize a página periodicamente. Assim que a Apple concluir a validação, o status mudará automaticamente para **Pronto para envio** ou **Pronto para teste** (*Ready to Test*).
   - Não é necessário preencher formulário de criptografia, pois o binário já traz a isenção de não-isenção configurada.

---

## 7. Como Conferir a Simbolização no Crashlytics

Para que relatórios de falhas inesperadas cheguem legíveis com as linhas exatas do código Swift, há duas etapas distintas:

### 7.1 Conferência do Envio de Símbolos (dSYMs)
1. Acesse o **Console do Firebase** em [console.firebase.google.com](https://console.firebase.google.com/).
2. Selecione o projeto associado ao ambiente correspondente (conforme configurado em `GoogleService-Info.plist` para Dev/Beta ou Prod).
3. No menu lateral esquerdo, navegue até **Release & Monitor > Crashlytics** e clique na aba superior **dSYMs**.
4. Verifique se o build enviado consta com status **OK** (símbolos processados sem triângulo amarelo de aviso *"Missing dSYM"*).
   - *Nota:* A CI executa o upload dos dSYMs durante o job via `upload-symbols` (`testflight.yml`).

### 7.2 Comprovação Efetiva da Simbolização de Falhas (Ensaio de Falha)
A simples presença de dSYMs no painel atesta o recebimento dos arquivos de símbolo, mas não substitui a comprovação funcional de que uma falha real chega desofuscada. O procedimento canônico e obrigatório do projeto para comprovar a simbolização é o **Ensaio de Falha do TestFlight** (`iOS/Docs/CI.md:339–349`):
1. No disparo manual do workflow (`testflight.yml`), ative a opção **Ensaio de falha** (`FRILA_ENSAIO_FALHA: true`). Esse parâmetro compila o botão especial `BotaoDeFalhaDoEnsaio` (`FalhaDoEnsaio.swift`) e marca a compilação como `testFlightInternalTestingOnly`.
2. Instale o build de ensaio no iPhone via TestFlight (grupo interno).
3. Toque em **Forçar falha (ensaio)** no canto inferior da tela. O aplicativo será encerrado intencionalmente.
4. Abra o aplicativo novamente, sem reinstalar (o envio do relatório de travamento ao Firebase ocorre no lançamento subsequente).
5. No painel do Crashlytics do projeto de desenvolvimento, confirme o registro da falha *"Falha forçada do ensaio do TestFlight"*, verificando se a pilha de execução (stack trace) aparece 100% legível com nomes de funções, arquivos (`FalhaDoEnsaio.swift`) e linhas de código Swift desofuscadas.
6. *Nota Operacional:* A execução deste ensaio em aparelho físico é uma tarefa de teste reservada para a homologação humana antes da liberação a grupos externos.

---

## 8. Atividades Reservadas a Pessoas Responsáveis (Governança e Política do Frila)

Embora a API da App Store Connect disponibilize endpoints para operações de gerenciamento de perfis, grupos beta e submissões, **por governança estrita do projeto Frila, integridade de segurança e política definida pelos sócios**, as seguintes ações são categoricamente reservadas a pessoas físicas responsáveis (Account Holder ou Admin):

1. **Aceitar Acordos Legais e Termos da Apple:** Qualquer atualização no *Apple Developer Program License Agreement* ou no *Paid Applications Agreement* exige anuência jurídica exclusiva do titular da conta (Account Holder, Cauê Carneiro ou João Paulo). A Apple bloqueia compilações do TestFlight enquanto houver termos pendentes.
2. **Emissão e Guarda de Certificados de Distribuição:** Os certificados `Apple Distribution` e suas chaves privadas `.p12` são gerados e mantidos manualmente por pessoa com perfil de Account Holder ou Admin. É estritamente proibida a criação automatizada de certificados na CI, mitigando qualquer risco de revogação inadvertida de perfis corporativos.
3. **Criação e Renovação de Perfis de Provisionamento:** A geração de perfis App Store no Developer Portal e a atualização periódica do `.mobileprovision` anual são realizadas e validadas manualmente.
4. **Governança de Grupos Externos no TestFlight:**
   - Adicionar ou remover e-mails de testadores externos convidados.
   - Criar e gerenciar links públicos de convite para os grupos de validação do piloto no Distrito Federal.
5. **Decisão de Submissão para Beta App Review:** A submissão inicial de compilações para revisão externa do TestFlight (*Beta App Review*) é iniciada intencionalmente por pessoa na interface web do App Store Connect, evitando abertura prematura de versões sem conferência humana.
6. **Aprovação Definitiva de Lançamento na App Store:** A liberação do build 1.0 para o público geral na App Store é uma decisão soberana e colegiada dos sócios do Frila.
