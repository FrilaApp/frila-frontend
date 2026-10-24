import FrilaDominio
import SwiftUI

/// "Mais opções" no fim do estúdio: rateio dos 10%, observações e alerta de vaga vazia, campos do
/// contrato que o Estúdio da origem não desenhou. O cartão-linha é o do protótipo midfi da origem
/// (`Publicar.dc.html`: título, apoio em cinza e chevron), que lá levava à tela `MaisOpcoes.dc.html`;
/// aqui ele abre no lugar, com o assentamento dos containers que expandem (`FrilaLPEMotion.disclosure*`).
/// Os campos usam as peças do formulário da origem (linha Sim/Não, campo rotulado, segmentado) e os
/// mesmos textos e identificadores do formulário antigo. O traje fica na etapa Turno, onde a origem o pôs.
struct MaisOpcoesEstudioFrilaLPE: View {
    @Bindable var vaga: PublicarVagaViewModel
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @FocusState private var observacoesEmFoco: Bool

    /// Antecedências do alerta de vaga vazia (minutos), na ordem crescente do protótipo midfi.
    private static let antecedencias: [FrilaLPESegmentedItem<Int>] = [
        FrilaLPESegmentedItem(tag: 120, title: TextosPublicarVaga.alertaDuasHoras),
        FrilaLPESegmentedItem(tag: 180, title: TextosPublicarVaga.alertaTresHoras),
        FrilaLPESegmentedItem(tag: 360, title: TextosPublicarVaga.alertaSeisHoras)
    ]

    /// Aberto pelo usuário, pela restauração (campos preenchidos) ou por um erro que mora aqui dentro.
    private var aberto: Bool {
        vaga.mostrandoMaisOpcoes || vaga.erros[.observacoes] != nil || vaga.erros[.rateio] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecalho

            if aberto {
                VStack(alignment: .leading, spacing: FrilaLPEGeometry.space20) {
                    rateio
                    observacoes
                    alerta
                }
                .padding(.horizontal, FrilaLPEGeometry.space16)
                .padding(.top, FrilaLPEGeometry.space8)
                .padding(.bottom, FrilaLPEGeometry.space20)
                .transition(.opacity.animation(FrilaMovimento.animacao(FrilaLPEMotion.contentFadeIn, reduzir: reduzirMovimento)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaLPEColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaLPEColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaLPEFormLift(isDark: isDark)
        .frilaLPEDisclosureDrop(isOpen: aberto, reduceMotion: reduzirMovimento)
        .disabled(vaga.camposBloqueados)
    }

    /// Cartão-linha do midfi: título, apoio e chevron. Fechado aponta para baixo; aberto, para cima.
    private var cabecalho: some View {
        Button {
            let curva = aberto ? FrilaLPEMotion.disclosureCollapse : FrilaLPEMotion.disclosureExpand
            withAnimation(FrilaMovimento.animacao(curva, reduzir: reduzirMovimento)) {
                vaga.mostrandoMaisOpcoes.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: FrilaLPEGeometry.space8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: TextosPublicarVaga.maisOpcoes)
                        .frilaLPEType(FrilaLPEFormType.input, dynamic: true)
                        .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: TextosPublicarVaga.maisOpcoesAjudaEstudio)
                        .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                        .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(FrilaLPEFonteDoSistema.fonte(size: 15, weight: .semibold))
                    .foregroundStyle(FrilaLPEColor.dynamicTextMuted(isDark: isDark))
                    .rotationEffect(.degrees(aberto ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaLPEGeometry.space16)
            .padding(.vertical, FrilaLPEGeometry.space8)
            .frame(maxWidth: .infinity, minHeight: FrilaLPEGeometry.buttonHeightProminent, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TextosPublicarVaga.maisOpcoes)
        .accessibilityHint(TextosPublicarVaga.maisOpcoesAjudaEstudio)
        .accessibilityValue(aberto ? TextosPublicarVaga.maisOpcoesAberto : TextosPublicarVaga.maisOpcoesFechado)
        .accessibilityIdentifier("mais-opcoes-botao")
    }

    private var rateio: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
            FrilaLPEJobFormYesNoRow(title: TextosPublicarVaga.rateio, isOn: $vaga.participaRateioOuNao, isDark: isDark)
                .accessibilityIdentifier("rateio-vaga-campo")
            erro(vaga.erros[.rateio], id: "erro-publicacao-rateio")
        }
    }

    private var observacoes: some View {
        VStack(alignment: .leading, spacing: FrilaLPEGeometry.space8) {
            FrilaLPEJobFormLabeledField(label: TextosPublicarVaga.observacoes, isDark: isDark, support: TextosPublicarVaga.observacoesAjuda) {
                TextField(TextosPublicarVaga.observacoes, text: $vaga.observacoes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($observacoesEmFoco)
                    .accessibilityIdentifier("observacoes-vaga-campo")
                    .frilaLPEType(FrilaLPEFormType.input, dynamic: true)
                    .foregroundStyle(FrilaLPEColor.dynamicTextPrimary(isDark: isDark))
                    .padding(.horizontal, FrilaLPEGeometry.space14)
                    .padding(.vertical, FrilaLPEGeometry.space14)
                    .frame(maxWidth: .infinity, minHeight: FrilaLPEGeometry.buttonHeightProminent, alignment: .topLeading)
                    .background(FrilaLPEColor.dynamicFormFieldSurface(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusInput, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaLPEGeometry.radiusInput, style: .continuous)
                            .strokeBorder(
                                vaga.erros[.observacoes] == nil ? FrilaLPEColor.dynamicFormFieldBorder(isDark: isDark) : FrilaLPEColor.dynamicError(isDark: isDark),
                                lineWidth: vaga.erros[.observacoes] == nil ? 1 : 1.5
                            )
                    }
                    .frilaLPEFormField(id: "observacoes-vaga-campo", isFocused: observacoesEmFoco, onDismiss: { observacoesEmFoco = false })
            }
            erro(vaga.erros[.observacoes], id: "erro-publicacao-observacoes")
        }
    }

    private var alerta: some View {
        FrilaLPEJobFormLabeledField(label: TextosPublicarVaga.alerta, isDark: isDark) {
            FrilaLPESegmentedControl(
                items: Self.antecedencias,
                selection: $vaga.alertaAntecedenciaMinutos,
                isDark: isDark,
                height: FrilaLPEGeometry.buttonHeightStandard
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(TextosPublicarVaga.alerta)
            .accessibilityIdentifier("alerta-vaga-picker")
        }
    }

    @ViewBuilder
    private func erro(_ texto: String?, id: String) -> some View {
        if let texto {
            Label(texto, systemImage: "exclamationmark.circle.fill")
                .frilaLPEType(FrilaLPEFormType.detail, dynamic: true)
                .foregroundStyle(FrilaLPEColor.dynamicError(isDark: isDark))
                .accessibilityIdentifier(id)
        }
    }
}
