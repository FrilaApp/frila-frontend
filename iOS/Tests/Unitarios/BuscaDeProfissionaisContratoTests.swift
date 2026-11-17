import Foundation
@testable import FrilaDados
import FrilaDominio
import Testing

/// Os tipos da busca (contrato 0.2.88) contra o `Contrato/openapi.yaml` espelhado: os JSON de
/// exemplo seguem os schemas `CartaoProfissional`, `PreferenciaChamadas` e `RecursosDoApp` e os
/// corpos de `buscar_profissionais`, `definir_preferencia_chamadas` e `chamar_profissional`.
@Suite("Busca de profissionais: DTOs do contrato 0.2.88")
struct BuscaDeProfissionaisContratoTests {
    private static let casaID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private static let garcomID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

    private static let cartaoMaria = """
    {
      "id": "b5000000-0000-0000-0000-000000000001",
      "nome": "Maria S.",
      "servico": {
        "funcao": { "id": "20000000-0000-0000-0000-000000000001", "nome": "Garçom", "categoria": "Salão" },
        "unidade": "hora",
        "valor_centavos": 3500
      },
      "regioes": [{ "id": 1, "numero": "I", "nome": "Plano Piloto", "ativo": true }],
      "atende_todo_df": false,
      "distancia_faixa": "ate_5_km",
      "reputacao": { "positivas": 9, "total": 10, "taxa_comparecimento": 0.9, "turnos_considerados": 10, "turnos_realizados": 9 },
      "disponivel_no_horario": true
    }
    """

    private func json(_ valor: some Encodable) throws -> [String: Any] {
        let dados = try JSONEncoder().encode(valor)
        return try #require(JSONSerialization.jsonObject(with: dados) as? [String: Any])
    }

    /// As propriedades de um schema do espelho, lidas do texto (como `ErrosAPITests` lê a tabela).
    private func propriedades(doSchema nome: String) throws -> Set<String> {
        let contrato = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Contrato/openapi.yaml")
        let linhas = try String(contentsOf: contrato, encoding: .utf8).components(separatedBy: "\n")
        let inicio = try #require(linhas.firstIndex(of: "    \(nome):"))
        var dentroDasPropriedades = false
        var nomes: Set<String> = []
        for linha in linhas[(inicio + 1)...] {
            let recuo = linha.prefix { $0 == " " }.count
            if recuo == 4, !linha.trimmingCharacters(in: .whitespaces).isEmpty { break } // o próximo schema
            if recuo == 6 { dentroDasPropriedades = linha == "      properties:"; continue }
            if dentroDasPropriedades, recuo == 8, linha.hasSuffix(":") {
                nomes.insert(String(linha.dropFirst(8).dropLast()))
            }
        }
        return nomes
    }

