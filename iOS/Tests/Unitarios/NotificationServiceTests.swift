import Foundation
import FrilaDominio
import Testing

/// A conferência que a extensão de serviço de notificação faz antes de o sistema mostrar o push
/// (#253). A extensão em si é só a cola com o `UNNotificationServiceExtension`; a regra está em
/// `FiltroDoPushPorVinculo`, no domínio, e é ela que estes testes exercitam.
@Suite("Extensão de notificação: o push de outro vínculo vira texto neutro (#253)")
struct NotificationServiceTests {
    private static let vinculoAtivo = UUID(uuidString: "4d2f6c1a-9b3e-4e7a-8c5d-2f1b0a9e8d7c")!
    private static let outroVinculo = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
    private static let vagaID = "a5a98fd8-fd4e-4c5e-9fbd-37a1a6c0e000"

    /// O aviso como o FCM o entrega: os campos de `data` na raiz, como texto, ao lado do `aps`.
    private func aviso(vinculo: String?) -> ConteudoDoPush {
        var payload = ["tipo": "vaga", "vaga_id": Self.vagaID, "gcm.message_id": "123"]
        payload[FiltroDoPushPorVinculo.chaveDoVinculo] = vinculo
        return ConteudoDoPush(titulo: "Vaga de garçom", subtitulo: "Bar do Zé", corpo: "Sexta, 19h às 23h, R$ 180", payload: payload)
    }

    @Test("vinculo_id igual ao guardado: o aviso é de quem está no aparelho e segue como veio")
    func mesmoVinculo() {
        let original = aviso(vinculo: Self.vinculoAtivo.uuidString.lowercased())

        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: Self.vinculoAtivo) == .manter)
        #expect(FiltroDoPushPorVinculo.filtrar(original, vinculoAtivo: Self.vinculoAtivo) == original)
    }

    @Test("vinculo_id em maiúsculas ainda é o mesmo UUID")
    func mesmoVinculoEmMaiusculas() {
        let original = aviso(vinculo: Self.vinculoAtivo.uuidString.uppercased())
        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: Self.vinculoAtivo) == .manter)
    }

    @Test("vinculo_id diferente do guardado: texto neutro e payload vazio, para a tela de bloqueio e o toque não exporem a outra conta")
    func outroVinculo() {
        let original = aviso(vinculo: Self.outroVinculo.uuidString)

        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: Self.vinculoAtivo) == .neutralizar)
        let filtrado = FiltroDoPushPorVinculo.filtrar(original, vinculoAtivo: Self.vinculoAtivo)
        #expect(filtrado == ConteudoDoPush(titulo: FiltroDoPushPorVinculo.tituloNeutro, subtitulo: "", corpo: FiltroDoPushPorVinculo.corpoNeutro, payload: [:]))
        // Sem `tipo`, o toque no aviso neutro não abre nada no app.
        #expect(AvisoDePush(payload: filtrado.payload) == nil)
    }

    @Test("Sem sessão (nada guardado no App Group), o aviso com vinculo_id é tratado como de outra conta")
    func semSessao() {
        let original = aviso(vinculo: Self.vinculoAtivo.uuidString)

        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: nil) == .neutralizar)
        #expect(FiltroDoPushPorVinculo.filtrar(original, vinculoAtivo: nil).corpo == FiltroDoPushPorVinculo.corpoNeutro)
    }

    @Test("vinculo_id que não é UUID conta como de outra conta")
    func vinculoInvalido() {
        #expect(FiltroDoPushPorVinculo.decidir(payload: aviso(vinculo: "nao-e-uuid").payload, vinculoAtivo: Self.vinculoAtivo) == .neutralizar)
        #expect(FiltroDoPushPorVinculo.decidir(payload: aviso(vinculo: "nao-e-uuid").payload, vinculoAtivo: nil) == .neutralizar)
    }

    @Test("Sem vinculo_id (servidor anterior à 0.2.30), o aviso segue como veio, com ou sem sessão")
    func legado() {
        let original = aviso(vinculo: nil)

        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: Self.vinculoAtivo) == .manter)
        #expect(FiltroDoPushPorVinculo.decidir(payload: original.payload, vinculoAtivo: nil) == .manter)
        #expect(FiltroDoPushPorVinculo.filtrar(original, vinculoAtivo: nil) == original)
    }

    @Test("A decisão lê o userInfo como o sistema o entrega, com o aps ao lado dos campos de texto")
    func userInfoDoSistema() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Vaga de garçom"], "mutable-content": 1],
            "tipo": "vaga",
            FiltroDoPushPorVinculo.chaveDoVinculo: Self.outroVinculo.uuidString,
        ]
        #expect(FiltroDoPushPorVinculo.decidir(payload: userInfo, vinculoAtivo: Self.vinculoAtivo) == .neutralizar)
        #expect(FiltroDoPushPorVinculo.decidir(payload: userInfo, vinculoAtivo: Self.outroVinculo) == .manter)
    }

    @Test("O texto neutro não traz nada do aviso original")
    func textoNeutro() {
        #expect(!FiltroDoPushPorVinculo.tituloNeutro.isEmpty)
        #expect(!FiltroDoPushPorVinculo.corpoNeutro.isEmpty)
        let neutro = FiltroDoPushPorVinculo.filtrar(aviso(vinculo: Self.outroVinculo.uuidString), vinculoAtivo: nil)
        for texto in ["garçom", "Zé", "R$", Self.vagaID] {
            #expect(!neutro.titulo.contains(texto))
            #expect(!neutro.corpo.contains(texto))
        }
    }

    @Test("O vinculo_id no App Group: grava, lê e apaga, em minúsculas como o contrato")
    func grupoDoApp() throws {
        let grupo = "group.com.frila.org.app.teste.\(UUID().uuidString)"
        let armazenamento = VinculoNoGrupoDoApp(grupo: grupo)
        defer { UserDefaults(suiteName: grupo)?.removePersistentDomain(forName: grupo) }
        #expect(armazenamento.ler() == nil)

        armazenamento.guardar(Self.vinculoAtivo)
        #expect(armazenamento.ler() == Self.vinculoAtivo)
        #expect(UserDefaults(suiteName: grupo)?.string(forKey: "vinculo_id") == Self.vinculoAtivo.uuidString.lowercased())
        // O que a extensão lê é o mesmo que o app gravou: outra instância, a mesma suíte.
        #expect(VinculoNoGrupoDoApp(grupo: grupo).ler() == Self.vinculoAtivo)

        armazenamento.guardar(nil)
        #expect(armazenamento.ler() == nil)
    }
}
