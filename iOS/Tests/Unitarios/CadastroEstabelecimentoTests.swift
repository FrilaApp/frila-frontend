import Foundation
import FrilaDominio
import MapKit
import Testing
@testable import FrilaApresentacao

@MainActor
@Suite("Cadastro do estabelecimento (#99)")
struct CadastroEstabelecimentoTests {
    @Test("Máscara mantém CPF e CNPJ visualmente formatados e envia apenas dígitos")
    func mascara() {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        // CPF completo (11 dígitos)
        vm.atualizarDocumento("12345678901")
        #expect(vm.documentoFormatado == "123.456.789-01")
        #expect(vm.documento == "12345678901")

        // CNPJ completo (14 dígitos)
        vm.atualizarDocumento("12345678000199")
        #expect(vm.documentoFormatado == "12.345.678/0001-99")
        #expect(vm.documento == "12345678000199")

        // Dígitos parciais (digitação progressiva)
        vm.atualizarDocumento("123")
        #expect(vm.documentoFormatado == "123")
        vm.atualizarDocumento("1234")
        #expect(vm.documentoFormatado == "123.4")
        vm.atualizarDocumento("123456")
        #expect(vm.documentoFormatado == "123.456")
        vm.atualizarDocumento("1234567")
        #expect(vm.documentoFormatado == "123.456.7")
        vm.atualizarDocumento("123456789")
        #expect(vm.documentoFormatado == "123.456.789")
        vm.atualizarDocumento("1234567890")
        #expect(vm.documentoFormatado == "123.456.789-0")
        vm.atualizarDocumento("123456789012")
        #expect(vm.documentoFormatado == "12.345.678/9012")
        vm.atualizarDocumento("1234567890123")
        #expect(vm.documentoFormatado == "12.345.678/9012-3")
        vm.atualizarDocumento("12345678901234")
        #expect(vm.documentoFormatado == "12.345.678/9012-34")

        // Filtragem de caracteres não numéricos e teto em 14 dígitos
        vm.atualizarDocumento("12.345.678/0001-99 abc !?")
        #expect(vm.documento == "12345678000199")
        #expect(vm.documentoFormatado == "12.345.678/0001-99")

        vm.atualizarDocumento("1234567800019999999")
        #expect(vm.documento.count == 14)
        #expect(vm.documento == "12345678000199")
    }

    @Test("Binding do documento formatado mantém somente os dígitos no cadastro")
    func bindingDocumentoFormatado() {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        for (formatado, digitos) in [("123.456.789-01", "12345678901"), ("12.345.678/0001-99", "12345678000199")] {
            vm.documentoFormatado = formatado
            #expect(vm.documento == digitos)
            #expect(vm.documentoFormatado == formatado)
        }
    }

    @Test("Validação de documento recusa tamanhos diferentes de 11 e 14 dígitos")
    func validacaoDocumento() async {
        for docInvalido in ["", "1", "1234567890", "123456789012", "1234567890123"] {
            let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
            preencher(vm)
            vm.atualizarDocumento(docInvalido)
            await vm.salvar()
            #expect(vm.erro == .campo(.documento, .invalido), "Documento '\(docInvalido)' deveria ser inválido")
            #expect(!vm.concluido)
        }
    }

    @Test("Lista oficial contém exatamente as 35 Regiões Administrativas do DF sem repetição")
    func lista35RegioesAdministrativasOficiais() {
        let ras = CadastroEstabelecimentoViewModel.regioesAdministrativas
        #expect(ras.count == 35, "Devem existir exatamente 35 RAs oficiais do DF")
        #expect(Set(ras).count == 35, "A lista não pode conter RAs repetidas")

        // Contém RAs clássicas e recentes do GDF (leis 7.190 e 7.191 de 2022)
        let esperadas = [
            "Água Quente", "Águas Claras", "Arapoanga", "Arniqueira", "Brazlândia",
            "Candangolândia", "Ceilândia", "Cruzeiro", "Fercal", "Gama",
            "Guará", "Itapoã", "Jardim Botânico", "Lago Norte", "Lago Sul",
            "Núcleo Bandeirante", "Paranoá", "Park Way", "Planaltina", "Plano Piloto",
            "Recanto das Emas", "Riacho Fundo", "Riacho Fundo II", "Samambaia", "Santa Maria",
            "São Sebastião", "SCIA / Estrutural", "SIA", "Sobradinho", "Sobradinho II",
            "Sol Nascente/Pôr do Sol", "Sudoeste/Octogonal", "Taguatinga", "Varjão", "Vicente Pires"
        ]
        for esperada in esperadas {
            #expect(ras.contains(esperada), "Deveria conter a RA \(esperada)")
        }
        #expect(ras == ras.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, "A lista deve estar em ordem alfabética para facilitar a seleção")
    }

