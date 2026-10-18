# Fixture Binário: FrilaV3-gravado-esquema-v3.store

## Origem e Propósito
Este arquivo é um banco de dados SQLite/SwiftData binário pré-gravado para validar a migração de persistência do `EsquemaFrilaV3` para o `EsquemaFrilaV4` sem que a suíte de testes precise instanciar ou declarar o esquema V3 em tempo de execução.

**Nota:** Este fixture foi gerado por gravação direta em disco utilizando as definições formais de `EsquemaFrilaV3`, e **não** extraído de um build antigo do aplicativo instalado em dispositivo real.

## Conteúdo do Store
O arquivo contém exclusivamente dados sintéticos determinísticos (sem PII real, telefones reais ou tokens de sessão):
- 1 `TurnoPersistido` (ID `40000000-0000-0000-0000-000000000001`, função "Barista", contraparte "Café Gourmet")
- 1 `ContatoDoTurnoPersistido` (telefone sintético "+5561988887777", nome "Gerente Café")
- 1 `AcaoPendentePersistida` (tipo check-in, chave UUID sintética)
- 1 `AcaoRecusadaPersistida` (código de recusa `vaga_encerrada`)
- 1 `FuncaoPersistida` (categoria "Cafeteria", nome "Barista")
- 1 `SessaoPersistida` (perfil profissional)

## Como Regerar este Fixture
Se o modelo ou os tipos do esquema V3 mudarem, execute no contexto de testes do Xcode:

```swift
let url = URL(fileURLWithPath: "iOS/Tests/Fixtures/SwiftData/FrilaV3-gravado-esquema-v3.store")
try? FileManager.default.removeItem(at: url)

let esquemaV3 = Schema(versionedSchema: EsquemaFrilaV3.self)
let config = ModelConfiguration("FrilaV3", schema: esquemaV3, url: url)
let container = try ModelContainer(for: esquemaV3, configurations: [config])
let contexto = ModelContext(container)

// Insira os modelos sintéticos utilizando EsquemaFrilaV3...
contexto.insert(...)
try contexto.save()
```
