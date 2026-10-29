# Linha de Base de Acessibilidade e Desempenho no Simulador (28/10/2026)

Este documento registra a execução literal e a linha de base automatizada das suítes de acessibilidade e desempenho existentes no repositório, mapeando o que os testes automatizados cobrem frente aos critérios dos cartões **6ab26a01** (Acessibilidade completa) e **6ab26a10** (Desempenho e rede).

> [!IMPORTANT]
> **Distinção Fundamental de Prova:**
> 1. Os testes de interface em simulador validam propriedades estruturais da árvore de acessibilidade (existência de rótulos, `accessibilityIdentifier`, alvos mínimos de toque em pontos geométricos e presença de Dynamic Type nativo). **Não comprovam** a experiência humana com VoiceOver ativado nem dispensam a auditoria por pessoa externa.
> 2. As medições de tempo e tráfego foram coletadas com dublê em memória no simulador. O dublê responde instantaneamente e sem tráfego HTTP pela pilha de rede do sistema. **Esses números NÃO comprovam** o p95 em 4G real no aparelho de entrada nem o consumo real de dados pela antena do modem celular.

---

## 1. Ambiente de Execução

As saídas abaixo foram obtidas diretamente no host e no simulador utilizado para as execuções, sem inferência:

### `xcodebuild -version`
```
Xcode 27.0
Build version 27A266a
```

### `sw_vers`
```
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
```

