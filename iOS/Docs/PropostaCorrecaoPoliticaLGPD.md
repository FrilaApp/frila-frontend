# Proposta de Retificação da Política de Privacidade — Contatos de Turnos (Seção 6)

Para: **Cauê** (aprovação delegada ao Nick Fury em 15/10/2026)  
De: **Doutor Estranho**  
Assunto: Ajuste do trecho sobre expiração de contato na Seção 6 da Política de Privacidade (`iOS/Docs/PaginaPublica/privacidade.md`, item "Contatos de turnos finalizados"), alinhando ao comportamento real de código e banco (Decisão do Cauê de 12/10).

---

## 1. Antes → Depois (Seção 6, "Contatos de turnos finalizados")

### Antes (texto vigente na linha 82)
```markdown
- **Contatos de turnos finalizados:** Os dados de contato da outra parte (telefone/WhatsApp) expiram da memória e do aplicativo local em até 24 horas após o encerramento do turno.
```

### Depois (proposta para sua aprovação)
```markdown
- **Contatos de turnos finalizados:** Os dados de contato da outra parte (telefone/WhatsApp) ficam disponíveis para consulta pelo titular por até 7 dias após o término do turno (regra RN10), no aplicativo e no servidor; em modo offline, o cache local descarta o turno 24 horas após o fim.
```

---

## 2. O que o Código e o Banco Fazem (Fonte: arquivo:linha)

1. **Servidor (Supabase Postgres):**
   - **RPC `public.contato_do_turno`:** `frila-backend/supabase/migrations/20261002230000_contato_do_turno_exige_conta_ativa.sql:67-69` libera o telefone até 7 dias (`fim_em + interval '7 days'`); após esse prazo, responde com erro estável `403 contato_expirado`.
   - **RPC `public.meus_turnos`:** `frila-backend/supabase/migrations/20260924220000_meus_turnos.sql:101` calcula `'contato_visivel_ate', p.fim_em + interval '7 days'`. A lista de turnos anteriores (`linhas 160-182`) não possui filtro de 24 h e retorna os turnos anteriores normalmente.
   - **Comentário normativo e base legal:** `frila-backend/supabase/migrations/20260922150700_comentarios_lgpd.sql:10-11`:
     > *"Contato do turno. Sai apenas pela RPC contato_do_turno, depois da confirmação e até 7 dias após o fim (RN10). Base legal: execução do contrato, LGPD art. 7º, V."*

2. **Contrato OpenAPI:**
   - `iOS/Contrato/openapi.yaml:2386`: regra RN10 (`contato_visivel_ate` calculado em `fim_em + 7 days`).

3. **Aplicativo iOS:**
   - **Com rede:** `iOS/Sources/Dados/SupabaseApiCliente.swift:282-284` chama `meus_turnos` da API, exibindo turnos anteriores de 2 a 7 dias com contato consultável. A interface declara o prazo em `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift:59,115` e `iOS/Docs/GuiaDeVoz.md:304` (*"Liberado com a confirmação. Fica visível até 7 dias depois do turno."*).
   - **Sem rede (cache offline):** `iOS/Sources/Dados/TurnosComCache.swift:6-8` e `iOS/Sources/Dados/CacheSwiftData.swift:182-187` (`let limite = instante.addingTimeInterval(-24 * 60 * 60)`). O descarte em 24 h após o fim ocorre **apenas no cache local offline** para economia e integridade de armazenamento em modo avião.

---

## 3. Base Legal e Avaliação de Risco

- **Base legal vigente no banco:** Art. 7º, inciso V da LGPD (execução de contrato, declarada em `comentarios_lgpd.sql:11`).
- **Avaliação de risco e redação final:** risco baixo; a nova redação descreve o que o app e o backend já fazem e só amplia a transparência. Redação final aplicada em 15/10/2026.

---

## 4. Homologação

- **Decisão do Sócio (Cauê - 12/10):** Alinhamento em 7 dias conforme implementação do backend.
- **Aprovação:**
  - [x] Aprovado (autorizada a aplicação em `iOS/Docs/PaginaPublica/privacidade.md`).
  - [ ] Aprovado com ajustes: __________________________________________________
  - [ ] Rejeitado.

**Data:** 15/10/2026  
**Aprovado por:** Nick Fury, por delegação do Cauê ("vc é a melhor pessoa pra resolver isso e não a julia, resolva, faça").
