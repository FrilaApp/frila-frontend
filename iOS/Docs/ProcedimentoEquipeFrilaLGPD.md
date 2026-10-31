Revisado e aprovado pelo Jurídico do time (agente de IA, skill leis-do-brasil) em 31/10/2026. Não é parecer de advogado.

# Procedimento da Equipe Frila — Grupo Interno de Testes (LGPD e TestFlight)

Documento normativo e operacional de privacidade e proteção de dados para o grupo interno de testes do aplicativo iOS (**Equipe Frila**) no Apple TestFlight / App Store Connect, em conformidade com a Lei Geral de Proteção de Dados Pessoais (LGPD — Lei nº 13.709/2018), as diretrizes da Apple e as rotinas de engenharia do Frila.

> [!NOTE]
> **Contexto de Criação (J-001):** Este procedimento não existia como documento autônomo específico em `iOS/Docs`, encontrando-se fragmentado nas especificações de CI (`CI.md:259-266`, `RunbookProd.md:127`, `GapsTestFlight05.md:169`) e no manual operacional de suporte (`frila-backend/supabase/operacao/equipe-frila.md`). O presente texto consolida e formaliza a governança jurídica e operacional de testes internos.

---

## 1. Definição, Finalidade e Distinção de Grupos

1. **Definição:** O grupo **Equipe Frila** é o grupo interno oficial de homologação no TestFlight, composto estritamente pelos integrantes e colaboradores diretos do projeto Frila.
2. **Finalidade:** Homologação técnica antecipada, testes de regressão, validação de interface e controle de qualidade dos builds gerados pela branch `main` antes da liberação ao público externo (Art. 7º, V e IX da LGPD).
3. **Distinção do Grupo Externo:**
   - **Grupo Interno ("Equipe Frila"):** Exclusivo para até 100 membros da equipe interna, com acesso automático a todos os builds (`hasAccessToAllBuilds=true`), sem necessidade de aprovação prévia em revisão beta pela Apple (App Review).
   - **Grupo Externo ("Testadores Frila"):** Grupo aberto com link público limitado a 1.000 testadores voluntários (`GrupoExternoTestFlight.md`), com builds que obrigatoriamente passam pela revisão de teste beta da Apple e aceitam os Termos de Uso padrão do TestFlight.

---

## 2. Tratamento de Dados Pessoais dos Testadores Internos (ROPA)

| Dado Tratado | Finalidade | Base Legal (LGPD) | Armazenamento e Acesso | Retenção e Descarte |
|---|---|---|---|---|
| **E-mail (Apple ID)** | Envio de convites e provisionamento de acesso aos builds no TestFlight. | **Art. 7º, V**<br>(Execução de contrato / vínculo com a empresa) | App Store Connect / Apple Inc. | Enquanto mantido o vínculo com a equipe; removido imediatamente no desligamento. |
| **Identificador de Dispositivo e Logs de Falha** | Diagnóstico de travamentos durante testes internos via Firebase Crashlytics e Xcode Organizer. | **Art. 7º, IX**<br>(Legítimo interesse do controlador em estabilidade e segurança) | Firebase Crashlytics / Apple App Analytics | Descarte padrão do Crashlytics (90 dias); desvinculado de nomes e CPFs. |
| **Eventos de Teste (`evento_app`)** | Registro de jornada para validação de fluxos. Contas da equipe são identificadas no banco (`privado.conta_equipe`). | **Art. 7º, IX**<br>(Legítimo interesse) | Supabase Postgres (schema analítico) | 90 dias (rotina diária `privado.limpar_eventos_app`); expurgadas de relatórios públicos de conversão. |

---

## 3. Salvaguardas de Segurança e Diretrizes de Sigilo (RN15, RNF13)

1. **Proteção Rigorosa de Segredos no CI/CD:**
   - A gestão do grupo interno via automação (`app-store-connect.yml`) utiliza o script `Scripts/app-store-connect.rb`, que assina tokens JWT ES256 exclusivamente em memória. Nenhuma chave privada `.p8` ou segredo corporativo é persistido em disco ou exibido nos logs de execução do GitHub Actions.
   - O script `iOS/Scripts/conferir-release.sh` audita compilações e impede que arquivos de configuração sensíveis (`Secrets.xcconfig`, `.p8`) sejam empacotados no aplicativo.
2. **Uso Exclusivo de Dados de Teste:**
   - Durante os ciclos de teste no TestFlight, os testadores internos devem utilizar contas de teste e dados simulados (fixtures), sendo **estritamente vedado** inserir dados pessoais reais de clientes ou terceiros em ambientes de homologação sem consentimento específico.
3. **Desligamento e Revogação Imediata:**
   - Ao término da participação de qualquer colaborador no time, seu acesso ao grupo interno no App Store Connect e às credenciais do projeto é imediatamente revogado pelo sócio-administrador.

---

## 4. Ressalva Jurídica ("Precisa de Advogado")

- > [!IMPORTANT]
  > **Termo de Confidencialidade e Propriedade Intelectual ("Precisa de Advogado"):** *Precisa de advogado para elaborar termo formal de adesão a testes internos e acordo de confidencialidade (NDA) para colaboradores e eventuais testadores convidados que tenham acesso antecipado a segredos de negócio e funcionalidades proprietárias da plataforma.*