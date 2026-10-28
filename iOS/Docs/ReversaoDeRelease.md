# Procedimento de Reversão de Release do Aplicativo iOS

> **Guia Técnico de Contingência.** Vinculado ao Brief P-005 e às rotinas operacionais do Frila.  
> **Status:** Documento técnico normativo para tratamento de incidentes e versões defeituosas do app.

---

## 1. Princípios de reversão na plataforma Apple

No ambiente iOS e na App Store, não existe o conceito de reversão retroativa direta (*rollback* de binário). A Apple não permite despublicar uma versão em produção para restaurar uma versão anterior já aprovada.

Portanto, qualquer procedimento de reversão de versão defeituosa combina obrigatoriamente duas frentes:
1. **Contenção imediata no backend:** Bloqueio das versões afetadas via `versao_minima` no banco de dados, forçando a exibição da tela de atualização obrigatória nos aparelhos dos usuários;
2. **Correção estritamente à frente (*Forward Fix*):** Geração, compilação e publicação ágil de um novo build corretivo com numeração de versão superior na App Store Connect.

---

## 2. Procedimento numerado de reversão

```
[Defeito Crítico Detectado]
       │
       ▼
1. Bloqueio no Banco (versao_minima em configuracao_app superior à defeituosa)
       │
       ▼
2. Contenção na Loja (Pausar Phased Release / Expirar Build TestFlight)
       │
       ▼
3. Build Corretivo (Incrementar versão + Tag vX.Y.Z na main + ESQUEMA_DA_TAG em testflight.yml)
       │
       ▼
4. Solicitação de Aceleração (Expedited Review na Apple)
       │
       ▼
5. Publicação e Desbloqueio (Atualizar versao_minima para o novo build)
```

---

### Passo 1: Bloqueio emergencial de versão no backend

Assim que um defeito impeditivo for confirmado (vazamento de dados, falha grave de integridade ou travamento generalizado):

- **Ação:** O operador executa a atualização emergencial da tabela `privado.configuracao_app` no banco Supabase de produção (`frila-prod`). A operação é uma instrução DML pontual de uma linha, isenta das restrições de horário da regra RNF12 (fonte: `subir-versao-minima.md:24-37` no `frila-backend`).
- **Lógica de bloqueio por versão mínima:**
  - O aplicativo compara se `versao_instalada >= versao_minima`.
  - Para bloquear uma versão defeituosa (ex.: `1.0.1`), a `versao_minima` deve ser definida obrigatoriamente para um valor estritamente superior à versão com falha (ex.: `1.0.2` ou a versão corretiva planejada).
  - Definir uma versão anterior (ex.: `1.0.0`) **não** bloquearia a versão defeituosa `1.0.1`.
  - **Efeito colateral obrigatório:** Ao elevar a versão mínima acima da versão defeituosa, todas as versões anteriores (mesmo as saudáveis, como `1.0.0`) também serão barradas pela tela de atualização obrigatória até que os usuários instalem o novo build corretivo.
- **Comando SQL:**
  ```sql
  update privado.configuracao_app
     set versao_minima      = '<versao_superior_a_defeituosa>',
         versao_recomendada = '<versao_superior_a_defeituosa>',
         mensagem           = 'Versão descontinuada para manutenção preventiva. Por favor, atualize o aplicativo.',
         atualizado_em      = now()
   where plataforma = 'ios';
  ```
- **Definição da tabela e RPC (fonte: `subir-versao-minima.md:39-49`):**
  - A tabela `privado.configuracao_app` possui RLS ativo sem políticas e permissões revogadas para `public`, `anon` e `authenticated`. Apenas operadores com papel administrativo (`postgres` ou `service_role`) podem alterá-la.
  - O banco aplica restrições `CHECK` de integridade (`versao_minima_formato`, `versao_recomendada_formato`, `recomendada_nao_abaixo_da_minima`, `url_da_loja_https` e `mensagem_nao_vazia`). A versão deve conter apenas números e pontos (ex.: `1.0.2`, nunca `v1.0.2`).
  - A leitura é exposta sem sessão pela RPC pública `public.configuracao_do_app(text)` via PostgREST: `GET /rest/v1/rpc/configuracao_do_app?plataforma=ios`.