    @Test("CartaoProfissional do contrato tem exatamente os campos que o DTO lê")
    func camposDoCartao() throws {
        let doContrato = try propriedades(doSchema: "CartaoProfissional")
        // 0.2.90 (CD-B07): o cartão ganhou foto_url e foto_id, com as mesmas condições de PerfilPublico.
        #expect(doContrato == ["id", "nome", "servico", "regioes", "atende_todo_df", "distancia_faixa", "reputacao", "disponivel_no_horario",
                               "foto_url", "foto_id"])
    }

    @Test("A página decodifica o cartão inteiro e o cursor; cartão com faixa nova sai da página, os outros ficam")
    func pagina() throws {
        let corpo = """
        { "itens": [\(Self.cartaoMaria), \(Self.cartaoMaria.replacingOccurrences(of: "ate_5_km", with: "faixa_nova"))],
          "proximo_cursor": "abc" }
        """
        let dto = try ContratoAPI.decodificador().decode(ContratoAPI.RespostaBuscarProfissionais.self, from: Data(corpo.utf8))
        let (pagina, descartados) = dto.dominio()
        #expect(descartados == 1)
        #expect(pagina.proximoCursor == "abc")
        let maria = try #require(pagina.itens.first)
        #expect(maria.id == UUID(uuidString: "b5000000-0000-0000-0000-000000000001"))
        #expect(maria.nome == "Maria S.")
        #expect(maria.servico.funcao.nome == "Garçom")
        #expect(maria.servico.servico.unidade == .hora)
        #expect(maria.servico.servico.valorCentavos == 3_500)
        #expect(maria.regioes.map(\.id) == [1])
        #expect(!maria.atendeTodoDF)
        #expect(maria.distanciaFaixa == .ate5km)
        #expect(maria.reputacao.total == 10)
        #expect(maria.disponivelNoHorario == true)

        let ultima = try ContratoAPI.decodificador().decode(ContratoAPI.RespostaBuscarProfissionais.self,
                                                              from: Data(#"{"itens":[],"proximo_cursor":null}"#.utf8))
        #expect(ultima.dominio().pagina.itens.isEmpty)
        #expect(!ultima.dominio().pagina.temMais)
    }

    @Test("Sem horário, disponivel_no_horario não vem e fica nil")
    func cartaoSemSelo() throws {
        let semSelo = Self.cartaoMaria.replacingOccurrences(of: ",\n  \"disponivel_no_horario\": true", with: "")
        let dto = try ContratoAPI.decodificador().decode(ContratoAPI.CartaoProfissionalDTO.self, from: Data(semSelo.utf8))
        #expect(dto.dominio().disponivelNoHorario == nil)
    }

    @Test("O corpo de buscar_profissionais leva os filtros com os nomes do contrato; ausente fica fora")
    func corpoDaBusca() throws {
        let horario = try Periodo(inicio: ContratoAPI.instante("2026-11-17T23:00:00Z")!, fim: ContratoAPI.instante("2026-11-18T02:00:00Z")!)
        let completo = try json(ContratoAPI.BuscarProfissionais(
            filtro: FiltroBuscaProfissionais(estabelecimentoID: Self.casaID, funcaoID: Self.garcomID, regiaoID: 3, horario: horario),
            cursor: "abc", limite: 20
        ))
        #expect(Set(completo.keys) == ["estabelecimento_id", "funcao_id", "regiao_id", "inicio_em", "fim_em", "cursor", "limite"])
        #expect(completo["estabelecimento_id"] as? String == Self.casaID.uuidString)
        #expect(completo["funcao_id"] as? String == Self.garcomID.uuidString)
        #expect(completo["regiao_id"] as? Int == 3)
        #expect(completo["inicio_em"] as? String == "2026-11-17T23:00:00Z")
        #expect(completo["fim_em"] as? String == "2026-11-18T02:00:00Z")
        #expect(completo["cursor"] as? String == "abc")
        #expect(completo["limite"] as? Int == 20)

        let minimo = try json(ContratoAPI.BuscarProfissionais(
            filtro: FiltroBuscaProfissionais(estabelecimentoID: Self.casaID, funcaoID: Self.garcomID), cursor: nil, limite: nil
        ))
        #expect(Set(minimo.keys) == ["estabelecimento_id", "funcao_id"])

        let acimaDoTeto = try json(ContratoAPI.BuscarProfissionais(
            filtro: FiltroBuscaProfissionais(estabelecimentoID: Self.casaID, funcaoID: Self.garcomID), cursor: nil, limite: 50
        ))
        #expect(acimaDoTeto["limite"] as? Int == 20)
    }

    @Test("PreferenciaChamadas lê aceita_chamadas e pendencias_para_busca; valor desconhecido sai, ausente vale desligado")
    func preferencia() throws {
        let corpo = """
        { "aceita_de_quem_ja_trabalhou": true, "pausado_ate": null, "antecedencia_minima_h": 6, "aceita_de": "todos",
          "aceita_chamadas": true, "pendencias_para_busca": ["sem_regiao", "valor_novo", "sem_aparelho_atualizado"] }
        """
        let ligada = try ContratoAPI.decodificador().decode(ContratoAPI.PreferenciaChamadasDTO.self, from: Data(corpo.utf8)).dominio()
        #expect(ligada.aceitaChamadas)
        #expect(ligada.pendenciasParaBusca == [.semRegiao, .semAparelhoAtualizado])
        #expect(!ligada.apareceNaBusca)

        let antiga = #"{"aceita_de_quem_ja_trabalhou":true,"pausado_ate":null,"antecedencia_minima_h":6,"aceita_de":"todos"}"#
        let semCampos = try ContratoAPI.decodificador().decode(ContratoAPI.PreferenciaChamadasDTO.self, from: Data(antiga.utf8)).dominio()
        #expect(!semCampos.aceitaChamadas)
        #expect(semCampos.pendenciasParaBusca.isEmpty)
        #expect(Set(PendenciaParaBusca.allCases.map(\.rawValue)) == ["sem_servico_com_preco", "sem_regiao", "pausado", "sem_aparelho_atualizado"])
    }

    @Test("PreferenciaChamadas guardada antes da 0.2.88 ainda se lê (campos novos valem desligado)")
    func preferenciaGuardadaAntes() throws {
        let antiga = #"{"aceitaDeQuemJaTrabalhou":true,"antecedenciaMinimaH":6,"aceitaDe":"todos"}"#
        let lida = try JSONDecoder().decode(PreferenciaChamadas.self, from: Data(antiga.utf8))
        #expect(!lida.aceitaChamadas)
        let ida = try JSONDecoder().decode(PreferenciaChamadas.self, from: JSONEncoder().encode(
            PreferenciaChamadas(aceitaChamadas: true, pendenciasParaBusca: [.pausado])))
        #expect(ida.aceitaChamadas)
        #expect(ida.pendenciasParaBusca == [.pausado])
    }

    @Test("definir_preferencia_chamadas manda aceita_chamadas e a versão só ao ligar")
    func corpoDaPreferencia() throws {
        let ligar = try json(ContratoAPI.DefinirPreferenciaChamadas(
            aceitaDeQuemJaTrabalhou: nil, pausadoAte: nil, removerPausa: false, antecedenciaMinimaH: nil, aceitaDe: nil,
            aceitaChamadas: true, versaoTextoBusca: "busca-v1"
        ))
        #expect(Set(ligar.keys) == ["aceita_chamadas", "versao_texto_busca"])
        #expect(ligar["aceita_chamadas"] as? Bool == true)
        #expect(ligar["versao_texto_busca"] as? String == "busca-v1")

        let desligar = try json(ContratoAPI.DefinirPreferenciaChamadas(
            aceitaDeQuemJaTrabalhou: nil, pausadoAte: nil, removerPausa: false, antecedenciaMinimaH: nil, aceitaDe: nil,
            aceitaChamadas: false, versaoTextoBusca: "busca-v1"
        ))
        #expect(Set(desligar.keys) == ["aceita_chamadas"])

        let semMudar = try json(ContratoAPI.DefinirPreferenciaChamadas(
            aceitaDeQuemJaTrabalhou: true, pausadoAte: nil, removerPausa: false, antecedenciaMinimaH: nil, aceitaDe: nil
        ))
        #expect(semMudar["aceita_chamadas"] == nil)
    }

    @Test("RecursosDoApp.busca_profissionais: ausente vale false e só vale true com chamada_direta")
    func recurso() throws {
        func ler(_ texto: String) throws -> RecursosDoApp {
            try JSONDecoder().decode(ContratoAPI.RecursosDoAppDTO.self, from: Data(texto.utf8)).dominio()
        }
        #expect(try ler(#"{"chamada_direta":true,"busca_profissionais":true}"#).buscaProfissionais)
        #expect(try !ler(#"{"chamada_direta":false,"busca_profissionais":true}"#).buscaProfissionais)
        #expect(try !ler(#"{"chamada_direta":true}"#).buscaProfissionais)
        // Valor guardado antes da chave nova ainda se lê.
        let guardado = try JSONDecoder().decode(RecursosDoApp.self, from: Data(#"{"chamadaDireta":true}"#.utf8))
        #expect(!guardado.buscaProfissionais)
        let ida = try JSONDecoder().decode(RecursosDoApp.self, from: JSONEncoder().encode(RecursosDoApp(chamadaDireta: true, buscaProfissionais: true)))
        #expect(ida.buscaProfissionais)
    }

    @Test("chamar_profissional manda o regiao_id da busca quando vem e o omite fora dela")
    func regiaoNaChamada() throws {
        let trabalho = PublicacaoVaga(
            estabelecimentoID: Self.casaID, funcaoID: Self.garcomID,
            periodo: try Periodo(inicio: ContratoAPI.instante("2026-11-17T23:00:00Z")!, fim: ContratoAPI.instante("2026-11-18T02:00:00Z")!),
            local: "SCLS 405", regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.82, longitude: -47.92),
            valor: Dinheiro(centavos: 20_000), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Ana", chave: UUID()
        )
        let comRegiao = try json(ContratoAPI.ChamarProfissional(pedido: PedidoChamada(profissionalID: UUID(), trabalho: trabalho, regiaoID: 1)))
        #expect(comRegiao["regiao_id"] as? Int == 1)
        #expect(comRegiao["regiao_administrativa"] as? String == "Plano Piloto")
        let semRegiao = try json(ContratoAPI.ChamarProfissional(pedido: PedidoChamada(profissionalID: UUID(), trabalho: trabalho)))
        #expect(semRegiao["regiao_id"] == nil)
    }

    @Test("chamar_profissional leva o vaga_id OU os campos do trabalho, nunca os dois (oneOf do contrato)")
    func vagaIDOuTrabalho() throws {
        let trabalho = PublicacaoVaga(
            estabelecimentoID: Self.casaID, funcaoID: Self.garcomID,
            periodo: try Periodo(inicio: ContratoAPI.instante("2026-11-17T23:00:00Z")!, fim: ContratoAPI.instante("2026-11-18T02:00:00Z")!),
            local: "SCLS 405", regiaoAdministrativa: "Plano Piloto", ponto: try Coordenada(latitude: -15.82, longitude: -47.92),
            valor: Dinheiro(centavos: 20_000), posicoes: 1,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Ana", chave: UUID()
        )
        let camposDoTrabalho: Set<String> = ["funcao_id", "inicio_em", "fim_em", "local", "regiao_administrativa", "ponto",
                                             "valor_centavos", "inclui_refeicao", "inclui_transporte",
                                             "exige_material_proprio", "responsavel_local"]
        let profissionalID = UUID()
        let vagaID = UUID()
        let chave = UUID()
        let pelaVaga = try json(ContratoAPI.ChamarProfissional(pedido: PedidoChamada(
            profissionalID: profissionalID, vagaID: vagaID, estabelecimentoID: Self.casaID, chave: chave,
            recado: "Pode vir cedo?", confirmoRecorrencia: true)))
        // O estabelecimento_id é obrigatório nos dois ramos do contrato; a região é a da vaga.
        #expect(Set(pelaVaga.keys) == ["chave", "profissional_id", "estabelecimento_id", "vaga_id", "recado", "confirmo_recorrencia"])
        #expect(pelaVaga["vaga_id"] as? String == vagaID.uuidString)
        #expect(pelaVaga["chave"] as? String == chave.uuidString)
        #expect(pelaVaga["estabelecimento_id"] as? String == Self.casaID.uuidString)
        #expect(pelaVaga["confirmo_recorrencia"] as? Bool == true)

        let peloTrabalho = try json(ContratoAPI.ChamarProfissional(pedido: PedidoChamada(
            profissionalID: profissionalID, trabalho: trabalho, regiaoID: 1)))
        #expect(peloTrabalho["vaga_id"] == nil)
        #expect(camposDoTrabalho.isSubset(of: Set(peloTrabalho.keys)))
        #expect(peloTrabalho["chave"] as? String == trabalho.chave.uuidString)

        // O domínio não deixa montar os dois: pelo vaga_id não há trabalho nem região.
        let pedido = PedidoChamada(profissionalID: profissionalID, vagaID: vagaID, estabelecimentoID: Self.casaID, chave: chave)
        #expect(pedido.trabalho == nil && pedido.regiaoID == nil && pedido.vagaID == vagaID && pedido.chave == chave)
        #expect(pedido.confirmando(true).alvo == pedido.alvo)
    }
}
