# AGENTS.md: frila-frontend

Instruções para agentes de IA neste repositório. A seção 1 vale para todos. A seção 2 vale **só** para os agentes do andar `alinhamento` do Maestri (Roles "Frila ..."); outros agentes podem ignorá-la.

## 1. Para todos os agentes

- **Regras de código e design** moram nos documentos do próprio repo: `iOS/README.md`, `iOS/Docs/GuiaDoFabricio.md`, `iOS/Docs/DesignSystem.md` e, para telas, `iOS/Docs/HiFi/REFERENCIA.md` e `iOS/Docs/HiFi/ESTADO.md`. Este arquivo não as repete.
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
- **Fila de Logs** é uma nota do canvas, escrita só pelo Claude: `LOG-ID título | status | grupo` seguido de um `> Resumo` de até 4 linhas do que o Log promove. Só ficam os Logs em aberto e os 3 últimos aceitos; o histórico mora nos PRs e em `~/dev/frila-orquestra/briefs/`. Status: rascunho → validação humana → disponível → assumido → implementado → revisão → aceito.
- **Área:** CO1 fica com componentes e tokens (`Componentes.swift`, `DesignTokens.swift`, catálogo do design system); CO2 com as telas. Log que cruza vira duas tarefas, componentes primeiro.
- **Afinidade:** o mesmo arquivo fica com o mesmo AGY até o fim do Log.
- **Conta:** os trios compartilham `agy-1`, `agy-2` e `agy-3` (`AGY1` e `CO2-AGY1` = `agy-1`, e assim por diante). No máximo um AGY ativo por conta.
- **Um escritor por arquivo** entre os dois grupos. Builds no mesmo worktree em série. No máximo 2 simuladores ligados na máquina.

### 2.5 Versionamento e gate

- Um Log = uma branch `log/<ID>-<slug>` de `origin/main` = um PR para `main`. Tarefa paralela = worktree e branch `log/<ID>-<tarefa>` nascida da branch do Log.
- Rodadas não viram commit; o Codex revisa pelo `git diff` e faz **um commit por tarefa aceita**. Mensagem em português, no padrão `tipo(escopo): descrição`, **sem citar IA, modelo ou ferramenta** e sem `Co-Authored-By`.
- **Gate local mínimo** (o Codex pede a um AGY, no worktree do Log, a partir de `iOS/`):
  1. `Scripts/gerar-projeto.sh` (uma vez por worktree);
  2. `Scripts/conferir-textos.sh`;
  3. `xcodebuild build -scheme Frila-Local -destination 'platform=iOS Simulator,name=<simulador do despacho>'`;
  4. testes só quando o Log os listar: troque o `build` por `build-for-testing` e rode `xcodebuild test-without-building` com o mesmo esquema e destino, só `-only-testing:` dos testes listados (o de regressão de um bug, os testes adaptados com autorização expressa do §2.2 ou o smoke UITest do caminho feliz). Para o smoke, reaproveite teste existente; teste novo só com autorização expressa no Log (§2.2), meta de até 2 min e uma classe. Sem lista no Log, não há teste. Nada de suíte inteira nem de teste novo sem autorização expressa no Log.
- Fora do gate por ora (decisão do usuário, 28/10): auditoria de acessibilidade, AX5, Reduzir Movimento e texto grande. Voltam por Log próprio (LOG-006). O gate enxuto vale a partir do LOG-011; o LOG-010 segue o processo anterior.
- A conferência visual é a demo (§2.7); o gate verifica compilação, textos e os testes listados no Log.
- O Codex do Log integra, roda o gate, faz push, abre o PR e avisa o Claude. O Claude leva ao usuário e, com o ok, faz o merge (`gh pr merge <n> --merge`). O Codex remove os worktrees.
- **CI (`ios.yml`) fica ligado e não bloqueia o merge** (leva de 70 a 90 min). CI vermelho num PR já mesclado vira um Log de correção na frente da Fila.

### 2.6 Mensagens

- Rode `maestri list` antes de endereçar um agente.
- **Despacho** (Codex → AGY, ~10 linhas): `ID/rN`; objetivo; solução; worktree; arquivos permitidos; critérios; comandos; retorno com `maestri ask "<Codex>" "..."`.
- **Devolução** (AGY → Codex, uma por rodada, até 15 linhas): `ID/rN | ok, bloqueado ou falhou | arquivos | comandos e saídas | bloqueio`. Não invente sucesso.
- **Codex → Claude, só nos marcos e em até 5 linhas:** assumido; pronto para integrar (PR, gate, aceite técnico); bloqueio; decisão de produto com as opções.
- No máximo 2 rodadas de correção por tarefa; na terceira, muda a abordagem ou sobe ao Claude. Sem tarefa: aguarde, sem polling.

