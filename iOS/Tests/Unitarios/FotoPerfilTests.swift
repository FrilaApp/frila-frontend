import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
@testable import FrilaInfraestrutura
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

/// Foto de perfil (contrato 0.2.54, RN37 e RN46): DTOs, erros, recorte, verificações do aparelho,
/// preparo do JPEG sem metadados, cliente em memória e o fluxo da tela.
@Suite("Foto de perfil: contrato 0.2.54, verificações do aparelho e fluxo")
struct FotoPerfilTests {

    // MARK: Contrato: enums, DTOs e erros

    @Test("Os enums de mídia espelham o contrato caso a caso")
    func enumsDeMidia() throws {
        #expect(Set(TipoMidia.allCases.map(\.rawValue)) == ["foto_perfil"])
        let decodificado = try JSONDecoder().decode(TipoMidia.self, from: Data("\"tipo_futuro_do_servidor\"".utf8))
        #expect(decodificado == .desconhecido("tipo_futuro_do_servidor"))
        #expect(Set(EstadoMidia.allCases.map(\.rawValue)) == [
            "enviando", "em_analise", "aprovada", "recusada", "nao_publicada", "ocultada", "removida",
        ])
        #expect(Set(MotivoRecusaMidia.allCases.map(\.rawValue)) == [
            "foto_inadequada", "texto_ou_dado_pessoal", "nao_e_pessoa_ou_servico", "nao_analisada",
        ])
        #expect(TipoDeAviso(rawValue: "midia_recusada") == .midiaRecusada)
    }

    @Test("Midia decodifica a fixture aprovada, com url, instantes e motivo nulo")
    func midiaAprovada() throws {
        let midia = try FixturesDoContrato.carregar("midia-aprovada", como: ContratoAPI.MidiaDTO.self).dominio()
        #expect(midia.id == UUID(uuidString: "5d0f1c2a-7b7e-4c1b-9a55-0c6b2e4f7a10"))
        #expect(midia.tipo == .fotoPerfil)
        #expect(midia.estado == .aprovada)
        #expect(midia.motivoRecusa == nil)
        #expect(midia.podePedirNovaAnalise == false)
        #expect(midia.url?.host == "armazenamento.frila.invalid")
        #expect(midia.estabelecimentoID == nil)
        #expect(midia.enviadaEm != nil && midia.decididaEm != nil)
    }

    @Test("minhas_midias decodifica os sete estados, com os campos opcionais ausentes")
    func minhasMidias() throws {
        let midias = try FixturesDoContrato.carregar("minhas-midias", como: [ContratoAPI.MidiaDTO].self).map { $0.dominio() }
        #expect(midias.map(\.estado) == [.enviando, .emAnalise, .recusada, .naoPublicada, .ocultada, .removida])
        #expect(midias[2].motivoRecusa == .textoOuDadoPessoal)
        #expect(midias[2].podePedirNovaAnalise)
        #expect(midias[3].motivoRecusa == .naoAnalisada)
        #expect(midias[0].url == nil && midias[0].decididaEm == nil)
        #expect(midias[5].estabelecimentoID != nil)
    }

    @Test("Uma mídia com estado que o app não conhece não decodifica (a lista descarta o item, não a resposta)")
    func estadoDesconhecido() {
        let json = #"{"id":"5d0f1c2a-7b7e-4c1b-9a55-0c6b2e4f7a10","tipo":"foto_perfil","estado":"em_quarentena","pode_pedir_nova_analise":false}"#
        #expect(throws: DecodingError.self) {
            try ContratoAPI.decodificador().decode(ContratoAPI.MidiaDTO.self, from: Data(json.utf8))
        }
    }

    @Test("solicitar_upload_midia: a resposta decodifica e o pedido sai igual à fixture de requisição")
    func uploadDeMidia() throws {
        let upload = try FixturesDoContrato.carregar("upload-midia", como: ContratoAPI.UploadMidiaDTO.self).dominio()
        #expect(upload.uploadURL.scheme == "https")
        #expect(upload.uploadURLMiniatura != nil)
        let corpo = try JSONEncoder().encode(ContratoAPI.SolicitarUploadMidia(PedidoDeUploadDeMidia(bytes: 482_113)))
        let enviado = try JSONSerialization.jsonObject(with: corpo) as? [String: Any]
        let fixture = try JSONSerialization.jsonObject(with: FixturesDoContrato.dados("requisicao-solicitar-upload-midia")) as? [String: Any]
        #expect(enviado?["tipo"] as? String == fixture?["tipo"] as? String)
        #expect(enviado?["mime"] as? String == fixture?["mime"] as? String)
        #expect(enviado?["bytes"] as? Int == fixture?["bytes"] as? Int)
        #expect(enviado?["estabelecimento_id"] == nil)
    }

    @Test("PerfilPublico traz foto_url e foto_id só quando o servidor os manda")
    func perfilPublicoComEFotoSemFoto() throws {
        let com = try FixturesDoContrato.carregar("perfil-publico-com-foto", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
        #expect(com.fotoURL?.host == "armazenamento.frila.invalid")
        #expect(com.fotoID == UUID(uuidString: "5d0f1c2a-7b7e-4c1b-9a55-0c6b2e4f7a10"))
        let sem = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
        #expect(sem.fotoURL == nil && sem.fotoID == nil)
        #expect(sem.nome == com.nome)
    }

    @Test("ConfiguracaoDoApp.recursos: ausente, parcial e completo valem desligado onde faltam")
    func recursosDoApp() throws {
        let ausente = try FixturesDoContrato.carregar("configuracao-do-app", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
        #expect(ausente.recursos == .desligados)
        let ligado = try FixturesDoContrato.carregar("configuracao-do-app-com-recursos", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
        #expect(ligado.recursos == RecursosDoApp(fotoDePerfil: true, chamadaDireta: false))
        let parcial = #"{"versao_minima":"1.0.0","versao_recomendada":"1.0.0","url_da_loja":"https://apps.apple.com/app/id1","recursos":{"chamada_direta":true}}"#
        let dto = try JSONDecoder().decode(ContratoAPI.ConfiguracaoDoAppDTO.self, from: Data(parcial.utf8))
        #expect(dto.dominio().recursos == RecursosDoApp(fotoDePerfil: false, chamadaDireta: true))
    }

    @Test("ConfiguracaoApp guardada antes da 0.2.54 (sem recursos) ainda decodifica, com tudo desligado")
    func configuracaoGuardadaAntiga() throws {
        let antiga = #"{"versaoMinima":"1.0.0","versaoRecomendada":"1.1.0","urlDaLoja":"https://apps.apple.com/app/id1"}"#
        let configuracao = try JSONDecoder().decode(ConfiguracaoApp.self, from: Data(antiga.utf8))
        #expect(configuracao.recursos == .desligados)
        let volta = try JSONDecoder().decode(ConfiguracaoApp.self, from: JSONEncoder().encode(
            ConfiguracaoApp(versaoMinima: "1", versaoRecomendada: "1", mensagem: nil, urlDaLoja: configuracao.urlDaLoja, recursos: RecursosDoApp(fotoDePerfil: true))
        ))
        #expect(volta.recursos.fotoDePerfil)
    }

    @Test("Os quatro erros novos mapeiam do código estável; recurso_desligado vem como sem_permissao com details")
    func errosNovos() {
        for codigo in ["funcao_nao_marcada", "midia_indisponivel", "midia_invalida", "recurso_desligado"] {
            let erro = DecodificadorErroAPI.mapear(codigo: codigo, detalhes: nil)
            #expect(erro.codigo.rawValue == codigo)
            #expect(erro.codigo != .desconhecido)
        }
        let desligado = DecodificadorErroAPI.mapear(codigo: "sem_permissao", detalhes: "recurso_desligado")
        #expect(desligado.recursoDesligado)
        #expect(DecodificadorErroAPI.mapear(codigo: "sem_permissao", detalhes: "conta_suspensa").recursoDesligado == false)
        #expect(DecodificadorErroAPI.mapear(codigo: "sem_permissao", detalhes: nil).recursoDesligado == false)
    }

    // MARK: Recorte quadrado 1:1

    @Test("Recorte centralizado de foto horizontal e vertical é o maior quadrado do meio")
    func recorteCentralizado() throws {
        let horizontal = try #require(RecorteQuadrado.centralizado.retangulo(larguraDaImagem: 3000, alturaDaImagem: 2000))
        #expect(horizontal == CGRect(x: 500, y: 0, width: 2000, height: 2000))
        let vertical = try #require(RecorteQuadrado.centralizado.retangulo(larguraDaImagem: 2000, alturaDaImagem: 3000))
        #expect(vertical == CGRect(x: 0, y: 500, width: 2000, height: 2000))
    }

    @Test("Com zoom 2 o quadrado cai à metade e, nos extremos do deslocamento, encosta na borda sem sair da imagem")
    func recorteComZoomEDeslocamento() throws {
        let aEsquerda = try #require(RecorteQuadrado(zoom: 2, deslocamentoX: -1).retangulo(larguraDaImagem: 3000, alturaDaImagem: 2000))
        #expect(aEsquerda == CGRect(x: 0, y: 500, width: 1000, height: 1000))
        let aDireita = try #require(RecorteQuadrado(zoom: 2, deslocamentoX: 1, deslocamentoY: 1).retangulo(larguraDaImagem: 3000, alturaDaImagem: 2000))
        #expect(aDireita == CGRect(x: 2000, y: 1000, width: 1000, height: 1000))
    }

    @Test("Valores fora da faixa ou inválidos viram um recorte válido, e imagem sem área não tem recorte",
          arguments: [(0.0, 5.0, -9.0), (Double.nan, Double.infinity, -Double.infinity), (100.0, 0.0, 0.0)])
    func recorteSempreDentroDaImagem(zoom: Double, x: Double, y: Double) throws {
        let recorte = RecorteQuadrado(zoom: zoom, deslocamentoX: x, deslocamentoY: y)
        let area = try #require(recorte.retangulo(larguraDaImagem: 1200, alturaDaImagem: 800))
        #expect(area.minX >= 0 && area.minY >= 0 && area.maxX <= 1200 && area.maxY <= 800)
        #expect(area.width == area.height && area.width >= 1)
        #expect(RecorteQuadrado.centralizado.retangulo(larguraDaImagem: 0, alturaDaImagem: 100) == nil)
    }

    // MARK: Texto na foto: telefone, e-mail, link, @ e Pix

    @Test("Texto com telefone, e-mail, link, @ ou Pix é barrado, com o motivo certo", arguments: [
        ("(61) 99876-5432", MotivoDeBloqueioLocal.telefone),
        ("61 998765432", .telefone),
        ("+55 61 9 9876-5432", .telefone),
        ("99876-5432", .telefone),
        ("ana.cunha@gmail.com", .email),
        ("ana @ frila.com.br", .email),
        ("www.meusite.com", .linkOuArroba),
        ("https://wa.me/5561998765432", .linkOuArroba),
        ("frila.com.br", .linkOuArroba),
        ("@ana.garcom", .linkOuArroba),
        ("siga @ana_cunha", .linkOuArroba),
        ("Pix: 61 99876-5432", .chavePix),
        ("PIX", .chavePix),
        ("123.456.789-09", .chavePix),
        ("12.345.678/0001-95", .chavePix),
        ("5d0f1c2a-7b7e-4c1b-9a55-0c6b2e4f7a10", .chavePix),
    ])
    func textoBarrado(texto: String, motivo: MotivoDeBloqueioLocal) {
        #expect(DetectorDeDadosEmTexto.motivo(em: texto) == motivo)
    }

    @Test("Texto comum de camisa e crachá não é barrado", arguments: [
        "", "   ", "Bar do Lago", "Garçom", "2020-2024", "Camisa 10", "Desde 1998", "Ana Cunha", "Equipe A", "São Paulo FC", "Turno das 18h às 23h",
    ])
    func textoLimpo(texto: String) {
        #expect(DetectorDeDadosEmTexto.motivo(em: texto) == nil)
    }

    @Test("Com várias linhas, o Pix vence o e-mail, que vence o link, que vence o telefone")
    func prioridadeDosMotivos() {
        #expect(DetectorDeDadosEmTexto.motivo(em: ["(61) 99876-5432", "www.site.com"]) == .linkOuArroba)
        #expect(DetectorDeDadosEmTexto.motivo(em: ["www.site.com", "a@b.com"]) == .email)
        #expect(DetectorDeDadosEmTexto.motivo(em: ["a@b.com", "chave pix"]) == .chavePix)
        #expect(DetectorDeDadosEmTexto.motivo(em: ["Bar do Lago", "Garçom"]) == nil)
    }

    // MARK: Vision e CoreML: o verificador do aparelho

    private struct ClassificadorFalso: ClassificadorDeConteudo {
        let resultado: Result<Double, ErroDoClassificadorDeConteudo>
        func pontuacaoDeConteudoImproprio(em jpeg: Data) async throws -> Double { try resultado.get() }
    }

    private struct ClassificadorQueNaoVolta: ClassificadorDeConteudo {
        func pontuacaoDeConteudoImproprio(em jpeg: Data) async throws -> Double {
            try await Task.sleep(for: .seconds(600))
            return 0
        }
    }

    @Test("Foto limpa e classificador abaixo do limite: liberada")
    func fotoLimpaLiberada() async throws {
        let verificador = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorFalso(resultado: .success(0.05)))
        let resultado = await verificador.verificar(jpeg: try Imagens.jpegDeTexto(nil))
        #expect(resultado == .liberada)
    }

    @Test("Classificador acima do limite: conteúdo impróprio")
    func conteudoImproprio() async throws {
        let verificador = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorFalso(resultado: .success(0.93)))
        #expect(await verificador.verificar(jpeg: try Imagens.jpegDeTexto(nil)) == .bloqueada(.conteudoImproprio))
    }

    @Test("Falha fechada: classificador que falha ou modelo ausente impede o envio")
    func falhaFechada() async throws {
        let jpeg = try Imagens.jpegDeTexto(nil)
        let quebrado = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorFalso(resultado: .failure(.semResultado)))
        #expect(await quebrado.verificar(jpeg: jpeg) == .bloqueada(.analiseIndisponivel))
        // O bundle dos testes não tem `FrilaModeracaoFoto.mlmodelc`: sem o modelo a foto não sobe.
        let semModelo = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorDeConteudoCoreML(bundle: Bundle(for: MarcadorDosTestes.self)))
        #expect(await semModelo.verificar(jpeg: jpeg) == .bloqueada(.analiseIndisponivel))
        #expect(await semModelo.verificar(jpeg: Data("isto não é imagem".utf8)) == .bloqueada(.analiseIndisponivel))
        await #expect(throws: ErroDoClassificadorDeConteudo.modeloAusente) {
            try await ClassificadorDeConteudoCoreML(bundle: Bundle(for: MarcadorDosTestes.self)).pontuacaoDeConteudoImproprio(em: jpeg)
        }
    }

    @Test("Falha fechada: análise que não termina no prazo bloqueia em vez de esperar")
    func prazoEstourado() async throws {
        let verificador = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorQueNaoVolta(), prazo: .milliseconds(400))
        let inicio = ContinuousClock.now
        let resultado = await verificador.verificar(jpeg: try Imagens.jpegDeTexto(nil))
        #expect(resultado == .bloqueada(.analiseIndisponivel))
        #expect(inicio.duration(to: .now) < .seconds(20))
    }

    @Test("Vision lê um QR code na foto e a barra, antes de chamar o classificador")
    func qrCodeBarrado() async throws {
        // Se o classificador fosse chamado, a foto seria liberada: o QR precisa vencer antes.
        let verificador = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorFalso(resultado: .success(0)))
        let resultado = await verificador.verificar(jpeg: try Imagens.jpegComQRCode("https://wa.me/5561998765432"))
        #expect(resultado == .bloqueada(.qrCode), "obtido: \(resultado)")
    }

    @Test("Vision lê o texto da foto: telefone e chave Pix são barrados, nome comum passa",
          arguments: [
              ("Zap 61 99876-5432", ResultadoDaVerificacaoLocal.bloqueada(.telefone)),
              ("chave pix: ana@frila.com.br", .bloqueada(.chavePix)),
              ("Ana Cunha", .liberada),
          ])
    func textoDaFotoLidoPeloVision(texto: String, esperado: ResultadoDaVerificacaoLocal) async throws {
        let verificador = VerificadorLocalDeFotoDoSistema(classificador: ClassificadorFalso(resultado: .success(0)))
        #expect(await verificador.verificar(jpeg: try Imagens.jpegDeTexto(texto)) == esperado)
    }

    // MARK: Preparo do JPEG: recorte, tamanho e metadados

    @Test("O original com EXIF, GPS e orientação sai quadrado, até 1600 px, sem nenhum metadado")
    func preparoSemMetadados() throws {
        let original = try Imagens.jpegComMetadados(largura: 3000, altura: 2000)
        // Sem esta guarda o teste passaria mesmo se o limpador não fizesse nada.
        #expect(LimpadorDeMetadadosJPEG.temMetadados(original))
        let propriedadesDoOriginal = try Imagens.propriedades(original)
        #expect(propriedadesDoOriginal[kCGImagePropertyGPSDictionary] != nil)

        let foto = try PreparadorDeFotoDoSistema().preparar(original: original, recorte: .centralizado)
        #expect(foto.lado == 1600)
        #expect(foto.jpeg.count <= LimitesDaFoto.bytesMaximos)
        #expect(foto.jpeg.prefix(2) == Data([0xFF, 0xD8]))
        #expect(!LimpadorDeMetadadosJPEG.temMetadados(foto.jpeg))

        let propriedades = try Imagens.propriedades(foto.jpeg)
        #expect(propriedades[kCGImagePropertyGPSDictionary] == nil)
        #expect(propriedades[kCGImagePropertyExifDictionary] == nil)
        #expect(propriedades[kCGImagePropertyIPTCDictionary] == nil)
        #expect((propriedades[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFOrientation] == nil)
        #expect(propriedades[kCGImagePropertyOrientation] == nil)
        #expect(propriedades[kCGImagePropertyPixelWidth] as? Int == 1600)
        #expect(propriedades[kCGImagePropertyPixelHeight] as? Int == 1600)
    }

    @Test("A orientação gravada é aplicada nos pixels antes de sumir com o metadado")
    func orientacaoAplicadaNosPixels() throws {
        // Esquerda vermelha, direita azul, com orientação 6 (gira 90° no sentido horário): o vermelho vai para cima.
        let original = try Imagens.jpegDeDuasMetades(orientacao: 6)
        let foto = try PreparadorDeFotoDoSistema().preparar(original: original, recorte: .centralizado)
        let cima = try Imagens.corDoPixel(foto.jpeg, x: foto.lado / 2, y: foto.lado / 8)
        let baixo = try Imagens.corDoPixel(foto.jpeg, x: foto.lado / 2, y: foto.lado * 7 / 8)
        #expect(cima.r > 150 && cima.b < 100, "o topo deveria ser vermelho: \(cima)")
        #expect(baixo.b > 150 && baixo.r < 100, "a base deveria ser azul: \(baixo)")
    }

    @Test("O zoom e o deslocamento escolhem o pedaço certo: a esquerda de uma foto de duas cores é só vermelha")
    func recorteEscolheOPedaco() throws {
        let original = try Imagens.jpegDeDuasMetades(orientacao: 1, largura: 2000, altura: 1000)
        let aEsquerda = try PreparadorDeFotoDoSistema().preparar(original: original, recorte: RecorteQuadrado(zoom: 2, deslocamentoX: -1))
        let centro = try Imagens.corDoPixel(aEsquerda.jpeg, x: aEsquerda.lado / 2, y: aEsquerda.lado / 2)
        #expect(centro.r > 150 && centro.b < 100)
        let aDireita = try PreparadorDeFotoDoSistema().preparar(original: original, recorte: RecorteQuadrado(zoom: 2, deslocamentoX: 1))
        let outroCentro = try Imagens.corDoPixel(aDireita.jpeg, x: aDireita.lado / 2, y: aDireita.lado / 2)
        #expect(outroCentro.b > 150 && outroCentro.r < 100)
    }

    @Test("Foto pequena não é ampliada: o lado fica o do quadrado recortado")
    func fotoPequenaNaoAmplia() throws {
        let original = try Imagens.jpegComMetadados(largura: 800, altura: 600, orientacao: 1)
        let foto = try PreparadorDeFotoDoSistema().preparar(original: original, recorte: .centralizado)
        #expect(foto.lado == 600)
    }

    @Test("Bytes que não são imagem são recusados, e o limpador devolve o que não entende")
    func imagemInvalida() {
        #expect(throws: ErroDePreparoDaFoto.imagemInvalida) {
            try PreparadorDeFotoDoSistema().preparar(original: Data("não sou imagem".utf8), recorte: .centralizado)
        }
        #expect(throws: ErroDePreparoDaFoto.imagemInvalida) {
            try PreparadorDeFotoDoSistema().preparar(original: Data(), recorte: .centralizado)
        }
        let texto = Data("nem jpeg".utf8)
        #expect(LimpadorDeMetadadosJPEG.limpar(texto) == texto)
    }

    @Test("O limpador tira APP1 (Exif/XMP), APP13 (IPTC) e comentário, e mantém JFIF e perfil ICC")
    func limpadorPorSegmento() {
        func segmento(_ marcador: UInt8, _ carga: [UInt8]) -> [UInt8] {
            let tamanho = carga.count + 2
            return [0xFF, marcador, UInt8(tamanho >> 8), UInt8(tamanho & 0xFF)] + carga
        }
        let jfif = segmento(0xE0, Array("JFIF\0".utf8))
        let exif = segmento(0xE1, Array("Exif\0\0".utf8) + [1, 2, 3])
        let icc = segmento(0xE2, Array("ICC_PROFILE\0".utf8))
        let iptc = segmento(0xED, Array("Photoshop 3.0\0".utf8))
        let comentario = segmento(0xFE, Array("GPS -15.79".utf8))
        let varredura: [UInt8] = [0xFF, 0xDA, 0x00, 0x02, 0xAA, 0xBB, 0xFF, 0xD9]
        let sujo = Data([0xFF, 0xD8] + jfif + exif + icc + iptc + comentario + varredura)
        let limpo = LimpadorDeMetadadosJPEG.limpar(sujo)
        #expect(limpo == Data([0xFF, 0xD8] + jfif + icc + varredura))
        #expect(LimpadorDeMetadadosJPEG.temMetadados(sujo))
        #expect(!LimpadorDeMetadadosJPEG.temMetadados(limpo))
    }

    // MARK: Cliente em memória

    @Test("Os cenários da foto começam em cada um dos sete estados, com o recurso ligado menos o desligado")
    func cenariosDeExemplo() async throws {
        let esperado: [(ApiClienteEmMemoria.Cenario, EstadoMidia?, Bool)] = [
            (.fotoSemFoto, nil, true), (.fotoEmAnalise, .emAnalise, true), (.fotoAprovada, .aprovada, true),
            (.fotoRecusada, .recusada, true), (.fotoNaoPublicada, .naoPublicada, true), (.fotoOcultada, .ocultada, true),
            (.fotoRecursoDesligado, .aprovada, false),
        ]
        for (cenario, estado, ligado) in esperado {
            let api = ApiClienteEmMemoria(cenario: cenario)
            let midias = try await api.minhasMidias()
            #expect(midias.first?.estado == estado, "\(cenario)")
            #expect(try await api.configuracaoDoApp().recursos.fotoDePerfil == ligado, "\(cenario)")
        }
        let aprovada = try await ApiClienteEmMemoria(cenario: .fotoAprovada).minhasMidias()
        #expect(aprovada.first?.url != nil)
        // Fora dos cenários da foto o recurso fica desligado, como no Prod.
        #expect(try await ApiClienteEmMemoria().configuracaoDoApp().recursos == .desligados)
    }

    @Test("Em memória: pedir URL, confirmar e confirmar de novo (idempotente) leva a em_analise")
    func ciclodeEnvioEmMemoria() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let upload = try await api.solicitarUploadMidia(PedidoDeUploadDeMidia(bytes: 300_000))
        #expect(try await api.minhasMidias().map(\.estado) == [.enviando])
        let primeira = try await api.confirmarUploadMidia(id: upload.midiaID)
        let segunda = try await api.confirmarUploadMidia(id: upload.midiaID)
        #expect(primeira.estado == .emAnalise)
        #expect(segunda == primeira)
        try await api.decidirMidiaParaTeste(id: upload.midiaID, estado: .aprovada)
        let aprovada = try await api.confirmarUploadMidia(id: upload.midiaID)
        #expect(aprovada.estado == .aprovada, "confirmar depois da decisão devolve o estado atual, sem voltar a em_analise")
    }

    @Test("Em memória: tipo reservado, formato e tamanho fora do limite são midia_invalida, com o details do contrato")
    func recusasDeEntradaEmMemoria() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let casos: [(PedidoDeUploadDeMidia, String)] = [
            (PedidoDeUploadDeMidia(tipo: TipoMidia(rawValue: "curriculo"), bytes: 100), "tipo_indisponivel"),
            (PedidoDeUploadDeMidia(tipo: TipoMidia(rawValue: "foto_trabalho"), bytes: 100), "tipo_indisponivel"),
            (PedidoDeUploadDeMidia(mime: "image/png", bytes: 100), "formato"),
            (PedidoDeUploadDeMidia(bytes: LimitesDaFoto.bytesMaximos + 1), "tamanho"),
            (PedidoDeUploadDeMidia(bytes: 0), "tamanho"),
        ]
        for (pedido, detalhe) in casos {
            do {
                _ = try await api.solicitarUploadMidia(pedido)
                Issue.record("deveria recusar \(pedido)")
            } catch let erro as ErroDaApi {
                #expect(erro.codigo == .midiaInvalida)
                #expect(erro.detalhes == detalhe)
            }
        }
        #expect(try await api.minhasMidias().isEmpty, "recusa na entrada não cria mídia")
    }

    @Test("Em memória: com o recurso desligado, enviar e pedir análise são recusados, mas listar e remover funcionam")
    func recursoDesligadoEmMemoria() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoRecursoDesligado)
        do {
            _ = try await api.solicitarUploadMidia(PedidoDeUploadDeMidia(bytes: 1_000))
            Issue.record("deveria recusar com o recurso desligado")
        } catch let erro as ErroDaApi {
            #expect(erro.recursoDesligado)
            #expect(erro.codigo == .semPermissao)
        }
        let existente = try #require(try await api.minhasMidias().first)
        await #expect(throws: ErroDaApi.self) { try await api.pedirNovaAnaliseMidia(id: existente.id) }
        await #expect(throws: ErroDaApi.self) { try await api.confirmarUploadMidia(id: existente.id) }
        let removida = try await api.removerMidia(id: existente.id)
        #expect(removida.estado == .removida)
        #expect(try await api.removerMidia(id: existente.id) == removida, "remover é idempotente")
    }

    @Test("Em memória: nova análise vale uma vez, só para recusada ou não publicada, e não vale depois do expurgo")
    func novaAnaliseEmMemoria() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoRecusada)
        let recusada = try #require(try await api.minhasMidias().first)
        #expect(recusada.podePedirNovaAnalise)
        let emAnalise = try await api.pedirNovaAnaliseMidia(id: recusada.id)
        #expect(emAnalise.estado == .emAnalise)
        #expect(try await api.pedirNovaAnaliseMidia(id: recusada.id) == emAnalise, "repetir não gera outra análise")
        // A decisão da nova análise: recusada de novo, e agora não cabe mais pedir.
        try await api.decidirMidiaParaTeste(id: recusada.id, estado: .recusada, motivo: .fotoInadequada)
        #expect(try await api.minhasMidias().first?.podePedirNovaAnalise == false)

        let aprovada = ApiClienteEmMemoria(cenario: .fotoAprovada)
        let id = try #require(try await aprovada.minhasMidias().first).id
        do {
            _ = try await aprovada.pedirNovaAnaliseMidia(id: id)
            Issue.record("mídia aprovada não pede nova análise")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .midiaIndisponivel)
            #expect(erro.detalhes == "estado_invalido")
        }

        let expurgada = ApiClienteEmMemoria(cenario: .fotoNaoPublicada)
        let idExpurgada = try #require(try await expurgada.minhasMidias().first).id
        try await expurgada.expurgarMidiaParaTeste(id: idExpurgada)
        do {
            _ = try await expurgada.pedirNovaAnaliseMidia(id: idExpurgada)
            Issue.record("depois do expurgo não há o que reanalisar")
        } catch let erro as ErroDaApi {
            #expect(erro.codigo == .midiaIndisponivel)
            #expect(erro.detalhes == "expurgada")
        }
    }

    // MARK: Fluxo da tela

    private static func ferramentas(
        verificador: VerificadorLocalDeFotoSimulado = VerificadorLocalDeFotoSimulado(),
        enviador: EnviadorDeMidiaSimulado = EnviadorDeMidiaSimulado()
    ) -> FerramentasDaFoto {
        FerramentasDaFoto(preparador: PreparadorDeFotoDoSistema(), verificador: verificador, enviador: enviador)
    }

    @Test("A seção só aparece com o recurso ligado ou com uma foto para remover")
    @MainActor func visibilidadeDaSecao() async {
        let semFoto = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: .fotoSemFoto), ferramentas: Self.ferramentas())
        #expect(!semFoto.secaoVisivel, "antes de carregar não mostra nada")
        await semFoto.carregar()
        #expect(semFoto.secaoVisivel && semFoto.podeEscolherFoto && !semFoto.podeRemover)

        // O Prod nasce desligado: sem foto, a entrada some e não marca falha.
        let desligado = FotoDePerfilViewModel(api: ApiClienteEmMemoria(), ferramentas: Self.ferramentas())
        await desligado.carregar()
        #expect(!desligado.secaoVisivel && !desligado.podeEscolherFoto)
        #expect(!desligado.falhouAoCarregar)

        // Desligado com foto: aparece só para remover, sem escolher nem pedir análise.
        let comFoto = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: .fotoRecursoDesligado), ferramentas: Self.ferramentas())
        await comFoto.carregar()
        #expect(comFoto.secaoVisivel && comFoto.podeRemover)
        #expect(!comFoto.podeEscolherFoto && !comFoto.podePedirNovaAnalise)
        #expect(!comFoto.falhouAoCarregar)
    }

    @Test("Com o recurso desligado, falha em minhas_midias não levanta erro na tela (EMAIL #52252)")
    @MainActor func falhaEmMinhasMidiasComRecursoDesligadoNaoGeraErro() async {
        let api = ApiClienteEmMemoria()
        await api.definirRedeCaida(true)
        let model = FotoDePerfilViewModel(api: api, ferramentas: Self.ferramentas())
        await model.carregar()
        #expect(!model.secaoVisivel)
        #expect(!model.falhouAoCarregar)
        #expect(model.aviso == nil)
    }

    @Test("Cada um dos sete estados diz o que pode fazer")
    @MainActor func acoesPorEstado() async {
        let esperado: [(ApiClienteEmMemoria.Cenario, EstadoMidia, escolher: Bool, analise: Bool, remover: Bool)] = [
            (.fotoEmAnalise, .emAnalise, true, false, true),
            (.fotoAprovada, .aprovada, true, false, true),
            (.fotoRecusada, .recusada, true, true, true),
            (.fotoNaoPublicada, .naoPublicada, true, true, true),
            (.fotoOcultada, .ocultada, true, false, true),
        ]
        for (cenario, estado, escolher, analise, remover) in esperado {
            let model = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: cenario), ferramentas: Self.ferramentas())
            await model.carregar()
            #expect(model.midia?.estado == estado, "\(cenario)")
            #expect(model.podeEscolherFoto == escolher, "\(cenario)")
            #expect(model.podePedirNovaAnalise == analise, "\(cenario)")
            #expect(model.podeRemover == remover, "\(cenario)")
        }
    }

    @Test("Foto limpa: prepara, confere, pede a URL, envia só o original e fica em análise")
    @MainActor func envioDeFoto() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let enviador = EnviadorDeMidiaSimulado()
        let verificador = VerificadorLocalDeFotoSimulado()
        let model = FotoDePerfilViewModel(api: api, ferramentas: Self.ferramentas(verificador: verificador, enviador: enviador))
        await model.carregar()

        await model.enviar(original: try Imagens.jpegComMetadados(largura: 2400, altura: 1800), recorte: .centralizado)

        #expect(model.aviso == nil)
        #expect(model.etapa == .ocioso)
        #expect(model.midia?.estado == .emAnalise)
        #expect(model.estaAcompanhando)
        #expect(verificador.chamadas == 1)
        #expect(enviador.envios.count == 1, "só o original sobe; a miniatura deriva do servidor")
        let enviado = try #require(enviador.envios.first)
        let pedidos = await api.pedidosDeUploadDeMidia
        #expect(pedidos.count == 1)
        #expect(pedidos.first?.bytes == enviado.bytes, "o servidor é avisado do tamanho real do JPEG")
        #expect(pedidos.first?.mime == "image/jpeg")
    }

    @Test("Bloqueio do aparelho: nada vai ao servidor nem ao Storage, e a tela diz o que fazer",
          arguments: [MotivoDeBloqueioLocal.telefone, .qrCode, .conteudoImproprio, .analiseIndisponivel])
    @MainActor func bloqueioNoAparelho(motivo: MotivoDeBloqueioLocal) async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let enviador = EnviadorDeMidiaSimulado()
        let model = FotoDePerfilViewModel(
            api: api, ferramentas: Self.ferramentas(verificador: VerificadorLocalDeFotoSimulado(resultado: .bloqueada(motivo)), enviador: enviador)
        )
        await model.carregar()

        await model.enviar(original: try Imagens.jpegComMetadados(largura: 1200, altura: 1200), recorte: .centralizado)

        #expect(model.aviso == .bloqueadaNoAparelho(motivo))
        #expect(model.etapa == .ocioso)
        #expect(await api.pedidosDeUploadDeMidia.isEmpty, "o servidor nem fica sabendo da foto")
        #expect(enviador.envios.isEmpty)
        #expect(try await api.minhasMidias().isEmpty)
        #expect(!TextosFotoDePerfil.aviso(.bloqueadaNoAparelho(motivo)).isEmpty)
    }

    @Test("Foto que não abre: aviso amigável e nenhuma chamada")
    @MainActor func fotoQueNaoAbre() async {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let model = FotoDePerfilViewModel(api: api, ferramentas: Self.ferramentas())
        await model.carregar()
        await model.enviar(original: Data("lixo".utf8), recorte: .centralizado)
        #expect(model.aviso == .imagemInvalida)
        #expect(await api.pedidosDeUploadDeMidia.isEmpty)
    }

    @Test("Sem as peças montadas (ferramentas indisponíveis) nada sobe: falha fechada")
    @MainActor func ferramentasIndisponiveis() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let model = FotoDePerfilViewModel(api: api, ferramentas: .indisponivel)
        await model.carregar()
        await model.enviar(original: try Imagens.jpegComMetadados(largura: 900, altura: 900), recorte: .centralizado)
        #expect(model.aviso != nil)
        #expect(await api.pedidosDeUploadDeMidia.isEmpty)
    }

    @Test("Falha no envio do arquivo: aviso, e a mídia que ficou em enviando é retirada do caminho")
    @MainActor func falhaNoUpload() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoSemFoto)
        let model = FotoDePerfilViewModel(
            api: api, ferramentas: Self.ferramentas(enviador: EnviadorDeMidiaSimulado(erro: ErroDaApi(codigo: .semRede)))
        )
        await model.carregar()
        await model.enviar(original: try Imagens.jpegComMetadados(largura: 1000, altura: 1000), recorte: .centralizado)
        #expect(model.aviso == .semRede)
        #expect(model.midia == nil, "nenhuma foto presa em enviando")
        #expect(try await api.minhasMidias().allSatisfy { $0.estado == .removida })
        #expect(model.podeEscolherFoto, "dá para tentar de novo")
    }

    @Test("Pedir nova análise leva a em_analise uma vez só; depois a ação some")
    @MainActor func pedirNovaAnalise() async {
        let model = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: .fotoRecusada), ferramentas: Self.ferramentas())
        await model.carregar()
        #expect(model.podePedirNovaAnalise)
        await model.pedirNovaAnalise()
        #expect(model.midia?.estado == .emAnalise)
        #expect(!model.podePedirNovaAnalise)
        #expect(model.aviso == nil)
    }

    @Test("Remover tira a foto da tela; com o recurso desligado ainda remove, e a seção some")
    @MainActor func removerFoto() async {
        let model = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: .fotoRecursoDesligado), ferramentas: Self.ferramentas())
        await model.carregar()
        #expect(model.midia?.estado == .aprovada)
        await model.remover()
        #expect(model.midia == nil && model.fotoPublicada == nil)
        #expect(!model.secaoVisivel, "recurso desligado e sem foto: a entrada some")
        #expect(model.aviso == nil)

        let ligado = FotoDePerfilViewModel(api: ApiClienteEmMemoria(cenario: .fotoAprovada), ferramentas: Self.ferramentas())
        await ligado.carregar()
        await ligado.remover()
        #expect(ligado.midia == nil)
        #expect(ligado.secaoVisivel && ligado.podeEscolherFoto, "ligado: volta a oferecer Escolher foto")
    }

    @Test("Enquanto a análise roda, o acompanhamento relê e para na decisão")
    @MainActor func acompanhamento() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoEmAnalise)
        let model = FotoDePerfilViewModel(
            api: api, ferramentas: Self.ferramentas(), intervaloDoAcompanhamento: .milliseconds(20), tentativasDoAcompanhamento: 50
        )
        await model.carregar()
        #expect(model.estaAcompanhando)
        let id = try #require(model.midia?.id)
        let acompanhando = Task { await model.acompanhar() }
        try await Task.sleep(for: .milliseconds(80))
        try await api.decidirMidiaParaTeste(id: id, estado: .aprovada)
        await acompanhando.value
        #expect(model.midia?.estado == .aprovada)
        #expect(!model.estaAcompanhando)
        #expect(model.urlDaFoto != nil)
    }

    @Test("O acompanhamento tem limite de tentativas e não gira para sempre")
    @MainActor func acompanhamentoComLimite() async {
        let model = FotoDePerfilViewModel(
            api: ApiClienteEmMemoria(cenario: .fotoEmAnalise), ferramentas: Self.ferramentas(),
            intervaloDoAcompanhamento: .milliseconds(5), tentativasDoAcompanhamento: 3
        )
        await model.carregar()
        await model.acompanhar()
        #expect(model.midia?.estado == .emAnalise)
    }

    @Test("Troca de foto: a aprovada segue à mostra enquanto a nova espera a análise")
    @MainActor func trocaDeFoto() async throws {
        let api = ApiClienteEmMemoria(cenario: .fotoAprovada)
        let model = FotoDePerfilViewModel(api: api, ferramentas: Self.ferramentas())
        await model.carregar()
        let aprovada = try #require(model.fotoPublicada)
        await model.enviar(original: try Imagens.jpegComMetadados(largura: 1000, altura: 1000), recorte: .centralizado)
        #expect(model.midia?.estado == .emAnalise)
        #expect(model.fotoPublicada?.id == aprovada.id)
        #expect(model.urlDaFoto == aprovada.url)
    }

    @Test("Os erros da API viram o aviso certo")
    func avisoPorErro() {
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .semPermissao, detalhes: "recurso_desligado")) == .recursoDesligado)
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa")) == .contaSuspensa)
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .midiaInvalida, detalhes: "formato")) == .recusadaPeloServidor)
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .midiaIndisponivel, detalhes: "expurgada")) == .expurgada)
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .midiaIndisponivel, detalhes: "estado_invalido")) == .indisponivelAgora)
        #expect(FotoDePerfilViewModel.aviso(para: ErroDaApi(codigo: .semRede)) == .semRede)
        #expect(FotoDePerfilViewModel.aviso(para: URLError(.badServerResponse)) == .indisponivelAgora)
    }

    @Test("Todo estado, motivo e aviso tem texto próprio, sem prometer revisão por pessoa")
    func textos() {
        let todos = MotivoRecusaMidia.allCases.map { TextosFotoDePerfil.motivo($0) } + [TextosFotoDePerfil.motivo(nil)]
        #expect(todos.allSatisfy { !$0.isEmpty })
        #expect(Set(todos).count == todos.count)
        let avisos: [FotoDePerfilViewModel.Aviso] = [
            .imagemInvalida, .semRede, .recusadaPeloServidor, .recursoDesligado, .expurgada, .contaSuspensa, .indisponivelAgora,
        ] + [MotivoDeBloqueioLocal.telefone, .qrCode, .conteudoImproprio, .analiseIndisponivel].map { .bloqueadaNoAparelho($0) }
        let frases = avisos.map(TextosFotoDePerfil.aviso) + [TextosFotoDePerfil.textoEmAnalise, TextosFotoDePerfil.textoNaoPublicada, TextosFotoDePerfil.textoOcultada]
        #expect(frases.allSatisfy { !$0.isEmpty })
        for frase in frases {
            #expect(!frase.localizedCaseInsensitiveContains("revis"), "o app não promete revisão por pessoa: \(frase)")
        }
    }
}