- **Efeito no app:** Os aparelhos que abrirem o app recebem a resposta da RPC e exibem a tela de bloqueio com botão de redirecionamento para a App Store. Aparelhos em uso offline só serão bloqueados na próxima tentativa com rede (fonte: `subir-versao-minima.md:5`).
- **Comprovação em teste local (HTTP anônimo e SQL):**
  - Chamada HTTP sem sessão via PostgREST/Kong no ambiente local:
    ```bash
    curl -s "http://127.0.0.1:54321/rest/v1/rpc/configuracao_do_app?plataforma=ios"
    ```
  - Retorno HTTP 200 comprovando leitura pública anônima imediata:
    ```json
    {"mensagem": null, "plataforma": "ios", "url_da_loja": "https://apps.apple.com/app/id6815311991", "versao_minima": "0.1.0", "versao_recomendada": "0.1.0"}
    ```
  - Teste de mutação DML no Postgres via container `supabase_db_frila-backend`: executado `BEGIN; UPDATE privado.configuracao_app SET versao_minima = '1.0.2'; SELECT public.configuracao_do_app('ios'); ROLLBACK;`, confirmando atualização atômica e reflexo imediato sem cache.
- **Quem executa:** Engenheiro de Backend ou Administrador de Banco (`cauecarneiro` ou `jotape12-Dev`).

### Passo 2: Contenção de distribuição na App Store Connect

- **Cenário A: Build em TestFlight (Testadores internos ou externos)**
  - Acessar o console do App Store Connect: menu **TestFlight** > **iOS**.
  - Selecionar o número do build com falha e acionar a opção **Expirar Build** (*Expire Build*).
  - *Efeito:* O build é imediatamente desativado para novas instalações e bloqueado para os testadores existentes.
  - *Quem executa:* Titular da conta Apple Developer (`cauecarneiro`).
  - *Verificabilidade:* **A confirmar por quem tem acesso** (depende de credenciais e autenticação 2FA no console da Apple).

- **Cenário B: Versão publicada na App Store em Liberação Gradual (*Phased Release*)**
  - Se a versão estiver em fase de liberação gradual de 7 dias: pausar imediatamente a distribuição acionando **Pausar Liberação Gradual** (*Pause Phased Release*).
  - *Efeito:* Impede que novos usuários recebam a atualização automática enquanto o problema é solucionado.
  - *Quem executa:* Titular da conta Apple Developer (`cauecarneiro`).
  - *Verificabilidade:* **A confirmar por quem tem acesso**.

- **Cenário C: Versão 100% liberada na App Store**
  - Manter o bloqueio ativo via `versao_minima` do Passo 1.
  - Em situações extremas de violação legal iminente, remover temporariamente o app de comercialização em **Preço e Disponibilidade** > **Remover da Venda** (*Remove from Sale*).
  - *Quem executa:* Titular da conta Apple Developer (`cauecarneiro`).
  - *Verificabilidade:* **A confirmar por quem tem acesso**.

### Passo 3: Geração do build corretivo, tag na main e `ESQUEMA_DA_TAG`

- **Versionamento no projeto:**
  - Editar `iOS/project.yml`, incrementando a versão comercial (`MARKETING_VERSION`, ex.: de `1.0.1` para `1.0.2`) e o número sequencial de build (`CURRENT_PROJECT_VERSION`).
  - A App Store Connect rejeita qualquer novo upload cujo build seja menor ou igual a versões já enviadas.
- **Exigência de commit na branch `main` (fonte: `CI.md:95-110`):**
  - O workflow `.github/workflows/testflight.yml` exige obrigatoriamente que a tag `vX.Y.Z` esteja apontando para um commit já integrado à branch `main`.
  - Tags criadas em branches secundárias ou fora da `main` são rejeitadas pela esteira de CI.
  - O formato da tag deve casar estritamente com `vX.Y.Z`, onde `X.Y.Z` é idêntico à `MARKETING_VERSION` definida em `iOS/project.yml`.
