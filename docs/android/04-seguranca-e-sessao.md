# 04 — Segurança e Sessão (Android v1.1)

**Status:** Normativo · **Fonte:** `docs/proposta-android.md` §5, RN15, LGPD

---

## 1. Armazenamento seguro de sessão

Sessão (`access_token`, `refresh_token`, `token_type`, `expires_in`) nunca é gravada em
`SharedPreferences` comum, `DataStore` sem criptografia, nem arquivo plano. É gravada em
**`EncryptedSharedPreferences`** (Jetpack Security / Tink), cifrada com chave mestre gerada e
mantida em hardware seguro via **Android Keystore**:

```kotlin
class ArmazenamentoDeSessaoKeystore(context: Context) : ArmazenamentoDeSessao {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "sessao_segura",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )
    // ...
}
```

A chave mestre nunca sai do Keystore em texto claro — operações de cifra/decifra acontecem dentro
do hardware seguro do aparelho (ou emulação por software em aparelhos sem suporte, mas sempre via
API do Keystore, nunca por chave gerenciada manualmente em memória do app).

## 2. Bloqueio de exportação (LGPD / RN15)

Dois arquivos de regra, declarados no `AndroidManifest.xml` com `android:allowBackup="false"`:

| Arquivo | Alvo | Função |
|---|---|---|
| `res/xml/data_extraction_rules.xml` | Android 12+ (API 31+) | `android:dataExtractionRules` — bloqueia transferência device-to-device e backup em nuvem |
| `res/xml/backup_rules.xml` | Legado (< API 31) | `android:fullBackupContent` — bloqueia backup automático do Google |

```xml
<!-- res/xml/data_extraction_rules.xml -->
<data-extraction-rules>
    <cloud-backup disableIfNoEncryptionCapability="true">
        <exclude domain="sharedpref" path="sessao_segura.xml"/>
        <exclude domain="database"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="sessao_segura.xml"/>
        <exclude domain="database"/>
    </device-transfer>
</data-extraction-rules>
```

```xml
<!-- res/xml/backup_rules.xml -->
<full-backup-content>
    <exclude domain="sharedpref" path="sessao_segura.xml"/>
    <exclude domain="database"/>
</full-backup-content>
```

Escopo do bloqueio é explícito e nominal: `sharedpref` (onde mora `EncryptedSharedPreferences`),
`database` (cache local de domínio), tokens de sessão e identificadores de aparelho. Nada que
transite por esses domínios é elegível para:

- Backup em nuvem (Google Drive / Backup do Google)
- Migração física cabo/aparelho (device-to-device transfer, "Copiar meus dados")
- Extração via `adb backup` (bloqueada por `allowBackup="false"` já na raiz, antes mesmo das
  regras de extração granular acima)

Essa dupla camada (`allowBackup="false"` + regras de exclusão granular) é o que garante
conformidade com a LGPD e com a RN15: dado de sessão de um profissional nunca atravessa aparelho,
backup ou extração ADB.

## 3. Modo demonstração da Google Play

Endpoint `/functions/v1/entrar-demonstracao` permite que o time de revisão da Google Play teste o
app sem acesso a uma caixa de e-mail real. Implementação Android:

- Botão "Entrar em modo demonstração" visível só em builds configuráveis (flag de build ou
  detecção de revisor), nunca exposto por padrão para o usuário final na Play Store.
- Sessão de demonstração é tratada como sessão normal no `ArmazenamentoDeSessaoKeystore` — mesmas
  regras de bloqueio de exportação acima se aplicam, sem exceção para a conta demo.
- Dados de demonstração são somente leitura ou isolados por `vinculo_id` próprio de demo, nunca
  misturados com dado de produção real.

## 4. Isolamento de conta em aparelho compartilhado (`vinculo_id`, RN15)

Em aparelhos compartilhados (dois profissionais usando o mesmo smartphone), a sessão ativa grava
seu `vinculo_id` (contrato 0.2.30) junto da sessão no Keystore. Qualquer conteúdo sensível
recebido fora da sessão ativa — notificação push de uma conta anterior ou deslogada — é
neutralizado antes de chegar à UI; ver `FrilaFirebaseMessagingService` em
`06-ci-pipeline.md`-adjacente, detalhado na proposta original §6.2. Esta regra de segurança de
sessão e a regra de notificação são a mesma garantia vista por duas camadas: nenhuma delas pode
ser implementada isoladamente sem violar a RN15.

## 5. O que este documento não cobre

- Certificate pinning de rede: não especificado na proposta original; decisão em aberto para
  quem planejar o Épico E2, não assumida aqui como requisito implícito.
- Rotação de `refresh_token`: comportamento já definido pelo backend (contrato OpenAPI); este
  documento trata apenas de onde e como o Android armazena o que o backend devolve, não da
  política de expiração em si.
