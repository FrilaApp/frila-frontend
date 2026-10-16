# Guia de Testes Swift e Padrões da Suíte iOS

**Data de consolidação:** 16 de outubro de 2026  
**Autor:** Trovão  
**Escopo:** Diretrizes normativas, armadilhas identificadas na esteira e convenções para escrita e manutenção de testes unitários (`Swift Testing`), testes de integração e testes de interface (`XCTest`) no repositório `frila-frontend`.

---

## 1. Compilar Contra a API Real (Sem Assinaturas Fantasmas)

### A Armadilha
Ao escrever testes unitários em branches isoladas ou sob pressão de tempo, é comum deduzir ou inventar mentalmente a assinatura de helpers, formatadores e clientes de API (exemplo: chamar `formatador.moeda(100)` ou inventar métodos em dublês). Quando o código é submetido, a compilação local ou a CI quebra imediatamente com erros de tipo, bloqueando a esteira.

### Padrão Normativo
- **Sempre conferir a declaração pública real** do tipo antes de instanciá-lo ou chamá-lo nos testes.
- **Caso Real no Repositório:** No tipo `FormatadorFrila` (`iOS/Sources/Dominio/FormatadorFrila.swift:9`), o método disponível é:
  ```swift
  public func dinheiro(_ valor: Dinheiro) -> String
  ```
  O teste unitário em `iOS/Tests/Unitarios/DinheiroTests.swift:104-107` compila estritamente contra essa assinatura:
  ```swift
  let formatador = FormatadorFrila()
  let formatado = formatador.dinheiro(valor)
  ```
- **Conferência de Enums e Contrato:** Em `iOS/Tests/Unitarios/ErrosAPITests.swift:18-31`, o teste lê o arquivo OpenAPI espelhado diretamente do disco (`Contrato/openapi.yaml`) e confere que cada código retornado pelo contrato possui um caso idêntico em `CodigoErroAPI` (`iOS/Sources/Dominio/ErrosDaAPI.swift:3-42`). Se o backend adicionar um código novo, o teste quebra na hora impedindo que o app caia no fallback genérico `.desconhecido`.

---

## 2. Decodable Sintetizado Burla Validações de `init`

### A Armadilha
No Swift, structs que conformam a `Codable` recebem implementações automáticas sintetizadas de `init(from: Decoder)` e `encode(to: Encoder)`. **O `init(from: Decoder)` gerado pelo compilador acessa a memória bruta das propriedades e NÃO invoca o inicializador customizado da struct**.  
Consequentemente, qualquer `precondition(...)`, `assert(...)` ou `guard ... else { throw }` presente no `init(...)` do tipo é sumariamente ignorado quando o objeto é decodificado via JSON (vindo de API ou do cache local em disco).

### Casos no Repositório
1. **`Dinheiro`:** O inicializador primário em `iOS/Sources/Dominio/ObjetosDeValor.swift:6-9` exige que o valor não seja negativo:
   ```swift
   public init(centavos: Int) {
       precondition(centavos >= 0, "Dinheiro não pode ter centavos negativos")
       self.centavos = centavos
   }
   ```
   Entretanto, um payload JSON `{"centavos": -1}` burlava a pré-condição na decodificação. Foi implementado `init(from decoder: Decoder)` explícito em `iOS/Sources/Dominio/ObjetosDeValor.swift:11-22`:
   ```swift
   public init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)
       let valor = try container.decode(Int.self, forKey: .centavos)
       guard valor >= 0 else {
           throw DecodingError.dataCorruptedError(
               forKey: .centavos,
               in: container,
               debugDescription: "Dinheiro não pode ter centavos negativos: \(valor)"
           )
       }
       self.centavos = valor
   }
   ```
   O teste de decodificação negativa correspondente comprova a rejeição em `iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift:30-41`.

