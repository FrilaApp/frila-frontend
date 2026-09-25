# Roteador de Orquestração — Codex (orquestrador) × Claude Code (workers)

> Documento operacional do projeto `frila-frontend` no Agent Orchestrator (AO).
> Última verificação: **2026-09-25** — AO daemon `dev`, Claude Code `2.1.282`, codex-cli `0.154.0`.
> **Regra de ouro:** quando este documento e a "memória" de um modelo divergirem sobre nomes de modelo,
> flags ou versões, **vale este documento** (e, acima dele, a saída real dos comandos de verificação da §3).

---

## 1. Papéis

| Papel | Harness | O que faz | O que **não** faz |
|---|---|---|---|
| **Orquestrador** | `codex` | Inspeciona estado, quebra a demanda em tarefas, spawna/redireciona workers, roteia CI e review, resume para o humano | Editar código, commitar, push, abrir PR, resolver conflito |
| **Worker** | `claude-code` | Executa uma tarefa especializada num worktree isolado, verifica, abre/atualiza PR quando autorizado | Coordenar outros workers, mudar escopo sem avisar |
| **Reviewer** (opcional) | configurável | Revisa o PR de um worker (`ao review trigger`) | Implementar correções |

Configuração atual do projeto (`ao project get frila-frontend --json`):

```json
{ "worker": { "agent": "claude-code" }, "orchestrator": { "agent": "codex" } }
```

---

## 2. Incidente de referência: "o Sonnet 5 não funciona"

**Sintoma:** o orquestrador reportou que "`sonnet-5` não está disponível" e sugeriu voltar para Sonnet 4.5.

**Causa real:** o orquestrador spawnou os workers com `--model sonnet-5` — **um ID que não existe**.
O Sonnet 5 existe, é o Sonnet mais atual, e funciona. Verificado em 2026-09-25:

| `--model` | Resultado |
|---|---|
| `sonnet-5` | ❌ `[claude-code:unrecognized_model] "sonnet-5" isn't described by this version's model catalog` |
| `claude-sonnet-5` | ✅ resolve para `claude-sonnet-5` |
| `sonnet` | ✅ resolve para `claude-sonnet-5` |

**Lição:** o erro foi de *nome*, não de *disponibilidade*. O Codex tem corte de conhecimento anterior à família
Claude 5 e "adivinhou" um ID no formato errado; depois interpretou o erro como falta de acesso.
Nunca rebaixe o modelo por causa de um erro de ID — corrija o ID.

---

## 3. Tabela de modelos válidos

### 3.1 Claude Code (workers)

Use **alias** sempre que possível — o alias acompanha a versão mais nova automaticamente.

| Uso | Alias (preferido) | ID completo | Observação |
|---|---|---|---|
| Padrão de implementação | `sonnet` | `claude-sonnet-5` | Janela de 1M nativa. Custo menor |
| Raciocínio pesado / arquitetura | `opus` | `claude-opus-5-5` | Default da conta |
| Opus com 1M explícito | `opus[1m]` | `claude-opus-5-5[1m]` | |
| Tarefas longas e autônomas | `fable` | `claude-fable-5-1` | Mais caro |
| Tarefas mecânicas / rápidas | `haiku` | `claude-haiku-4-5` | Haiku ainda é 4.5 |
| Plano em Opus, execução em Sonnet | `opusplan` | — | |

**IDs que falham** (testados em 2026-09-25 com `claude -p --model`): `sonnet-5`, `opus-5.5`, `claude-opus-4`.
Atenção: o exemplo da própria doc do AO (`/guides/per-role-agents/`) usa `"claude-opus-4"` — **não copie**.
Também não trate `claude-sonnet-4-5` como "o Sonnet mais recente": é duas gerações atrás.

Catálogo que o AO usa para o Claude Code (aliases): `fable`, `haiku`, `opus`, `opus[1m]`, `sonnet` (default).
O AO aceita IDs customizados (`allowCustom: true`), então um ID errado **não é barrado no spawn** — só falha
quando o worker tenta rodar. Por isso a verificação da §3.3 importa.

