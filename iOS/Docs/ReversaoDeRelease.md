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
1. Bloqueio no Banco (versao_minima em configuracao_app)
       │
       ▼
2. Contenção na Loja (Pausar Phased Release / Expirar Build TestFlight)
       │
       ▼
3. Build Corretivo (Incrementar versão + ESQUEMA_DA_TAG em testflight.yml)
       │
       ▼
4. Submissão e Expedited Review na App Store Connect
       │
       ▼
5. Publicação do Build Corretivo e Liberação da versao_minima
```

### Passo 1: Bloqueio imediato via `versao_minima` no backend

Assim que um defeito impeditivo for confirmado (vazamento de dados, falha grave de integridade ou travamento generalizado):

- **Ação:** O operador executa a atualização emergencial da tabela `privado.configuracao_app` no banco Supabase de produção (`frila-prod`). A operação é uma instrução DML pontual de uma linha, isenta das restrições de horário da regra RNF12 (fonte: `subir-versao-minima.md` no `frila-backend`).
- **Comando SQL:**
  ```sql
  update privado.configuracao_app
     set versao_minima      = '<versao_estavel_ou_corretiva>',
         versao_recomendada = '<versao_estavel_ou_corretiva>',
         mensagem           = 'Versão descontinuada para manutenção preventiva. Por favor, atualize o aplicativo.',
         atualizado_em      = now()
   where plataforma = 'ios';
  ```
- **Efeito no app:** Os aparelhos que abrirem o app recebem a resposta da RPC `public.configuracao_do_app('ios')` e exibem a tela de bloqueio com botão de redirecionamento para a App Store. Aparelhos em uso offline só serão bloqueados na próxima tentativa com rede (fonte: `subir-versao-minima.md:5`).
- **Comprovação em teste:** Procedimento testado e validado com sucesso no container local do Postgres (`supabase_db_frila-backend`), confirmando que o PostgREST reflete os novos parâmetros imediatamente na chamada sem sessão.
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

### Passo 3: Geração do build corretivo e papel do `ESQUEMA_DA_TAG`

- **Versionamento no projeto:**
  - Editar `iOS/project.yml`, incrementando a versão comercial (`MARKETING_VERSION`, ex.: de `1.0.0` para `1.0.1`) e o número sequencial de build (`CURRENT_PROJECT_VERSION`).
  - A App Store Connect rejeita qualquer novo upload cujo build seja menor ou igual a versões já enviadas.
- **O papel do `ESQUEMA_DA_TAG` no workflow:**
  - A esteira de integração e entrega contínua em `.github/workflows/testflight.yml` compila e envia o binário para o TestFlight quando uma tag Git que casa com o padrão `v*` é publicada.
  - O parâmetro de ambiente `ESQUEMA_DA_TAG` define o destino da compilação:
    - `ESQUEMA_DA_TAG: Frila-Beta` direciona o app para o ambiente de homologação (`frila-dev`).
    - `ESQUEMA_DA_TAG: Frila-Prod` direciona o app para o ambiente de produção (`frila-prod`) com chaves de produção (conforme documentado em [RunbookProd.md](RunbookProd.md#L63) e [CI.md](CI.md#L105)).
  - Ao preparar uma reversão para produção, o operador deve garantir que `testflight.yml` esteja configurado com `ESQUEMA_DA_TAG: Frila-Prod` antes de subir a tag corretiva.
- **Criação da tag de release corretiva:**
  ```bash
  git tag v1.0.1
  git push origin v1.0.1
  ```
- **Quem executa:** Engenheiro iOS (`silvaaszx` ou `cauecarneiro`).

### Passo 4: Solicitação de Revisão Acelerada (*Expedited Review*)

- Após o processamento do binário no App Store Connect, submeter a versão `1.0.1` para análise.
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
        set versao_minima      = '1.0.1',
            versao_recomendada = '1.0.1',
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
| **1. Bloqueio no Banco** | Update em `privado.configuracao_app` | Backend / DBA | Verificável via SQL local e remoto |
| **2. Contenção TestFlight** | Expirar build problemático | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **3. Contenção App Store** | Pausar Phased Release | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **4. Build Corretivo** | Subir versão em `project.yml` e tag | Engenheiro iOS | Verificável no Git e GitHub Actions |
| **5. Direcionamento CI** | Conferir `ESQUEMA_DA_TAG: Frila-Prod` | Engenheiro iOS | Verificável em `.github/workflows/testflight.yml` |
| **6. Aceleração Apple** | Pedido de Expedited Review | Dono da conta Apple | **A confirmar por quem tem acesso** |
| **7. Desbloqueio Final** | Atualizar `versao_minima` para o fix | Backend / DBA | Verificável via consulta à RPC pública |