### 2.7 Demo pós-iteração

- Depois do gate verde e antes do marco "pronto para integrar", o Codex do Log pede ao mesmo AGY: compilar a branch do Log (`Frila-Local`) no simulador **Frila Demo** (UDID `907B7EAE-82FB-439F-8054-B0CB496A222D`), instalar e abrir o app **na tela alvo** só por argumentos de lançamento e cenários que já existem (sem clicar, sem mudar código), e deixar o app aberto sem rodar mais testes nesse simulador.
- O marco "pronto para integrar" passa a trazer também `demo: <UDID> | <argumentos> | <tela alcançada ou o toque que falta>` e um contexto de até 4 linhas para o usuário: o que mudou, o que conferir, as ressalvas e a referência ao roteiro de interação do Log, executado pelo usuário na demo.
- O Claude abre a demo com `~/dev/frila-orquestra/demo.sh`: um único portal de simulador e uma única nota ("Demo atual") no canvas; a demo anterior fecha sozinha.

### 2.8 Lições

- Antes de rascunhar um Log, rode `gh pr list` e compare os arquivos com os PRs abertos; Log com sobreposição espera.
- O Log declara `iOS/Docs/HiFi/REFERENCIA.md` como referência de design; o Codex a confere em `origin/main` antes de detalhar a solução.
- `ask` volta cedo e `/clear` pode engolir o ask seguinte: confirme a caixa pronta, a entrega por `maestri check` e o diff, sem polling.
- `Frila.xcodeproj` não é versionado: rode `iOS/Scripts/gerar-projeto.sh` por worktree. iOS 26.4 não existe aqui: gate no iPhone 18 Pro (iOS 27.0; UDID `2AF3E1DE-44A3-433F-B09B-CDC8E0BD8737`), demo no Frila Demo; papéis exclusivos, sem criar outro simulador.
- Na retomada pós-reset, o estado do andar vive na Fila de Logs e no `git status` do worktree, não na conversa.
- Devolução longa vai para arquivo; a mensagem leva só o caminho.
- `maestri ask` passa para segundo plano depois de uns 20 s e devolve `OK`; a resposta do agente chega depois, como mensagem. Não descarte a saída, não faça polling; confirme com `maestri check`.
- O Claude só alcança CO1 e CO2; os AGYs respondem ao seu Codex.
- Limpar contexto (`/clear`): AGYs primeiro, pelo próprio Codex, um por vez; Codex por último. `maestri ask "<agente>" --raw "/clear\n"` deixa o texto só digitado: envie `--raw "\r"` e confirme o prompt vazio com `maestri check`. Antes de limpar um Codex, grave o que ele vai precisar em `~/dev/frila-orquestra/briefs/` e cite o caminho no ask seguinte.
- Loading sem fim: procure primeiro um `await` sem prazo, sobretudo APIs do sistema (ex.: DeclaredAgeRange, LOG-004). Todo `await` de API do sistema dentro de um fluxo com `carregando` leva prazo e fallback explícito.
- Bug visto no aparelho: o Log traz o trecho do log do aparelho e a causa confirmada ou descartada; o teste de regressão vem antes do fix.
- Build no iPhone físico: `iOS/Configurations/Secrets.xcconfig` fica fora do Git (`chmod 600`; nunca em PR, chat ou e-mail). Ajustes locais de assinatura (time pessoal, bundle ID, entitlements) não entram em commit e se desfazem antes de um pull que mexa nesses arquivos.
- Antes de liberar um Log, além do `gh pr list`, confira arquivo a arquivo se algum PR aberto toca os mesmos arquivos.
- **Relato do usuário literal.** O brief e o Log citam o relato com as palavras do usuário e classificam o tipo (UX e movimento, layout, componente, bug de dados) **antes** de rotear. Não traduza "tempo de resposta e glitch na troca de aba" em "falha de layout" (LOG-008).
- **Veredito objetivo antes de medir.** Em bug de percepção (piscar, latência, sobreposição), fixe os critérios de defeito em ms e em quadros **antes** de olhar os números, nas duas versões (antes e depois), em mais de uma tela. Dois vereditos: defeito comprovado ou sem defeito comprovado. Simulador não prova o aparelho: diga o que ficou sem prova.
- **Evidência de mídia não se apaga sem índice.** Guarde os quadros do instante do toque em `briefs/<ID>-quadros/` com `INDICE.md` por commit, cenário e transição; apague só os brutos.
- **Consulta direta.** O Claude lê os terminais com `maestri check`; não espere a mensagem. `maestri ask` passa para segundo plano depois de uns 20 s; a resposta chega depois. Monitor de andamento usa sinais estáveis (commits, fontes alteradas, PR), não a tela do Codex, que rola e esvazia o filtro.
- **Modo automático (`/goal`).** Com o usuário em modo automático, o Claude valida Log e design por ele e responde as perguntas de produto pelo critério já aprovado; o merge na `main` ainda pede o ok final. Toda decisão tomada pelo Claude entra no Log como "decisão do Claude, a validar na demo".
- **Restrição de escopo vira instrução ao Codex na hora.** Quando o usuário restringe o escopo no meio do Log (ex.: sem mexer em esqueletos), o Claude manda ao Codex, que reverte o que já tocou e devolve `bloqueado: depende de <X>` se a causa exigir o proibido.
- **Build no iPhone físico.** CO1 despacha ao AGY2: `git pull --ff-only` (patch local de assinatura intocado e sem commit), `Scripts/gerar-projeto.sh`, `xcodebuild -scheme Frila-Dev -destination 'id=<UDID>' -allowProvisioningUpdates build`, `xcrun devicectl device install app` e `process launch com.fabriciotosta.frila`. Aparelho bloqueado devolve `FBSOpenApplicationErrorDomain error 7 - Locked`: peça ao usuário para desbloquear. Nunca apagar `iOS DeviceSupport`.
- **PR em rascunho.** O Codex abre o PR como rascunho; antes do merge o Claude o tira de rascunho (`gh pr ready <n>`) e mescla com o ok do usuário.
- **Causa em área restrita adia o Log, não o contorna.** Se um defeito comprovado tem a causa numa área que o usuário restringiu (ex.: `EstadoCarregando` e esqueletos), o Codex devolve `bloqueado: depende de <X>`, o achado fica no Log e nos briefs com os quadros, o worktree e a branch são removidos, e o Claude marca o Log como `adiado` na Fila até o usuário liberar a área. Não se mascara o defeito por layout (LOG-008: 6 quadros de `EstadoCarregando` antes dos dados na 1ª abertura de Conta).

