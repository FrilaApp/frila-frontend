import FrilaDominio
import SwiftUI

public struct TelaFuncoesEHorariosProvisoria: View {
    public let conta: Conta?

    public init(conta: Conta? = nil) {
        self.conta = conta
    }

    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(FrilaCor.primaria)

            Text("Funções e horários", bundle: bundleApresentacao)
                .font(.title.bold())
                .foregroundStyle(FrilaCor.texto)

            Text("Configuração de funções e horários disponíveis para o profissional (Cartão #98).", bundle: bundleApresentacao)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FrilaEspaco.medio)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("funcoes-e-horarios-provisoria")
    }
}

public struct TelaInicioContratanteProvisoria: View {
    public let conta: Conta?

    public init(conta: Conta? = nil) {
        self.conta = conta
    }

    public var body: some View {
        VStack(spacing: FrilaEspaco.medio) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(FrilaCor.primaria)

            Text("Início do contratante", bundle: bundleApresentacao)
                .font(.title.bold())
                .foregroundStyle(FrilaCor.texto)

            Text("Painel do contratante para publicação e gestão de turnos.", bundle: bundleApresentacao)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FrilaEspaco.medio)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inicio-contratante-provisoria")
    }
}