- **O papel do `ESQUEMA_DA_TAG` no workflow:**
  - O parâmetro de ambiente `ESQUEMA_DA_TAG` em `.github/workflows/testflight.yml` define o destino da compilação:
    - `ESQUEMA_DA_TAG: Frila-Beta` direciona o app para o ambiente de homologação (`frila-dev`).
    - `ESQUEMA_DA_TAG: Frila-Prod` direciona o app para o ambiente de produção (`frila-prod`) com chaves de produção (conforme documentado em [RunbookProd.md](RunbookProd.md#L63) e [CI.md](CI.md#L105)).
  - Ao preparar uma reversão para produção, o operador deve garantir que `testflight.yml` esteja configurado com `ESQUEMA_DA_TAG: Frila-Prod` antes de subir a tag corretiva.
- **Procedimento para publicação da tag corretiva:**
  1. Integrar o PR com a correção e o incremento de versão à branch `main`;
  2. Atualizar a branch local `main` e criar a tag correspondente:
     ```bash
     git checkout main
     git pull origin main
     git tag v1.0.2
     git push origin v1.0.2
     ```
- **Quem executa:** Engenheiro iOS (`silvaaszx` ou `cauecarneiro`).

### Passo 4: Solicitação de Revisão Acelerada (*Expedited Review*)

- Após o processamento do binário no App Store Connect, submeter a versão `1.0.2` para análise.
- Acessar o formulário oficial de **Expedited App Review** na Apple Developer Network informando:
  - Tipo de urgência: Correção crítica de bug em produção / Falha de segurança;
  - Descrição objetiva do problema sanado e impacto evitado.
- **Quem executa:** Titular da conta Apple Developer (`cauecarneiro`).
- **Verificabilidade:** **A confirmar por quem tem acesso** (o tempo de resposta e deferimento da aceleração é discricionário da equipe de revisão da Apple).

### Passo 5: Publicação e conciliação pós-incidente

- Assim que a versão corretiva for aprovada pela Apple e disponibilizada na App Store:
  1. No banco de dados Supabase de produção, atualizar a configuração do app ajustando a versão mínima para a nova versão e limpando a mensagem de bloqueio:
     ```sql
     update privado.configuracao_app
        set versao_minima      = '1.0.2',
            versao_recomendada = '1.0.2',
            mensagem           = null,
            atualizado_em      = now()
      where plataforma = 'ios';
     ```
  2. Caso o incidente tenha envolvido necessidade de reversão estrutural no banco de dados, aplicar o procedimento canônico de *Forward Fix* de migrações (conforme seção 6 do RUNBOOK-INCIDENTES do `frila-backend`), mantendo a imutabilidade linear do histórico do banco.
  3. Registrar a ocorrência do incidente no histórico do projeto para acompanhamento da equipe.
- **Quem executa:** Engenheiro de Backend e Engenheiro iOS.

---

## 3. Matriz de responsabilidades na reversão

| Etapa | Ação principal | Responsável | Verificabilidade no repositório |
|---|---|---|---|
| **1. Bloqueio no Banco** | Update em `privado.configuracao_app` | Backend / DBA | Verificável via SQL e HTTP anônimo |
| **2. Contenção TestFlight** | Expirar build problemático | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **3. Contenção App Store** | Pausar Phased Release | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **4. Build Corretivo** | Subir versão em `project.yml` e tag na main | Engenheiro iOS | Verificável no Git e GitHub Actions |
| **5. Direcionamento CI** | Conferir `ESQUEMA_DA_TAG: Frila-Prod` | Engenheiro iOS | Verificável em `.github/workflows/testflight.yml` |
| **6. Aceleração Apple** | Pedido de Expedited Review | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **7. Desbloqueio Final** | Atualizar `versao_minima` para o fix | Backend / DBA | Verificável via consulta à RPC pública |
