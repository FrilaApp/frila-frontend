import FrilaDominio
import SwiftUI

/// T4b · Cancelar turno (#20, Lote 5).
/// Sheet com altura ajustada ao conteúdo para confirmação de cancelamento antes do início do turno,
/// ou estado "Seu turno já começou" quando o horário já foi ultrapassado.
public struct FolhaCancelarTurno: View {
    @Environment(\.dismiss) private var dismiss
    private let nomeCasa: String
    private let horarioInicio: String
    private let horarioFim: String
    private let horarioJaComecou: Bool
    private let aoCancelar: ((String?) -> Void)?
    private let aoSairDoTurno: (() -> Void)?

    @State private var motivoSelecionado: String?

    private let motivosDisponiveis: [String] = [
        TextosLote4.motivoImprevisto,
        TextosLote4.motivoSaude,
        TextosLote4.motivoTransporte,
        TextosLote4.motivoOutro
    ]

    public init(
        nomeCasa: String = "Bar do Porto",
        horarioInicio: String = "18:00",
        horarioFim: String = "00:00",
        horarioJaComecou: Bool = false,
        aoCancelar: ((String?) -> Void)? = nil,
        aoSairDoTurno: (() -> Void)? = nil
    ) {
        self.nomeCasa = nomeCasa
        self.horarioInicio = horarioInicio
        self.horarioFim = horarioFim
        self.horarioJaComecou = horarioJaComecou
        self.aoCancelar = aoCancelar
        self.aoSairDoTurno = aoSairDoTurno
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    if horarioJaComecou {
                        conteudoHorarioComecou
                    } else {
                        conteudoCancelamentoNormal
                    }
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.top, FrilaEspaco.pequeno)
                .padding(.bottom, FrilaEspaco.grande)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: TextosLote4.fechar)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("cancelar-turno-fechar")
                }
            }
            .accessibilityIdentifier("folha-cancelar-turno")
        }
        .presentationDetents([.height(490), .medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Estado Normal (T4b)

    private var conteudoCancelamentoNormal: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosLote4.cancelarEsteTurno)
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: TextosLote4.casaHojeHorario(casa: nomeCasa, inicio: horarioInicio, fim: horarioFim))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            Text(verbatim: TextosLote4.consequenciaCancelamento)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)

            // Grupo de Motivo (opcional)
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                HStack {
                    Text(verbatim: TextosLote4.motivoOpcional)
                        .font(FrilaTipo.rotuloDoCampo)
                        .foregroundStyle(FrilaCor.textoSecundario)

                    Spacer()

                    if motivoSelecionado != nil {
                        Button {
                            motivoSelecionado = nil
                            UIAccessibility.post(notification: .announcement, argument: TextosLote4.nenhumMotivoEscolhido)
                        } label: {
                            Text(verbatim: TextosLote4.limparMotivo)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cancelar-turno-limpar-motivo")
                    }
                }

                FrilaFlowLayout(horizontalSpacing: FrilaEspaco.pequeno, verticalSpacing: FrilaEspaco.pequeno) {
                    ForEach(motivosDisponiveis, id: \.self) { motivo in
                        let selecionado = motivoSelecionado == motivo
                        Button {
                            motivoSelecionado = motivo
                        } label: {
                            Text(verbatim: motivo)
                                .font(FrilaTipo.corpo)
                                .padding(.horizontal, FrilaEspaco.medio)
                                .frame(minHeight: FrilaMetrica.alvoMinimo)
                                .foregroundStyle(selecionado ? FrilaCor.sobreSelecao : FrilaCor.texto)
                                .background(
                                    selecionado ? FrilaCor.selecao : FrilaCor.controle,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
                        .accessibilityIdentifier("motivo-\(motivo.lowercased())")
                    }
                }
            }
            .padding(.top, FrilaEspaco.minimo)

            // Botão Cancelar turno
            Button {
                aoCancelar?(motivoSelecionado)
                UIAccessibility.post(notification: .announcement, argument: TextosLote4.turnoCancelado)
                dismiss()
            } label: {
                Text(verbatim: TextosLote4.cancelarTurno)
                    .font(FrilaTipo.botaoPadrao)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                    .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                            .strokeBorder(FrilaCor.borda, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, FrilaEspaco.pequeno)
            .accessibilityIdentifier("cancelar-turno-confirmar")
        }
    }

    // MARK: - Estado Quando o Horário Começou (T4b-horario-comecou)

    private var conteudoHorarioComecou: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosLote4.seuTurnoJaComecou)
                    .font(FrilaTipo.secao)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: TextosLote4.casaHojeHorario(casa: nomeCasa, inicio: horarioInicio, fim: horarioFim))
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            Text(verbatim: TextosLote4.avisoHorarioComecou)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
                aoSairDoTurno?()
            } label: {
                Text(verbatim: TextosLote4.sairDoTurno)
                    .font(FrilaTipo.botaoPadrao)
                    .foregroundStyle(FrilaCor.texto)
                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                    .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                            .strokeBorder(FrilaCor.borda, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, FrilaEspaco.pequeno)
            .accessibilityIdentifier("cancelar-turno-sair-do-turno")
        }
    }
}
