import Foundation
import Observation

/// Guarda o `BuscaDeProfissionaisViewModel` fora da folha da busca. A folha é recriada a cada apresentação; sem esta
/// guarda, fechar a busca com um envio em curso ou incerto apagaria a trava e a chave do pedido, e a folha nova mandaria
/// outro trabalho completo (DINHEIRO: 2ª vaga). Com envio em curso ou incerto o ViewModel fica (a folha fecha normalmente
/// e, reaberta, mostra o envio ou o pendente com o mesmo trabalho e as mesmas chaves); sem eles, a busca recomeça limpa.
@MainActor
@Observable
public final class GuardaDaBuscaDeProfissionais {
    public private(set) var viewModel: BuscaDeProfissionaisViewModel?
    private let criar: () -> BuscaDeProfissionaisViewModel

    public init(criar: @escaping () -> BuscaDeProfissionaisViewModel) {
        self.criar = criar
    }

    /// O da busca em curso, ou um novo se não há nenhum.
    public func aoAbrir() -> BuscaDeProfissionaisViewModel {
        if let viewModel { return viewModel }
        let novo = criar()
        viewModel = novo
        return novo
    }

    /// Chamado quando a folha some: um envio em curso ou incerto segura o ViewModel. Com o pedido em voo, a resposta ainda
    /// pode criar a vaga, e só este ViewModel tem a chave e o trabalho para resolver no "Tentar de novo".
    public func aoFechar() {
        guard let viewModel, !viewModel.enviando, !viewModel.travadoPeloIncerto else { return }
        self.viewModel = nil
    }
}
