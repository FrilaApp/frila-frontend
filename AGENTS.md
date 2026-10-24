# AGENTS.md: frila-frontend

Instruções para agentes de IA neste repositório. A seção 1 vale para todos. A seção 2 vale **só** para os agentes do andar `alinhamento` do Maestri (Roles "Frila ..."); outros agentes podem ignorá-la.

## 1. Para todos os agentes

- **Regras de código e design** moram nos documentos do próprio repo: `iOS/README.md`, `iOS/Docs/GuiaDoFabricio.md`, `iOS/Docs/DesignSystem.md` e, para telas, `iOS/Docs/MidFi/DESIGN.md` e `iOS/Docs/MidFi/FLUXOS.md`. Este arquivo não as repete.
- **Branch nova sempre a partir de `origin/main`**, um worktree por branch. A `main` é protegida: só entra por PR.
- **`Frila.xcodeproj` não é versionado.** Em todo clone ou worktree novo, e depois de trocar de branch, rode `iOS/Scripts/gerar-projeto.sh`.
- Proibido: force push, apagar a `main`, `git reset --hard` ou `git clean` em trabalho que não é seu.

## 2. Andar alinhamento (Maestri)

### 2.1 Quem faz o quê

| Quem | Faz | Não faz |
|---|---|---|
| **Usuário** (Fabrício, product designer) | Aprova Logs, design e cada merge. | |
| **Claude** (Maestro Maior) | Mantém a Fila de Logs; roteia para CO1 ou CO2; arbitra conflitos e leva decisões de produto ao usuário; dá o aceite integrado pelo marco; faz o merge com o ok do usuário. | Não despacha a AGYs. Em Eco: não lê diff, não roda build, não redige Log, não integra. |
| **CO1, CO2** (Codex) | Rascunham o Log; detalham a solução; despacham e revisam o próprio trio; commitam a tarefa aceita; o Codex do Log integra, faz push e abre o PR. | Não decidem produto ou design. Não rodam o que um AGY pode rodar. |
| **AGYs** (CO1: `AGY1..3`; CO2: `CO2-AGY1..3`) | Implementam o despacho exato e rodam gate, testes e capturas pedidos. | Não decidem, não ampliam escopo, não fazem commit, push, merge nem PR, não aprovam a própria entrega. |

### 2.2 Escopo de edição

Só `iOS/Sources/Apresentacao/`. Nunca `Dominio/`, `Dados/`, `Infraestrutura/`, `App/`, `Contrato/`, `NotificationService/`, `project.yml`, `Configurations/`, `.github/`, `android/`. Se a tarefa exigir mexer fora, o AGY para e devolve `bloqueado: fora do escopo`; o Claude leva ao usuário.

**Exceção estreita: testes que procuram texto.** Quando a tela troca um texto, título, rótulo ou placeholder que um teste em `iOS/Tests` procura, o AGY atualiza a asserção **na mesma entrega**, trocando só o texto e o localizador, sem mudar a lógica do teste (fluxo, esperas, condições, quantidade de asserções). O Codex acha as dependências com `grep -rn '"<texto antigo>"' iOS/Tests` (só dentro de `iOS/Tests`) e lista os arquivos no despacho. Prefira localizar por `accessibilityIdentifier`, que não muda. Qualquer outra mudança em teste segue a regra acima.

**Exceção estreita: texto novo no catálogo.** Quando uma tela em `iOS/Sources/Apresentacao/` usa um texto novo, aprovado no Log, o AGY acrescenta **só as entradas novas** em `iOS/Resources/Localizable.xcstrings`, na mesma entrega. Não altera, renomeia nem apaga entradas existentes, e não mexe em `InfoPlist.xcstrings`. A edição preserva o formato JSON do Xcode (chaves em ordem, mesma indentação), e o gate prova com `Scripts/conferir-textos.sh` sem falhas. O despacho do Codex lista as chaves novas.

### 2.3 Consumo por camada

Empurrar para baixo: cada tarefa vai à camada mais barata que a faça bem; sobe só por ambiguidade ou julgamento.

| Camada | Modelo | Gasta tokens com | Não gasta com |
|---|---|---|---|
| Claude | Claude (mais caro e escasso) | Prioridade, roteamento, arbitragem, aceite pelo resumo | Código, diff, log de build |
| Codex | GPT do Codex | Solução, passos exatos, revisão de diff, rascunho do Log | Build, teste, simulador, inventário: vai a um AGY |
| AGY | Gemini 3.8 Flash High | Executar despacho exato, rodar comandos, medir | Interpretar intenção, escolher abordagem |

- Despacho exato (arquivo, símbolo, mudança, valores, comandos) para o AGY não precisar raciocinar. Ambiguidade: o AGY devolve `bloqueado: ambiguidade`.
- Referência por Log: Claude abaixo de 10%, Codex de 25% a 35%, AGYs o resto.
- Modos do Claude, declarados pelo usuário: **Normal**, **Eco** (padrão) e **Mínimo** (só repassa decisões e faz merge; CO1 e CO2 coordenam pela Fila). Aviso de limite rebaixa para Mínimo.