### 3.2 Codex (orquestrador)

| Slug | Esforços suportados | Default |
|---|---|---|
| `gpt-6-astra` | low · medium · high · xhigh · max · ultra | low (default do catálogo AO) |
| `gpt-5.6-sol` | low · medium · high · xhigh · max · ultra | low |
| `gpt-5.6-terra` | low · medium · high · xhigh · max · ultra | medium (**atual em `~/.codex/config.toml`, esforço `high`**) |
| `gpt-5.6-luna` | low · medium · high · xhigh · max | medium |
| `gpt-5.5` | low · medium · high · xhigh | medium |

### 3.3 Como verificar antes de afirmar que um modelo "não funciona"

```bash
# Catálogo de modelos que o AO conhece por harness
sqlite3 ~/.ao/data/ao.db "select agent_id, catalog_json from agent_model_catalog where project_id='frila-frontend'"

# Harnesses instalados e autenticados
ao agent ls

# Teste real e barato de um ID de modelo do Claude Code (1 turno)
claude -p --model claude-sonnet-5 --max-turns 1 "Responda só com o ID do seu modelo."

# Catálogo real do Codex, com níveis de esforço
codex debug models
```

Só reporte "modelo indisponível" ao humano se o teste real falhar com erro de **acesso/cota**
(não com `unrecognized_model`, que é erro de digitação).

---

## 4. Roteador: tipo de tarefa → worker, modelo e esforço

| Tipo de tarefa | `--agent` | `--model` | Esforço sugerido |
|---|---|---|---|
| Feature/UI comum, ajuste de tela, bugfix localizado | `claude-code` | `sonnet` | high |
| Refatoração ampla, arquitetura, migração, bug difícil | `claude-code` | `opus` | high / xhigh |
| Auditoria de segurança, review profundo (read-only) | `claude-code` | `opus` | xhigh |
| Tarefa longa e autônoma (muitos arquivos, várias horas) | `claude-code` | `fable` | high |
| Mecânica: renomear, formatar, atualizar docs/strings | `claude-code` | `haiku` | low / medium |
| Correção de CI / resposta a comentário de review | mesmo worker dono do PR | (manter) | (manter) |
| Segunda opinião de outro fornecedor | `codex` | `gpt-5.6-terra` | high |

Se o humano pedir um modelo explicitamente, use exatamente o que ele pediu (convertendo para o ID válido
da §3). Não troque de modelo por conta própria; se falhar, reporte o erro literal e pergunte.

### 4.1 Como controlar o esforço (effort)

`ao spawn` **não tem flag de esforço**. Opções, da mais granular para a mais ampla:

1. **Por modelo, no repositório** — `.claude/settings.json` do repo (vale para todo worker Claude Code):
   ```json
   {
     "modelSettings": {
       "claude-sonnet-5": { "effort": "high" },
       "claude-opus-5-5": { "effort": "xhigh" },
       "claude-haiku-4-5": { "effort": "low" }
     }
   }
   ```
   Assim, escolher o modelo no spawn já implica o esforço. *(Não validado ainda dentro do AO.)*
2. **Por projeto, via env** — `CLAUDE_CODE_EFFORT_LEVEL=<low|medium|high|xhigh|max>` com
   `ao project set-config ... --env` (vale para todas as sessões do projeto).
3. **Dentro da sessão** — o worker/humano pode rodar `/effort <nível>` numa sessão em modo TUI.

Níveis do Claude Code: `low` · `medium` · `high` · `xhigh` · `max` · `ultracode`.
No Codex: `-c model_reasoning_effort="high"` ou `model_reasoning_effort` em `~/.codex/config.toml`.

---

## 5. Roteador de comandos por momento do ciclo