// MARK: - Apoio

private final class MarcadorDosTestes {}

/// Imagens sintéticas dos testes: nada de foto nem de pessoa real.
private enum Imagens {
    struct Cor { let r: Int; let g: Int; let b: Int }

    static func jpeg(_ imagem: CGImage, propriedades: [CFString: Any] = [:]) throws -> Data {
        let dados = NSMutableData()
        let destino = try #require(CGImageDestinationCreateWithData(dados, UTType.jpeg.identifier as CFString, 1, nil))
        var opcoes = propriedades
        opcoes[kCGImageDestinationLossyCompressionQuality] = 0.9
        CGImageDestinationAddImage(destino, imagem, opcoes as CFDictionary)
        try #require(CGImageDestinationFinalize(destino))
        return dados as Data
    }

    static func desenhar(largura: Int, altura: Int, _ corpo: (CGContext) -> Void) throws -> CGImage {
        let espaco = CGColorSpaceCreateDeviceRGB()
        let contexto = try #require(CGContext(
            data: nil, width: largura, height: altura, bitsPerComponent: 8, bytesPerRow: 0, space: espaco,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        corpo(contexto)
        return try #require(contexto.makeImage())
    }

    /// JPEG com EXIF, GPS, TIFF e orientação gravados, como sai de uma câmera.
    static func jpegComMetadados(largura: Int, altura: Int, orientacao: Int = 6) throws -> Data {
        let imagem = try desenhar(largura: largura, altura: altura) { contexto in
            contexto.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.3, alpha: 1))
            contexto.fill(CGRect(x: 0, y: 0, width: largura, height: altura))
            contexto.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1))
            contexto.fillEllipse(in: CGRect(x: largura / 3, y: altura / 4, width: largura / 3, height: altura / 2))
        }
        return try jpeg(imagem, propriedades: [
            kCGImagePropertyOrientation: orientacao,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Aparelho de teste", kCGImagePropertyTIFFOrientation: orientacao],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "dado pessoal de teste"],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 15.79, kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 47.88, kCGImagePropertyGPSLongitudeRef: "W",
            ],
        ])
    }

    /// Metade esquerda vermelha e direita azul, com a orientação gravada.
    static func jpegDeDuasMetades(orientacao: Int, largura: Int = 1200, altura: Int = 800) throws -> Data {
        let imagem = try desenhar(largura: largura, altura: altura) { contexto in
            contexto.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            contexto.fill(CGRect(x: 0, y: 0, width: largura / 2, height: altura))
            contexto.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            contexto.fill(CGRect(x: largura / 2, y: 0, width: largura - largura / 2, height: altura))
        }
        return try jpeg(imagem, propriedades: [kCGImagePropertyOrientation: orientacao])
    }

    /// Fundo claro, com o texto em preto grande, como um cartaz ou uma camisa.
    static func jpegDeTexto(_ texto: String?) throws -> Data {
        let lado = CGSize(width: 1000, height: 1000)
        let renderizador = UIGraphicsImageRenderer(size: lado)
        let imagem = renderizador.image { contexto in
            UIColor.white.setFill()
            contexto.fill(CGRect(origin: .zero, size: lado))
            guard let texto else { return }
            let estilo = NSMutableParagraphStyle()
            estilo.alignment = .center
            (texto as NSString).draw(
                in: CGRect(x: 40, y: 380, width: 920, height: 300),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 110), .foregroundColor: UIColor.black, .paragraphStyle: estilo]
            )
        }
        return try #require(imagem.jpegData(compressionQuality: 0.95))
    }

    static func jpegComQRCode(_ conteudo: String) throws -> Data {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(conteudo.utf8)
        let pequeno = try #require(filtro.outputImage)
        let modulos = try #require(CIContext().createCGImage(pequeno, from: pequeno.extent))
        // Cada módulo do QR vira um bloco de 24 px, sem suavização, sobre fundo branco com margem.
        let escala = 24
        let margem = 4 * escala
        let lado = modulos.width * escala + 2 * margem
        let imagem = try desenhar(largura: lado, altura: lado) { contexto in
            contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            contexto.fill(CGRect(x: 0, y: 0, width: lado, height: lado))
            contexto.interpolationQuality = .none
            contexto.draw(modulos, in: CGRect(x: margem, y: margem, width: modulos.width * escala, height: modulos.height * escala))
        }
        return try jpeg(imagem)
    }

    static func propriedades(_ jpeg: Data) throws -> [CFString: Any] {
        let fonte = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(fonte, 0, nil) as? [CFString: Any])
    }

    static func corDoPixel(_ jpeg: Data, x: Int, y: Int) throws -> Cor {
        let fonte = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let imagem = try #require(CGImageSourceCreateImageAtIndex(fonte, 0, nil))
        var pixel = [UInt8](repeating: 0, count: 4)
        let contexto = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Desenha só o pixel pedido na posição (0, 0) do contexto de 1 x 1.
        contexto.draw(imagem, in: CGRect(x: -x, y: -(imagem.height - 1 - y), width: imagem.width, height: imagem.height))
        return Cor(r: Int(pixel[0]), g: Int(pixel[1]), b: Int(pixel[2]))
    }
}