### 2.4 Logs, Fila e roteamento

- **Log** = blueprint aprovado pelo usuário, em `iOS/Docs/Logs/<ID>.md` (modelo em `iOS/Docs/Logs/MODELO.md`). O Codex da área rascunha; o usuário valida; muda só com nova validação.
- **Fila de Logs** é uma nota do canvas, escrita só pelo Claude: `ID | status | grupo | branch | contas em uso | bloqueio`. Status: rascunho → validação humana → disponível → assumido → implementado → revisão → aceito.
- **Área:** CO1 fica com componentes e tokens (`Componentes.swift`, `DesignTokens.swift`, catálogo do design system); CO2 com as telas. Log que cruza vira duas tarefas, componentes primeiro.
- **Afinidade:** o mesmo arquivo fica com o mesmo AGY até o fim do Log.
- **Conta:** os trios compartilham `agy-1`, `agy-2` e `agy-3` (`AGY1` e `CO2-AGY1` = `agy-1`, e assim por diante). No máximo um AGY ativo por conta.
- **Um escritor por arquivo** entre os dois grupos. Builds no mesmo worktree em série. No máximo 2 simuladores ligados na máquina.

### 2.5 Versionamento e gate

- Um Log = uma branch `log/<ID>-<slug>` de `origin/main` = um PR para `main`. Tarefa paralela = worktree e branch `log/<ID>-<tarefa>` nascida da branch do Log.
- Rodadas não viram commit; o Codex revisa pelo `git diff` e faz **um commit por tarefa aceita**. Mensagem em português, no padrão `tipo(escopo): descrição`, **sem citar IA, modelo ou ferramenta** e sem `Co-Authored-By`.
- **Gate local** (o Codex pede a um AGY, no worktree do Log, a partir de `iOS/`):
  1. `Scripts/gerar-projeto.sh` (uma vez por worktree);
  2. `Scripts/conferir-textos.sh`;
  3. `xcodebuild build-for-testing -scheme Frila-Local -destination 'platform=iOS Simulator,name=<simulador do despacho>'`;
  4. `xcodebuild test-without-building` com o mesmo esquema e destino, só `-only-testing:` dos testes da tela tocada.
- O Codex do Log integra, roda o gate, faz push, abre o PR e avisa o Claude. O Claude leva ao usuário e, com o ok, faz o merge (`gh pr merge <n> --merge`). O Codex remove os worktrees.
- **CI (`ios.yml`) fica ligado e não bloqueia o merge** (leva de 70 a 90 min). CI vermelho num PR já mesclado vira um Log de correção na frente da Fila.

### 2.6 Mensagens

- Rode `maestri list` antes de endereçar um agente.
- **Despacho** (Codex → AGY, ~10 linhas): `ID/rN`; objetivo; solução; worktree; arquivos permitidos; critérios; comandos; retorno com `maestri ask "<Codex>" "..."`.
- **Devolução** (AGY → Codex, uma por rodada, até 15 linhas): `ID/rN | ok, bloqueado ou falhou | arquivos | comandos e saídas | bloqueio`. Não invente sucesso.
- **Codex → Claude, só nos marcos e em até 5 linhas:** assumido; pronto para integrar (PR, gate, aceite técnico); bloqueio; decisão de produto com as opções.
- No máximo 2 rodadas de correção por tarefa; na terceira, muda a abordagem ou sobe ao Claude. Sem tarefa: aguarde, sem polling.
- `maestri ask` pode voltar antes de o agente terminar: confirme pelo diff e por `maestri check`. Depois de `/clear`, confira a caixa pronta antes do `ask`.

### 2.7 Demo pós-iteração

- Depois do gate verde e antes do marco "pronto para integrar", o Codex do Log pede ao mesmo AGY: compilar a branch do Log (`Frila-Local`) no simulador **Frila Demo** (UDID `907B7EAE-82FB-439F-8054-B0CB496A222D`), instalar e abrir o app **na tela alvo** só por argumentos de lançamento e cenários que já existem (sem clicar, sem mudar código), e deixar o app aberto sem rodar mais testes nesse simulador.
- O marco "pronto para integrar" passa a trazer também `demo: <UDID> | <argumentos> | <tela alcançada ou o toque que falta>` e um contexto de até 4 linhas para o usuário: o que mudou, o que conferir e as ressalvas.
- O Claude abre a demo com `~/dev/frila-orquestra/demo.sh`: um único portal de simulador e uma única nota ("Demo atual") no canvas; a demo anterior fecha sozinha.
- **Dois simuladores, papéis fixos:** "Frila Demo" só para demos (nunca para testes) e "iPhone 18 Pro" (UDID `2AF3E1DE-44A3-433F-B09B-CDC8E0BD8737`) só para gates. Assim um gate não espera a demo. Ninguém cria outro simulador.
