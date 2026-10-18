# Fixture Binário: FrilaV3-gravado-esquema-v3.store

## Origem e Propósito
Este arquivo é um banco de dados SQLite/SwiftData binário pré-gravado para validar a migração de persistência do `EsquemaFrilaV3` para o `EsquemaFrilaV4` sem que a suíte de testes dependa da declaração ou instanciação de `EsquemaFrilaV3` em tempo de execução.

- **Data de Geração:** 17 de outubro de 2026.
- **Commit Base:** `73ec118` (PR #389).
- **Nota de Integridade:** Este fixture foi gerado por gravação direta em disco utilizando as definições formais de `EsquemaFrilaV3` no contexto de testes da suíte iOS, e **não** extraído de um build antigo do aplicativo instalado em dispositivo real.
- **Ciclo de Vida:** O fixture só deve ser regerado se o `EsquemaFrilaV3` (lista de modelos persistidos) sofrer alteração estrutural, o que **não deve ocorrer** em condições normais, visto que o V3 é uma versão de esquema histórica e imutável.

---

## Conteúdo Real do Store e Mapeamento de Testes
O arquivo contém exclusivamente dados sintéticos determinísticos (sem PII real, telefones reais ou tokens de sessão). Os valores batem estritamente com os dados preparados pelo teste `migracaoEsquemaV3ParaV4ConservaDadosEContato` e validados pelo teste `migracaoEsquemaV3ParaV4ComFixtureBinario`:

| Entidade / Coluna SQLite | Valor Sintético Gravado | Onde o Teste o Usa (`SwiftDataTests.swift`) |
|---|---|---|
| `TurnoPersistido.ZID` | `11111111-2222-3333-4444-555555555555` | `XCTAssertEqual(turnoApos.id, turnoID)` |
| `TurnoPersistido.ZPOSICAOID` | `22222222-3333-4444-5555-666666666666` | `XCTAssertEqual(turnoApos.posicaoID, posicaoID)` |
| `TurnoPersistido.ZCONTEUDO` (contraparte) | `33333333-4444-5555-6666-777777777777` ("Café Gourmet") | `XCTAssertEqual(turnoApos.contraparte.nome, "Café Gourmet")` |
| `TurnoPersistido.ZCONTEUDO` (função) | "Barista" | `XCTAssertEqual(turnoApos.vaga.funcao, "Barista")` |
| `TurnoPersistido.ZSALVOEM` | `1800000000` (timestamp CoreData: `821692800`, 2027-01-15T08:00:00Z) | `XCTAssertEqual(tApos.salvoEm, agora)` |
| `TurnoPersistido.ZFIM` | `1800014400` (+4 horas, CoreData: `821707200`) | `XCTAssertEqual(tApos.fim, agora.addingTimeInterval(14_400))` |
| `TurnoPersistido.ZCONTATOVISIVELATE` | `1800086400` (+24 horas, CoreData: `821779200`) | `XCTAssertEqual(tApos.contatoVisivelAte, agora.addingTimeInterval(86_400))` |
| `TurnoPersistido.ZCONTEUDO` (valor) | 15.000 centavos (R$ 150,00) | `XCTAssertEqual(turnoApos.valorAcordado, Dinheiro(centavos: 15_000))` |
| `ContatoDoTurnoPersistido.ZTURNOID` | `11111111-2222-3333-4444-555555555555` | `XCTAssertEqual(contatos.first?.turnoID, turnoID)` |
| `ContatoDoTurnoPersistido.ZCONTEUDO` | Nome: "Gerente Café", Telefone: "+5561988887777", WhatsApp: `https://wa.me/5561988887777` | `XCTAssertEqual(contatoDecodificado.nome, "Gerente Café")` / `XCTAssertEqual(contatoDecodificado.telefone, "+5561988887777")` |
| `AcaoPendentePersistida.ZID` | `69CF3F50-2C05-4610-8CB7-0A9E1548E037` | `XCTAssertEqual(acoes.first?.id, acaoID)` |
| `AcaoPendentePersistida.ZTIPO` | `"checkin"` | `XCTAssertEqual(acaoDecodificada.tipo, .checkin)` |
| `AcaoPendentePersistida.ZCONTEUDO` (chave) | `44444444-5555-6666-7777-888888888888` | `XCTAssertEqual(acaoDecodificada.chave, chaveAcao)` |
| `AcaoPendentePersistida.ZCONTEUDO` (instante) | `1800000000` | `XCTAssertEqual(acaoDecodificada.instanteDoToque, agora)` |
| `AcaoPendentePersistida.ZCONTEUDO` (distância) | `15` metros | `XCTAssertEqual(acaoDecodificada.distanciaMetros, 15)` |
| `AcaoRecusadaPersistida.ZID` | `69CF3F50-2C05-4610-8CB7-0A9E1548E037` | `XCTAssertEqual(recusas.first?.id, acaoID)` |
| `AcaoRecusadaPersistida.ZCONTEUDO` (código) | `"vaga_encerrada"` (`.vagaEncerrada`) | `XCTAssertEqual(recusaDecodificada.codigo, .vagaEncerrada)` |
| `FuncaoPersistida.ZID` | `55555555-6666-7777-8888-999999999999` | `XCTAssertEqual(funcoes.first?.id, funcaoID)` |
| `SessaoPersistida.ZCONTEUDO` (usuarioID) | `66666666-7777-8888-9999-000000000000` | `XCTAssertEqual(sessaoDecodificada.usuarioID, usuarioID)` |
| `SessaoPersistida.ZCONTEUDO` (perfil) | `"profissional"` (`.profissional`) | `XCTAssertEqual(sessaoDecodificada.perfil, .profissional)` |

---

## Como Regerar este Fixture

> **Dica:** O teste `migracaoEsquemaV3ParaV4ConservaDadosEContato` em `SwiftDataTests.swift` já instancia um container V3 e grava exatamente esse conjunto de dados antes de aplicar a migração. O procedimento abaixo isola a gravação inicial determinística em arquivo permanente.

### Passo 1: Executar a gravação dos dados via Swift
Execute o bloco abaixo dentro do contexto da suíte de testes do Xcode (por exemplo em um método temporário de teste em `SwiftDataTests.swift`), que importa `@testable import FrilaDados`, `FrilaDominio`, `Foundation` e `SwiftData`:

```swift
// Resolve caminho absoluto determinístico no projeto sem depender do diretório de sandbox do simulador
let raiz = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // Unitarios/
    .deletingLastPathComponent() // Tests/
let urlDestino = raiz.appending(path: "Fixtures/SwiftData/FrilaV3-gravado-esquema-v3.store")

// Remove artefatos pré-existentes
for sufixo in ["", "-wal", "-shm"] {
    try? FileManager.default.removeItem(at: URL(fileURLWithPath: urlDestino.path + sufixo))
}

let agora = Date(timeIntervalSince1970: 1_800_000_000)
let turnoID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
let posicaoID = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
let estabelecimentoID = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
let acaoID = UUID(uuidString: "69CF3F50-2C05-4610-8CB7-0A9E1548E037")!
let chaveAcao = UUID(uuidString: "44444444-5555-6666-7777-888888888888")!
let funcaoID = UUID(uuidString: "55555555-6666-7777-8888-999999999999")!
let usuarioID = UUID(uuidString: "66666666-7777-8888-9999-000000000000")!

let periodo = try Periodo(inicio: agora, fim: agora.addingTimeInterval(14_400))
let resumo = VagaResumo(id: UUID(uuidString: "44444444-0000-0000-0000-000000000001")!, funcao: "Barista", local: "Asa Norte", regiaoAdministrativa: "Brasília", periodo: periodo, valor: Dinheiro(centavos: 15_000))
let reputacao = Reputacao(positivas: 5, total: 5, taxaComparecimento: 1, turnosConsiderados: 5, turnosRealizados: 5)
let contraparte = PerfilPublico(id: estabelecimentoID, tipo: .estabelecimento, nome: "Café Gourmet", reputacao: reputacao)
let contato = Contato(nome: "Gerente Café", telefone: "+5561988887777", whatsappURL: URL(string: "https://wa.me/5561988887777")!, visivelAte: agora.addingTimeInterval(86_400))
let turno = Turno(id: turnoID, posicaoID: posicaoID, vaga: resumo, contraparte: contraparte, contatoVisivelAte: agora.addingTimeInterval(86_400), verificacao: .pendente, valorAcordado: Dinheiro(centavos: 15_000), podeAvaliar: false, contato: nil)

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

let acao = AcaoPendente(id: acaoID, tipo: .checkin, turnoID: turnoID, instanteDoToque: agora, chave: chaveAcao, distanciaMetros: 15)
let acaoRecusada = AcaoRecusada(acao: acao, codigo: .vagaEncerrada)
let funcao = Funcao(id: funcaoID, nome: "Barista", categoria: "Cafeteria")
let sessao = SessaoUsuario(usuarioID: usuarioID, perfil: .profissional)

do {
    let esquemaV3 = Schema(versionedSchema: EsquemaFrilaV3.self)
    let configV3 = ModelConfiguration("FrilaV3", schema: esquemaV3, url: urlDestino)
    let containerV3 = try ModelContainer(for: esquemaV3, configurations: [configV3])
    let contextoV3 = ModelContext(containerV3)

    contextoV3.insert(TurnoPersistido(id: turnoID, conteudo: try encoder.encode(turno), fim: periodo.fim, contatoVisivelAte: turno.contatoVisivelAte, salvoEm: agora))
    contextoV3.insert(ContatoDoTurnoPersistido(turnoID: turnoID, conteudo: try JSONEncoder().encode(contato)))
    contextoV3.insert(AcaoPendentePersistida(id: acao.id, tipo: acao.tipo.rawValue, conteudo: try encoder.encode(acao), instanteDoToque: acao.instanteDoToque))
    contextoV3.insert(AcaoRecusadaPersistida(id: acaoRecusada.id, conteudo: try JSONEncoder().encode(acaoRecusada)))
    contextoV3.insert(FuncaoPersistida(id: funcao.id, conteudo: try JSONEncoder().encode(funcao)))
    contextoV3.insert(SessaoPersistida(conteudo: try JSONEncoder().encode(sessao)))
    try contextoV3.save()
}
// Escopo fechado para garantir a liberação e fechamento dos handles do ModelContainer
```

### Passo 2: Checkpoint de WAL e limpeza de arquivos auxiliares
No terminal, execute o checkpoint para incorporar as transações pendentes de Write-Ahead Logging diretamente ao arquivo `.store` e remover os arquivos auxiliares temporários (`-wal` e `-shm`):

```bash
STORE_PATH="iOS/Tests/Fixtures/SwiftData/FrilaV3-gravado-esquema-v3.store"

# Executa checkpoint completo truncando o log WAL
sqlite3 "$STORE_PATH" "PRAGMA wal_checkpoint(TRUNCATE);"

# Remove -wal e -shm se remanescentes
rm -f "$STORE_PATH-wal" "$STORE_PATH-shm"

# Verifica integridade do arquivo SQLite resultante
sqlite3 "$STORE_PATH" "PRAGMA integrity_check;"
# Deve retornar: ok
```

### Passo 3: Conferência estrita de Z_PRIMARYKEY
Verifique se exatamente as 6 entidades do esquema V3 estão registradas com `Z_MAX = 1` e que nenhuma tabela de esquema posterior (como `EventoDeTelemetriaPersistido` do V4) foi gravada:

```bash
sqlite3 "$STORE_PATH" "SELECT Z_NAME, Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME NOT LIKE 'CHANGE%' AND Z_NAME NOT LIKE 'TRANSACTION%';" | sort
```

Saída esperada:
```
AcaoPendentePersistida|1
AcaoRecusadaPersistida|1
ContatoDoTurnoPersistido|1
FuncaoPersistida|1
SessaoPersistida|1
TurnoPersistido|1
```
