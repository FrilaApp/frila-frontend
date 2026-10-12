# Proposta de Retificação da Política de Privacidade — Janela de Contatos de Turnos (LGPD / RN10)

> [!IMPORTANT]
> **DOCUMENTO PARA APRECIAÇÃO JURÍDICA EXCLUSIVA DA JÚLIA**  
> Este documento submete formalmente à aprovação da responsável jurídica (**Júlia**) a proposta de retificação textual da Política de Privacidade pública do Frila (`iOS/Docs/PaginaPublica/privacidade.md`).  
> **Conforme a Decisão do Cauê (12/10/2026):** Alinhamento técnico mantido estritamente ao que o backend e contrato já implementam hoje (**7 dias**, regra RN10), sem alterar o backend nem o código. A política pública vigente **não foi alterada nem publicada**; a retificação depende da homologação desta minuta.

---

## 1. Identificação do Ponto de Retificação

| Item | Descrição |
|---|---|
| **Documento Alvo** | `iOS/Docs/PaginaPublica/privacidade.md` (espelho da página institucional pública `https://frila.app/privacidade`, documentado em `FichaAppStore.md:115`) |
| **Seção Alvo** | Seção 6 (*"Por quanto tempo guardamos seus dados (Retenção e Descarte)"*), linha 82 |
| **Objeto do Tratamento** | Dados de contato operacional direto (Nome, Telefone e link sanitizado de WhatsApp) liberados entre profissional e contratante após a confirmação do turno |
| **Regra de Negócio** | **RN10** (*"Liberação de contato pós-confirmação e expiração em 7 dias"*) |
| **Base Legal (LGPD)** | **Art. 7º, inciso V** (Execução de contrato do qual seja parte o titular, a seu pedido) |

---

## 2. Comparativo Textual: Antes × Depois

### Texto Vigente na Política (`privacidade.md:82`) — ANTES
```markdown
- **Contatos de turnos finalizados:** Os dados de contato da outra parte (telefone/WhatsApp) expiram da memória e do aplicativo local em até 24 horas após o encerramento do turno.
```

### Texto Proposto para Aprovação da Júlia — DEPOIS
```markdown
- **Contatos de turnos finalizados:** O aplicativo oculta os dados de contato da outra parte (telefone/WhatsApp) em até 24 horas após o encerramento do turno; o servidor os mantém acessíveis para consulta pelo titular participante por até 7 (sete) dias após o término, expirando o acesso em definitivo após esse prazo.
```

---

## 3. Rastreabilidade Técnica e Fontes Verificadas

A redação proposta espelha com exatidão a arquitetura de dois níveis (cliente e servidor) implementada na plataforma:

1. **No Backend Supabase (`frila-backend`):**
   - **Arquivo e Linhas:** `frila-backend/supabase/migrations/20261002230000_contato_do_turno_exige_conta_ativa.sql:67-69`.
   - **Lógica da RPC `public.contato_do_turno`:**
     ```sql
     if privado.agora() > v_pos.fim_em + interval '7 days' then
       perform public.erro(403, 'contato_expirado');
     end if;
     ```
   - **Comentário Normativo no Banco:** `20260922150700_comentarios_lgpd.sql:10-11` (*"Contato do turno. Sai apenas pela RPC contato_do_turno, depois da confirmação e até 7 dias após o fim (RN10). Base legal: execução do contrato, LGPD art. 7º, V."*).
   - **Segurança de Acesso:** A função exige conta ativa (`privado.exigir_conta_ativa()`), valida pertinência ao turno (`v_sou_prof` ou `privado.eh_membro(v_estab)`), bloqueia em caso de bloqueio mútuo (RF26) e retorna erro `404` para não-participantes.

2. **No Contrato OpenAPI (`frila-docs` e `frila-frontend`):**
   - **Arquivo e Linha:** `iOS/Contrato/openapi.yaml:4498`.
   - **Propriedade:** `contato_visivel_ate` calculado como `fim_em + 7 days`.

3. **No Aplicativo Móvel iOS (`frila-frontend`):**
   - **Expurgo do Cache Local em 24 h:** `iOS/Sources/Dados/TurnosComCache.swift:6-8` e `iOS/Sources/Dados/CacheSwiftData.swift:183-187` (`let limite = instante.addingTimeInterval(-24 * 60 * 60)`). Turnos finalizados e seus dados locais são purgados do cache do dispositivo 24 horas após o horário de término.
   - **Textos de Interface com o Usuário:**
     - `iOS/Sources/Apresentacao/Fluxos/Profissional/TextosDoProfissional.swift`: `lembretesEVisibilidade` e `contatoLiberado` informam: *"Liberado com a confirmação. Fica visível até 7 dias depois do turno."*.
     - `iOS/Docs/GuiaDeVoz.md:304`: *"Liberado com a confirmação. Fica visível até 7 dias depois do término do turno."*.

---

## 4. Justificativa Jurídico-Operacional

1. **Por que 7 dias no Servidor:**  
   No setor de gastronomia e eventos (bares, restaurantes, bufês), a prestação de serviços avulsos frequentemente demanda acertos pós-turno nos dias subsequentes (esclarecimento de itens deixados no local, conferência de horas extras ou resolução amigável de divergências sobre o pagamento direto da diária). Uma janela estrita de 24 horas no servidor forçaria a judicialização ou a abertura de chamados desnecessários de suporte para contato básico entre as partes. A janela de 7 dias atende à finalidade operacional (Art. 6º, I da LGPD) sob a base legal de execução de contrato (Art. 7º, V da LGPD).

2. **Por que 24 horas no Aplicativo:**  
   Para atender ao princípio da segurança (Art. 6º, VII) e evitar exposição desnecessária em caso de extravio do aparelho, o aplicativo móvel descarrega o histórico ativo do turno de sua interface primária em 24 horas após o encerramento. Caso o titular necessite do contato entre o 2º e o 7º dia, a chamada autenticada à API recupera as informações pela RPC segura.

3. **Eliminação do Descompasso:**  
   Com a retificação proposta, a Política de Privacidade passa a declarar a verdade técnica de ponta a ponta: o app oculta localmente em 24 h e o servidor expira a permissão em 7 dias, eliminando qualquer risco de apontamento de publicidade enganosa ou descumprimento de dever de informação (Art. 6º, VI e Art. 9º da LGPD).

---

## 5. Parecer e Homologação da Responsável Jurídica

- **Decisão do Sócio (Cauê - 12/10/2026):** Acatada a recomendação de alinhamento em 7 dias conforme implementação do backend.
- **Avaliação da Responsável Jurídica (Júlia):**
  - [ ] Aprovado na íntegra (autorizada a aplicação em `iOS/Docs/PaginaPublica/privacidade.md`).
  - [ ] Aprovado com ressalvas textuais: __________________________________________________
  - [ ] Rejeitado.

**Data de Apreciação:** `[A DEFINIR: Júlia]`  
**Assinatura / Deferimento:** `[A DEFINIR: Júlia]`