### 2.9 Playbooks por tipo de Log

A decisão de produto ou design vai ao usuário uma vez, de uma só vez, antes do rascunho (escopo, onde entra cor, coordenação com outro time). O resto o Claude roteia sem perguntar de novo.

| Tipo | Rota | Passos | Específico do tipo |
|---|---|---|---|
| Correção de bug | CO da área | evidência do aparelho → causa → Log mínimo → teste de regressão antes do fix → fix → gate → demo → merge | exceção de teste só com autorização expressa no Log |
| Refino visual de tela | CO2 (telas); CO1 antes, se houver componente ou token novo | briefing do usuário (captura e decisões) em `~/dev/frila-orquestra/briefs/` → rascunho com antes/depois por tokens → validação do design → implementação → gate mínimo + smoke do caminho feliz → demo → merge | diff-log (`~/dev/frila-orquestra/diff-log/MODELO.md`): antes de `origin/main`, depois da branch, claro, topo/meio/fim, sem números de cor. Roteiro de interação (usuário-modelo e usuário médio) no Log, executado pelo usuário na demo. UI primeiro, esqueletos depois: não crie nem mude esqueleto, EstadoCarregando ou placeholder compartilhado em Log de refino; esqueletos espelham a UI depois que ela estiver estável. |
| Componente ou token | CO1 | Log → implementação → catálogo do design system → gate → merge | telas que dependem esperam o merge |
| Documentação e governança | CO1 | briefing exato → commit `docs(governanca)` → PR → merge | sem build; o usuário valida o texto |
| Exploração livre | Claude | `demo.sh EXPLORACAO <UDID> "<contexto>"` com `Frila-Local` instalado no Frila Demo; o usuário anota; o Claude agrupa por área e abre os Logs | sem Log até o usuário listar os pontos |