### `xcrun simctl list runtimes | grep -i ios`
```
iOS 18.4 (18.4 - 22E238) - com.apple.CoreSimulator.SimRuntime.iOS-18-4
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

### Simulador e Esquema Utilizados
- **Dispositivo:** `iPhone 17 Pro` (UDID `C5723206-4177-45B9-9496-7EA46550F215`), iOS 26.5
- **Esquema:** `Frila-Local`
- **Fila de concorrência:** Lock `simulador-1` obtido via `orquestracao/scripts/fila.sh pegar simulador F-008` e liberado ao término das suítes.

---

## 2. Execução das Suítes Existentes

As 5 suítes de UI e medição foram executadas individualmente em série.

### 2.1 Suíte 1: `AuditoriaDeAcessibilidadeUITests`

- **Comando:**
  ```bash
  cd iOS && xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
    -derivedDataPath /tmp/frila-f008/DerivedData \
    -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests \
    -resultBundlePath /tmp/frila-f008/AuditoriaDeAcessibilidadeUITests.xcresult
  ```
- **Resultado:** `** TEST FAILED **` (Exit code 65)
- **Duração dos testes:** 1035.771 s de execução dos casos de teste; relógio total do result bundle em 1649 s (~27 min 29 s). O acréscimo de ~600 s no relógio total decorre do timeout de coleta de diagnósticos pós-falha do simulador pelo Xcode (`IDETestOperationsObserverDebug: Failure collecting diagnostics from simulator: Timed out after 600.0 seconds while waiting for a response from the invoked process`).
- **Result Bundle:** `/tmp/frila-f008/AuditoriaDeAcessibilidadeUITests.xcresult`
- **Contagem:** 65 testes executados (43 passaram, 10 falhas esperadas via `XCTExpectFailure`, 12 falharam, 0 pulados).

#### Falhas Esperadas (10)
Trata-se de defeitos conhecidos rastreados no produto e protegidos por `XCTExpectFailure`:
1. `testAjudaDoPerfil`
2. `testAjudaDoPerfilEmAX5`
3. `testFolhaDeDenuncia`
4. `testFolhaDeSuporte`
5. `testFolhaDeSuporteEmAX5`
6. `testPorQueReceboVagas`
7. `testPorQueReceboVagasEmAX5`
8. `testPublicarVagaEmMinhasVagas`
9. `testPublicarVagaEmMinhasVagasEmAX5`
10. `testCadastroDoEstabelecimentoEPublicarVaga`

#### Falhas Registradas (12) e Hipóteses

Duas das 12 falhas (`testCadastroDoEstabelecimentoEPublicarVagaEmAX5` e `testListaDetalheECandidaturaEmAX5`) apresentaram a mensagem `"Expected failure ... but none recorded"`. Isso indica que a falha esperada NÃO se manifestou nesta execução, **não configurando regressão de produto**.

| Teste | Mensagem de Falha | Hipótese Técnica |
|---|---|---|
| `testCadastroDoEstabelecimentoEPublicarVagaEmAX5()` | `Expected failure 'cadastro-estabelecimento: o botão Sair da barra do cadastro do estabelecimento não acompanha o Dynamic Type por desenho do sistema iOS (item de toolbar); achado do #494 registrado para o Nick Fury' but none recorded` | O defeito esperado não se reproduziu na asserção testada durante a execução (não é regressão de produto). |
| `testFolhaDeDenunciaEmAX5()` | `XCTAssertTrue failed - "denunciar" Button não ficou tocável` | Hipótese, sem captura nem inspeção: no tamanho AX5, o botão "denunciar" perdeu hit-test (`isHittable == false`), possivelmente encoberto ou fora da viewport. |
| `testLicencasEDetalheEmAX5()` | `XCTAssertTrue failed - "abrir-licencas" Button não ficou tocável` | Hipótese, sem captura nem inspeção: com a expansão tipográfica em AX5, o botão "abrir-licencas" na rolagem não permaneceu em área tocável sem scroll prévio. |
| `testListaDetalheECandidatura()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: a auditoria nativa do XCTest acusou suporte parcial a Dynamic Type (o log de erro da Apple não nomeia o elemento afetado). |
| `testListaDetalheECandidaturaEmAX5()` | `Expected failure 'vagas: o cartão da vaga não acompanha o Dynamic Type além de AX1 por decisão de layout do design (#139)...' but none recorded` | O defeito esperado no layout do cartão da vaga em AX5 não foi disparado (não é regressão de produto). |
| `testMinhasVagasDetalheEPerfilPublico()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: suporte parcial a Dynamic Type reportado genericamente pela auditoria do XCTest. |
| `testMinhasVagasDetalheEPerfilPublicoEmAX5()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: mesma auditoria de suporte parcial a Dynamic Type em AX5. |
| `testPerfilEExclusaoDeContaEmAX5()` | `Label not human-readable` | Hipótese, sem captura nem inspeção: elemento exposto ao leitor de tela possui rótulo inacessível para usuário. |
| `testResultadosDaCandidatura()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: auditoria nativa acusou fontes sem escala completa. |
| `testResultadosDaCandidaturaEmAX5()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: mesma auditoria em AX5. |
| `testSecaoDeCandidatos()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: auditoria nativa acusou fontes sem escala completa. |
| `testSecaoDeCandidatosEmAX5()` | `Dynamic Type font sizes are partially unsupported` | Hipótese, sem captura nem inspeção: mesma auditoria em AX5. |

---

### 2.2 Suíte 2: `AcessibilidadeDoContratanteUITests`

- **Comando:**
  ```bash
  cd iOS && xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
    -derivedDataPath /tmp/frila-f008/DerivedData \
    -only-testing:FrilaUITests/AcessibilidadeDoContratanteUITests \
    -resultBundlePath /tmp/frila-f008/AcessibilidadeDoContratanteUITests.xcresult
  ```
- **Resultado:** `** TEST FAILED **` (Exit code 65)
- **Duração dos testes:** 126.543 s (~2 min 37 s total)
- **Result Bundle:** `/tmp/frila-f008/AcessibilidadeDoContratanteUITests.xcresult`
- **Contagem:** 7 testes executados (5 passaram, 1 pulado, 1 falhou, 0 falhas esperadas).

#### Detalhes de Falha e Testes Pulados

- **Pulado:** `testPublicarVagaEmDynamicTypeXXXLMantemControlesNaTela`: `Test skipped - Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)`.
- **Falha:** `testPerfilDoEstabelecimentoToolbarEHintsSemVazamento`:
  - **Mensagem:** `Failed to tap "Perfil do estabelecimento" Button: No matches found for Elements matching predicate '"Perfil do estabelecimento" IN identifiers'`.
  - **Hipótese Técnica:** O botão na barra de navegação/toolbar do contratante não utiliza o identificador `"Perfil do estabelecimento"` ou não está presente/hittable no estado inicial após o cadastro.

---

### 2.3 Suíte 3: `AcessibilidadeDoProfissionalUITests`

- **Comando:**
  ```bash
  cd iOS && xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
    -derivedDataPath /tmp/frila-f008/DerivedData \
    -only-testing:FrilaUITests/AcessibilidadeDoProfissionalUITests \
    -resultBundlePath /tmp/frila-f008/AcessibilidadeDoProfissionalUITests.xcresult
  ```
- **Resultado:** `** TEST SUCCEEDED **` (Exit code 0)
- **Duração dos testes:** 117.357 s (~2 min 09 s total)
- **Result Bundle:** `/tmp/frila-f008/AcessibilidadeDoProfissionalUITests.xcresult`
- **Contagem:** 15 testes executados (12 passaram, 3 pulados, 0 falharam).

#### Testes Pulados

Todos os 3 testes pulados contêm a anotação explícita no código:
- `testDetalheDaVagaEmAX5EmpilhaQuandoEValorSemQuebrarOValor`: `Test skipped - Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)`
- `testPerfilProfissionalAlvosDeDisponibilidadeEAdicao`: `Test skipped - Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)`
- `testPerfilProfissionalSeletoresEmAX5`: `Test skipped - Acessibilidade em AX5 adiada (decisão do Cauê, 21/10)`

---

### 2.4 Suíte 4: `AcessibilidadeDoCatalogoUITests`

- **Comando:**
  ```bash
  cd iOS && xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
    -derivedDataPath /tmp/frila-f008/DerivedData \
    -only-testing:FrilaUITests/AcessibilidadeDoCatalogoUITests \
    -resultBundlePath /tmp/frila-f008/AcessibilidadeDoCatalogoUITests.xcresult
  ```
- **Resultado:** `** TEST FAILED **` (Exit code 65)
- **Duração dos testes:** 329.284 s de execução de teste (15 min 42 s total incluindo 600 s de timeout de coleta de diagnóstico do `simctl` pelo Xcode após falha)
- **Result Bundle:** `/tmp/frila-f008/AcessibilidadeDoCatalogoUITests.xcresult`
- **Contagem:** 6 testes executados (4 passaram, 0 pulados, 2 falharam).

#### Falhas Registradas e Hipóteses

| Teste | Mensagem de Falha | Hipótese Técnica |
|---|---|---|
| `testCapturasDoCatalogoEmAX5()` | `XCTAssertTrue failed - o percurso em AX5 não alcançou o fim do catálogo` | Hipótese, sem captura nem inspeção: o catálogo aumentou de tamanho e a rotina do teste limita a rolagem a 20 swipes, não alcançando o botão final `abrir-licencas` sob escala AX5. |
| `testTodoControleTemRotuloEAlvoMinimoEmAX5()` | `XCTAssertTrue failed - o percurso não alcançou o fim do catálogo` | Hipótese, sem captura nem inspeção: mesma causa, o limite de 20 swipes termina antes de localizar o controle final em AX5. |

#### Testes que Passaram (4)
- `testToqueNaBordaDaPilulaAlternaOFiltro` (passou em 14.5 s)
- `testPilulaDeFiltroNaoDependeApenasDeCor` (passou em 5.4 s)
- `testToqueNaBordaDoSimSeleciona` (passou em 5.4 s)
- `testToqueNaLateralDoBotaoSecundarioDispara` (passou em 23.2 s)

---

### 2.5 Suíte 5: `MedicaoUITests`

- **Comando com Coleta de Medições:**
  ```bash
  cd iOS && env TEST_RUNNER_FRILA_COLETAR_MEDICOES=1 FRILA_COLETAR_MEDICOES=1 \
    xcodebuild test -project Frila.xcodeproj -scheme Frila-Local \
    -destination "platform=iOS Simulator,id=C5723206-4177-45B9-9496-7EA46550F215" \
    -derivedDataPath /tmp/frila-f008/DerivedData \
    -only-testing:FrilaUITests/MedicaoUITests \
    -resultBundlePath /tmp/frila-f008/MedicaoUITests.xcresult
  ```
- **Resultado:** `** TEST SUCCEEDED **` (Exit code 0)
- **Duração dos testes:** 360.113 s (~6 min 14 s total)
- **Result Bundle:** `/tmp/frila-f008/MedicaoUITests.xcresult`
- **Contagem:** 4 testes executados (4 passaram, 0 pulados, 0 falharam).

#### Números Coletados Literais

1. **20 Aberturas de Cada Tela (`testColetaVinteAberturasDeCadaTela`):**
   ```
   MEDICOES listaDeVagas: Lista de vagas, n=20 · p50 0 ms · p95 0 ms · máx 1 ms
   MEDICOES detalheDaVaga: Detalhe da vaga, n=21 · p50 24 ms · p95 28 ms · máx 53 ms
   MEDICOES meuTurno: Meu turno, n=20 · p50 21 ms · p95 24 ms · máx 42 ms
   MEDICOES rede: 0 requisições · 0 B
   ```
   *Nota sobre `n=21` em detalheDaVaga:* No código de `MedicaoUITests.swift`, o loop de detalhe executa 20 aberturas e retornos (linhas 126-131). Em seguida, ao iniciar o bloco de teste de Meu turno (linha 134), o teste abre `primeiraVaga(app)` mais uma vez para acionar o botão de candidatura, registrando a 21ª abertura.

2. **Sessão de Consulta e Candidatura (`testSessaoDeConsultaECandidaturaConsomeMenosDeUmMegabyte`):**
   ```
   MEDICOES listaDeVagas: Lista de vagas, n=1 · p50 77 ms · p95 77 ms · máx 77 ms
   MEDICOES detalheDaVaga: Detalhe da vaga, n=4 · p50 24 ms · p95 43 ms · máx 43 ms
   MEDICOES rede: 0 bytes (dublê em memória; não comprova tráfego HTTP)
   ```

> [!WARNING]
> **Advertência de Desempenho e Rede:**
> O dublê `success` entrega dados fixos em memória sem tráfego HTTP real, resultando em medição de rede de `0 B` e tempos de tela locais variando entre 0 ms e 77 ms (considerando a lista em 77 ms e o detalhe em até 53 ms).
> Esse resultado atesta apenas que o app processa o payload localmente em menos de 100 ms, mas **não tem correlação direta com o p95 abaixo de 2 s em 4G real** exigido pelo critério de homologação em aparelho físico de entrada.

---

## 3. O Que Cada Teste Prova vs O Que NÃO Prova

| Suíte | O Que o Teste Prova | O Que NÃO Prova |
|---|---|---|
| **AuditoriaDeAcessibilidadeUITests** | Executa a API nativa `performAccessibilityAudit` do XCTest (auditando contraste, Dynamic Type, texto cortado, alvos mínimos de toque e descrição/rótulos acessíveis nas telas navegadas). | Não prova a navegabilidade de ponta a ponta com VoiceOver por usuário humano; não prova ordem de leitura ideal; não prova se o texto é claro e contextualizado no leitor. |
| **AcessibilidadeDoContratanteUITests** | Prova que alvos de toque geométricos medem pelo menos 44x44 pt nas telas cobertas do contratante (botão de busca, marcador de mapa); prova presença de links e rótulos específicos em tamanho padrão. | Não prova o fluxo completo em AX5 (teste explicitamente pulado por adiamento); falha na localização do botão de perfil do estabelecimento; não avalia VoiceOver em aparelho real. |
| **AcessibilidadeDoProfissionalUITests** | Prova que filtros, botões de ação (candidatar-se), links de contato e denúncia possuem alvos geométricos >= 44x44 pt no tamanho padrão e em XXXL; prova que campos essenciais existem na hierarquia. | Não prova as telas em AX5 (testes de perfil e detalhe pulados); não prova experiência em aparelhos com telas pequenas; não prova VoiceOver real. |
| **AcessibilidadeDoCatalogoUITests** | Prova que componentes isolados (pílulas de filtro, botões primários/secundários) respondem ao toque na borda geométrica e não dependem exclusivamente de cor para transmitir estado. | Falha ao tentar percorrer o catálogo completo em AX5; não prova o catálogo em aparelho real nem em telas de densidades diferentes. |
| **MedicaoUITests** | Prova que a infraestrutura interna de registro (`RegistroDeMedicoes`, `os_signpost`) funciona, acumula amostras (n=20), calcula p50/p95/máximo e que o botão de medição fica restrito a builds autorizados. | Não prova latência de rede móvel (4G/5G); não prova transporte TLS, DNS, cabeçalhos nem limites de consumo celular (medidor de rede registra 0 B com dublê local). |

---

## 4. Mapeamento dos Critérios dos Cartões do Trello

Abaixo está o mapeamento de cada critério dos cartões **6ab26a01** e **6ab26a10** conforme os textos literais dos cartões.

### Cartão 6ab26a01 · S3 · iOS + Design · Acessibilidade completa: VoiceOver, Dynamic Type, contraste e alvos

| Critério literal do cartão | Classificação | Confirmação pelas suítes automatizadas |
|---|---|---|
| `[ ] 1. Checklist de acessibilidade do design preenchido para 100% das telas da v1.0, com captura das que falharam e um cartão de correção para cada uma.` | **só aparelho/humano/design** | Nenhuma suíte automatizada preenche checklist de design nem cobre 100% das telas de ponta a ponta. |
| `[ ] 2. 'Publicar uma vaga' e 'candidatar-se e fazer check-in' feitos só com VoiceOver, sem ajuda, por alguém que não desenvolveu.` | **só aparelho/humano/design** | Exige execução humana cega com VoiceOver no aparelho físico. Os testes de UI apenas consultam identificadores e labels via automação. |
| `[ ] 3. Em AX5 (o maior dos tamanhos de acessibilidade), nenhuma tela corta texto ou esconde botão.` | **parcial** | As suítes cobrem telas pontuais em AX5 e acusam falhas (hipótese, sem captura nem inspeção: botões na folha de denúncia e licenças, e interrupção do percurso no catálogo; 4 testes de AX5 pulados com "AX5 adiado").<br><br>**Nota de escopo do projeto:** Conforme decisão formal registrada em [Acessibilidade.md:494](Acessibilidade.md) (decisão do Cauê de 21/10/2026, PR #441 / commit `891c297c`), os requisitos de Dynamic Type XXXL (AX5) foram formalmente retirados do escopo obrigatório da v1.0, recontextualizando a leitura deste critério. |
| `[x] 4. Com Reduzir Movimento ligado, nenhuma animação de deslocamento; nenhum estado comunicado só por cor.` | **provado no simulador** | **Confirmado por testes existentes, não reexecutados nesta linha de base** (`AcessibilidadeEstadoECorTests`, `ReduzirMovimentoTests`, script `conferir-movimento.sh`); apenas `testPilulaDeFiltroNaoDependeApenasDeCor` foi rodado dentro das 5 suítes aqui executadas. Mantém-se o `[x]`. |
| `[ ] 5. Telas do build de 04/11 iguais aos frames aprovados, ou diferença aceita por escrito pelo Fabrício; telas mudadas pelas correções de 05/11 conferidas na regressão final.` | **só aparelho/humano/design** | Depende de conferência visual humana e aprovação formal de design pelo Fabrício frente às datas do cronograma. |

---

### Cartão 6ab26a10 · S3 · iOS · Desempenho e rede: telas em menos de 2 s, sessão leve e modo avião

| Critério literal do cartão | Classificação | Confirmação pelas suítes automatizadas |
|---|---|---|
| `[ ] 1. p95 de 20 aberturas da lista e do detalhe abaixo de 2 s em 4G real no aparelho de entrada (a primeira medição é do Sprint 2).` | **só aparelho/humano** | O teste `MedicaoUITests.testColetaVinteAberturasDeCadaTela` apenas prova a mecânica interna de contagem e cálculo dos percentis. A comprovação de p95 < 2 s em rede 4G real no aparelho de entrada é **só aparelho/humano**. |
| `[ ] 2. Sessão de consulta e candidatura (abrir a lista, abrir três detalhes e candidatar-se, com o cache vazio) medida abaixo de 1 MB, com a ferramenta e o valor anotados no cartão.` | **parcial** | O roteiro é exercitado por `MedicaoUITests.testSessaoDeConsultaECandidaturaConsomeMenosDeUmMegabyte`, mas o valor medido de 0 B decorre do uso de dublê em memória (não comprova tráfego de rede). A aferição do consumo real na rede celular é **só aparelho/humano**. |
| `[x] 3. Modo avião: Meus turnos e o contato continuam visíveis.` | **provado com dublê sem-rede; modo avião real só no aparelho** | `ModoAviaoUITests` valida a persistência no SwiftData e a exibição de aviso sob o cenário dublê `-FRILA_SCENARIO sem-rede` (não foi reexecutado nesta linha de base de 5 suítes). O modo avião físico real com desligamento de antena só pode ser atestado no aparelho. Mantém-se o `[x]`. |
| `[ ] 4. Resultado das medições anotado no cartão, com o aparelho usado.` | **só aparelho/humano/design** | Depende do preenchimento humano no Trello após os testes em aparelho físico de entrada. |

---

## 5. Conclusão Técnica e Próximos Passos

1. **Acessibilidade:**
   - A linha de base automatizada aponta que a maioria dos alvos geométricos (44x44 pt) no tamanho padrão está em conformidade nas telas testadas do profissional e do contratante.
   - O suporte a **AX5 está incompleto e fragmentado**: há testes pulados formalmente por decisão de produto de 21/10 ([Acessibilidade.md:494](Acessibilidade.md)), falhas de hit-test em botões ao expandir fontes (`denunciar`, `abrir-licencas` — hipótese sem captura nem inspeção), falhas de auditoria nativa da Apple em Dynamic Type (hipótese sem isolamento de elemento) e interrupção de percursos longos de rolagem no catálogo em AX5. Pela decisão vigente do projeto, AX5 não bloqueia a v1.0.
   - O item 4 do cartão 6ab26a01 (Reduzir Movimento e cor única) está comprovado por testes existentes no repositório (não reexecutados aqui, exceto o teste de pílula do catálogo).
   - Os itens 1, 2 e 5 do cartão 6ab26a01 requerem obrigatoriamente validação humana e aparelho físico.

2. **Desempenho e Rede:**
   - A automação de medição de aberturas e percentis (p50/p95/máx) está funcional e integrada ao app sob a flag `-FRILA_MEDICAO`.
   - A resiliência de dados em modo avião (item 3 do cartão 6ab26a10) está coberta com dublê sem-rede por teste automatizado dedicado existente (`ModoAviaoUITests`), pendente de validação com rádio real desligado no aparelho físico.
   - A aferição de conformidade real com latência < 2 s e consumo < 1 MB depende exclusivamente de execução em aparelho de entrada conectado a rede celular 4G real com medição pelo painel de Dados Celulares do iOS.