| Momento | Comando | Observação |
|---|---|---|
| Início de qualquer rodada | `ao status` | Sempre antes de spawnar, para não duplicar trabalho |
| Ver workers do projeto | `ao session ls --project frila-frontend` | `--all` mostra o orquestrador |
| Detalhar um worker | `ao session get <id>` | Inclui modelo, harness, prompt, última atualização |
| Nova tarefa livre | `ao spawn --project frila-frontend --name "<≤20 chars>" --agent claude-code --model sonnet --prompt "<tarefa>"` | Conte os caracteres do `--name` |
| Nova tarefa de issue | `ao spawn --project frila-frontend --name "<≤20>" --issue <n> --model sonnet` | |
| Corrigir rumo de um worker | `ao send --session <id> --message "<instrução>"` | Nunca escrever direto em tmux/PTY |
| CI falhou | `ao send --session <dono-do-PR> --message "<log da falha>"` | O AO também injeta CI automaticamente |
| Pedir review do PR | `ao review trigger <worker-id>` · `ao review ls <worker-id>` | |
| Continuar PR existente | `ao session claim-pr <worker-id> <pr>` | Nunca no orquestrador |
| Trocar o harness de um worker vivo | `ao session switch-agent <id> <harness>` | |
| Agente saiu, sessão viva | `ao session resume-agent <id>` | |
| Sessão terminada, relançar | `ao session restore <id>` | |
| Trocar o **modelo** de um worker | `ao session kill <id>` + novo `ao spawn --model <válido>` | Não há troca de modelo em sessão viva via CLI |
| Encerrar | `ao session kill <id>` · `ao session cleanup` | |
| Algo estranho no AO | `ao doctor` · `ao agent ls` | |
| Mudar defaults do projeto | `ao project set-config frila-frontend --config-json '<json completo>'` | **Substitui o config inteiro** — parta do `ao project get --json` |

---

## 6. Como escrever o prompt de um worker (cargas de habilidade)

Todo `--prompt` deve conter:

1. **Objetivo** em uma frase e o **resultado esperado** (ex.: "PR com X", "relatório em markdown, sem editar arquivos").
2. **Escopo e limites**: pastas/arquivos, o que não tocar, se pode publicar (commit/push/PR) ou é *read-only*.
3. **Habilidades a carregar**: skills do Claude Code relevantes (ex.: "use a skill de revisão de segurança",
   "consulte `iOS/Docs/Architecture.md` e `iOS/Docs/DesignSystem.md` antes de editar").
4. **Critério de pronto**: como verificar (build, testes, screenshot via `ao preview`/`ao browser`).
5. **Formato do retorno** para o orquestrador consolidar.

Um worker = uma especialidade. Para trabalho paralelo, spawne vários workers com escopos que não se sobrepõem.

---

## 7. Recuperação do incidente atual

Os workers `frila-frontend-2` (`sec-audit-auth`) e `frila-frontend-3` (`sec-audit-web`) foram criados com
`model = sonnet-5` e não executaram. Para corrigir:

```bash
ao session kill frila-frontend-2
ao session kill frila-frontend-3
ao spawn --project frila-frontend --name "sec-audit-auth" --agent claude-code --model sonnet --prompt "<mesmo prompt de antes>"
ao spawn --project frila-frontend --name "sec-audit-web"  --agent claude-code --model sonnet --prompt "<mesmo prompt de antes>"
```

(Os prompts originais podem ser recuperados com `ao session get <id>`.)

---

## 8. Fontes

- Agent Orchestrator: <https://docs.aoagents.dev/> — CLI (`/cli/`), per-role agents (`/guides/per-role-agents/`), projects config (`/configuration/projects/`)
- Claude Code: <https://code.claude.com/docs/en/overview> e configuração de modelos <https://code.claude.com/docs/en/model-config>
- Codex CLI: `codex --help`, `codex debug models`, `~/.codex/config.toml`
- Saídas locais: `ao --help`, `ao spawn --help`, `ao project set-config --help`, tabela `agent_model_catalog` em `~/.ao/data/ao.db`