    @Test("Casamento de RA por texto identifica regiões, numerais romanos e bairros do Plano Piloto")
    func casamentoDeRegiaoPorTexto() {
        // Casamentos diretos e com acentuação/maiúsculas
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Águas Claras, Brasília - DF") == "Águas Claras")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Av. das Castanheiras - aguas claras") == "Águas Claras")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Taguatinga Sul") == "Taguatinga")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Ceilândia Centro") == "Ceilândia")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Guará II") == "Guará")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Gama Leste") == "Gama")

        // Bairros clássicos que casam com Plano Piloto
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Asa Sul") == "Plano Piloto")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Asa Norte, Brasília - DF") == "Plano Piloto")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Noroeste") == "Plano Piloto")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Vila Planalto") == "Plano Piloto")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Plano Piloto") == "Plano Piloto")

        // Distinção de numerais romanos (II antes de I)
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Riacho Fundo II, QN 14") == "Riacho Fundo II")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Riacho Fundo 2") == "Riacho Fundo II")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Riacho Fundo I") == "Riacho Fundo")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Riacho Fundo") == "Riacho Fundo")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Sobradinho II") == "Sobradinho II")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Sobradinho") == "Sobradinho")

        // Nomes compostos com barra
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Sudoeste") == "Sudoeste/Octogonal")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Octogonal") == "Sudoeste/Octogonal")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Estrutural") == "SCIA / Estrutural")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "SCIA Trecho 2") == "SCIA / Estrutural")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Sol Nascente") == "Sol Nascente/Pôr do Sol")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Pôr do Sol") == "Sol Nascente/Pôr do Sol")

        // RAs recentes
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Arapoanga") == "Arapoanga")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Água Quente") == "Água Quente")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Arniqueiras") == "Arniqueira")

        // SIA (não deve casar falso-positivo com Brasília)
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "SIA Trecho 3") == "SIA")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Setor de Indústria e Abastecimento") == "SIA")
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Brasília, DF") == nil)

        // Casos que não devem casar
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Goiânia, GO") == nil)
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "Rua 12, Casa 3") == nil)
        #expect(CadastroEstabelecimentoViewModel.casarRegiaoAdministrativa(noTexto: "") == nil)
    }

    @Test("Selecionar endereço pré-seleciona a RA correspondente ou deixa vazio se não houver casamento")
    func preSelecaoAoSelecionarItem() {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        let coord = CLLocationCoordinate2D(latitude: -15.83, longitude: -48.02)

        // Item com nome casando com Águas Claras
        let itemAguasClaras = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        itemAguasClaras.name = "Restaurante Águas Claras"
        vm.selecionar(itemAguasClaras)
        #expect(vm.regiaoAdministrativa == "Águas Claras")

        // Item com endereço que não casa com nenhuma RA: deve limpar para não gravar RA não visualizada
        let itemDesconhecido = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        itemDesconhecido.name = "Loja em Valparaíso de Goiás"
        vm.selecionar(itemDesconhecido)
        #expect(vm.regiaoAdministrativa.isEmpty, "Quando o endereço não traz RA conhecida, deve deixar vazio")
    }

    @Test("Selecionar um segundo endereço atualiza o ponto e o alvo da câmera")
    func cameraAcompanhaNovaSelecao() {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        let primeiroPonto = CLLocationCoordinate2D(latitude: -15.78, longitude: -47.93)
        let segundoPonto = CLLocationCoordinate2D(latitude: -15.80, longitude: -47.88)
        vm.selecionar(MKMapItem(placemark: MKPlacemark(coordinate: primeiroPonto)))
        #expect(vm.ponto?.latitude == primeiroPonto.latitude)
        #expect(vm.alvoDaCamera?.longitude == primeiroPonto.longitude)
        vm.selecionar(MKMapItem(placemark: MKPlacemark(coordinate: segundoPonto)))
        #expect(vm.ponto?.latitude == segundoPonto.latitude)
        #expect(vm.ponto?.longitude == segundoPonto.longitude)
        #expect(vm.alvoDaCamera?.latitude == segundoPonto.latitude)
        #expect(vm.alvoDaCamera?.longitude == segundoPonto.longitude)
    }

    @Test("Cadastro bem-sucedido conclui o formulário")
    func sucesso() async throws {
        let vm = CadastroEstabelecimentoViewModel { cadastro in
            #expect(cadastro.documento == "12345678901")
            #expect(cadastro.tipo == .foodService)
            return Self.criado(cadastro)
        }
        preencher(vm)
        await vm.salvar()
        #expect(vm.concluido)
        #expect(vm.erro == nil)
    }

    @Test("O cadastro envia a região administrativa, sem os espaços das pontas (contrato 0.2.20)")
    func enviaARegiaoAdministrativa() async throws {
        let enviados = Enviados()
        let vm = CadastroEstabelecimentoViewModel { cadastro in
            await enviados.guardar(cadastro)
            return Self.criado(cadastro)
        }
        preencher(vm)
        vm.regiaoAdministrativa = "  Águas Claras \n"
        await vm.salvar()
        #expect(vm.concluido)
        #expect(await enviados.todos.map(\.regiaoAdministrativa) == ["Águas Claras"])
    }

    @Test("Sem região administrativa, o erro fica no campo e nada é enviado", arguments: ["", "   "])
    func regiaoAdministrativaObrigatoria(regiao: String) async {
        let enviados = Enviados()
        let vm = CadastroEstabelecimentoViewModel { cadastro in
            await enviados.guardar(cadastro)
            return Self.criado(cadastro)
        }
        preencher(vm)
        vm.regiaoAdministrativa = regiao
        await vm.salvar()
        #expect(vm.erro == .campo(.regiaoAdministrativa, .obrigatorio))
        #expect(!vm.concluido)
        #expect(await enviados.todos.isEmpty)
    }

    @Test("409 de documento duplicado mostra estado próprio")
    func duplicado() async {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .documentoJaCadastrado) }
        preencher(vm)
        await vm.salvar()
        #expect(vm.erro == .documentoDuplicado)
    }

    @Test("Erro de falta de conexão mostra mensagem própria de rede")
    func semRede() async {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .semRede) }
        preencher(vm)
        await vm.salvar()
        #expect(vm.erro == .semRede)
        #expect(vm.mensagem(vm.erro!) == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
    }

    @Test("422 campo obrigatório e inválido focam o campo indicado")
    func errosPorCampo() async {
        for (regra, codigo) in [(RegraCampoCadastro.obrigatorio, CodigoErroAPI.campoObrigatorio), (.invalido, .campoInvalido)] {
            let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: codigo, detalhes: "documento") }
            preencher(vm)
            await vm.salvar()
            #expect(vm.erro == .campo(.documento, regra))
        }
    }

    @Test("422 do servidor na região administrativa destaca o campo da região")
    func errosNaRegiaoAdministrativa() async {
        // `campo_invalido` aqui é o filtro de texto da diretriz 1.2, que só o servidor aplica.
        for (regra, codigo) in [(RegraCampoCadastro.obrigatorio, CodigoErroAPI.campoObrigatorio), (.invalido, .campoInvalido)] {
            let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: codigo, detalhes: "regiao_administrativa") }
            preencher(vm)
            await vm.salvar()
            #expect(vm.erro == .campo(.regiaoAdministrativa, regra))
        }
    }

    private func preencher(_ vm: CadastroEstabelecimentoViewModel) {
        vm.nome = "Bar Frila"
        vm.atualizarDocumento("12345678901")
        vm.endereco = "Brasília, DF"
        vm.regiaoAdministrativa = "Plano Piloto"
        vm.ponto = .init(latitude: -15.78, longitude: -47.93)
    }

    private static func criado(_ cadastro: CadastroEstabelecimento) -> Estabelecimento {
        Estabelecimento(
            id: UUID(), nome: cadastro.nome, documento: cadastro.documento, tipo: cadastro.tipo, endereco: cadastro.endereco,
            regiaoAdministrativa: cadastro.regiaoAdministrativa, ponto: cadastro.ponto
        )
    }

    @Test(
        "Buscar endereço com texto vazio ou composto apenas de espaços não dispara busca nem altera sugestões",
        arguments: ["", "   ", "   \n\t  "]
    )
    func buscarEnderecoComTextoVazioNaoDisparaBusca(entrada: String) async {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        vm.endereco = entrada
        await vm.buscarEndereco()
        #expect(!vm.carregandoBusca)
        #expect(vm.sugestoes.isEmpty)
    }

    @Test("Buscar endereço com espaços em branco preserva sugestões existentes sem ativar carregamento")
    func buscarEnderecoComEspacosPreservaSugestoes() async {
        let vm = CadastroEstabelecimentoViewModel { _ in throw ErroDaApi(codigo: .desconhecido) }
        let ponto = CLLocationCoordinate2D(latitude: -15.78, longitude: -47.93)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: ponto))
        vm.sugestoes = [item]
        vm.endereco = "   \n  "
        await vm.buscarEndereco()
        #expect(!vm.carregandoBusca)
        #expect(vm.sugestoes.count == 1)
    }
}

/// O que a tela mandou para `cadastrar_estabelecimento`.
private actor Enviados {
    private(set) var todos: [CadastroEstabelecimento] = []
    func guardar(_ cadastro: CadastroEstabelecimento) { todos.append(cadastro) }
}