2. **`Coordenada`:** O `init` nominal em `iOS/Sources/Dominio/ObjetosDeValor.swift:46-51` valida intervalos geodésicos (`-90...90` e `-180...180`), além de rejeitar `NaN` e `isInfinite`. A decodificação defensiva foi implementada em `iOS/Sources/Dominio/ObjetosDeValor.swift:53-70`, testada em `iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift:66-77`.

3. **Lacuna Conhecida (`Periodo`):** O tipo `Periodo` em `iOS/Sources/Dominio/ObjetosDeValor.swift:105-111` valida `guard fim > inicio else { throw .fimNaoPosteriorAoInicio }` no inicializador comum, mas conforma a `Codable` de forma sintetizada (sem `init(from: Decoder)` defensivo). Hoje, dados decodificados diretamente ignoram a restrição de término posterior ao início — vulnerabilidade apontada na revisão do PR #338 com correção preparada para follow-up.

---

## 3. Divisão da Suíte na CI: `@Suite struct` vs. `XCTestCase`

### A Arquitetura da CI
Para viabilizar paralelismo e limitar o tempo de execução na máquina macOS da CI, o workflow `.github/workflows/ios.yml:100-103` executa:
```bash
Scripts/teste-partes-dos-testes.sh
Scripts/partes-dos-testes.sh conferir
```
Esse portão valida se a Parte 1 (`-only-testing`) e a Parte 2 (`-skip-testing`) somam a suíte inteira, sem sobreposições e sem testes esquecidos.

### A Restrição de Swift Testing (`@Suite struct`)
- O script `iOS/Scripts/partes-dos-testes.sh:82-83` inspeciona estaticamente o código via regex:
  ```python
  declaracao = re.compile(
      r"^\s*(?:@\w+\s+)*(?:(?:public|internal|open|final)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)
  ```
- **Consequência:** O script mapeia exclusivamente classes derivadas de `XCTestCase`. Tipos `@Suite struct` do Swift Testing não são reconhecidos por essa expressão.
- **Mensagem de Erro Real:** Caso uma struct de teste unitário seja incluída na lista (por exemplo, `FrilaTests/DinheiroTests`), o script falha em `iOS/Scripts/partes-dos-testes.sh:107-108` com:
  ```text
  ERRO: classe FrilaTests/DinheiroTests da lista não existe em FrilaTests (renomeada ou apagada?)
  ```
  *(A mensagem alternativa de linhas 112-114 só é disparada se uma classe `XCTestCase` válida for listada conjuntamente com o alvo inteiro).*
- **Regra de Catalogação:** Em `iOS/Tests/parte-1-da-ci.txt:11`, o alvo `FrilaTests` é catalogado **por inteiro**:
  ```text
  FrilaTests
  ```
  Portanto, **nunca** liste suítes unitárias individuais sob `FrilaTests/` no arquivo `parte-1-da-ci.txt`. Apenas classes individuais de interface do alvo `FrilaUITests` (`iOS/Tests/parte-1-da-ci.txt:12-23`) devem constar na divisão.

---

## 4. Datas Determinísticas (Preferir Datas Fixas)

### A Armadilha
Instanciar `Date()` ou `Date.now` dinamicamente em testes gera testes instáveis (*flaky*):
- O teste pode passar durante o dia e quebrar em builds noturnas por virada de meia-noite (UTC vs horário local);
- Diferenças de submilissegundos entre o disparo da ação e a asserção quebram checagens de igualdade;
- Em `iOS/Scripts/conferir-datas-fixas.sh:3`, o repositório barra datas literais de 2025/2026 em tipos de dublê nos testes.

### Padrão Recomendado
Embora o código legado ainda apresente usos de `Date()` (ex.: `iOS/Tests/Unitarios/DispositivoPushTests.swift:15`), deve-se **preferir timestamps epoch fixos** (`Date(timeIntervalSince1970:)`):
- Em `iOS/Tests/Unitarios/RepublicarVagaViewModelTests.swift:38`:
  ```swift
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  ```
- Em `iOS/Tests/Unitarios/PresencaBordasTests.swift:50`:
  ```swift
  private let agora = Date(timeIntervalSince1970: 1_791_000_000)
  ```
