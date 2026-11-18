import FrilaDominio
import SwiftUI

/// As linhas da casa no topo da Conta de quem contrata:
/// - **Equipe da casa**: só quando a conta é administradora da casa em uso (o servidor é a regra; a tela só não oferece);
/// - **Trocar de casa**: só quando `meus_estabelecimentos` tem mais de uma casa;
/// - **Tenho um convite**: para toda conta de contratante, inclusive a que ainda não tem casa (quem foi convidado).
///
/// O papel vem da última leitura de `meus_estabelecimentos` (a que o fluxo do contratante guarda). `aoAtualizarCasas` a relê
/// quando a pessoa perde a administração (um 403 na equipe) ou aceita um convite.
struct EntradasDaCasaNaConta: View {
    let api: any ApiCliente
    let casa: EstabelecimentoDaConta?
    let casas: [EstabelecimentoDaConta]
    let aoEscolherCasa: (UUID) -> Void
    let aoAtualizarCasas: () -> Void
    let aoAbrirCasa: (UUID) -> Void

    /// A casa em uso, com o papel da leitura mais nova.
    private var casaEmUso: EstabelecimentoDaConta? {
        guard let casa else { return nil }
        return casas.first { $0.id == casa.id } ?? casa
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let casaEmUso, casaEmUso.papel == .administrador {
                NavigationLink {
                    DestinoDaEquipeDaCasa(api: api, casa: casaEmUso, aoPerderAdministracao: aoAtualizarCasas)
                } label: {
                    RotuloDeLinha(TextosDaEquipeDaCasa.entradaEquipe)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("conta-equipe-da-casa")
                DivisoriaDeLinha()
            }
            if casas.count > 1 {
                NavigationLink {
                    DestinoDeTrocarDeCasa(api: api, casaEmUso: casaEmUso?.id, aoEscolher: aoEscolherCasa)
                } label: {
                    RotuloDeLinha(TextosDaEquipeDaCasa.entradaTrocar)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("conta-trocar-de-casa")
                DivisoriaDeLinha()
            }
            NavigationLink {
                DestinoDoConvite(api: api, aoAceitar: aoAtualizarCasas, aoAbrirCasa: aoAbrirCasa)
            } label: {
                RotuloDeLinha(TextosDaEquipeDaCasa.entradaConvite)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("conta-tenho-um-convite")
            DivisoriaDeLinha()
        }
    }
}

/// A equipe de uma casa. Um modelo por casa (`.id`): trocar de casa nunca reaproveita a lista de outra.
private struct DestinoDaEquipeDaCasa: View {
    let api: any ApiCliente
    let casa: EstabelecimentoDaConta
    let aoPerderAdministracao: () -> Void

    var body: some View {
        TelaEquipeDaCasa(
            modelo: EquipeDaCasaViewModel(api: api, estabelecimentoID: casa.id, papel: casa.papel),
            aoPerderAdministracao: aoPerderAdministracao
        )
        .id(casa.id)
    }
}

private struct DestinoDeTrocarDeCasa: View {
    @Environment(\.dismiss) private var voltar
    let api: any ApiCliente
    let casaEmUso: UUID?
    let aoEscolher: (UUID) -> Void

    var body: some View {
        TelaTrocarDeCasa(modelo: TrocarDeCasaViewModel(api: api), casaEmUso: casaEmUso) { id in
            aoEscolher(id)
            voltar()
        }
    }
}

private struct DestinoDoConvite: View {
    @Environment(\.dismiss) private var voltar
    let api: any ApiCliente
    let aoAceitar: () -> Void
    let aoAbrirCasa: (UUID) -> Void

    var body: some View {
        TelaTenhoUmConvite(modelo: TenhoUmConviteViewModel(api: api), aoAceitar: aoAceitar) { id in
            voltar()
            aoAbrirCasa(id)
        }
    }
}
