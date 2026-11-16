import Foundation
import Observation

/// Guarda o `BuscaDeProfissionaisViewModel` fora da folha da busca. A folha é recriada a cada apresentação; sem esta
/// guarda, fechar a busca com um envio incerto apagaria a trava e a chave do pedido, e chamar a mesma pessoa de novo
/// abriria outra vaga (DINHEIRO). Com envio incerto o ViewModel fica (a folha fecha normalmente e, reaberta, mostra o
/// pendente com o mesmo trabalho e as mesmas chaves); sem ele, a busca recomeça limpa.
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

    /// Chamado quando a folha some: só um envio incerto segura o ViewModel.
    public func aoFechar() {
        if viewModel?.travadoPeloIncerto != true { viewModel = nil }
    }
}