- Em `iOS/Tests/Unitarios/SwiftDataTests.swift:18`:
  ```swift
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  ```
- Para aferir intervalos relativos, calcule deslocamentos sobre a data base fixa: `base.addingTimeInterval(3600)`.

---

## 5. Identificadores de UI Estáveis (`accessibilityIdentifier`)

### A Armadilha
Buscar elementos na árvore de interface por seu texto visível (ex.: `app.buttons["Continuar"]`) cria fragilidade:
- O teste quebra caso a cópia de produto seja refinada no `GuiaDeVoz.md`;
- Quebra ao testar internacionalização ou suporte a múltiplos idiomas;
- Pode colidir com rótulos repetidos na tela.

### Padrão Normativo
Todo elemento interativo deve ter um identificador semântico único e estável atribuído via `.accessibilityIdentifier(...)`:
- No código de apresentação:
  - `iOS/Sources/Apresentacao/Componentes.swift:424`:
    ```swift
    .accessibilityIdentifier(valor ? "resposta-sim" : "resposta-nao")
    ```
  - `iOS/Sources/Apresentacao/CatalogoDesignSystem.swift:54`:
    ```swift
    .accessibilityIdentifier("abrir-licencas")
    ```
  - `iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:79`:
    ```swift
    .accessibilityIdentifier("cadastro-nome")
    ```
- Na suíte de testes de UI correspondente:
  - `iOS/Tests/UI/AcessibilidadeDoContratanteUITests.swift:288-289`:
    ```swift
    let sim = app.buttons["resposta-sim"]
    let nao = app.buttons["resposta-nao"]
    ```
  - `iOS/Tests/UI/AcessibilidadeDoCatalogoUITests.swift:79`:
    ```swift
    let fim = app.buttons["abrir-licencas"]
    ```

---

## 6. Esperas Assíncronas Explícitas com `tocar()` e `esperarHabilitado`

### A Armadilha
Chamar `elemento.tap()` logo após uma transição frequentemente dispara falhas de XCTest (`element not hittable` ou timeouts de sincronização de UI). O uso de `sleep` cego é expressamente proibido por desacelerar a esteira e não resolver corridas em runners sob alta carga.

### Padrão Normativo
O módulo `iOS/Tests/UI/Esperas.swift` provê rotinas para aguardar antes de interagir:
1. **Helper `tocar(...)`** (`iOS/Tests/UI/Esperas.swift:10-18`):
   ```swift
   func tocar(_ elemento: XCUIElement, timeout: TimeInterval = Espera.aparecer, file: StaticString = #filePath, line: UInt = #line) {
       XCTAssertTrue(elemento.waitForExistence(timeout: timeout), file: file, line: line)
       if !elemento.isHittable || !elemento.isEnabled {
           let pronto = NSPredicate(format: "hittable == true AND enabled == true")
           let espera = XCTNSPredicateExpectation(predicate: pronto, object: elemento)
           _ = XCTWaiter.wait(for: [espera], timeout: timeout)
       }
       elemento.tap()
   }
   ```
   *Nota de implementação:* A rotina aguarda a existência e tenta esperar que o elemento se torne interagível via predicado antes de executar o toque.
2. **Helper `esperarHabilitado(...)`** (`iOS/Tests/UI/Esperas.swift:28-34`):
   Aguarda assincronamente a transição de estado de botões e controles via `XCTNSPredicateExpectation`.

---

## 7. Mutação Obrigatória

### O Princípio
Um teste automatizado só tem valor se for comprovado que ele **reprova quando a regra de produção for alterada**. Antes de submeter código, aplique uma mutação de teste (mentalmente ou localmente) para validar a eficácia da asserção.

