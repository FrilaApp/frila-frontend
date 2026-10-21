import Foundation
import Testing
@testable import FrilaDados

struct ReproContratanteNovoTests {
    @Test("Regressão (jDbluAEX): o caminho do diretório Frila obtido com caminho decodificado é acessível no sistema de arquivos")
    func caminhoDoDiretorioFrilaDeveSerAcessivelNoSistemaDeArquivos() throws {
        let suporte = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let diretorio = suporte.appending(path: "Frila", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)

        // Regressão jDbluAEX: no build 0.4.0, usava-se diretorio.path(), que gerava percent-encoding (%20)
        // em pastas com espaço como 'Application Support', fazendo o FileManager falhar com CocoaError 260.
        // Com a correção (caminho decodificado / percentEncoded: false), o caminho é resolvido
        // com sucesso pelo sistema de arquivos e os atributos são lidos sem erro.
        let caminhoCorrigido = diretorio.path(percentEncoded: false)
        let atributos = try FileManager.default.attributesOfItem(atPath: caminhoCorrigido)
        #expect(!atributos.isEmpty)
    }

    @Test("Regressão (jDbluAEX): PersistenciaFrila.criarContainer em disco deve ser instanciado com sucesso")
    func criarContainerPersistenteComSucesso() throws {
        let container = try PersistenciaFrila.criarContainer(emMemoria: false)
        #expect(container.configurations.first?.isStoredInMemoryOnly == false)
    }
}
