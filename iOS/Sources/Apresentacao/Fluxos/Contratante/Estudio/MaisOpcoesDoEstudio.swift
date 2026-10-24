import FrilaDominio
import SwiftUI

/// "Mais opções" no fim do estúdio: rateio dos 10%, observações e alerta de vaga vazia, campos do
/// contrato que o Estúdio da origem não desenhou. O cartão-linha é o do protótipo midfi da origem
/// (`Publicar.dc.html`: título, apoio em cinza e chevron), que lá levava à tela `MaisOpcoes.dc.html`;
/// aqui ele abre no lugar, com o assentamento dos containers que expandem (`FrilaMotion.disclosure*`).
/// Os campos usam as peças do formulário da origem (linha Sim/Não, campo rotulado, segmentado) e os
/// mesmos textos e identificadores do formulário antigo. O traje fica na etapa Turno, onde a origem o pôs.
struct MaisOpcoesDoEstudio: View {
    @Bindable var vaga: PublicarVagaViewModel
    let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @FocusState private var observacoesEmFoco: Bool

    /// Antecedências do alerta de vaga vazia (minutos), na ordem crescente do protótipo midfi.
    private static let antecedencias: [FrilaSegmentedItem<Int>] = [
        FrilaSegmentedItem(tag: 120, title: TextosPublicarVaga.alertaDuasHoras),
        FrilaSegmentedItem(tag: 180, title: TextosPublicarVaga.alertaTresHoras),
        FrilaSegmentedItem(tag: 360, title: TextosPublicarVaga.alertaSeisHoras)
    ]

    /// Aberto pelo usuário, pela restauração (campos preenchidos) ou por um erro que mora aqui dentro.
    private var aberto: Bool {
        vaga.mostrandoMaisOpcoes || vaga.erros[.observacoes] != nil || vaga.erros[.rateio] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cabecalho

            if aberto {
                VStack(alignment: .leading, spacing: FrilaGeometry.space20) {
                    rateio
                    observacoes
                    alerta
                }
                .padding(.horizontal, FrilaGeometry.space16)
                .padding(.top, FrilaGeometry.space8)
                .padding(.bottom, FrilaGeometry.space20)
                .transition(.opacity.animation(FrilaMovimento.animacao(FrilaMotion.contentFadeIn, reduzir: reduzirMovimento)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrilaColor.dynamicFormCardSurface(isDark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FrilaGeometry.radiusCard, style: .continuous)
                .strokeBorder(FrilaColor.dynamicFormCardBorder(isDark: isDark), lineWidth: 1)
        }
        .frilaFormLift(isDark: isDark)
        .frilaDisclosureDrop(isOpen: aberto, reduceMotion: reduzirMovimento)
        .disabled(vaga.camposBloqueados)
    }

    /// Cartão-linha do midfi: título, apoio e chevron. Fechado aponta para baixo; aberto, para cima.
    private var cabecalho: some View {
        Button {
            let curva = aberto ? FrilaMotion.disclosureCollapse : FrilaMotion.disclosureExpand
            withAnimation(FrilaMovimento.animacao(curva, reduzir: reduzirMovimento)) {
                vaga.mostrandoMaisOpcoes.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: FrilaGeometry.space8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: TextosPublicarVaga.maisOpcoes)
                        .frilaType(FrilaFormType.input, dynamic: true)
                        .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: TextosPublicarVaga.maisOpcoesAjudaEstudio)
                        .frilaType(FrilaFormType.detail, dynamic: true)
                        .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(FrilaFonteDoSistema.fonte(size: 15, weight: .semibold))
                    .foregroundStyle(FrilaColor.dynamicTextMuted(isDark: isDark))
                    .rotationEffect(.degrees(aberto ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FrilaGeometry.space16)
            .padding(.vertical, FrilaGeometry.space8)
            .frame(maxWidth: .infinity, minHeight: FrilaGeometry.buttonHeightProminent, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TextosPublicarVaga.maisOpcoes)
        .accessibilityHint(TextosPublicarVaga.maisOpcoesAjudaEstudio)
        .accessibilityValue(aberto ? TextosPublicarVaga.maisOpcoesAberto : TextosPublicarVaga.maisOpcoesFechado)
        .accessibilityIdentifier("mais-opcoes-botao")
    }

    private var rateio: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space8) {
            FrilaJobFormYesNoRow(title: TextosPublicarVaga.rateio, isOn: $vaga.participaRateioOuNao, isDark: isDark)
                .accessibilityIdentifier("rateio-vaga-campo")
            erro(vaga.erros[.rateio], id: "erro-publicacao-rateio")
        }
    }

    private var observacoes: some View {
        VStack(alignment: .leading, spacing: FrilaGeometry.space8) {
            FrilaJobFormLabeledField(label: TextosPublicarVaga.observacoes, isDark: isDark, support: TextosPublicarVaga.observacoesAjuda) {
                TextField(TextosPublicarVaga.observacoes, text: $vaga.observacoes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($observacoesEmFoco)
                    .accessibilityIdentifier("observacoes-vaga-campo")
                    .frilaType(FrilaFormType.input, dynamic: true)
                    .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))
                    .padding(.horizontal, FrilaGeometry.space14)
                    .padding(.vertical, FrilaGeometry.space14)
                    .frame(maxWidth: .infinity, minHeight: FrilaGeometry.buttonHeightProminent, alignment: .topLeading)
                    .background(FrilaColor.dynamicFormFieldSurface(isDark: isDark))
                    .clipShape(RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FrilaGeometry.radiusInput, style: .continuous)
                            .strokeBorder(
                                vaga.erros[.observacoes] == nil ? FrilaColor.dynamicFormFieldBorder(isDark: isDark) : FrilaColor.dynamicError(isDark: isDark),
                                lineWidth: vaga.erros[.observacoes] == nil ? 1 : 1.5
                            )
                    }
                    .frilaFormField(id: "observacoes-vaga-campo", isFocused: observacoesEmFoco, onDismiss: { observacoesEmFoco = false })
            }
            erro(vaga.erros[.observacoes], id: "erro-publicacao-observacoes")
        }
    }

    private var alerta: some View {
        FrilaJobFormLabeledField(label: TextosPublicarVaga.alerta, isDark: isDark) {
            FrilaSegmentedControl(
                items: Self.antecedencias,
                selection: $vaga.alertaAntecedenciaMinutos,
                isDark: isDark,
                height: FrilaGeometry.buttonHeightStandard
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
                .frilaType(FrilaFormType.detail, dynamic: true)
                .foregroundStyle(FrilaColor.dynamicError(isDark: isDark))
                .accessibilityIdentifier(id)
        }
    }
}