### Exemplos no Repositório
1. **Comparação Estrita de Valores (`Dinheiro`):**  
   Em `iOS/Tests/Unitarios/DinheiroTests.swift:69-72`:
   ```swift
   #expect(d10 < d20)
   #expect(!(d20 < d10))
   #expect(!(d20 < d20Outro))
   #expect(d20 == d20Outro)
   ```
   Se a implementação de `<` em `iOS/Sources/Dominio/ObjetosDeValor.swift:34` for mutada para `<=`, as asserções `!(d20 < d20Outro)` e `!(d20 < d10)` reprovariam imediatamente.
2. **Exaustividade de Catálogo (`ErrosDaAPI`):**  
   Em `iOS/Tests/Unitarios/ErrosAPITests.swift:30-31`:
   ```swift
   let semCaso = codigos.filter { CodigoErroAPI(rawValue: $0) == nil }.sorted()
   #expect(semCaso.isEmpty, "códigos do contrato sem caso em CodigoErroAPI: \(semCaso)")
   ```
   Se qualquer código presente no OpenAPI espelhado for omitido do enum de domínio, a lista não vazia reprovaria o teste. O mesmo raciocínio foi aplicado no PR #340 para as propriedades `recusaDefinitivaDePublicacao` e `recusaDefinitivaDeCancelamento` (`iOS/Sources/Dominio/ErrosDaAPI.swift:57-66`), onde percorrer `allCases` garante que inclusões, exclusões ou inversões de fallback reprovariam a suíte.

---

## 8. Não Afirmar o que o Teste Não Prova (Evitar Tautologias)

### A Armadilha dos Testes Tautológicos
Um teste tautológico é aquele que afirma um estado que ele próprio acabou de atribuir localmente, sem exercitar qualquer método, mutação ou invariante do tipo sob teste.

### Exemplos e Correções (PR #337 / PR #339)
- **Atribuição Local vs Lógica do Tipo:**  
  Na `main` (`iOS/Tests/Unitarios/DispositivoPushTests.swift:73-80`), o teste simula desvinculação manipulando campos de um struct:
  ```swift
  aparelho.contaAnterior = aparelho.vinculo?.contaID
  aparelho.vinculo = nil
  #expect(aparelho.contaAnterior == conta1)
  ```
  Esse teste afere apenas a atribuição da propriedade em memória realizada pelo próprio teste, pois `AparelhoGuardado` é uma estrutura simples sem métodos. Na revisão do PR #337, orientou-se renomear o teste para deixar explícito que se trata apenas de vinculação e desvinculação campo a campo, sem vender uma falsa ideia de validação de fluxo de negócio.
- **Asserções Frouxas:**  
  Em `iOS/Tests/Unitarios/DispositivoPushTests.swift:90` na `main`, asserir que a string JSON codificada continha `"ios"` (`#expect(string.contains("ios"))`) é frouxo, pois passaria para valores como `"curiosidade"` ou `"ios_fake"`. Em revisões de PR (como no #339), o padrão é exigir correspondência estrita (`string == "\"ios\""`).

---

## 9. Checklist Pré-Submissão de Testes

Antes de abrir um PR envolvendo testes no iOS:
- [ ] O código compila contra as assinaturas públicas reais (`FormatadorFrila`, DTOs, etc.).
- [ ] Todo novo tipo de valor `Codable` com invariantes possui `init(from: Decoder)` com `DecodingError.dataCorruptedError`.
- [ ] Novas suítes unitárias (`@Suite struct`) pertencem ao alvo `FrilaTests` e **não** são adicionadas como classes avulsas em `parte-1-da-ci.txt`.
- [ ] Preferência estrita por datas fixas (`Date(timeIntervalSince1970:)`) para evitar instabilidade temporal.
- [ ] Elementos de UI são referenciados via `.accessibilityIdentifier(...)` e nunca por texto mutável.
- [ ] Toques e validações de interface utilizam os helpers de `Esperas.swift` (`tocar`, `esperarHabilitado`).
- [ ] O teste foi submetido a verificação de mutação para assegurar que reprovaria diante de falha real.
- [ ] Foram eliminadas asserções tautológicas e verificações parciais frouxas.
