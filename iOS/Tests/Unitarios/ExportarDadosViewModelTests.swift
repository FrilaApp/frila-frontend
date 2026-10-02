import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Exportar Meus Dados: View Model (#219)")
struct ExportarDadosViewModelTests {

    private struct RelogioFixo: Relogio {
        let agora: Date
    }

    private final class DubleApiExportar: ApiClienteEncaminhador, @unchecked Sendable {
        var resultado: Result<Data, Error> = .success(Data("{\"gerado_em\":\"2026-10-02T12:00:00Z\"}".utf8))
        var chamadasExportar = 0
        var atrasoEmNanosegundos: UInt64?

        override func exportarMeusDados() async throws -> Data {
            chamadasExportar += 1
            if let atrasoEmNanosegundos {
                try? await Task.sleep(nanoseconds: atrasoEmNanosegundos)
            }
            switch resultado {
            case let .success(dados): return dados
            case let .failure(erro): throw erro
            }
        }
    }

    @Test("Sucesso: gera arquivo temporário, prepara para compartilhar e limpa estado de erro")
    func sucessoGeraArquivoEPreparaCompartilhamento() async throws {
        let duble = DubleApiExportar()
        let relogio = RelogioFixo(agora: Date(timeIntervalSince1970: 1_790_000_000))
        let diretorioTeste = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorioTeste, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorioTeste) }

        let vm = ExportarDadosViewModel(api: duble, relogio: relogio, diretorioTemporario: diretorioTeste)

        #expect(vm.estado == .ocioso)
        #expect(!vm.estaCarregando)
        #expect(vm.arquivoParaCompartilhar == nil)
        #expect(!vm.mostrarFolhaCompartilhamento)

        await vm.exportarDados()

        #expect(vm.estado == .ocioso)
        #expect(!vm.estaCarregando)
        #expect(vm.mostrarFolhaCompartilhamento)
        #expect(vm.mensagemErro == nil)

        let url = try #require(vm.arquivoParaCompartilhar)
        #expect(url.lastPathComponent.hasPrefix("frila-meus-dados-"))
        #expect(url.pathExtension == "json")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let conteudo = try Data(contentsOf: url)
        #expect(conteudo == Data("{\"gerado_em\":\"2026-10-02T12:00:00Z\"}".utf8))
        #expect(duble.chamadasExportar == 1)

        vm.folhaCompartilhamentoFechada()
    }

    @Test("Sem rede: exibe mensagem amigável de conexão e não abre folha de compartilhamento")
    func semRedeExibeMensagemAmigavel() async throws {
        let duble = DubleApiExportar()
        duble.resultado = .failure(ErroDaApi(codigo: .semRede))

        let vm = ExportarDadosViewModel(api: duble)

        await vm.exportarDados()

        #expect(vm.estado == .erro(MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede))))
        #expect(vm.mensagemErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        #expect(!vm.mostrarFolhaCompartilhamento)
        #expect(vm.arquivoParaCompartilhar == nil)
        #expect(duble.chamadasExportar == 1)
    }

    @Test("Erro do servidor: exibe mensagem padrão e permite tentar de novo")
    func erroDoServidorEPermiteTentarNovamente() async throws {
        let duble = DubleApiExportar()
        duble.resultado = .failure(ErroDaApi(codigo: .desconhecido))

        let vm = ExportarDadosViewModel(api: duble)

        await vm.exportarDados()

        #expect(vm.mensagemErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido)))
        #expect(!vm.mostrarFolhaCompartilhamento)
        #expect(vm.arquivoParaCompartilhar == nil)

        // Tentar de novo com sucesso
        duble.resultado = .success(Data("{\"ok\":true}".utf8))
        await vm.exportarDados()

        #expect(vm.mensagemErro == nil)
        #expect(vm.mostrarFolhaCompartilhamento)
        #expect(vm.arquivoParaCompartilhar != nil)
        #expect(duble.chamadasExportar == 2)

        vm.folhaCompartilhamentoFechada()
    }

    @Test("Toque duplo: chamadas concorrentes enquanto está carregando não disparam segunda requisição")
    func toqueDuploNaoDisparaSegundaRequisicao() async throws {
        let duble = DubleApiExportar()
        duble.atrasoEmNanosegundos = 100_000_000 // 100ms
        let vm = ExportarDadosViewModel(api: duble)

        async let primeira: () = vm.exportarDados()
        async let segunda: () = vm.exportarDados()

        _ = await (primeira, segunda)

        #expect(duble.chamadasExportar == 1)
        vm.folhaCompartilhamentoFechada()
    }

    @Test("Arquivo apagado ao fechar: fechar a folha remove o arquivo temporário do disco imediatamente")
    func arquivoApagadoAoFecharFolha() async throws {
        let duble = DubleApiExportar()
        let diretorioTeste = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorioTeste, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorioTeste) }

        let vm = ExportarDadosViewModel(api: duble, diretorioTemporario: diretorioTeste)

        await vm.exportarDados()

        let url = try #require(vm.arquivoParaCompartilhar)
        #expect(FileManager.default.fileExists(atPath: url.path))

        vm.folhaCompartilhamentoFechada()

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(vm.arquivoParaCompartilhar == nil)
        #expect(!vm.mostrarFolhaCompartilhamento)
    }
}
