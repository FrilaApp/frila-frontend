# Guia de Testes Swift e Padrões da Suíte iOS

**Data de consolidação:** 16 de outubro de 2026  
**Autores:** Engenharia iOS (Trovão / Oráculo / Marika I)  
**Escopo:** Diretrizes normativas, armadilhas identificadas em produção e convenções para escrita e manutenção de testes unitários (`Swift Testing`), testes de integração e testes de interface (`XCTest`) no repositório `frila-frontend`.

---

## 1. Compilar Contra a API Real (Sem Assinaturas Fantasmas)

### A Armadilha
Ao escrever testes unitários em branches isoladas ou sob pressão de tempo, é comum deduzir ou inventar mentalmente a assinatura de helpers, formatadores e clientes de API (exemplo: chamar `formatador.moeda(100)` ou inventar métodos em dublês). Quando o código é submetido, a compilação local ou a CI quebra imediatamente com erros de tipo, bloqueando a esteira.

### Padrão Normativo
- **Sempre conferir a declaração pública real** do tipo antes de instanciá-lo ou chamá-lo nos testes.
- **Caso Real no Repositório:** No tipo `FormatadorFrila` ([`iOS/Sources/Dominio/FormatadorFrila.swift:9`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/FormatadorFrila.swift#L9)), o método disponível é:
  ```swift
  public func dinheiro(_ valor: Dinheiro) -> String
  ```
  O teste unitário em [`iOS/Tests/Unitarios/DinheiroTests.swift:104-107`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DinheiroTests.swift#L104-L107) compila estritamente contra essa assinatura:
  ```swift
  let formatador = FormatadorFrila()
  let formatado = formatador.dinheiro(valor)
  ```
- **Conferência de Enums e Contrato:** Em [`iOS/Tests/Unitarios/ErrosAPITests.swift:18-31`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/ErrosAPITests.swift#L18-L31), o teste lê o arquivo OpenAPI espelhado diretamente do disco (`Contrato/openapi.yaml`) e confere que cada código retornado pelo contrato possui um caso idêntico em `CodigoErroAPI` ([`iOS/Sources/Dominio/ErrosDaAPI.swift:3-42`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ErrosDaAPI.swift#L3-L42)). Se o backend adicionar um código novo, o teste quebra na hora impedindo que o app caia no fallback genérico `.desconhecido`.

---

## 2. Decodable Sintetizado Burla Validações de `init`

### A Armadilha
No Swift, structs que conformam a `Codable` recebem implementações automáticas sintetizadas de `init(from: Decoder)` e `encode(to: Encoder)`. **O `init(from: Decoder)` gerado pelo compilador acessa a memória bruta das propriedades e NÃO invoca o inicializador customizado da struct**.  
Consequentemente, qualquer `precondition(...)`, `assert(...)` ou `guard ... else { throw }` presente no `init(...)` do tipo é sumariamente ignorado quando o objeto é decodificado via JSON (vindo de API ou do cache local em disco).

### Casos Reais no Repositório
1. **`Dinheiro`:** O inicializador primário em [`iOS/Sources/Dominio/ObjetosDeValor.swift:6-9`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ObjetosDeValor.swift#L6-L9) exige que o valor não seja negativo:
   ```swift
   public init(centavos: Int) {
       precondition(centavos >= 0, "Dinheiro não pode ter centavos negativos")
       self.centavos = centavos
   }
   ```
   Entretanto, um payload JSON `{"centavos": -1}` burlava a pré-condição. Foi obrigatório implementar `init(from decoder: Decoder)` explícito em [`iOS/Sources/Dominio/ObjetosDeValor.swift:11-22`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ObjetosDeValor.swift#L11-L22):
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
   O teste de decodificação negativa correspondente comprova a rejeição em [`iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift:30-41`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift#L30-L41).

2. **`Coordenada`:** O `init` nominal em [`iOS/Sources/Dominio/ObjetosDeValor.swift:46-51`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ObjetosDeValor.swift#L46-L51) valida intervalos geodésicos (`-90...90` e `-180...180`), além de rejeitar `NaN` e `isInfinite`. A decodificação defensiva foi implementada em [`iOS/Sources/Dominio/ObjetosDeValor.swift:53-70`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ObjetosDeValor.swift#L53-L70), testada em [`iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift:66-77`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DecodificacaoValoresDeDominioTests.swift#L66-L77).

3. **`Periodo`:** Struct de início e fim de turno. Se sintetizada, aceitaria `fim <= inicio`. O guard exige `init(from: Decoder)` com `dataCorruptedError` quando o término não for estritamente posterior ao início.

---

## 3. Divisão da Suíte na CI: `@Suite struct` vs. `XCTestCase`

### A Arquitetura da CI
Para viabilizar paralelismo e limitar o tempo de execução na máquina macOS da CI, o workflow [`.github/workflows/ios.yml:100-103`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/.github/workflows/ios.yml#L100-L103) executa:
```bash
Scripts/teste-partes-dos-testes.sh
Scripts/partes-dos-testes.sh conferir
```
Esse portão garante que a Parte 1 (`-only-testing`) e a Parte 2 (`-skip-testing`) somem a suíte inteira, sem sobreposições e sem testes esquecidos.

### A Armadilha de Swift Testing (`@Suite struct`)
- O script [`iOS/Scripts/partes-dos-testes.sh:82-83`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Scripts/partes-dos-testes.sh#L82-L83) faz a reflexão estática via expressão regular:
  ```python
  declaracao = re.compile(
      r"^\s*(?:@\w+\s+)*(?:(?:public|internal|open|final)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)
  ```
- **Consequência:** O script busca exclusivamente classes derivadas de `XCTestCase`. Tipos `@Suite struct` do novo framework Swift Testing **não** são reconhecidos como classes individuais por essa expressão regular.
- **Regra de Catalogação:** Em [`iOS/Tests/parte-1-da-ci.txt:11`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/parte-1-da-ci.txt#L11), o alvo `FrilaTests` é catalogado **por inteiro**:
  ```text
  FrilaTests
  ```
  Portanto, **NUNCA** liste structs de teste individuais (ex: `FrilaTests/DinheiroTests`) no arquivo `parte-1-da-ci.txt`. Fazer isso causa falha de validação imediata em [`iOS/Scripts/partes-dos-testes.sh:112-114`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Scripts/partes-dos-testes.sh#L112-L114):
  `ERRO: a lista tem o alvo FrilaTests inteiro e também classes dele`.  
  Apenas classes individuais de interface do alvo `FrilaUITests` devem constar na lista (linhas 12 a 23 de `parte-1-da-ci.txt`).

---

## 4. Datas Determinísticas sem `Date()`

### A Armadilha
Instanciar `Date()` ou `Date.now` em testes gera testes instáveis e não determinísticos (*flaky*):
- O teste pode passar durante o dia e quebrar em builds noturnas por virada de meia-noite (UTC vs horário local);
- Diferenças de submilissegundos entre o momento do evento e a asserção quebram checagens de igualdade;
- A CI do projeto possui um validador obrigatório em [`iOS/Scripts/conferir-datas-fixas.sh:3-7`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Scripts/conferir-datas-fixas.sh#L3-L7) que recusa datas literais voláteis em tipos de dublês.

### Padrão Normativo
Use sempre timestamps epoch fixos (`Date(timeIntervalSince1970:)`) para pontos no tempo:
- Em [`iOS/Tests/Unitarios/DispositivoPushTests.swift:10`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DispositivoPushTests.swift#L10):
  ```swift
  private static let dataFixa = Date(timeIntervalSince1970: 1_700_000_000)
  ```
- Em [`iOS/Tests/Unitarios/RepublicarVagaViewModelTests.swift:38`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/RepublicarVagaViewModelTests.swift#L38):
  ```swift
  let base = Date(timeIntervalSince1970: 1_800_000_000)
  ```
- Em [`iOS/Tests/Unitarios/PresencaBordasTests.swift:50`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/PresencaBordasTests.swift#L50):
  ```swift
  private let agora = Date(timeIntervalSince1970: 1_791_000_000)
  ```
- Para janelas relativas, desloque segundos a partir da data base fixa: `base.addingTimeInterval(3600)`.

---

## 5. Identificadores de UI Estáveis (`accessibilityIdentifier`)

### A Armadilha
Buscar elementos na árvore de interface por seu texto visível (ex.: `app.buttons["Continuar"]` ou `app.staticTexts["Salvar"]`) cria fragilidade extrema:
- O teste falha caso a cópia de produto ou tom de voz seja refinada no `GuiaDeVoz.md`;
- Quebra ao testar internacionalização ou suporte a múltiplos idiomas;
- Pode conflitar com títulos repetidos na mesma hierarquia de views.

### Padrão Normativo
Todo elemento interativo deve ter um identificador semântico único e estável atribuído via `.accessibilityIdentifier(...)`:
- No código de apresentação:
  - [`iOS/Sources/Apresentacao/Componentes.swift:424`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Apresentacao/Componentes.swift#L424):
    ```swift
    .accessibilityIdentifier(valor ? "resposta-sim" : "resposta-nao")
    ```
  - [`iOS/Sources/Apresentacao/CatalogoDesignSystem.swift:54`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Apresentacao/CatalogoDesignSystem.swift#L54):
    ```swift
    .accessibilityIdentifier("abrir-licencas")
    ```
  - [`iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift:79`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Apresentacao/Fluxos/Autenticacao/TelaCadastro.swift#L79):
    ```swift
    .accessibilityIdentifier("cadastro-nome")
    ```
- Na suíte de testes de UI correspondente:
  - [`iOS/Tests/UI/AcessibilidadeDoContratanteUITests.swift:288-289`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/UI/AcessibilidadeDoContratanteUITests.swift#L288-L289):
    ```swift
    let sim = app.buttons["resposta-sim"]
    let nao = app.buttons["resposta-nao"]
    ```
  - [`iOS/Tests/UI/AcessibilidadeDoCatalogoUITests.swift:79`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/UI/AcessibilidadeDoCatalogoUITests.swift#L79):
    ```swift
    let fim = app.buttons["abrir-licencas"]
    ```

---

## 6. Esperas Assíncronas Explícitas com `tocar()` e `esperarHabilitado`

### A Armadilha
Chamar `elemento.tap()` logo após uma transição ou tela carregar frequentemente dispara o erro clássico de XCTest:  
`Failed to tap: element not hittable` ou `background assertion timeout`.  
Recorrer a `Thread.sleep` ou `Task.sleep` cego é proibido: desacelera a esteira desnecessariamente e não elimina flakes em runners sob alta carga.

### Padrão Normativo
O módulo [`iOS/Tests/UI/Esperas.swift`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/UI/Esperas.swift) centraliza as primitivas padronizadas:
1. **Helper `tocar(...)`** ([`iOS/Tests/UI/Esperas.swift:10-18`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/UI/Esperas.swift#L10-L18)):
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
   Garante que o elemento exista, esteja habilitado e não esteja obstruído por animações antes de enviar o evento de toque.
2. **Helper `esperarHabilitado(...)`** ([`iOS/Tests/UI/Esperas.swift:28-34`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/UI/Esperas.swift#L28-L34)):
   Aguarda assincronamente até que botões com validação reativa (ex: formulários de cadastro) transitem para habilitado via `XCTNSPredicateExpectation`.

---

## 7. Mutação Obrigatória

### O Princípio
Um teste automatizado só tem valor se for comprovado que ele **falha quando o comportamento de produção for adulterado**. Antes de abrir um PR ou aprovar um teste, mentalize ou aplique uma mutação local para confirmar a quebra da suíte.

### Exemplos no Repositório
1. **Exaustividade em Enums de Erro:**  
   Em [`iOS/Tests/Unitarios/RegrasDefinitivasErrosAPITests.swift:15-21`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/RegrasDefinitivasErrosAPITests.swift#L15-L21):
   ```swift
   for codigo in CodigoErroAPI.allCases {
       if definitivos.contains(codigo) {
           #expect(codigo.recusaDefinitivaDePublicacao, "Esperava que \(codigo) fosse recusa definitiva")
       } else {
           #expect(!codigo.recusaDefinitivaDePublicacao, "Esperava que \(codigo) NÃO fosse recusa definitiva")
       }
   }
   ```
   - **Mutação:** Se alguém remover um dos casos da propriedade em [`iOS/Sources/Dominio/ErrosDaAPI.swift:57-66`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Sources/Dominio/ErrosDaAPI.swift#L57-L66) ou inverter o fallback `default: false` para `true`, o teste quebra infalivelmente.
2. **Operadores de Borda em Períodos:**  
   No guard de `Periodo` (`guard fim > inicio`):
   - Se mutado para `fim >= inicio`: o teste de `fim == inicio` reprova.
   - Se o guard for removido: os testes de rejeição com throw reprovam.
   - Se `inicio < outro.fim && outro.inicio < fim` for mutado para `<=`: os testes de períodos adjacentes passam a detectar colisão e reprovam.

---

## 8. Não Afirmar o que o Teste Não Prova (Evitar Tautologias)

### A Armadilha dos Testes Tautológicos
Um teste tautológico é aquele que afirma um estado que ele próprio atribuiu ou que não exerce nenhuma lógica de produção real. Ele cria uma falsa sensação de segurança na métrica de cobertura.

### Apontamentos Reais de Revisão (PR #337 / PR #339)
- **Atribuição Local vs Lógica do Tipo:** No teste de `AparelhoGuardado` ([`iOS/Tests/Unitarios/DispositivoPushTests.swift:75-82`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DispositivoPushTests.swift#L75-L82)), o teste original foi nomeado como *"registra transição de saída e preserva contaAnterior"*, mas o corpo do teste fazia:
  ```swift
  aparelho.contaAnterior = aparelho.vinculo?.contaID
  aparelho.vinculo = nil
  #expect(aparelho.contaAnterior == conta1)
  ```
  Isso estava apenas testando a leitura de uma propriedade que o próprio teste acabou de sobrescrever localmente, pois `AparelhoGuardado` é uma struct plana sem métodos. O teste foi corrigido e renomeado para *"aceita vincular e desvincular campo a campo"*, refletindo honestamente a sua abrangência.
- **Asserções Frouxas com `contains`:**  
  Em [`iOS/Tests/Unitarios/DispositivoPushTests.swift:107-110`](file:///Users/jotape/Documents/Frila-AO/wt-trovao-espelho-0.2.42/iOS/Tests/Unitarios/DispositivoPushTests.swift#L107-L110), asserir que a saída JSON de uma plataforma codificada continha `"ios"` (`string.contains("ios")`) era frouxo demais, pois passaria para `"curiosidade"` ou `"ios_fake"`. A asserção foi tornada estrita:
  ```swift
  #expect(string == "\"ios\"")
  ```

---

## 9. Resumo do Checklist Pré-Submissão

Antes de abrir qualquer PR de testes no iOS:
- [ ] O código compila contra as assinaturas públicas reais (`swift build` / `xcodebuild`).
- [ ] Todo struct `Codable` com invariantes possui `init(from: Decoder)` defensivo com `DecodingError`.
- [ ] Novas suítes unitárias com `@Suite struct` pertencem ao alvo `FrilaTests` e **não** foram incluídas isoladamente em `parte-1-da-ci.txt`.
- [ ] Não há chamadas a `Date()` ou `Date.now` nos testes; todas as datas são derivadas de constantes epoch fixas.
- [ ] Elementos de UI são acessados por `.accessibilityIdentifier(...)` padronizados, e não por textos traduzíveis.
- [ ] Toques e interações em testes de interface utilizam o helper `tocar(...)` de `Esperas.swift`.
- [ ] Cada asserção foi submetida a teste mental/prático de mutação.
- [ ] O teste não contém autoafirmações tautológicas de variáveis locais.
